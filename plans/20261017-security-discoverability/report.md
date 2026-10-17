# Report: security-discoverability

Plan: `plan.md` (Phases 1-5 plus 4b, added on a user decision during cook). Branch `feat/security-discoverability`, not committed.

## Phases completed
| Phase | Result |
| --- | --- |
| 1 — P-15 test-hooks table | done |
| 2 — P-6 `/devkit:llms` | done; second-run overwrite prompt not verified (interactive only) |
| 3 — P-14a `security-scanner` agent | done; tool behavior recorded below |
| 4 — P-14b `/devkit:security-scan` | done; headless run exposed 28 permission denials, which led to 4b |
| 4b — deterministic scan in `scan-secrets.sh` | done; final headless run has 0 denials |
| 5 — docs and counts | done |

## Files changed
- New: `plugins/devkit/skills/llms/SKILL.md`, `plugins/devkit/skills/security-scan/SKILL.md`, `plugins/devkit/agents/security-scanner.md`, `plugins/devkit/scripts/scan-secrets.sh`.
- Changed: `scripts/test-hooks.sh`, `plugins/devkit/references/conventions.md` (2 Directories rows), `plugins/devkit/templates/gitignore-additions.txt`, `plugins/devkit/skills/review/SKILL.md`, `plugins/devkit/skills/check/SKILL.md`, `README.md`, `UPSTREAM.md`, `CHANGELOG.md`, `plugins/devkit/.claude-plugin/plugin.json`, `.claude-plugin/marketplace.json`.

## Evidence (final state)
| Command | Result |
| --- | --- |
| `scripts/test-hooks.sh; echo exit=$?` | `129 cases, 0 failed`, `All hooks passed.`, `exit=0` (82 hook cases + 47 scan-secrets cases) |
| `scripts/test-hooks.sh >/dev/null; echo exit=$?` (the `release.sh:31` call) | `exit=0` |
| Negative check (`.env blocked` expected 0) | one row `FAIL protect-files .env blocked 0 2 18 Blocked by devkit: /r/.env …`, `125 cases, 1 failed`, `exit=1` |
| `scripts/test-hooks.sh \| LC_ALL=C grep -c '[^ -~]'` | `0` |
| `/bin/bash -n plugins/devkit/scripts/scan-secrets.sh` | ok |
| `claude plugin validate plugins/devkit --strict && claude plugin validate .` | `✔ Validation passed` ×2 |
| Description lengths (llms, security-scan, security-scanner) | 153, 233, 237 |
| Stop-list gate (`AK[I]A`, `gh[p]_`, `xo[x]`, `-----BEG[I]N`, `s[k]-`, `password=`, `secret=`, `api_key`) on the added diff lines and the new files | 0 matches |
| Skills / agents count | 19 / 10; README `19 commands` ×2; plugin.json and marketplace.json descriptions identical |
| llms fixture (`llms-fx`, no origin/HEAD) | `# ` ×1, `> ` ×1, no relative links, `raw.githubusercontent.com/example/fx/main/` ×3, no staging/internal/.env/wip |
| Final headless `/devkit:security-scan` (fixture `fx9`, `acceptEdits` + narrow `--allowedTools`, no bypass) | 0 permission denials; script modes used: scan, `--sinks`, `--check` ×2 rules; only Read was `src/q.js`; 1 report file; rows: critical `src/config.js:1` `AK[I]A****`, critical `minimist` advisory, high `.env` tracked, medium `.env` not ignored, medium sink `src/q.js:1`, low `test/fixture.js:1` |
| Planted bodies (16, 36, 20 chars) in transcript and report | full 0, 12-char prefix 0 for each |
| Ignore warning (Phase 4 run a, before 4b) | warned and asked; `ls security-scan` → absent |
| `PATH=/usr/bin:/bin` run (Phase 4, before 4b) | report row `info … npm audit … npm missing` |

## Review
`devkit:code-reviewer`: 0 Critical, 6 Warning, 8 Optional. Fixed:
- W1 `--check` turned errors into 0. Now it uses literal pathspecs, requires a tracked path, and exits 2 on error; the skill keeps the row on error.
- W2 C-quoted and newline paths. Now `ls-files -z`; newline/control paths get an `info` row; nested untracked `.env` is reported.
- W3 and W4 the sink pass could print full lines and used made-up regexes. Now `--sinks` mode has POSIX rules with self-tests, excludes flagged paths, and prints `path:line<TAB>name` only.
- W5 literal stop-list strings in plan files. Now bracketed.
- W6 evidence covered only Phase 3. Now this report.
- Optional 1 (severity text), 3 (multi-word rule), 4 (column width), 5 (fixture git config), 6 (edge-case tests), 7 (`<root>` paths), 8 (SSH origins).

