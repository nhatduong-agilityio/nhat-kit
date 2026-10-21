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

## PR C — Phases 5–6 (branch `feat/check-fix-ruleset`, from `main` after #32/#33 merged)

### Files changed
- `plugins/devkit/scripts/team-fix.sh` (`ruleset [--admin-bypass] [--dry-run]`), `plugins/devkit/skills/check-fix/SKILL.md` (ruleset step), `plugins/devkit/skills/check/SKILL.md` (protection row → `/devkit:check-fix`), `scripts/test-hooks.sh` (+ ruleset section), `CHANGELOG.md`, `UPSTREAM.md` (P-32 ✅), `upstream/proposals/20261018.md` (P-32 done)

### Evidence
- `scripts/test-hooks.sh` → "746 cases, 0 failed. All hooks passed." (372 new P-32 rows in total; 374 before P-32)
- Live `team-fix.sh ruleset --dry-run`, run only through a write-blocking `gh` wrapper (refuses `-X` other than GET and any `--input`/field flag) → `action=ruleset result=would_create rules_added=pull_request,non_fast_forward bypass=none others=kit`; the wrapper blocked nothing (the script attempted no write); live rulesets still `["kit"]`
- `gh api` error body goes to stdout (live read-only 404 GET: stdout `{"message":"Not Found",…}`, stderr `gh: Not Found (HTTP 404)`)
- `claude plugin validate plugins/devkit --strict && claude plugin validate .` → both pass
- `bash pr-size.sh main` → `lines=282 files=8 … status=ok`
- TDD: 116 rows written first; the stub fails any implicit write (`gh api` POSTs when fields/`--input` are given without `-X`)

### Review findings
- Advisor (before tests): implicit POST in `gh api` → dry-run rows assert no body flags; all five `pull_request` params asserted; live dry-run only through a write-blocking wrapper.
- Code-reviewer + tester gaps (0 Critical), fixed in retry 1 on opus: W1 merge guard failed open on a `{}`/null GET (would PUT defaults over devkit's ruleset) → explicit existing mode, id/source/name/list checks, no PUT; W2 list pagination `per_page=100` (and fail at ≥100); W3 `bypass_rejected` only when the 422 body mentions bypass/actor, detail from the JSON body; W4 check-fix asks only on `would_create|would_update`, handles `unchanged`/`existed`, cites Approval; optional: `others=` names percent-encoded, no Tracebacks in detail, read-back GET failure no longer reads as `conflict`, 13 more negative rows, plan Risks reworded (no GET→PUT lost-update protection).
- Ship gate-6 review (0 Critical), fixed in retry 2 on opus: W1 `bypass_rejected` decided from the raw 422 body + stderr, `err` renders dict errors without `message` as `field: code` and joins multi-line text; W2 `bypass_rejected` only when this run added the Admin actor (`merge` prints `added_actor`); W3 check-fix manual steps (settings URL, the two rules, org/foreign owners); W4 check suggests `/devkit:check-fix` for worktrees and protection; S1 unknown `enforcement` on GET → failed, no PUT; S3 `others=` encodes all controls and DEL, cut after whole names to 200 bytes with `,…`; S5/S8 one result list in step 7, `created`/`updated` with `detail=` → settings URL, question says the dry-run is without bypass and the bypass answer adds the Admin role; S6 rows for ≥100 rulesets and `--force`. 746 cases, 0 failed.
- Remaining from gate 6: S2 `list` coerces ids with `int()` (accepts `11.9`, `"11"`, `true`); the merge guard fails closed (GET `id` must be an int equal to the listed id, plus `source_type` and `name`); S4 `detail=` runs to the end of the line (documented in the team-fix header).
- Remaining: Admin role `actor_id 5` unverified (read-back decides `bypass=verified|unverified`); no protection against an edit between our GET and PUT; `Bash(bash */team-fix.sh *)` matches any path (same pattern as other scripts).
