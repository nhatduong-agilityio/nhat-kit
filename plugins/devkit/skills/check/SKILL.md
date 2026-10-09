---
name: check
description: Health-check the current project's 4 Claude Code layers and point out what is missing or outdated. Read-only.
disable-model-invocation: true
allowed-tools: Bash(ls *) Bash(wc *) Bash(git log *) Bash(git status *)
---

# 4-layer health check

Read only; change nothing. Return one table: Layer · Item · Status (OK / Missing / Needs fix) · Notes.

**Layer 1 — Config & permissions**
- `.claude/settings.json` exists and is valid JSON; commands in `allow` still exist in the project's scripts.
- A `deny` for `.env*`; an `ask` for `git push`.
- Every referenced hook script exists and is executable.

**Layer 2 — Memory**
- `CLAUDE.md` exists, is under 120 lines, and its commands match the real scripts.
- `docs/PROJECT_BRIEF.md` exists; `.claude/rules/*.md` have `paths:` pointing to folders that still exist.
- `CLAUDE.local.md` and `.claude/settings.local.json` are in `.gitignore`.

**Layer 3 — Extensions**
- `.claude/skills/verify/SKILL.md` exists and its run recipe is still correct.
- `.claude/agents/*.md` have valid frontmatter (`claude plugin validate .claude/agents` if it can run).
- `.mcp.json` contains no hard-coded secrets.

**Layer 4 — Workflow**
- `docs/tasks/_TEMPLATE/SPEC.md`, `docs/BACKLOG.md`, `.github/pull_request_template.md` (if using GitHub).
- Work in progress: the contents of `.claude/current-task`.

After the table: at most 5 recommended actions, ordered by impact. Suggest `/devkit:bootstrap` to fill gaps, `/devkit:review` to review `CLAUDE.md` for conflicting instructions, and `/doctor` (Claude Code built-in) for a full installation health-check.
