---
name: retro
description: After a task or session, learn from the times the user had to correct Claude and propose updates to the project's CLAUDE.md, rules, skills, or hooks.
disable-model-invocation: true
---

# Retro — update the project's memory

Goal: next time, Claude doesn't repeat a mistake that was corrected in this session. Write all changes in English.

1. Review the current conversation. List every time the user corrected direction, rejected a change, or had to repeat the same point. Include recurring problems caught by review or tests. If `/insights` output is already present earlier in the conversation, read it too as extra input alongside the session's own corrections — `retro` has no way to invoke `/insights` itself.
2. For each lesson, pick the right place:
   - A fact needed in every session (commands, conventions) → `CLAUDE.md`.
   - A convention for one part of the code → `.claude/rules/<domain>.md` with `paths:`.
   - A multi-step procedure → a new skill in `.claude/skills/`.
   - Something that must happen 100% of the time and can be checked by a script → a hook in `.claude/settings.json`.
   - A personal preference, not a team standard → auto memory, if this Claude Code installation has it for the project (a `memory/` directory under this project's own entry in `~/.claude/projects/`). First read the existing `MEMORY.md` index to avoid duplicating an entry; if one already covers this preference, link it (`[[name]]`) or update it instead of writing a new one. Otherwise write a new memory file with frontmatter `metadata.type: feedback`, state in the body *why* — the user's correction or confirmation that produced this preference — so the memory stays interpretable later, then add a one-line pointer to `MEMORY.md` (`- [Title](file.md) — hook`). If auto memory isn't available for this project (no `memory/` directory, or the feature isn't present in this installation), fall back to `CLAUDE.local.md` as before.
3. Skip lessons Claude already gets right without being told, or that are already recorded.
4. Present the proposed changes as a diff, one reason per line. **Wait for the user's approval**, then apply them.
5. After applying: `wc -l CLAUDE.md` must still be under 120 lines; if it isn't, propose moving module-specific parts into rules.
