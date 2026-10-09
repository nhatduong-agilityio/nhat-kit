---
name: brainstorm
description: Explore a problem with the user and compare 2–4 solution directions with explicit trade-offs before planning; writes no code.
argument-hint: "<problem | idea>"
---

# Brainstorm

Problem: `$ARGUMENTS`

Do not write or edit code in this skill.

1. **Find the real goal.** Restate the problem in your own words in 1–2 sentences. Ask at most 3 questions with `AskUserQuestion` about what would change the choice: constraints (time, stack, team), scale, what must not be traded away.
2. **Understand the current state.** If existing code is involved, run a light `/devkit:scout`. If outside knowledge is needed, give the most critical question to `devkit:researcher`.
3. **Offer 2–4 genuinely different directions**, including at least the simplest possible one and a "don't build it" option. Compare in a table: complexity, risk, maintenance cost, time, extensibility, impact on other parts.
4. **Challenge yourself**: for the direction you favor, state what could make it fail.
5. **Recommend** one direction, with the reason and the conditions under which you'd change your mind.
6. Ask the user to choose. Once chosen: save a summary to `plans/<YYYYMMDD>-<slug>/brainstorm.md` (in English) and suggest `/devkit:plan plans/<...>/brainstorm.md`.
