# Report: block admin merges and self-approval (P-35)

Plan: `plan.md` (2 phases, --fast). Branch `feat/block-gh-bypass`, not committed.

## Phases completed
| Phase | Result |
| --- | --- |
| 1: tests first, then the gh checks | done. Before the change, all 12 new block rows failed (exp 2, got 0) |
| 2: docs | done |

## Files changed
- `plugins/devkit/scripts/block-force-push.sh`:
  - fast path `*git*push*|*gh*pr*`
  - `block <cmd> <reason>`; the git message text is unchanged
  - new `check_gh` and `is_false`
  - the per-line skip also lets `*gh*` lines through
  - header comment
- `scripts/test-hooks.sh`: 30 new `bash_cmd` rows.
- Docs: `README.md:3`, `CHANGELOG.md` `[Unreleased]` Changed, `UPSTREAM.md` P-35 → ✅, `upstream/proposals/20261018.md` v2.5.0 note.

## Evidence
| Command | Result |
| --- | --- |
| `scripts/test-hooks.sh; echo exit=$?` | `189 cases, 0 failed`, `All hooks passed.`, `exit=0` (159 before) |
| `/bin/bash -n plugins/devkit/scripts/block-force-push.sh` | ok |
| `echo '{"tool_input":{"command":"gh pr merge --admin"}}' \| …/block-force-push.sh` | exit 2, `Blocked by devkit: 'gh pr merge --admin' bypasses human review (admin merge or self-approval). Ask a reviewer; …` |
| `git push -f` through the hook | exit 2, original git message |
| `gh pr review 5 -Rmyorg/app --comment -b x` | exit 0 (was a false positive before the review fix) |
| Fast-path rows `npm run build`, `ls -f` | 13–14 ms before and after |
| `claude plugin validate plugins/devkit --strict && claude plugin validate .` | `✔ Validation passed` ×2 |

## Deviations from the plan
- The tokenizer's per-line fast skip had to allow `*gh*` lines. Without it, a line holding only a `gh` command was never parsed. This is recorded in the plan's Approach.
- Boolean values follow gh's flag parser: `--admin=False`, `=0`, `=f`, and similar count as false and pass.
- Option scanning stops at `--`.

## Review
1 round: 0 Critical, 2 Warning, 5 Optional.
- **Fixed:**
  - W1: `-R<repo>` attached to a review cluster was read as flags.
  - W2: value-taking letters (`b t F A R`) ending a merge cluster.
  - O1: boolean forms.
  - O2: `--` end of options.
  - O4: the deviation is now recorded.
- **Ship-gate review (round 2):** 0 Critical, 0 Warning, 1 Optional, fixed. A value letter attached inside a cluster (`-tb --admin`, `-bF --approve`) no longer makes the next word look like a value.
- **Not done:**
  - O3: a stderr-text assertion row. `bash_cmd` checks only exit codes; the manual verify above checks the message.
  - O5: no change was needed.

## Out of scope / open
- `gh api`/GraphQL merges, `bash -c "…"`, and aliases are not inspected. The hook is a guardrail; GitHub branch protection (P-44) is the real enforcement.
