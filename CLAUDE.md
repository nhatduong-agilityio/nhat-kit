# claude-kit

Personal marketplace `nhat-kit` containing the `devkit` plugin (an engineer kit for Claude Code). This repo is the kit's source code, not an app.

# Layout
- `plugins/devkit/skills/<name>/SKILL.md` — the `/devkit:<name>` commands
- `plugins/devkit/agents/*.md` — the `devkit:<name>` subagents; plugin agents cannot use `hooks`, `mcpServers`, or `permissionMode`
- `plugins/devkit/references/conventions.md` — shared conventions; skills point to it as `${CLAUDE_PLUGIN_ROOT}/references/conventions.md`
- `plugins/devkit/templates/` — files `/devkit:bootstrap` copies into projects
- `plugins/devkit/hooks/hooks.json` + `plugins/devkit/scripts/` — hooks that run in every project; they must be safe and fast
- `.claude/skills/` — skills for maintaining the kit only (`upstream-watch`, `release`)

# Commands
- Validate: `claude plugin validate plugins/devkit --strict && claude plugin validate .`
- Test hooks: `scripts/test-hooks.sh`
- Try the plugin without installing: `claude --plugin-dir plugins/devkit`
- Release: `/release <patch|minor|major>`

# Rules
- Everything in this repo is written in English.
- Write all content from scratch. ClaudeKit is an idea source only, through its public docs; never copy its wording or code. Record comparisons in `UPSTREAM.md`.
- Skills and agents are imperative and short. `description` stays under 300 characters and says when to use the skill.
- Skills with side effects (commit, push, writing many files) set `disable-model-invocation: true`.
- Adding or renaming a skill/agent: update `README.md`, `UPSTREAM.md`, and `[Unreleased]` in `CHANGELOG.md`.
- Hook scripts: plain bash, read JSON through `plugins/devkit/scripts/json-field.sh`, never break a session (errors → exit 0, unless deliberately blocking with exit 2).
