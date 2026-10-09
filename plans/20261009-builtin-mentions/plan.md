---
Status: done
---

# Plan: add built-in mentions to cook, plan, and ship

## Goal

Three independent one-sentence additions that point users to relevant Claude Code built-ins at the right moment:
- **cook**: mention `/batch` as the escalation path for codebase-wide changes (P-2)
- **plan**: suggest `/advisor fable` when a plan's risk is High/Critical (P-3)
- **ship**: mention `/autofix-pr` after gate 8 opens the PR (P-4)

## Context found

- `cook/SKILL.md:29` — "Independent phases that share no files may run in parallel…" — add `/batch` note immediately after.
- `plan/SKILL.md:48` — step 6 "Present a summary…" — add `/advisor` suggestion after the summary bullet.
- `ship/SKILL.md:21` — gate 8 "Ask for confirmation before pushing." — append `/autofix-pr` note on the same line or as a follow-on sentence.

## Approach

Three independent edits; no new files needed beyond CHANGELOG.

## Phases

### Phase 1 — Three file edits (XS, ~5 min)

**cook/SKILL.md** — after line 29, append a new line:

> If the change spans 10+ independent modules across the whole codebase, consider `/batch <instruction>` instead: it decomposes the work into isolated worktrees and runs each unit in parallel.

**plan/SKILL.md** — in step 6, after the summary bullet (line 48), add a new bullet:

> - If the plan has any High or Critical risk, suggest enabling `/advisor fable` for the cook phase so a second model gives guidance at key moments.

**ship/SKILL.md** — extend gate 8 (line 21) with a follow-on sentence:

Replace:
> 8. **Deliver**: follow the `/devkit:git pr` procedure (read `${CLAUDE_PLUGIN_ROOT}/skills/git/SKILL.md`). Ask for confirmation before pushing.

With:
> 8. **Deliver**: follow the `/devkit:git pr` procedure (read `${CLAUDE_PLUGIN_ROOT}/skills/git/SKILL.md`). Ask for confirmation before pushing. After the PR opens, suggest `/autofix-pr` so Claude Code watches CI failures and review comments and pushes fixes automatically.

Add single CHANGELOG entry covering all three.

**Verify:** `claude plugin validate plugins/devkit --strict` — must pass. Grep confirms no "batch", "advisor", "autofix" already present in the three files.

## Risks

None significant. All three are advisory suggestions in existing prose; they don't change any logic or format.

## Out of scope

- Integrating `/batch` or `/advisor` into the skills as active steps (would change skill behavior — separate MINOR proposal).
- Any changes to the `cook`, `plan`, or `ship` workflow logic.

## Red-team notes

*(none — not red-teamed; three advisory sentences)*
