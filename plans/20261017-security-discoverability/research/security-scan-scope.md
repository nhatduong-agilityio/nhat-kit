# Research: scope for /devkit:security-scan vs built-in /security-review

Date: 2026-10-17 · Claude Code docs checked live; tool versions not pinned.

## Conclusion
Built-in `/security-review` is a diff-only, LLM-based code review of the current branch against origin's default branch. It is not a whole-repo audit, a dependency-advisory check, or a git-history secret scan. `/devkit:security-scan` should fill exactly that gap: project-wide, deterministic, tool-backed checks (dependency advisories, secrets in tree and history, repo-hygiene), reported in one severity table. It should never re-review code logic (injection, authz, crypto), because `/security-review` already does that.

## (1) What /security-review covers
- Commands page: "Analyze the changes on your current branch... Reviews the diff between your branch and origin's default branch, identifying risks like injection, auth issues, and data exposure." Needs an `origin` remote (fails with `ambiguous argument` if `origin/HEAD` is missing).
- The upstream prompt (anthropics/claude-code-security-review, `.claude/commands/security-review.md`) builds scope from `git diff --merge-base origin/HEAD`, `git diff --name-only origin/HEAD...`, and `git log origin/HEAD...`. So: pending branch changes only, never the whole repo, never history.
- Vuln classes (README): injection (SQL, command, LDAP, XPath, NoSQL, XXE), authn/authz, data exposure (hardcoded secrets, PII logging), crypto, code execution (deserialization, eval), XSS, input validation, business-logic races, config (CORS, headers), supply chain (vulnerable deps, typosquatting) as an LLM judgement.
- Explicit exclusions in the prompt: DoS, rate limiting, secrets stored on disk (handled by other processes), memory-safety, test-only files, log spoofing, path-only SSRF, regex injection, most GitHub Actions issues. Confidence floor 0.8 (only 8+/10 survive). Severity HIGH/MEDIUM/LOW with file, line, category, exploit scenario, fix.
- Dependencies: the README lists "vulnerable dependencies" only as a category the model may notice in the diff. It does NOT run an advisory database lookup and does not walk lockfiles outside the diff. Secrets in git history: not covered (diff only, and "secrets on disk" is excluded).
- Related: the `security-guidance` plugin (docs) reviews the session's own edits as they happen; neither one is a project audit.

## (2) Dependency advisories per ecosystem
| Ecosystem | Command | Ships with toolchain? | JSON | Exit codes |
| --- | --- | --- | --- | --- |
| npm | `npm audit --json [--omit=dev] [--audit-level=high]` | Yes | `--json` | 0 = no vulns at/above `audit-level`; non-zero otherwise. Needs registry network and a lockfile (or `--no-package-lock`). |
| pnpm | `pnpm audit --json [--prod] [--audit-level high]` | Yes (with pnpm) | `--json` | Non-zero when vulns found (docs do not spell out; verify in the project). `--ignore-registry-errors` turns registry 5xx into success. |
| Yarn Berry | `yarn npm audit --json --all --recursive [--severity high]` | Yes (v2+) | NDJSON | Non-zero when vulns found. Defaults to direct deps of the current workspace only, so `--recursive` and `--all` matter. |
| Yarn classic | `yarn audit --json` | Yes (v1) | NDJSON | Exit is a bitmask of severities (from memory; not re-verified). |
| Python | `pip-audit -r requirements.txt --format json` | NO (`pip install pip-audit`, Python 3.10+) | `--format json` | 0 clean, 1 vulns found. With no args it audits the current environment, not the project; use `-r` or a project path. `--strict` fails if collection fails. |
| Rust | `cargo audit --json` | NO (`cargo install cargo-audit`) | `--json` | 1 on vulnerabilities (warnings such as unmaintained do not fail unless `--deny warnings`; from memory). Warning: if `Cargo.lock` is missing it runs `cargo update`, which can execute project code; for untrusted repos use `cargo audit --file <path/Cargo.lock>`. |
| Go | `govulncheck -format json ./...` | NO (`go install golang.org/x/vuln/cmd/govulncheck@latest`) | `-format json` (also sarif, openvex) | Text mode: non-zero on findings. With json/sarif/openvex it exits 0 regardless, so parse the output. Reachability-aware: reports called vulns separately from "informational". |
| Ruby | `bundle-audit check --update --format json` | NO (`gem install bundler-audit`) | `--format json` | Non-zero when vulns found (from memory). `--update` fetches ruby-advisory-db via git; the check itself is offline-capable. |
| Any | `osv-scanner scan source -r --format json .` (also `-L <lockfile>`) | NO (brew, go install, or `docker run ghcr.io/google/osv-scanner`) | `--format json`, to stdout | 0 clean, 1 vulns found, 127 error, 128 no packages found. Covers many lockfile types in one run; best generic fallback. |

Guidance: detect ecosystems by manifest/lockfile (`package-lock.json`, `pnpm-lock.yaml`, `yarn.lock`, `requirements*.txt`/`pyproject.toml`, `Cargo.lock`, `go.mod`, `Gemfile.lock`). Use the toolchain-bundled auditor first (npm/pnpm/yarn). For ecosystems whose tool is missing, use `osv-scanner` if present, otherwise report "skipped: <tool> not installed, install with <cmd>". Never install on the user's behalf (no-new-libraries rule). All of these need network (except bundler-audit with a cached DB), so report "could not reach registry" distinctly from "clean".

