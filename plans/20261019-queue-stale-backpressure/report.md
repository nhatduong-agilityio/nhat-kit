# Report: stale claims and open-PR back-pressure (P-30, P-36)

Plan: `plan.md` (2 phases, --fast). Branch `feat/queue-stale-backpressure`, not committed.

## Phases completed
| Phase | Result |
| --- | --- |
| 1: settings and `queue-status.sh`, tests first | done. 20 rows failed (exit 127) while the script was missing |
| 2: wire into task and conventions, then docs | done (main session) |

## Files changed
- New: `plugins/devkit/scripts/queue-status.sh`.
- Changed:
  - `plugins/devkit/templates/docs/devkit.md` (`claim_ttl_minutes`, `max_open_prs`)
  - `plugins/devkit/skills/task/SKILL.md` (the `next` bullet and allowed-tools)
  - `plugins/devkit/references/conventions.md` (stale claim and back-pressure rules)
  - `scripts/test-hooks.sh` (queue-status section)
  - `CHANGELOG.md`, `UPSTREAM.md`, `upstream/proposals/20261018.md`

## Evidence
| Command | Result |
| --- | --- |
| `scripts/test-hooks.sh; echo exit=$?` | `269 cases, 0 failed`, `exit=0`. The queue-status rows cover the 10 plan cases plus 18 review cases: the lost race, leftover label, pretty-printed gh output, closing keywords, host sanitizing, and `review=` |
| `bash plugins/devkit/scripts/queue-status.sh` (real `gh`, this repo) | `open_prs=0 max_open_prs=5 pressure=ok ttl_minutes=120 stale=0 review=-`, exit 0 |
| `claude plugin validate plugins/devkit --strict && claude plugin validate .` | `✔ Validation passed` ×2 |
| `git diff --numstat main -- plugins/devkit/skills/task/SKILL.md` | `2 2` |
| `bash plugins/devkit/scripts/pr-size.sh main` | `status=ok` under the repo's `docs/devkit.md` |

## Review
1 round: 0 Critical, 4 Warning, 4 Optional.
- **Fixed:**
  - W1: stale logic now works per host. A lost race (A claims, B claims, B releases) leaves A's old claim reported as stale. A leftover `in-progress` label with every claim released is reported as host `-`.
  - W2: gh outputs go to temp files, `json.load` each, and gh runs with `NO_COLOR` and without `CLICOLOR_FORCE`/`GH_FORCE_TTY`.
  - W3: the summary adds `review=` with the PR numbers to suggest; at most 4 AskUserQuestion options, with stale rows filling the free slots; stop only when there are no free issues and no stale rows; picking a stale row is the user's word for the takeover, after re-reading with `gh issue view`.
  - W4: the closing-keyword regex now matches GitHub's forms, with an optional colon.
  - O1: host sanitizing.
  - O3: a comment on equal timestamps.
  - O4: covered by the re-read before claiming.
- **Not done:** O2. `gh issue list --json comments` may return only the first 100 comments per issue (unverified). On a very long thread the latest claim could be missed; the re-read with `gh issue view` before a takeover limits the impact.

- Ship-gate re-review: 0 Critical, 1 Warning: after a takeover with no release, the stale row named the earliest claimer, so it now names the latest active claim, the owner per conventions; a row tests it. Optional fixed: the unused `Bash(gh pr list *)` allowed-tool was removed, and the conventions now cover the all-released-but-labelled case.

## Out of scope / open
- No live stale claim was available to check against real `gh` output; the stub fixtures use `gh`'s field names (`author.login`, `body`, `createdAt`).
