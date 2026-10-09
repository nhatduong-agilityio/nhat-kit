---
name: upstream-watch
description: Review ClaudeKit Engineer Kit's public changelog and feature list plus the Claude Code docs, compare with UPSTREAM.md, and propose features to add or drop in devkit.
disable-model-invocation: true
---

# Upstream watch

Run inside the `claude-kit` repo. The output is **proposals**, not code. Write everything in English.

## Hard boundaries

- Read **public** pages only: `https://docs.claudekit.cc/docs/changelog`, `https://docs.claudekit.cc/docs/engineer`, `https://docs.claudekit.cc/docs/engineer/agents`, and public sub-pages linked from them.
- Never access, or try to obtain, ClaudeKit's private repo, installers, or skill contents.
- Describe features in your own words (at most 2 sentences each); never copy wording from the source pages.

## Process

1. Read `UPSTREAM.md`: the last review date, the reviewed ClaudeKit version, the feature table.
2. Read the ClaudeKit pages above. Extract releases newer than the reviewed one (version, date, main changes) and skills/agents added or removed compared to the table.
3. Read `https://code.claude.com/docs/en/commands` and the Claude Code changelog if available. Look for new built-in features that could replace a devkit skill (mark it ⊘ and remove our code).
4. Classify each new item:
   - **Add**: in scope (frontend, full-stack web, team workflow) with no equivalent yet.
   - **Improve**: devkit has it, but the new idea makes it better — name the skill and the change.
   - **Use built-in**: Claude Code already provides it.
   - **Skip**: out of scope; one-line reason.
5. Write `upstream/proposals/<YYYYMMDD>.md`: a table (Item · Source · Class · Proposal for devkit · Size S/M/L · Expected bump patch/minor/major), ordered by value.
6. Update `UPSTREAM.md`: the new checkpoint, a new row in "Review history", and new items in the feature table with status ⏳ or ✗.
7. Reply with the 3–5 proposals most worth doing, each with a suggested `/devkit:plan <proposal>` command to start.

When running unattended (a routine): do steps 1–6 on a branch `upstream/<YYYYMMDD>`, commit, and open a PR titled `chore(upstream): review <YYYY-MM-DD>`; never modify skills or agents.
