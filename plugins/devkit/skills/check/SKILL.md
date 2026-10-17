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
- Whether any of the last 10 commits that touched a convention-changing file (`package.json` scripts, lint/format config, CI config, `.claude/rules/*.md`) also touched `CLAUDE.md`. Report: Status = Needs fix with the commit SHA(s) and one-line subject(s) that changed a convention without a matching `CLAUDE.md` commit; Status = OK if every such commit also touched `CLAUDE.md`, or if there were fewer than 10 commits total. N (10) is a fixed default in this patch, not user-configurable.
- `docs/PROJECT_BRIEF.md` exists; `.claude/rules/*.md` have `paths:` pointing to folders that still exist.
- `CLAUDE.local.md` and `.claude/settings.local.json` are in `.gitignore`.
- Auto memory: whether the project's own memory directory under `~/.claude/projects/` has a `MEMORY.md` that exists and is non-empty. Status = OK if present with content. Otherwise, never report "Needs fix" — this is optional infrastructure, a project can be perfectly healthy without using it — report it informationally with a one-line note: "auto memory unused for this project — `retro` can start writing to it."

**Layer 3 — Extensions**
- `.claude/skills/verify/SKILL.md` exists and its run recipe is still correct.
- `.claude/agents/*.md` have valid frontmatter (`claude plugin validate .claude/agents` if it can run).
- `.mcp.json` contains no hard-coded secrets.

**Layer 4 — Workflow**
- `docs/tasks/_TEMPLATE/SPEC.md`, `docs/BACKLOG.md`, `.github/pull_request_template.md` and `.github/ISSUE_TEMPLATE/` (if using GitHub); flag any leftover `{{` placeholder.
- Work in progress: the contents of `.claude/current-task`.

After the table: at most 5 recommended actions, ordered by impact. Suggest `/devkit:bootstrap` to fill gaps, `/devkit:review` to review `CLAUDE.md` for conflicting instructions, `/doctor` (Claude Code built-in) for a full installation health-check, `/doctor prompt-audit` (v2.1.283+) to audit `CLAUDE.md` instructions for internal conflicts and redundancies, and `/devkit:security-scan` for a whole-project scan of secrets, dependencies, and sensitive files.
