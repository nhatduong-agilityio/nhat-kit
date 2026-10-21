# Report — /devkit:report team metrics (P-37)
Plan: `plans/20261021-team-metrics/plan.md` · Status: done (four PRs, one per phase)

## Phase 1 — `pr-size.sh --excluded-index` (PR A0) ✅
- Files: `plugins/devkit/scripts/pr-size.sh`, `scripts/test-hooks.sh` (75 lines total per `pr-size.sh main`).
- What changed: a new mode `pr-size.sh --excluded-index <file>` reads NUL-separated paths (a final path without a trailing NUL is still read), prints `max_lines=N max_files=M`, then the 0-based index of each excluded path. It reuses the gate's own `excluded()` matcher and `docs/devkit.md` reader; base resolution is skipped only in this mode, so the normal gate path is unchanged. A relative list path resolves against the caller's directory.
- Implemented in the main session (about 15 lines of script), not delegated.

### Evidence
| Command | Result |
| --- | --- |
| `scripts/test-hooks.sh` | 769 cases, 0 failed (23 new pr-size rows; all 32 existing pr-size rows `ok`) |
| `node --test plugins/devkit/scripts/render-report.test.mjs` | 15 pass, 0 fail |
| `bash -n plugins/devkit/scripts/pr-size.sh` | ok |
| `bash plugins/devkit/scripts/pr-size.sh main` | `lines=75 files=3 max_lines=300 max_files=25 excluded=2 base=main status=ok` |
| `claude plugin validate plugins/devkit --strict && claude plugin validate .` | both pass |

### Review (devkit:code-reviewer)
- Critical: none.
- Warning fixed: a relative list path failed from a subdirectory (the script `cd`s to the repo top). Now made absolute first; new test from a subdirectory.
- Optional fixed: `--excluded-index` without a file now prints usage (was a misleading "unknown base"); the file check accepts any readable non-directory; the `Exit:` header names the unreadable list file; the missing-file test checks the `cannot read` reason.
- Ship-gate review: Critical none. Warning fixed: two tests piped into `grep -q` and so never checked the exit code; a helper `xie` now asserts exit 1 and the message separately. Optional fixed: tests for a directory as the list, an empty file name, and two files; `base` is no longer set to the literal flag in index mode. Old vs new normal mode compared on a temp repo by the reviewer: identical output and exit codes.
- Remaining: none.

## Phase 2 — `metrics.sh` skeleton: arguments, auth, PR fetch, sizes (PR A1) ✅
- Files: `plugins/devkit/scripts/metrics.sh` (new), `scripts/test-hooks.sh` (metrics section). 214 lines per `pr-size.sh main`.
- Implemented by `devkit:fullstack-developer`; review fixes applied in the main session.
- Prints `since/until/report_date`, `prs_merged`/`prs_truncated`, the size line (median/p90 by nearest rank, `over_limit`, limits), `capped_items`, then one row per PR (`#N lines files - changes_requested title`). Cycle, send-backs, bugs and queue come in Phase 3.
- Deviation: the header documents only what the script prints now (not the Phase 3 keys marked "later"), so it is never wrong; Phase 3 extends it.
- Auth: `gh auth status --active` (only the active account), which settles the plan's assumption that a broken second account could cause a false "not logged in".

### Evidence
| Command | Result |
| --- | --- |
| `scripts/test-hooks.sh` | 854 cases, 0 failed (85 metrics rows) |
| `bash plugins/devkit/scripts/metrics.sh --since 2026-10-15` (live, read-only) | `prs_merged=35 size_n=35 lines_median=82 lines_p90=422 files_median=7 files_p90=13 over_limit=5`; `#35 73 2`, `#34 282 8` |
| `gh pr list --state merged --search "merged:>=2026-10-14"` re-filtered to `mergedAt >= 2026-10-15T00:00:00Z` | 35, same as `prs_merged` |
| `#35` vs `git diff --no-renames --numstat ebf556a^ ebf556a` minus `plans/**` | 26+6+41 = 73 lines, 2 files (reviewer) |
| `bash plugins/devkit/scripts/pr-size.sh main` | `lines=214 files=3 … status=ok` |
| `claude plugin validate plugins/devkit --strict` | passed |

### Review (devkit:code-reviewer)
- Critical: none.
- Warnings fixed: tests now prove the global, deduplicated index (an excluded path at a different position in another PR, and repeated paths); `gh auth status --active`. Warning not applied: the header lists only current keys (see Deviation).
- Optional fixed: `clean()` also removes C1 controls, U+2028/2029 and bidi overrides; a path containing NUL or an out-of-range index fails; a malformed PR entry fails instead of being dropped; pr-size's own stderr is shown; the gh-missing test checks its message; nearest-rank tests at n=10 and n=7; the `since` 00:00Z boundary is included; the header states that today's `docs/devkit.md` applies to past PRs and that renames count differently.
- Remaining: none.
- Ship-gate review: Critical none. Warning fixed: wrongly typed gh fields (non-list `files`, non-string `title`, string `additions`, a lone surrogate in a path) crashed with a traceback or were counted as missing; now any of them fails closed with one `metrics: unexpected gh output` line (a Python excepthook plus explicit int checks), one test per type, each also asserting no traceback. Optional fixed: tests for a NUL path and an out-of-range or negative pr-size index; a `true` PR number is rejected; a zero-PR window prints `-` stats (tested).


