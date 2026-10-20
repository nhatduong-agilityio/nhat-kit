# Report: Team checks in /devkit:check, fixes in /devkit:check-fix (P-32)

Plan: `plans/20261020-check-fix/plan.md` · Delivered as 3 stacked PRs (A, B, C). This report grows per PR.

## PR A — Phases 1–2 (branch `feat/check-fix-team-status`)

### Files changed
- New: `plugins/devkit/scripts/team-status.sh` (79), `plugins/devkit/scripts/team-fix.sh` (44; `labels` only, other actions `not_implemented`), `plugins/devkit/skills/check-fix/SKILL.md` (17)
- Modified: `plugins/devkit/skills/check/SKILL.md` (allowed-tools + 2 Layer 4 rows + recommended action), `scripts/test-hooks.sh` (+139), `README.md` (row, list, "19 commands"), `UPSTREAM.md` (P-32 part 1 note, ⏳ kept), `CHANGELOG.md` (`### Added`), `upstream/proposals/20261018.md` (P-44 "PRs #30, #31", carried over)

### Evidence
- `scripts/test-hooks.sh` → "473 cases, 0 failed. All hooks passed." (99 new `team-status` rows; 374 before)
- `bash plugins/devkit/scripts/team-status.sh` (live, read-only) → `auth=ok login=nhatduong-agilityio scopes=gist,read:org,repo missing_scopes=-` / `repo=nhatduong-agilityio/nhat-kit visibility=PUBLIC permission=ADMIN` / `labels_missing=ai,severity:critical,severity:high,severity:medium,severity:low,in-progress`
- `gh label list` after all work → still no queue labels (no live write happened)
- `claude plugin validate plugins/devkit --strict && claude plugin validate .` → both pass
- `bash pr-size.sh main` → `lines=297 files=9 … status=ok`
- TDD: 81 rows written first, failing on the missing scripts

### Review findings
- Retry 1 on opus (size): first pass was 320 lines → `team-status.sh` merged into one python program, 116 → 79 lines, output byte-identical.
- Code-reviewer, 0 Critical; fixed in retry 1 on opus: W1 broken token reported `auth=ok` → `auth=error`; W2 empty gh output read as logged out → exit 1; W3 stderr mixed into label rows (garbage label write path) → separate stderr, row validation; W4 check-fix unhandled states, offer only with WRITE+ and `repo` scope, `! gh auth … -h <host>`; W5 check rows: Missing / Not checked; W6 README "19 commands"; W7 negative tests; O1 GHE host note in header.
- Ship re-review (0 Critical): W1 Queue labels row now "Missing" (matches plan); S1 `result=started` documented in the team-fix header; S2 label names compared case-insensitively; S3 `-h <host>` in check's auth hints; S4 scopes accepted as a list or a string.
- Remaining: O2 allow rule `Bash(bash */team-fix.sh *)` matches any path (same pattern as existing scripts); O3 re-check before create (team-fix already creates only what is missing).

### Out-of-scope issues found
- None.

## PR B — Phases 3–4 (branch `feat/check-fix-worktrees`, stacked on PR A)

### Files changed
- New: `plugins/devkit/scripts/worktree-status.sh` (75)
- Modified: `plugins/devkit/scripts/team-fix.sh` (`prune`, `remove-worktree <path> <ignored count>`), `plugins/devkit/skills/check/SKILL.md` ("Leftover worktrees" row), `plugins/devkit/skills/check-fix/SKILL.md` (prune in the safe question, one yes per merged worktree), `scripts/test-hooks.sh` (+99), `CHANGELOG.md`, `UPSTREAM.md`

### Evidence
- `scripts/test-hooks.sh` → "549 cases, 0 failed. All hooks passed." (76 new rows; 473 before)
- `bash plugins/devkit/scripts/worktree-status.sh` (live, read-only) → `worktrees=0 prunable=0 merged=0 kept=0 gh=ok`; outside a repo → exit 1
- `git --version` → 2.49.0; the removal rows prove `git worktree remove -- <path>` is accepted
- `claude plugin validate plugins/devkit --strict && claude plugin validate .` → both pass
- `bash pr-size.sh feat/check-fix-team-status` → `lines=237 files=7 … status=ok`
- prune/remove-worktree ran only against temp repos
- TDD: 51 rows written first, failing on the missing script

### Review findings
- Code-reviewer round 1: **C1** (data loss) `status.showUntrackedFiles=no` hid an untracked file and removal deleted it (reproduced) → clean check forces `-c status.showUntrackedFiles=all --untracked-files=all --ignore-submodules=none`; W1 skip-worktree/assume-unchanged edits → kept; W2 outside a repo → exit 1; W3 prune question lists prunable paths + unmounted-drive warning; W4 `remove-worktree` re-checks the ignored count; W5 prune independent of gh and label gating; W6 exact `reason=current`; O1 `ENVIRON` in awk; O5 `LC_ALL=C`; O6 header; O8 "no other session uses it". Retry 1 on opus.
- Round 2: W-a an ignored nested git repo would be deleted with its history → worktree `kept`; O-b count argument 1–6 digits, no arithmetic wrap; O-c header. Retry 2 on opus.
- Ship review: **C1** a nested repo below an ignored dir (`build/sub`, listing collapses to `build/`) and **C2** a name git quotes (`né/`) were missed and removal deleted their history → detected via a second, non-`--directory` listing (git stops at nested repos and lists each as `<dir>/`; stops at the first hit; a failed listing keeps the row) and `core.quotePath=false`; 6 new test rows, all failing on the old script. Retry 3 on opus.
- Ship gate-6 re-review (0 Critical/Warning): S1 the nested-repo listing now pipes to `grep -zqm1` (was a bash read loop, ~1.5 s per 200k-file tree); fail-closed via `PIPESTATUS` (git must exit 0 and grep 1 for `nest=0`) — probed with a failing `git ls-files` → `kept`.
- Remaining (accepted): O-a only the ignored *count* is re-checked (new files inside an already-listed ignored directory are not detected); O-d `prune` acts on whatever is prunable at run time (metadata only, locked entries respected); one gh call per eligible worktree on each status run.
