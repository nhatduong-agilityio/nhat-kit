# Security scan, llms.txt generator, and hook diagnostics
Status: done · Source: `upstream/proposals/20261009b.md` Space A: P-15 (hook diagnostics, :19), P-6 (`/devkit:llms`, :17), P-14 (`/devkit:security-scan`, :18) · Decisions: user, 2026-10-17 (Space A full; OWASP via grep-guided sink pass)

## Goal
`scripts/test-hooks.sh` prints one row per case: hook, case, expected/got exit, duration in ms, and the first stderr line on failure. Its exit semantics stay the same. `/devkit:llms` writes a spec-shaped `llms.txt` for a project. `/devkit:security-scan` and the new `security-scanner` agent produce a redacted whole-project report covering dependency advisories, secrets in the tracked tree, sensitive tracked files, and dangerous code sinks. It complements the built-in `/security-review`, which is an LLM review of the branch diff only.

## Context found
- `scripts/test-hooks.sh:3` has `set -u`. `:10-14`: `expect()` sends stderr to `/dev/null` and prints `ok`/`FAIL`. `:16-20`: `bash_cmd` builds JSON with `python3`. `:139-140`: notify is checked outside `expect`. `:142-143`: summary and `exit "$fail"`. Case names contain newlines and `|`.
- `scripts/release.sh:31` runs `scripts/test-hooks.sh >/dev/null` and checks only the exit code. `release.sh --dry-run` exits at `:27`, before that line.
- On this machine `/usr/bin/env bash` resolves to `/bin/bash` 3.2.57, and `which -a bash` lists only `/bin/bash`. The `time` keyword with `TIMEFORMAT=%3R` works on 3.2 and keeps the exit status (`{ time (exit 3); } 2>/dev/null; echo $?` → 3).
- `plugins/devkit/scripts/protect-files.sh:19-26`: sensitive-file `case` arms for `.env*` (sample files allowed) and `*.pem|*.key|*.p12|*.keystore|id_rsa|id_ed25519`. The stderr reasons contain `environment file` / `key/certificate`.
- `plugins/devkit/agents/git-manager.md:12`: substring list for the pre-commit scan. It **stops** on a match, with no confirm path, so kit files must not contain those literal substrings.
- Patterns to copy: skills `skills/issue/SKILL.md:1-12`, `skills/git/SKILL.md:1-13`, `skills/review/SKILL.md:16` (main session re-checks Critical findings). Agents `agents/code-reviewer.md:1-8`, Result block `references/conventions.md:142-153`, tiers `README.md:35-39`. Severity labels `critical|high|medium|low` are in `conventions.md:111`. `skills/issue/SKILL.md:14` accepts a findings file.
- On git 2.49 / macOS, `git grep -E` and `git log -G` match nothing for `\b` and `\s`. POSIX classes (`[[:space:]]`, `(^|[^A-Za-z0-9_])`) work. A path containing `:` breaks `awk -F:` parsing; `git grep -z` separates fields with NUL. (Technical red-team, verified in a fixture.)
- Touch points: `README.md:3`, `:5-27`, `:29`, `:37-39`, `:208-209`. `UPSTREAM.md:45`, `:48`, `:49`, `:81`. `CHANGELOG.md:5`. `plugins/devkit/.claude-plugin/plugin.json:3`, `.claude-plugin/marketplace.json:11`. `skills/review/SKILL.md:20`, `skills/check/SKILL.md:33`. `templates/gitignore-additions.txt:7-9`.
- Research: `research/llms-txt-spec.md`, `research/security-scan-scope.md`, `research/scout-map.md`.

## Approach
The three items are independent and follow the proposal's order: P-15 → P-6 → P-14. Within P-14 the risk is front-loaded: Phase 3 builds the agent and proves redaction and tool behavior on a fixture before Phase 4 wires up the skill. Counts and descriptions shared across features are edited once, in Phase 5.

