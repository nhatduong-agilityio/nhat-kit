# Report: PR size gate with project-doc limits (P-27)

Plan: `plan.md` (3 phases, --fast). Branch `feat/pr-size-gate`, not committed.

## Phases completed
| Phase | Result |
| --- | --- |
| 1: settings doc and counting script, tests first | done. Tests were written first; 26 rows failed while the script was missing |
| 2: wire into ship, task, review, conventions, bootstrap | done by the main session (one-line edits) |
| 3: docs | done |

## Files changed
- New: `plugins/devkit/scripts/pr-size.sh`, `plugins/devkit/templates/docs/devkit.md`.
- Changed:
  - `scripts/test-hooks.sh` (pr-size section)
  - `plugins/devkit/skills/{ship,task,review,bootstrap}/SKILL.md` (plus `task`'s allowed-tools)
  - `plugins/devkit/references/conventions.md` (Directories row; the P-23 line names `docs/devkit.md`)
  - `README.md`, `CHANGELOG.md`, `UPSTREAM.md`, `upstream/proposals/20261018.md`

## Evidence
| Command | Result |
| --- | --- |
| `scripts/test-hooks.sh; echo exit=$?` | `221 cases, 0 failed`, `exit=0` |
| `/bin/bash -n plugins/devkit/scripts/pr-size.sh` | ok |
| `bash plugins/devkit/scripts/pr-size.sh main` on this branch | `lines=296 files=13 … status=over`, exit 3. Correct: 13 files, which is over the 10-file default |
| Untracked tree: 300 files + 1,000 excluded `dist/` files + a `-dash.txt` + a name with a newline, then +3,000 more | 0.39 s for 4,302 files, with `excluded=1000` and `partial=untracked`. Before the review fix, 3,000 files took 18.8 s |
| `claude plugin validate plugins/devkit --strict && claude plugin validate .` | `✔ Validation passed` ×2 |

## Deviations from the plan
- Untracked files over 500 are counted as files only; the output adds `partial=untracked`. At that size the status is already over on files.
- Excluded untracked files are never read. Line counts come from one `xargs grep -cIH` batch. Binary files and names containing a newline count as files with 0 lines.
- A failed `git diff` exits 1 instead of reporting 0 lines.
- Display rows replace control characters in names with `?`.

## Review
1 round: 0 Critical, 3 Warning, 7 Optional.
- **Fixed:**
  - W1: `<base>` is defined in ship (the `[base]` argument, else the script default) and in task (the PR's target branch); exit 1 → report it and ask.
  - W2: review's base per scope; a path scope has no size check.
  - W3: performance and exclude-before-read.
  - O1: names starting with `-` (`grep --`).
  - O2: control characters in display rows.
  - O3: `git diff` failure.
  - O5: monorepo note (`**/dist/**`).
  - O6: the proposal row notes the built shape.
  - O7: status flipped here.
- **Not done:** O4. Markdown rendering of the glob list; the parser reads raw text and backticks would become part of the value.

## Out of scope / open
- Ship-gate re-review: 0 Critical, 1 Warning (review's empty scope hardcoded `main`; fixed: no base → script default, and exit 1 is reported). Optional, not done: an untracked symlink counts its target's lines (should be 1 file, 1 line); the task allowed-tools glob could be narrower.
- Per-task size tiers and a `gh pr create` hook.
- The P-30 and P-36 keys; their plans add them to `docs/devkit.md`.
