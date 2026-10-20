# Report: Protected branches — report GitHub protection, block local pushes (P-44)

Plan: `plans/20261020-protected-branches/plan.md` · Branch: `feat/protected-branches`

## Delivery
Split at ship gate 1 (392 lines / 11 files over the 300-line limit; user decision, 2026-10-20) into two stacked PRs: part 1 `feat/protected-push-hook` (template hook, bootstrap, check Layer 1, README; 214 lines) and part 2 `feat/branch-protection-report` (script, check Layer 4, CHANGELOG, UPSTREAM, proposal, this plan; 182 lines).

## Phases completed
1. Template hook `block-protected-push.sh` + tests (TDD: 29 rows written first, failing on the missing hook).
2. `scripts/branch-protection.sh` + stub-`gh` tests (TDD: 39 rows written first; one stub bug fixed — `classic404` missing from the protected case list).
3. Wiring: `/devkit:check` (Layer 1 hook item, Layer 4 "Default branch protection" row, "Unknown"/"Not checked" statuses, `Bash(bash */branch-protection.sh *)`), `/devkit:bootstrap` (plan-table row, step 4 fill/delete, step 5 CLAUDE.md, step 8 sample), `templates/settings.json`, `templates/CLAUDE.md`.
4. Docs: CHANGELOG `### Added`, README Layer 1 row, UPSTREAM ✅, proposal order/Done lines.

## Files changed
- New: `plugins/devkit/templates/hooks/block-protected-push.sh` (96 lines), `plugins/devkit/scripts/branch-protection.sh` (81 lines)
- Modified: `plugins/devkit/skills/check/SKILL.md`, `plugins/devkit/skills/bootstrap/SKILL.md`, `plugins/devkit/templates/settings.json`, `plugins/devkit/templates/CLAUDE.md`, `scripts/test-hooks.sh` (+182), `CHANGELOG.md`, `README.md`, `UPSTREAM.md`, `upstream/proposals/20261018.md` (also carries "PR #29" for P-34)

## Evidence
- `scripts/test-hooks.sh` → "374 cases, 0 failed. All hooks passed." (105 rows for `block-protected-push` + `branch-protection`; 269 before this change)
- `bash plugins/devkit/scripts/branch-protection.sh` (live, this repo) → `branch=main protected=true pr_required=false force_push_blocked=true source=rules`, exit 0
- `claude plugin validate plugins/devkit --strict && claude plugin validate .` → both "✔ Validation passed"
- `python3 -m json.tool plugins/devkit/templates/settings.json` → valid
- `node --test plugins/devkit/scripts/render-report.test.mjs` → 15 pass, 0 fail
- `bash -n` / `test -x` on both new scripts → pass (bash 3.2.57)

## Review findings
Fixed by the cook-phase reviewer (Phase 1 check): `git --git-dir x push` was not parsed (row added).
Code-reviewer, 0 Critical; fixed in one retry (Retry 1 on opus):
- W1 redirects (`2>&1`, `>/dev/null`) let a bare-remote push through → stripped before parsing; 6 rows.
- W2 the hook read the branch from `$CLAUDE_PROJECT_DIR`, blocking feature pushes from worktrees → uses the tool call's `cwd`, follows `cd <dir>` segments; 5 rows.
- W3 a failed rules call read as "no rules" → `unknown`; stub case `rulesfail`.
- W4 "Not checked" added to the check status list.
- W5 CHANGELOG test count corrected (103).
- O1 tag check on the destination; O2 `@` = HEAD; O3 `sudo -E`; O4 header limits; O5 separator-only list; O6 invalid branch name → exit 1; O8 `per_page=100`.
Remaining: O7 (the `Bash(bash */branch-protection.sh *)` allow rule matches any script of that name — same pattern as `queue-status.sh`; revisit with P-32 `--fix`).
Tester gaps pass: 16 rows added (comma list, `-d`, `HEAD`, `-o`, `--repo=`, `sudo`, `/usr/bin/git`, detached HEAD, glob over-match, multi-segment, `repo view` failure).

Ship re-review (0 Critical): W1 `>&FILE` without an fd let a remote-only push through → fixed (2 rows); S4 `source` names only what was read; S6 check: false wins over unknown, note "needs admin or API error". S1–S3 (wrapper options with values, glued `(`, glued redirects) and S5 (`#`/`%`/`@{` in an explicit branch name) documented as limits in the script headers.

## Out-of-scope issues found
- Known hook limits stay documented in its header: quoted words, aliases, scripts that push, `push.default`/remote mapping, `git push --repo x main` (value-taking `--repo` then `main` read as the remote).
