---
name: bootstrap
description: Set up all 4 Claude Code layers (config, memory, extensions, workflow) for a project from its requirements docs. Use when starting a new project or bringing Claude into an existing repo.
argument-hint: "[docs ...] [--greenfield]"
disable-model-invocation: true
allowed-tools: Bash(git status *) Bash(git log *) Bash(ls *) Bash(wc *)
---

# Bootstrap a project — 4 layers

Input docs: `$ARGUMENTS`

With no arguments: use files the user attached or @-mentioned in the conversation; otherwise look in `docs/`, `requirements/`, `specs/`; if nothing is found, ask the user where the docs are and stop.

Templates live in `${CLAUDE_PLUGIN_ROOT}/templates/`. Before writing a file, read its template, replace every `{{PLACEHOLDER}}` with a real value, and delete lines that don't apply and every `<!-- TEMPLATE: ... -->` comment.

Conventions: `${CLAUDE_PLUGIN_ROOT}/references/conventions.md`. Every file you write is in English.

## Hard rules

- **Never overwrite.** If a file exists (CLAUDE.md, settings, rules, .mcp.json…), read it, merge what's missing, and report what changed.
- **Never invent commands.** Only record build/test/lint commands found in `package.json`, `Makefile`, `pyproject.toml`… or commands you just created and ran successfully.
- **Never write secrets.** Tokens, keys, and internal URLs with credentials go through environment variables.
- **Small and correct.** CLAUDE.md stays under 120 lines and only records what Claude can't infer from the code.
- Use a task list so the user can follow the 8 steps below.

## Step 0 — Detect the repo state

Run `git status`, `ls -a`, and look for manifests (`package.json`, `pnpm-lock.yaml`, `pyproject.toml`, `go.mod`, `pom.xml`, …), `.claude/`, `CLAUDE.md`, `AGENTS.md`, `.github/workflows/`.

- **GREENFIELD**: the folder is empty or holds only docs, or `--greenfield` was passed.
- **EXISTING**: code already exists. Do not scaffold.

## Step 1 — Analyze (in parallel, with subagents)

1. Give the `devkit:requirements-analyst` subagent all input docs. Ask it to write `docs/PROJECT_BRIEF.md` from `${CLAUDE_PLUGIN_ROOT}/templates/docs/PROJECT_BRIEF.md` and `docs/BACKLOG.md` from `${CLAUDE_PLUGIN_ROOT}/templates/docs/BACKLOG.md`, and to return a summary: proposed or required stack, modules/domains, external integrations, non-functional requirements, open questions for the BA.
2. If EXISTING: at the same time, have an `Explore` subagent (very thorough) map the codebase: stack and versions, package manager, existing scripts, folder and module structure, test framework, lint/format tools, CI, commit/branch conventions visible in git log.

## Step 2 — Settle decisions and present the plan

Use `AskUserQuestion` (at most 4 questions, each with a recommended option) only for what the docs and code don't settle, for example:

- Stack and framework (GREENFIELD), package manager, test framework.
- Which MCP integrations to connect (issue tracker, Figma, DB, Sentry, browser).
- Whether to set up PR review in CI.

Then present the **BOOTSTRAP PLAN**: a table of every file to create or modify, per layer, plus the commands to run. **Stop and wait for the user's approval** before writing any file.

## Step 3 — Scaffold (GREENFIELD only)

- Use the stack's official scaffolder non-interactively; `git init` if needed.
- Ensure these scripts exist: `dev`, `build`, `lint`, `typecheck` (if typed), `test`, `format`. Add any that are missing.
- Install dependencies and run each script once; fix until each one works. Commit: `chore: scaffold project`.

## Step 4 — Layer 1: Config & permissions

- `.claude/settings.json` from `templates/settings.json`: `allow` exactly the commands that ran successfully; `ask` for `git push`; `deny` reading `.env*` and editing generated-code folders (if any).
- Copy `templates/hooks/*.sh` to `.claude/hooks/` and `chmod +x` them. Keep the format hook only if the project has a formatter.
- Append the lines from `templates/gitignore-additions.txt` to `.gitignore` (skip lines already present).
- Do not set `defaultMode` in the project file — Claude Code ignores `auto`/`bypassPermissions` there; the user sets it in `~/.claude/settings.json`.

## Step 5 — Layer 2: Memory & context

- `CLAUDE.md` from `templates/CLAUDE.md`, filled from the brief and the verified commands. Point to `docs/PROJECT_BRIEF.md` with a plain path, not an `@import` (imports load into every session), unless the brief is under 60 lines.
- `.claude/rules/<domain>.md` for each module with its own conventions, each with `paths:` matching that module's folder. Start from `templates/rules/`; delete rules that merely restate language defaults.
- `docs/architecture.md`: GREENFIELD records architecture decisions and why; EXISTING records a short module map.
- An empty `CLAUDE.local.md` with a one-line explanation (already gitignored).

## Step 6 — Layer 3: Extensions

- If the project has a web UI: copy `templates/agents/ui-verifier.md` to `.claude/agents/` (this agent needs an inline MCP server, so it must live in the project — plugin agents can't declare one).
- `.mcp.json`: only servers the user approved in step 2, following `templates/mcp.json.example`; credentials via environment variables. Remind the user to run `/mcp` to sign in with OAuth.
- Run `/run-skill-generator` so Claude Code writes a project-specific `verify` (and `run`) skill that knows this project's actual build and launch commands. (Built-in since Claude Code v2.1.215; if unavailable, write `.claude/skills/verify/SKILL.md` manually with the build/run recipe from step 3.)
- List (don't install) plugins worth adding for this stack, e.g. a TypeScript code intelligence plugin, with the install commands.

## Step 7 — Layer 4: Workflow & automation

- Copy `templates/docs/tasks/_TEMPLATE/SPEC.md` to `docs/tasks/_TEMPLATE/SPEC.md`.
- If the remote is GitHub: `.github/pull_request_template.md` from `templates/github/pull_request_template.md`.
- Don't install CI. In the final report, suggest `/install-github-app` (PR review in CI), `/schedule` (a morning PR review routine), `/autofix-pr`.

## Step 8 — Verify and hand off

1. Run lint, typecheck, and tests; all must pass (or note clearly which failures pre-date the bootstrap).
2. Test each hook script with sample JSON, e.g. `echo '{"tool_input":{"file_path":"src/x.ts"}}' | .claude/hooks/format-on-edit.sh; echo $?`.
3. If `.claude/agents/` exists: run `claude plugin validate .claude/agents`.
4. `wc -l CLAUDE.md` must be under 120.
5. Ask before committing; message: `chore: bootstrap claude code setup`.
6. The final report contains: a 4-layer table (files created / merged / skipped), open questions to send the BA, the first 3 backlog items with a `/devkit:task <item>` command to start each, and what the user must do themselves (set a personal `defaultMode`, sign in via `/mcp`, install suggested plugins).
