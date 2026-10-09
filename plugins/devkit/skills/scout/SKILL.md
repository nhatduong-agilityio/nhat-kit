---
name: scout
description: Quickly map the code for a topic (feature, flow, module) with several parallel search subagents — which files, which functions, how they connect — without filling the main context.
argument-hint: "<topic> [--deep]"
---

# Scout

Topic: `$ARGUMENTS`

1. Split the topic into 2–4 independent search angles (typically: UI/route entry points; logic and state; data and API; tests and config). `--deep` → up to 6 angles, `very thorough`.
2. Give each angle to its own `Explore` subagent in parallel. Ask for: only `path:line` + a one-line role, how pieces call each other, and what remains uncertain. No pasted file contents.
3. Merge and deduplicate into the answer:
   - **Summary**: 2–3 sentences on how the topic works.
   - **File map** ordered by flow (entry → processing → data), one `path:line — role` per line.
   - **Patterns to follow** when changing this area.
   - **Uncertain points** and how to check them.
4. Don't re-read whole files in the main context; open a file only to resolve a contradiction between subagents.
