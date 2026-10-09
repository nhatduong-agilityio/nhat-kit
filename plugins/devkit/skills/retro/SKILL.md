---
name: retro
description: After a task or session, learn from the times the user had to correct Claude and propose updates to the project's CLAUDE.md, rules, skills, or hooks.
disable-model-invocation: true
---

# Retro — update the project's memory

Goal: next time, Claude doesn't repeat a mistake that was corrected in this session. Write all changes in English.

1. Review the current conversation. List every time the user corrected direction, rejected a change, or had to repeat the same point. Include recurring problems caught by review or tests.
2. For each lesson, pick the right place:
   - A fact needed in every session (commands, conventions) → `CLAUDE.md`.
   - A convention for one part of the code → `.claude/rules/<domain>.md` with `paths:`.
   - A multi-step procedure → a new skill in `.claude/skills/`.
   - Something that must happen 100% of the time and can be checked by a script → a hook in `.claude/settings.json`.
   - A personal preference, not a team standard → `CLAUDE.local.md`.
3. Skip lessons Claude already gets right without being told, or that are already recorded.
4. Present the proposed changes as a diff, one reason per line. **Wait for the user's approval**, then apply them.
5. After applying: `wc -l CLAUDE.md` must still be under 120 lines; if it isn't, propose moving module-specific parts into rules.
