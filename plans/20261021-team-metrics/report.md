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
