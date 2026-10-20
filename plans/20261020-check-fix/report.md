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
