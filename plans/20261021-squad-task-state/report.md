# Report — P-46: where squad task state lives (research)
Plan: `plans/20261021-squad-task-state/plan.md` · Status: done

## Outcome
Native GitHub issues can hold stage-2 squad task state through `gh` alone: sub-issues for epic → task, issue dependencies for waves, labels and machine-readable comments for per-task values. No Projects board is needed, so relink stays skipped. Proven on a personal private repo; org repos are out of scope (user decision, 2026-10-21). GitHub accepts dependency cycles, so P-41 must detect them.

## Phases
1. Live write probe on a throwaway private repo `nhatduong-agilityio/devkit-p46-probe` (P0, W1–W7, S1), each write after its own yes; the user deleted the repo in the web UI (C1 skipped, C2 verified). ✅
2. Read-only org checks on Agility-Vietnam: type and field definitions read; the issue-level checks were then dropped as out of scope (user decision, 2026-10-21: no org connection needed). ✅
3. `research/findings.md`: verdict, store per need, Projects board, must-handle list for P-41/P-42, unverified items. ✅
4. Proposal (P-46, P-41, P-42 rows, Board relink skip row, v3.x line, next commands) and `UPSTREAM.md` P-46 row. No CHANGELOG entry: no shipped kit file changed. ✅

## Files changed
- `plans/20261021-squad-task-state/` (plan, report, `research/` sub-issues, dependencies, types-and-fields, schema-probe.txt, live-probe.md, findings.md)
- `upstream/proposals/20261018.md`, `UPSTREAM.md`

## Evidence
| Command | Result |
| --- | --- |
| `grep -cE '^\| (P0\|S1\|W[1-7]\|C[12])' research/live-probe.md` | 11 |
| `gh repo view nhatduong-agilityio/devkit-p46-probe` | exit 1 (repo gone) |
| findings.md section check | no missing section |
| `grep -c '^\| P-46 .*[Dd]one' upstream/proposals/20261018.md`; `grep -c '✅ \| P-46' UPSTREAM.md` | 1; 1 |
| `claude plugin validate plugins/devkit --strict && claude plugin validate .` | both pass |
| `scripts/test-hooks.sh` | All hooks passed |
| `bash plugins/devkit/scripts/pr-size.sh main` | `lines=16 files=2 … status=ok` |

Key probe results: sub-issue loops rejected; dependency cycles **accepted**, self-edge rejected; `blockedBy` node states current at once while summaries and `is:blocked` lag ~20 s; search needs full `owner/repo#n` refs and singular `has:sub-issue`; REST `sub_issue_id` is the database `.id`; `--type` and issue fields unavailable on personal repos (`issueFieldValues` errors there).

## Review (devkit:code-reviewer)
- Critical: none.
- Warnings fixed: Phase 2 issue-level items unticked and marked blocked (later superseded: dropped as out of scope by user decision 2026-10-21); readback wording (`issue list` for the tree, `issue view` for blockers; `issue list --json blockedBy` shape checked read-only on cli/cli); org column marked docs-only; "this token" instead of "this member" for the 0 visible repos; triage-or-higher permission for dependency writes added to findings and P-41; next command no longer skips v2.7.0, and P-46 is in the Done line.
- Suggestions applied: owner-type guard for `issueFieldValues`; `blockedBy` (not `subIssues`) node states in the W6 verdict; `nodes` vs `totalCount` check; UPSTREAM qualifier; `complexity:*` label in P-42.
- Remaining: none.

## Out of scope / follow-ups
- No Projects board work; it would need the `project` scope.
- Ship-gate review: Critical none. Warnings fixed: the live-probe org row, this report, and the plan's Approach, Phase 3 spec, Risks and Out of scope now all say org repos are out of scope (user decision 2026-10-21) instead of unverified. Suggestions applied: a legend for struck Phase 2 items, "out of scope" for setting an org issue type, a comma in the P-41 row, and a "pre-probe desk notes" line on the three docs reports.