## (3) Secret detection without installs
Use `git grep -nIE` (tracked files only, skips binaries, honors .gitignore; add `--untracked` for new files). Do not print matched values; print `file:line` and the rule name, with the value masked to its first 4 chars.
- AWS access key id: `\b(AK[I]A|ASIA|AGPA|AIDA|AROA)[0-9A-Z]{16}\b`
- GitHub tokens: `\b(ghp|gho|ghu|ghs|ghr)_[A-Za-z0-9]{36,}\b` and `github_pat_[A-Za-z0-9_]{50,}`
- Private key blocks: `-----BEG[I]N (RSA |EC |DSA |OPENSSH |PGP )?PRIVATE KEY( BLOCK)?-----`
- Slack: `xo[x][abprs]-[A-Za-z0-9-]{10,}`; Stripe live: `sk_live_[A-Za-z0-9]{20,}`; Google API: `AIza[0-9A-Za-z_-]{35}`; Anthropic/OpenAI style: `s[k]-(ant-)?[A-Za-z0-9_-]{32,}`
- Generic assignment (noisy, rate as low/medium and need review): `(?i)(api[_-]?key|secret|passwd|password|token)\s*[:=]\s*['"][^'"\s]{12,}['"]` (use `git grep -nIiE`; PCRE `-P` is not always compiled in on macOS).
- Hygiene checks: tracked `.env*` (`git ls-files | grep -E '(^|/)\.env($|\.)' | grep -v example`), tracked `*.pem`/`id_rsa`/`*.p12`, and `.gitignore` lacking `.env`.
- History: `git log -p --all -G'<regex>' --pickaxe-regex` or `git grep -E '<regex>' $(git rev-list --all)`. Cost grows with repo size (every commit's patch or tree is read); on large repos it can take minutes and huge memory for the `rev-list` form. Mitigate: prefer `git log --all -p -G` (streams), cap with `--since` or `-n`, or run only on request. A hit in history means "rotate the key", even if removed from HEAD.
- Entropy: no zero-install way to do real entropy checks beyond regex; leave it to gitleaks/trufflehog.
- gitleaks/trufflehog: use only when present (`command -v gitleaks`). gitleaks: `gitleaks git --report-format json --redact -r <file>` for history (it runs `git log -p`) and `gitleaks dir` for files; it exits 1 when leaks are found (default; from memory). Upstream says gitleaks is feature-complete and succeeded by Betterleaks, so do not hardcode a single tool. Always pass `--redact`.

## (4) Severity scale and finding table
Reuse devkit's existing scale (conventions.md, issue labels): critical, high, medium, low, so findings can feed `/devkit:issue` (`severity:*`) without translation. Add `info` for non-actionable notes.
- critical: live-looking credential/private key in tree or history; dependency advisory CVSS >= 9 or marked critical with a reachable/prod path.
- high: advisory high (CVSS 7-8.9) in a production dependency; tracked `.env` with real-looking values.
- medium: moderate advisory; dev-only high advisory; generic secret pattern needing review; missing `.gitignore` entry for secrets.
- low: low advisory, dev-only moderate, test fixtures with fake keys.
- info: tool skipped/not installed, network unavailable, lockfile missing.
Table: `| # | Severity | Category (dep/secret/hygiene) | Location (path:line or package@version) | Finding (masked) | Fix / next step | Source (tool + rule/advisory ID) |`, sorted by severity, plus a header line "Scanned: ecosystems, tools run, tools skipped". Record threshold (e.g. fail at high) in a project file read at run time, per the conventions' "tunable settings" rule. End the agent output with the standard Result block.

## Recommended gap vs /security-review
1. Scope: whole tree + full history + lockfiles. `/security-review` stays the code-logic reviewer for the branch diff; the skill's description should say "for code-logic review of your branch use /security-review".
2. Deterministic tool output (advisory IDs, regex rules), not model judgement; so no overlap on injection/authz/crypto.
3. Report what was not checked (tools missing, offline). Never auto-fix or install.
4. Read-only: the skill needs no side effects, so it can allow model invocation; mask secrets in all output and in any saved report (conventions "scrubbing" rule).

## Sources
- https://code.claude.com/docs/en/commands (security-review entry)
- https://code.claude.com/docs/en/security (related resources: security-guidance, /security-review)
- https://github.com/anthropics/claude-code-security-review (README) and its raw `.claude/commands/security-review.md`
- https://docs.npmjs.com/cli/v10/commands/npm-audit
- https://pnpm.io/cli/audit
- https://yarnpkg.com/cli/npm/audit
- https://github.com/pypa/pip-audit
- https://github.com/rustsec/rustsec/tree/main/cargo-audit
- https://pkg.go.dev/golang.org/x/vuln/cmd/govulncheck and https://go.dev/doc/tutorial/govulncheck
- https://github.com/rubysec/bundler-audit
- https://google.github.io/osv-scanner/output/ and /usage/
- https://github.com/gitleaks/gitleaks
- Items marked "from memory" were not confirmed on an opened page.