Key design choices:
- **Timing (P-15)**: bash `time` keyword with `TIMEFORMAT=%3R`. It is built in on bash 3.2, needs no extra process, and keeps the hook's exit code. There is no provider chain.
- **Secret values never enter context, enforced by tools, not just asked for**: the agent has `tools: Read, Glob, Bash`, with no `Grep`, because the Grep tool prints whole lines. Every secret search is `git grep -z -nIoE` piped through `tr '\0' '\037' | awk -F'\037'` (macOS awk can't split on NUL; found in Phase 3) (path, line, rule, first 4 chars + `****`). The agent never Reads a path that a secret rule or the sensitive-file check flagged. Fixture/test status is judged from the path only (`test/`, `tests/`, `fixtures/`, `*example*`, `*.sample`), never from the value.
- **Regex rules are POSIX ERE, written so kit files contain no literal token prefixes** (e.g. `gh[p]_`, `AK[I]A`, `-----BEG[I]N`). This keeps `git-manager`'s pre-commit stop from firing on the kit's own commit. A self-test runs each rule against a runtime-built positive string before the real scan; a rule that misses reports `tool error`, never "clean".
- **Sensitive files use the hook as the oracle**: prefilter `git ls-files` with one cheap regex, then pipe each candidate as `{"tool_input":{"file_path":"<p>"}}` into the given `protect-files.sh`. Exit 2 with `environment file`/`key/certificate` in stderr means a finding. This is deterministic, has no copy, and stays in sync with the hook, which is not changed.
- **Advisories only through tools that don't run repo code**: native `npm audit --json`, `pnpm audit --json`, `yarn audit --json` (classic), and `cargo audit --json --file <tracked Cargo.lock>`. Skip native yarn/pnpm when `.yarnrc.yml` has `yarnPath`, `.pnpmfile.cjs` exists, or `package.json` has a `packageManager` field. Every other ecosystem, and every skipped case, uses `osv-scanner -L <lockfile> --format json` if installed, otherwise `not run: <reason>`. Findings come from parsed output; exit codes only separate "tool error" from "ran".
- **OWASP (user decision)**: a grep-guided whole-project sink pass for `eval`/`exec`/`new Function`, SQL built by string concatenation or interpolation, `dangerouslySetInnerHTML`/`innerHTML =`, `shell=True`/`child_process.exec` with a variable, and disabled TLS verification (`verify=False`, `rejectUnauthorized: false`, `InsecureSkipVerify`). The agent Reads ±5 lines around each hit, but not in flagged secret/sensitive paths, and keeps only plausible ones as `medium`/`low` "review candidates". Deep logic review stays with `/security-review`.
- **Model tier for `security-scanner`: `sonnet`**. It parses several JSON formats, judges sink hits in context, and must redact reliably. The main session re-checks every critical row, as in `review/SKILL.md:16`.
- **Report**: `security-scan/<YYYYMMDD-HHMM>.md` at the project root. `gitignore-additions.txt` gains `security-scan/`. The skill runs `git check-ignore -q security-scan/` **before** writing. If the path is not ignored, it warns, names the line to add, and asks whether to write anyway. It never edits `.gitignore` itself.
- **Severity table lives in the agent file**, not in a plan research file that doesn't ship.

Rejected:
- A 4-step timer fallback (EPOCHREALTIME → perl → python3 → date): process startup dominated the ~5 ms hook times, and `$EPOCHREALTIME` aborts under `set -u` on 3.2.
- `--history` mode: not in P-14. `git log -G` also lists the removing commit, misses merges, and duplicates rows (technical red-team #6). The report instead points to `gitleaks git` plus credential rotation as a next step.
- govulncheck, bundle-audit, pip-audit and Yarn Berry branches: their behavior is unverifiable here, some run code or need a network, and the stack is JS/TS. `osv-scanner -L` covers them when it is installed.
- Repo-hygiene checks (tracked-but-ignored files, manifest without lockfile): noise, and overlap with `/devkit:check`. Only "`.env` exists and is not ignored" is kept, inside the sensitive-file step.
- Reading the globs from `protect-files.sh` as text and having the LLM interpret them: not deterministic. The hook is called as an oracle instead.
- A bash `security-scan.sh` with no agent: every audit JSON needs a parser, and the agent keeps that output out of the main context.

## Phases

### Phase 1 — P-15: structured result table in test-hooks.sh
- [x] Rework `expect()`: write stderr to a `mktemp` file (removed by `trap … EXIT`), and time the call with `TIMEFORMAT=%3R; { time printf '%s' "$4" | "$1" >/dev/null 2>"$err"; } 2>"$tf"`. Take `PIPESTATUS`/`$?` from the hook and convert seconds to integer ms by stripping the non-digits from `%3R`. Bash 3.2 compatible: no `$EPOCHREALTIME`, associative arrays, `${x,,}` or `mapfile`. File: `scripts/test-hooks.sh`.
- [x] Print a header once, then one fixed-width row per case: `RESULT  HOOK  CASE  EXP  GOT  MS  STDERR`. HOOK is the script basename without `.sh`. CASE has CR/LF/tab replaced by ASCII ` / ` and is cut to 48 bytes. STDERR appears only on FAIL: the first line, cut to 80 bytes. Everything is ASCII.
- [x] Route the notify check (`:139-140`) through `expect "$notify" 0 "always exits 0" '{"message":"test"}'`.
- [x] Footer: `N cases, F failed, total T ms`, then the existing `All hooks passed.` / `Some hooks failed.` line. `exit "$fail"` is unchanged.
- [x] Add a 2-line comment at the top describing the columns.
- [x] `UPSTREAM.md:81` → `✅`, "P-15: per-case table (hook, case, exit, ms, first stderr line) in `scripts/test-hooks.sh`". `CHANGELOG.md` `[Unreleased]` → `### Changed`.
- Verify:
  - `/bin/bash -n scripts/test-hooks.sh` → exit 0.
  - `scripts/test-hooks.sh; echo "exit=$?"` → every row `ok`, integer MS column, footer `… 0 failed …`, `exit=0`.
  - `scripts/test-hooks.sh >/dev/null; echo "exit=$?"` → `exit=0` (the call `release.sh:31` makes).
  - Negative check: `sed 's/expect "\$guard" 2 ".env blocked"/expect "$guard" 0 ".env blocked"/' scripts/test-hooks.sh > scripts/_neg.sh && bash scripts/_neg.sh; echo "exit=$?"; rm -f scripts/_neg.sh` → one `FAIL` row: hook `protect-files`, case `.env blocked`, EXP 0, GOT 2, STDERR starting `Blocked by devkit: /r/.env`; then `exit=1`.
  - `scripts/test-hooks.sh | LC_ALL=C grep -c '[^ -~]'` → 0 (ASCII only).

### Phase 2 — P-6: `/devkit:llms` skill
- [x] Create `plugins/devkit/skills/llms/SKILL.md`. Frontmatter: `name: llms`, description (< 300 chars, says when to use: "Generate or refresh the project's llms.txt — a short public index of its docs and API for LLM agents. Use when publishing a library, API, or docs site."), `argument-hint: "[output path]"`, `disable-model-invocation: true`, `allowed-tools: Bash(git ls-files *) Bash(git remote *) Bash(git symbolic-ref *) Bash(git branch *)`.
- [x] Body: one pass with no agent, imperative, written from scratch.
  1. Collect sources from tracked files only (`git ls-files`): README, `docs/**/*.md`, OpenAPI/Swagger specs, route definitions, and package-manifest entry points.
  2. Resolve the base URL. Prefer a docs site from the manifest's `homepage`/docs config. Otherwise, for a GitHub `origin`, use `https://raw.githubusercontent.com/<owner>/<repo>/<branch>/<path>`, where branch = `git symbolic-ref --short refs/remotes/origin/HEAD` (strip `origin/`), else `git branch --show-current`. Otherwise ask. Every link must be absolute.
  3. Build the file in spec order: one `# Name`, a `> summary`, optional short prose, `## <Section>` lists (`- [Title](url): note`), then `## Optional`. Target ≤ ~40 links.
  4. Public-only filter. Exclude `.env*`, and URLs with `localhost`, private IP ranges, or `staging`/`internal`/`dev.` hosts. Exclude pages whose front matter has `draft: true` or that sit under `drafts/`. Name the exclusions in the reply, not in the file.
  5. Write to `$ARGUMENTS` or `./llms.txt`. If the file exists, show a diff and **wait for confirmation** before overwriting.
  6. Reply with the path, the link count, and a reminder to publish at the site root (or docs subpath) and to re-run after doc changes.
- [x] Conventions Directories row: `llms.txt` (project root or given path) · public LLM index of the project's docs · `/devkit:llms`. File: `plugins/devkit/references/conventions.md`.
- [x] `UPSTREAM.md:48` → `/devkit:llms` ✅ "P-6: one-pass llms.txt generator; absolute links, public-only filter". `CHANGELOG.md` `[Unreleased]` → `### Added`.
- Verify:
  - `claude plugin validate plugins/devkit --strict && claude plugin validate .` → pass.
  - `awk '/^description:/{sub(/^description: /,"");print length}' plugins/devkit/skills/llms/SKILL.md` → < 300.
  - Fixture (`F=$(mktemp -d)/fx`): `git init -b main`, `git remote add origin https://github.com/example/fx.git` (no origin/HEAD, so the branch fallback runs), README, `docs/guide.md` linking `http://staging.internal/`, `docs/drafts/wip.md`, `openapi.yaml`, a tracked `.env` with a dummy value. Run `/devkit:llms` via `claude --plugin-dir <kit>/plugins/devkit`. Then:
    - `grep -c '^# ' llms.txt` → 1. `grep -c '^> ' llms.txt` ≥ 1.
    - `grep -oE '\]\([^)]*\)' llms.txt | grep -vE '^\]\(https?://'` → no output (no relative links).
    - `grep -c 'raw.githubusercontent.com/example/fx/main/' llms.txt` ≥ 1.
    - `grep -iE 'staging|internal|localhost|\.env|wip' llms.txt` → no output.
    - A second run shows a diff and asks before overwriting.

### Phase 3 — P-14a: `security-scanner` agent + redaction and tool-behavior proof
- [x] Create `plugins/devkit/agents/security-scanner.md`. Frontmatter: `name: security-scanner`, description ("Run deterministic whole-project security checks — dependency advisories with installed audit tools, secret patterns, sensitive tracked files, dangerous code sinks — and return a redacted finding table. Use from /devkit:security-scan."), `tools: Read, Glob, Bash`, `model: sonnet`. The body is short and imperative (target ≤ ~40 lines), with no literal token prefixes.
- [x] Inputs: project root, path to `protect-files.sh`, conventions path. Rules: read only. Never install, update or fetch anything beyond what an audit tool does itself. Never print or Read a secret value. Never Read a flagged path.
  1. **Rule self-test**: for each secret rule, build a positive string at runtime and pipe it through `grep -E`. A miss reports `tool error: rule <name>` and the scan continues.
  2. **Secrets (tracked tree)**: rules for AWS key id, GitHub tokens, private-key header, Slack, Stripe live, Google API key, `s[k]-`-style keys, and a generic `(password|secret|api_?key|token)[[:space:]]*[:=]` rule (`-i`). Each runs `git grep -z -nIoE '<re>' | awk -F'\0' '{print $1":"$2":"substr($3,1,4)"****"}'`. With `gitleaks` present, also run `gitleaks dir --redact` and merge by location.
  3. **Sensitive tracked files**: `git ls-files | grep -E '(^|/)\.env|\.(pem|key|p12|keystore)$|(^|/)id_(rsa|ed25519)$'`. Pipe each candidate as `{"tool_input":{"file_path":"<p>"}}` into the given `protect-files.sh`. Exit 2 means a finding (the stderr reason names the kind). A `.env` that exists and fails `git check-ignore -q` is a finding too.
  4. **Advisories**: detect from tracked lockfiles (`package-lock.json`, `pnpm-lock.yaml`, `yarn.lock`, `Cargo.lock`, and others). Use the native tool only per the Approach rules, otherwise `osv-scanner -L`, otherwise `info: not run: <tool> missing | would execute repo code`. A non-zero exit with unparseable output → `info: tool error: <first stderr line>`. A registry/network failure → `info: could not reach registry`, which is distinct from clean.
  5. **Code sinks**: `git grep -nIE` for the Approach's sink list, excluding flagged paths. Read ±5 lines around each hit and keep plausible ones as review candidates.
  6. **Severity** (inline table): critical = live-format secret in a non-test path, or advisory critical. high = private key/`.env` tracked, or advisory high. medium = generic-rule secret, `.env` not ignored, advisory moderate, or a sink with input reaching it. low = test/fixture-path hits, advisory low, or a weak sink candidate. info = not run, tool errors.
  7. **Output**: a `Scanned:` line (ecosystems, tools run, tools not run), then `| # | Severity | Category | Location | Finding (masked) | Fix / next step |` sorted by severity, then "Code-logic review of your branch: run /security-review. Secrets in git history: run `gitleaks git` if installed and rotate any credential ever committed." End with the Result block.
- [x] Proof run in a scratch fixture (`F=$(mktemp -d)/scan`, `git init`), recorded in `plans/20261017-security-discoverability/report.md`. Plant values built at runtime only:
  - `src/config.js` with `AK`+`IA` + a random 16-char `[A-Z0-9]` body (not AWS's `…EXAMPLE` key)
  - `test/fixture.js` with a `gh`+`p_` token whose body is 36 random alphanumerics
  - a tracked `.env` with `DB_PASS=<random 20 chars>`
  - `src/q.js` with ``db.query(`SELECT * FROM u WHERE id=${req.query.id}`)``
  - `package.json` + `npm install --package-lock-only minimist@1.2.0`
  - one commit

  Record the actual exit codes and JSON shape of `npm audit --json` (vulnerable and clean), and of every other tool `command -v` finds. Mark tools not on the machine as "unverified; agent relies on parsed output".
- Verify:
  - `claude plugin validate plugins/devkit --strict && claude plugin validate .` → pass.
  - `grep -nE 'gh[p]_|AK[I]A[0-9A-Z]|-----BEG[I]N|xo[x]' plugins/devkit/agents/security-scanner.md` → no output, meaning git-manager will not stop on the kit commit (the bracketed forms are themselves safe).
  - Run `claude --plugin-dir <kit>/plugins/devkit -p --output-format stream-json --verbose "Use the devkit:security-scanner agent on this repo; protect-files path: <kit>/plugins/devkit/scripts/protect-files.sh" > out.jsonl`, which captures tool results too, not just the final answer. If `-p` can't drive a plugin agent, run it interactively and export the transcript.
  - For each planted body (the 16-char AWS body, the 36-char token body, the 20-char `.env` value): `grep -c "<body>" out.jsonl` → 0, and the first 12 chars of each body → 0.
  - The final answer contains:
    - a critical row `src/config.js:1` (`AK[I]A****`)
    - a low row for `test/fixture.js`
    - a high row for `.env`
    - a dependency row naming `minimist`
    - a sink row for `src/q.js`
    - `not run:` lines for missing tools
    - the `/security-review` + `gitleaks git` line
    - `## Result`

### Phase 4 — P-14b: `/devkit:security-scan` skill and wiring
- [x] Create `plugins/devkit/skills/security-scan/SKILL.md`. Frontmatter: `name: security-scan`, description (< 300 chars: "Scan the whole project for leaked secrets, vulnerable dependencies (with audit tools already installed), sensitive tracked files, and risky code sinks; writes a redacted report. For a review of your branch diff, use /security-review."), `disable-model-invocation: true`.
- [x] Body:
  1. Stop if not in a git repo.
  2. Run `git check-ignore -q security-scan/`. If the path is not ignored, warn, show the line to add, and ask whether to write the report anyway.
  3. Delegate to `devkit:security-scanner` with the root, `${CLAUDE_PLUGIN_ROOT}/scripts/protect-files.sh`, and `${CLAUDE_PLUGIN_ROOT}/references/conventions.md`.
  4. Re-check every critical row with `git grep -c -E '<rule>' -- <path>` and `git ls-files -- <path>`, never printing the value. Drop rows that don't reproduce.
  5. Write `security-scan/<YYYYMMDD-HHMM>.md`.
  6. Reply with counts per severity, the top 5 rows, the `not run` items, the report path, and next steps: `/devkit:issue bug <report>` to file findings, `/security-review` for the branch diff. Never auto-fix or install.
- [x] Conventions Directories row: `security-scan/<YYYYMMDD-HHMM>.md` · redacted whole-project security scan (gitignored) · `/devkit:security-scan`, agent `security-scanner`.
- [x] Add `security-scan/` under a `# devkit security scan reports` comment. File: `plugins/devkit/templates/gitignore-additions.txt`.
- [x] `skills/review/SKILL.md:20`: append "for a whole-project scan of dependencies, secrets, sensitive files, and risky sinks, run `/devkit:security-scan`". `skills/check/SKILL.md:33`: add `/devkit:security-scan` to the follow-ups.
- [x] `UPSTREAM.md`: `:45` → `security` row stays ⊘ `/security-review` (branch-diff review). `:49` `security-scan` → `/devkit:security-scan` + agent `security-scanner`, ✅, "P-14: whole-project deps/secrets/sensitive files/sink candidates; deep logic review via built-in /security-review". `CHANGELOG.md` `[Unreleased]` → `### Added`.
- Verify:
  - `claude plugin validate plugins/devkit --strict && claude plugin validate .` → pass. Description < 300 (same `awk`).
  - `scripts/test-hooks.sh` → exit 0.
  - In the Phase 3 fixture, run `/devkit:security-scan` via `claude --plugin-dir <kit>/plugins/devkit` with `--output-format stream-json --verbose` captured. Then:
    - The skill warned that `security-scan/` is not ignored and asked **before** any file existed.
    - After a yes: `ls security-scan/*.md` → 1 file.
    - The planted-body greps from Phase 3 → 0 in both the report and the transcript.
    - The report has the `Scanned:` line, the table, and the deferral line.
  - `PATH=/usr/bin:/bin "$(command -v claude)" --plugin-dir …` run (npm lives under nvm, so it is absent) → the report says `not run: npm missing`.

### Phase 4b — Move the deterministic scan into a script (user decision, 2026-10-17)
Phase 4's headless run showed that the scanner's compound Bash pipelines (`for` loops, `git grep -z | tr | awk`) match no allow rule. The result was 28 permission denials and an incomplete scan, and every call prompts in a default session. Masking also depended on the agent following a prompt.
- [x] Add `plugins/devkit/scripts/scan-secrets.sh <root>` (plain bash 3.2, no new deps). It does the rule self-test, the masked `git grep` per rule, test/fixture-path downgrade, sensitive tracked files via the sibling `protect-files.sh` as oracle, and `.env` not ignored. It prints one TSV row per finding (`severity<TAB>category<TAB>path:line<TAB>masked<TAB>rule`), plus `info` rows for rule self-test failures. It never prints a matched value beyond 4 chars + `****`, and exits 0 except on bad usage (exit 1); `--check` exits 2 on an error or untracked path.
- [x] Tests first, in `scripts/test-hooks.sh`: a temp git fixture with runtime-built AWS-style and GitHub-style values in `src/` and `test/`, a tracked `.env`, a `-----BEG`+`IN … PRIVATE KEY` header, and a path containing `:`. Assert the expected rows/severities and that no full value or its first 12 chars appear in the output.
- [x] `security-scanner.md`: replace steps 1-3 with one call to `bash <scripts dir>/scan-secrets.sh <root>` and turn its rows into table rows. Advisories and sinks stay as single, simple commands (one tool per call, no loops). The skill passes `${CLAUDE_PLUGIN_ROOT}/scripts` instead of the `protect-files.sh` path.
- [x] `security-scan/SKILL.md` step 3: pass the scripts dir. Mention once that the user can allow `Bash(bash */scan-secrets.sh *)` to skip the prompt.
- Verify:
  - `scripts/test-hooks.sh` → exit 0, new scan-secrets rows `ok`.
  - The validate commands pass; the literal-prefix gate on the script, agent, and skill → no output.
  - Headless run in a fresh copy of the Phase 3 fixture, with `security-scan/` excluded: `claude --plugin-dir … -p "/devkit:security-scan" --output-format stream-json --verbose --permission-mode acceptEdits --allowedTools "Bash(bash *scan-secrets.sh *)" "Bash(npm audit *)" "Bash(git grep *)" "Bash(git ls-files *)" "Bash(git check-ignore *)" "Bash(git rev-parse *)" "Bash(command -v *)"`. Expect 0 permission denials (or list each one left), a critical `src/config.js:1` row, a `minimist` row, and planted-body greps (full and 12-char) → 0 in both the report and the transcript.

### Phase 5 — Cross-cutting docs and counts
- [x] `README.md`:
  - `:3` → 19 commands, 10 subagents.
  - Commands table: add `/devkit:llms [path]` (—) and `/devkit:security-scan` (`security-scanner`).
  - `:29` → add `llms`, `security-scan` to the manual-only list.
  - `:38` → add `security-scanner` to the sonnet tier.
  - `:208-209` → 19 / 10.
- [x] `plugins/devkit/.claude-plugin/plugin.json:3` and `.claude-plugin/marketplace.json:11`: add `security-scan, llms`, with identical text in both.
- [x] `CHANGELOG.md` `[Unreleased]`: read it through once. It needs one entry each for P-15/P-6/P-14, with no duplicates.
- Verify:
  - `claude plugin validate plugins/devkit --strict && claude plugin validate .` → pass.
  - `ls -d plugins/devkit/skills/*/ | wc -l` → 19. `ls plugins/devkit/agents/*.md | wc -l` → 10.
  - `grep -c '19 commands' README.md` → 2. `grep -n 'security-scanner' README.md` → tier row + commands row.
  - `diff <(jq -r .description plugins/devkit/.claude-plugin/plugin.json) <(jq -r '.plugins[0].description' .claude-plugin/marketplace.json)` → no output.
  - `scripts/test-hooks.sh` → exit 0.

## Risks
| Risk | Signal | Mitigation |
| --- | --- | --- |
| A secret value leaks into the agent's context or the report | Phase 3/4 stream-json grep for the planted bodies (full and 12-char prefix) hits | No Grep tool; only `git grep -z -o` + awk mask; no Read on flagged paths; fixture status from path only. The transcript grep is a gate |
| A regex silently matches nothing (GNU-only escapes) | Rule self-test reports `tool error` | POSIX ERE only; a self-test per rule before the scan |
| An audit tool executes repo code (`yarnPath`, `.pnpmfile.cjs`, corepack `packageManager`, `cargo update`) | Network/build activity; new files | Skip native yarn/pnpm in those cases; cargo only with `--file <tracked Cargo.lock>`; else `osv-scanner -L` or `not run` |
| Unverified exit codes / JSON shapes for tools not installed here | Rows show `tool error` on a vulnerable project | Findings from parsed output only; Phase 3 records observed behavior; the rest is marked unverified in `report.md` |
| Sink pass is noisy | Many low rows in a normal repo | Context read keeps plausible hits only; severity capped at medium; labeled "review candidates" |
| `git-manager` stops the kit's own commit | `/devkit:git cm` stops on `security-scanner.md` | Bracketed regex forms; the Phase 3 grep gate proves none of the literal prefixes are present |
| `test-hooks.sh` output change breaks a consumer | `release.sh` fails | Only `release.sh:31` consumes it, discarding stdout; exit unchanged; Phase 1 runs that exact call |
| Headless `-p` can't drive a plugin agent or manual-only skill | Empty or "unknown command" output | Interactive run with an exported transcript |

## Out of scope
- Deep code-logic security review (authz, crypto, business logic). Left to the built-in `/security-review`.
- Git-history secret scanning (pointed to `gitleaks git` in the report), entropy detection, auto-fix, installing tools, a CI/threshold mode, an allow-list file.
- Native govulncheck / bundle-audit / pip-audit / Yarn Berry support (covered by `osv-scanner -L` when installed).
- Unifying `git-manager.md:12`'s list with the scanner's rules.
- `llms-full.txt`, link-checking `llms.txt` in CI.
- Hook diagnostics beyond the table (logs, `-v`, the LLM judge from P-7).
- `UPSTREAM.md:13` stale version row (updated by `/release`).

## Decisions needed
1. **Report location**: `security-scan/<YYYYMMDD-HHMM>.md`, gitignored; warn only, never edit `.gitignore` (recommended).
2. **llms.txt links for a GitHub repo without a docs site**: `raw.githubusercontent.com` markdown URLs (recommended), or `github.com/.../blob/...` HTML pages.

## Red-team notes
Applied: scope 1-5, 7-12; technical 1-5, 7-14 (15 moot after dropping bundle-audit). Merged: scope 6 (inline globs) and technical 7 (hook as oracle). Took the oracle, since it removes both the copy and the LLM interpretation. Rejected:
- Technical 6 (fix history-mode semantics): moot, history mode was cut (scope 2), and the reasons are recorded under Rejected.
- Scope 5's "state the drop" alternative: the user chose the grep-guided sink pass.
