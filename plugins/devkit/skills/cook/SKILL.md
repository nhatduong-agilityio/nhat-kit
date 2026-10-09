---
name: cook
description: Implement a plan or a request end to end — plan first if needed, implement phase by phase with subagents, test, review, fix, and report with evidence.
argument-hint: "<plan.md | request> [--auto] [--no-tdd]"
disable-model-invocation: true
---

# Cook

Input: `$ARGUMENTS`

Conventions: `${CLAUDE_PLUGIN_ROOT}/references/conventions.md` — pass this path to every agent you delegate to. The plugin folder is `${CLAUDE_PLUGIN_ROOT}`; when you read another skill's file directly, replace the `CLAUDE_PLUGIN_ROOT` variable in it with this path. Use a task list: one item per phase, plus "Tests", "Review", "Report".

## 0. Is there a plan?

- Input is a `plan.md` with `Status: approved` → use it.
- Input is a `draft` plan → present its summary again and ask for approval (unless `--auto`).
- Input is a request → follow the `/devkit:plan` procedure (read `${CLAUDE_PLUGIN_ROOT}/skills/plan/SKILL.md`), in `--fast` mode for small requests. With `--auto`, don't wait for plan approval; otherwise **wait for approval**.
- Set the plan to `Status: in-progress`; write its path to `.claude/current-task`.
- On the main branch → create a `feat/<slug>` (or `fix/…`) branch following the repo's convention before editing code.

## 1. Each phase, in order

1. **Tests first** (skip with `--no-tdd`, or for phases without checkable behavior such as config or pure refactors): have `devkit:tester` run in `write-first` mode for this phase.
2. **Implement**: give this phase to `devkit:fullstack-developer`, with the list of files it owns, the plan path, and the tests just written.
3. **Check**: run the phase's verify command yourself. Red → send it back to the developer with the failing output (at most twice); still red → delegate to `devkit:debugger`, then fix at the root cause.
4. Post a one-line progress update for the user; tick the phase in the plan.

Independent phases that share no files may run in parallel with multiple `fullstack-developer` subagents. Do this only when the plan states they are independent.

If the change spans 10+ independent modules across the whole codebase, consider `/batch <instruction>` instead: it decomposes the work into isolated worktrees and runs each unit in parallel.

## 2. After all phases

1. Have `devkit:tester` run in `run` mode, then `gaps` mode for new behavior without tests.
2. Run the project's `verify` skill if there is one (the real app; for UI use the `ui-verifier` agent if the project has it).
3. Have `devkit:code-reviewer` review against the plan. Fix every **Critical** and reasonable **Warning**; re-run the tests. Loop at most 3 times; if Criticals remain after that → stop and tell the user.

## 3. Report

- Write `plans/<...>/report.md`: phases completed, files changed, evidence (command → result), review findings fixed and remaining, out-of-scope issues discovered.
- Set the plan to `Status: done`; delete `.claude/current-task`.
- Reply to the user: 2–3 lines of outcome, the key evidence, and the next step — `/devkit:git cm` to commit, or `/devkit:ship` to commit, push, and open a PR.
- Never commit or push on your own.
