# Living CLAUDE.md conventions (P-23) — report

Plan: `plans/20261017-living-claude-md-conventions/plan.md` · Branch: `feat/living-claude-md-conventions`

## Phases completed

| Phase | File | Verify |
| --- | --- | --- |
| 1 — Template sections | `plugins/devkit/templates/CLAUDE.md` | `claude plugin validate` → pass; `wc -l` → 51 (was 41, under 120 budget) |
| 2 — Bootstrap fill guidance | `plugins/devkit/skills/bootstrap/SKILL.md` | `claude plugin validate` → pass; bullet placement confirmed by read-back |
| 3 — Conventions principles | `plugins/devkit/references/conventions.md` | `claude plugin validate` → pass; `grep "same commit"` → found |
| 4 — `check` drift bullet | `plugins/devkit/skills/check/SKILL.md` | `claude plugin validate` → pass; manually applied the new bullet's logic to this repo → resolves to OK (no convention-changing files exist here) |
| 5 — Bookkeeping | `CHANGELOG.md`, `UPSTREAM.md` | `grep "P-23"` → both lines found; P-23 row flipped `◐` → `✅` |

## Evidence

- `claude plugin validate plugins/devkit --strict && claude plugin validate .` — exit 0, every phase.
- `scripts/test-hooks.sh` — all hooks pass, no regression (this change touches no hook logic).
- Code review (`devkit:code-reviewer`): Critical 0 / Warning 0 / Optional 2 (both informational — a minor line-count-estimate mismatch in the plan's own risk table, and a positive style-consistency note). No action needed.

## Files changed

- `plugins/devkit/templates/CLAUDE.md` — two new sections: *Remotes & never-push rules*, *Removed / reversed*
- `plugins/devkit/skills/bootstrap/SKILL.md` — one bullet on filling the new sections
- `plugins/devkit/references/conventions.md` — two new "General principles": CLAUDE.md-in-same-commit, externalize skill tunables
- `plugins/devkit/skills/check/SKILL.md` — new Layer 2 bullet flagging a stale CLAUDE.md
- `CHANGELOG.md` — `[Unreleased]/### Changed` entry (P-23)
- `UPSTREAM.md` — P-23 status `◐` → `✅`

## Out-of-scope items discovered

None beyond what the plan already excluded (no retrofit of existing skills' hardcoded tunables, no enforcement script/hook, repo's own root `CLAUDE.md` untouched — all confirmed respected by the code review).

Status: done
