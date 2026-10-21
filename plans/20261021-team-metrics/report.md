# Report — /devkit:report team metrics (P-37)
Plan: `plans/20261021-team-metrics/plan.md` · Status: in progress (one PR per phase)

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

