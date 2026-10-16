---
name: grill
description: Interview the user in rounds of questions, each with a recommended answer, until nothing about an idea is silently assumed; writes decisions.md for /devkit:plan. Use before planning a feature whose details are still open.
argument-hint: "<idea | brainstorm.md | SPEC.md>"
disable-model-invocation: true
---

# Grill

Idea: `$ARGUMENTS`

Do not write or edit code in this skill. Conventions: `${CLAUDE_PLUGIN_ROOT}/references/conventions.md`.

1. **Restate** the idea in 1–2 sentences. If the input is a file, read it first; what it already settles is not asked again.
2. **List the assumptions** a plan would otherwise have to guess: scope, behavior, data, edge cases, errors, UI states, permissions, rollout, non-goals. Keep this list as a ledger for the whole session.
3. **Look up facts; don't ask them.** Anything the code, docs, or config can answer, find yourself: read files, run `/devkit:scout`, or give outside questions to `devkit:researcher`. Record each fact with its source (`path:line` or URL). Tell the user the facts you found before round 1.
4. **Ask decisions in rounds.** One `AskUserQuestion` call per round, at most 4 questions. Each question has 2–4 concrete options; put the one you recommend first and end its label with "(Recommended)". Ask the most consequential questions first; let each round build on the last answers. Skip questions whose answer is obvious — record your choice as a default instead.
5. **Check in every 3 rounds**: offer "Continue" or "Stop — use the recommended answers for the rest". Mark answers taken that way as `default`.
6. **Done** when every ledger item is a verified fact or a decision. Write `plans/<YYYYMMDD>-<slug>/decisions.md` (reuse the folder if the input came from one):

   ```markdown
   # Decisions: <title>
   Source: <idea / file> · Rounds: <n>

   ## Goal
   ## Decisions
   | # | Question | Answer | Why | By (user / default) |
   ## Verified facts
   - <fact> — `path:line` or URL
   ## Deferred / open
   ## Out of scope
   ```

7. Summarize the key decisions in 3–5 bullets and suggest `/devkit:plan plans/<...>/decisions.md`.