Remaining Optional 2 is folded into W2: nested `.env` is now covered.

Ship-gate review (`/devkit:ship` gate 6): 0 Critical, 3 Warning, 5 Optional. Fixed W1 (root `.env` reported twice), W2 (`.envrc` and `.env*/` directories flagged; now basename-anchored), and W3 (re-check paths are single-quoted, and unusual paths skip the re-check). Also fixed Optional 1, 2, 3 and 5 (agent copies `info`/`# sinks:` rows as is; `--sinks` reports how many flagged files it skipped; usage comment). Kept Optional 4: CR/LF shown as ` / ` is the planned display.

## Out of scope / open
- Interactive checks not run: the llms second-run diff prompt, and the security-scan `AskUserQuestion` (headless asked in plain text instead).
- Tools not installed here and therefore unverified: osv-scanner, cargo-audit, gitleaks. `gitleaks dir` merging was dropped when the secret pass moved into the script; the report points to `gitleaks git` for history.
- Phase 3 and early Phase 4 headless runs used `bypassPermissions` inside scratch fixtures only. The final run used none.

## Phase 3 — tool behavior

Observed on macOS (Darwin 25.5, git 2.49, system awk 20200816), fixture `scan-fx` with `minimist@1.2.0` in `package-lock.json`.

### npm audit --json
- Vulnerable: exit 1. Top-level `auditReportVersion` (2), `vulnerabilities`, `metadata`. `vulnerabilities.minimist` has `severity` (critical), `isDirect`, `via[]` (objects with `title`, `url`, `severity`, `cvss.score`, `range`; transitive entries are strings), `range`, `fixAvailable`. `metadata.vulnerabilities` counts `info/low/moderate/high/critical/total`.
- Clean: exit 0, `vulnerabilities: {}`, all counts 0.

### Other tools (`command -v`)
| Tool | Found | Observed behavior |
| --- | --- | --- |
| pnpm | 10.7.1 | `pnpm audit --json` on a vulnerable lockfile: exit 1; keys `actions`, `advisories`, `muted`, `metadata`; advisory has `module_name`, `severity`, `title`, `url` |
| yarn | 1.22.22 (classic) | `yarn audit --json`: exit 20 (bitmask) when vulnerable; NDJSON `type` = `auditAdvisory` / `auditSummary` plus `warning` lines |
| osv-scanner | not found | unverified; agent relies on parsed output |
| cargo, cargo-audit | not found | unverified; agent relies on parsed output |
| gitleaks | not found | unverified; agent relies on parsed output |

### Findings that changed the design
- macOS awk cannot split on NUL (`awk -F'\0'` printed `s:r:c****`). The agent uses `tr '\0' '\037' | awk -F'\037'`; with `-z -n -o`, fields are `path NUL line NUL match`.
- Rules starting with `-` (private-key header) need `grep -e`; the agent file says so.
- Tools that did not run now get their own `info` row (`not run: <tool> <reason>`); run 1 only mentioned them in prose.

### Proof run
- Both validate commands passed. The literal-prefix gate (`gh[p]_|AK[I]A|-----BEG[I]N|xo[x]` plus git-manager's substrings) → no output.
- Headless `claude --plugin-dir … -p --output-format stream-json --verbose` (with `--permission-mode bypassPermissions`, in the scratch fixture only) invoked `devkit:security-scanner`. The transcript includes the subagent's own tool calls and results (9 messages with `parent_tool_use_id`).
- Planted bodies (16, 36, 20 chars), re-checked by the main session: `full=0 p12=0` for each.
- The only `Read` the scanner made was `src/q.js` (sink context), not a flagged path.
- Final answer rows: critical `src/config.js:1` (`AK[I]A****`); critical advisory `minimist` (GHSA-xvch-5gv4-984h); high `.env` tracked; medium `.env` not ignored; medium sink `src/q.js:1`; low `test/fixture.js:1`; three `info: not run:` rows; the `/security-review` + `gitleaks git` line; `## Result`.