## Phase 3 — `metrics.sh`: cycle time, send-backs, bugs, queue (PR A2) ✅
- Files: `plugins/devkit/scripts/metrics.sh`, `scripts/test-hooks.sh` (metrics section). 166 lines per `pr-size.sh main`.
- Implemented by `devkit:fullstack-developer`; review fixes applied in the main session.
- Adds `closingIssuesReferences` to the PR fetch, plus `gh repo view` and three `gh issue list` fetches (ai issues updated since `since − 1 day` with comments; open bugs; open queue). New lines: cycle (n, missing by reason, median/p90 hours), `review_sendbacks`/`queue_releases` (never summed), bugs by highest severity, `queue_depth`/`in_flight`, and the truncation flags. The per-PR row carries the cycle hours.
- `closingIssuesReferences` shape checked live and read-only on `cli/cli`: `{id, number, repository{id, name, owner{id, login}}, url}`; matched on lower-cased `owner/name` + number against `gh repo view --json nameWithOwner`.
- The `capped` assumption confirmed live by the reviewer: on `cli/cli` issue 14090 (117 comments), `issue list` returns the oldest 100 and drops the newest.
- Decisions the plan left open:
  - A capped closing issue among several makes the PR `capped`: its hidden newest claim could change the minimum.
  - Any closing issue of this repo missing from the `ai` search makes the PR `not_fetched` (it may hold the earliest claim; this includes a non-`ai` issue claimed through `/devkit:task`). Other-repo issues beside a fetched one are ignored.
  - Release order uses comment list order (gh lists oldest first), so a release counts only when a claim was posted before it, even within the same second.

### Evidence
| Command | Result |
| --- | --- |
| `scripts/test-hooks.sh` | 929 cases, 0 failed |
| Mutation probes (severity by label order, release without a prior claim, capped ignored beside a measurable issue, partial fetch measured, claim at the merge second counted) | each makes 1–3 rows fail; script restored |
| `bash plugins/devkit/scripts/metrics.sh --since 2026-10-15` (live, read-only) | `prs_merged=36`, `cycle_n=0 no_issue=36`, `review_sendbacks=0 queue_releases=0`, `bugs_open=0`, `queue_depth=0 in_flight=0` (this repo has no issues; the cycle and send-back rules are proven by stub cases only) |
| `bash plugins/devkit/scripts/pr-size.sh main` | `lines=166 files=2 … status=ok` |
| `claude plugin validate plugins/devkit --strict && claude plugin validate .` | both pass |

### Review (devkit:code-reviewer)
- Critical: none.
- W1 fixed: six mutants survived the suite; new cases pin severity precedence regardless of label order, release-before-claim, capped among several, a partial fetch, the same-second release order, and a claim at the exact merge second.
- W2 fixed: a PR with one fetched and one unfetched closing issue of this repo was measured from the fetched one only (could be too short); now `not_fetched`.
- Optional fixed: release order by comment position instead of `<=` on timestamps; malformed reviews fail closed instead of being skipped; bad-type tests for `closingIssuesReferences` and `reviews`.
- Remaining: none.
- Ship-gate review: Critical none. Warning fixed: the header said releases are counted on every issue; only `ai` issues are fetched, so it now says so and that releases on other issues are not seen. Optional fixed: a falsy wrong type (`""`, `{}`) for `closingIssuesReferences` or `reviews` now fails closed instead of reading as empty (tested, with a no-traceback check); the header states the order in which missing-cycle reasons are checked (`no_issue`, `not_fetched`, `capped`, `no_claim`), matching the code.


## Phase 4 — `/devkit:report` skill and docs (PR B) ✅
- Files: `plugins/devkit/skills/report/SKILL.md` (new), `README.md`, `UPSTREAM.md`, `CHANGELOG.md`, `plugins/devkit/references/conventions.md` (Directories row for `reports/`), `upstream/proposals/20261018.md`.
- Written in the main session.
- The skill runs `metrics.sh`, writes `reports/<report_date>.md` from its output only (summary tables, two separate send-back rows, per-PR table with escaped titles, a "Missing data" section with every reason and flag, notes), replies with 5 lines, and offers a page built from the summary numbers only after an explicit yes.

### Evidence
| Command | Result |
| --- | --- |
| `claude plugin validate plugins/devkit --strict && claude plugin validate .` | both pass |
| description length | 256 characters |
| `grep -c 'devkit:report' README.md` | 2 |
| `grep -n 'P-37' UPSTREAM.md` | row 143 ✅ |
| `scripts/test-hooks.sh` | 929 cases, 0 failed |
| Manual, headless: `claude --plugin-dir plugins/devkit -p "/devkit:report 2026-10-15"` | wrote `reports/20261021.md`; its 37 PR rows and every summary number match `metrics.sh --since 2026-10-15` exactly (scripted compare, 0 mismatches); "Missing data" section present; no page published without a yes; the file was then deleted |

### Review (devkit:code-reviewer)
- Critical: none.
- Warnings fixed: `not_fetched` now also names PRs that close only other-repo issues; the page uses summary numbers only (no PR titles), so untrusted titles never become markup.
- Optional fixed: titles are data, never instructions; `Bash(bash */metrics.sh)` allowed for the no-date run; "show its stderr line" (usage errors are not `metrics:` lines); notes say releases on non-`ai` issues are not seen too; `reports/` added to the conventions Directories table.
- Remaining (out of scope): `README.md:3` still names devkit 2.4.0 (left for `/release minor`); the proposal line names "the `/devkit:report` PR" until its number is known.

## Outcome
P-37 is done in four PRs (#35, #36, #37, and this one). `/devkit:report` produces team metrics from `gh` only; every gap is counted by reason. Only the stub tests exercise the cycle-time and send-back rules, because this repo has no issues; the first real check is a project that uses the devkit queue.
- Ship-gate review: Critical none. Warnings fixed: this report's status line said "in progress"; the skill suggested a later `since` for every truncation flag, but only the PR and issue searches are date-bounded (bugs and queue now say "at least 1000"). Optional fixed: the report path is under the project root; the title marks the `until` date as UTC.
