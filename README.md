# claude-kit — a personal engineer kit for Claude Code

The `nhat-kit` marketplace contains the **devkit 2.0.0** plugin: 14 commands, 8 subagents, 2 hooks, and 4-layer project templates. It is written entirely from scratch, using ClaudeKit Engineer Kit only as an idea source through its public docs (see `UPSTREAM.md`). It costs about 1,300 always-on tokens per session. Every artifact the kit produces is in English.

## Commands

| Command | Use when | Orchestrates |
| --- | --- | --- |
| `/devkit:bootstrap <docs>` | Starting a project, or bringing Claude into an existing repo | requirements-analyst, Explore |
| `/devkit:task <ticket>` | The BA assigns a task: SPEC with ACs → PR with evidence | requirements-analyst, tester, fullstack-developer, code-reviewer, git-manager |
| `/devkit:brainstorm <problem>` | You don't know which direction to take | researcher, Explore |
| `/devkit:plan <request> [--fast\|--hard]` | The change touches many files or the approach is unclear | Explore, researcher, planner, red-team |
| `/devkit:plan red-team <plan.md>` | Challenge an existing plan | 2 adversarial reviewers |
| `/devkit:cook <plan.md\|request>` | Implement end to end, phase by phase | tester → fullstack-developer → code-reviewer |
| `/devkit:scout <topic>` | You need a quick code map | 2–6 parallel Explore agents |
| `/devkit:fix <error>` | A specific error, failing test, build/type error | debugger when needed |
| `/devkit:debug <symptom>` | Hard, flaky, or regression bugs | debuggers per layer, bisect |
| `/devkit:test [run\|write\|gaps]` | Run diff-aware tests, write tests, fill coverage gaps | tester |
| `/devkit:review [base\|#PR] [--fix]` | Review against the plan/SPEC | code-reviewer |
| `/devkit:git cm\|cp\|pr\|sync` | Commit, push, open a PR | git-manager (Haiku) |
| `/devkit:ship` | Final gate, then open a PR | 8 gates + code-reviewer + git-manager |
| `/devkit:retro` | After a task where you had to correct Claude several times | — |
| `/devkit:check` | Health-check a project's 4 layers | — |

Claude may invoke these on its own when relevant: `plan`, `fix`, `debug`, `test`, `review`, `scout`, `brainstorm`. These run only when you type them because they have side effects: `bootstrap`, `task`, `cook`, `git`, `ship`, `retro`, `check`.

## The 4 layers bootstrap sets up in each project

| Layer | Content | Files in the project |
| --- | --- | --- |
| 1. Config & permissions | Commands allowed freely, commands that ask, blocked files; format and context-restore hooks | `.claude/settings.json`, `.claude/hooks/*.sh`, `.gitignore` |
| 2. Memory & context | Build/test commands, conventions, per-module rules, business brief | `CLAUDE.md`, `.claude/rules/*.md`, `docs/PROJECT_BRIEF.md`, `docs/architecture.md` |
| 3. Extensions | Browser-based UI verifier, real-app verify skill, MCP integrations | `.claude/agents/ui-verifier.md`, `.claude/skills/verify/`, `.mcp.json` |
| 4. Workflow | Backlog, task spec template, PR template | `docs/BACKLOG.md`, `docs/tasks/_TEMPLATE/SPEC.md`, `.github/pull_request_template.md` |

## Workflows

```text
New project:     /devkit:bootstrap docs/srs.pdf
BA task:         /devkit:task PROJ-381            (end to end, up to the PR)
Own feature:     /devkit:brainstorm → /devkit:plan → /devkit:cook → /devkit:ship
Something broke: /devkit:fix  (hard ones: /devkit:debug first)
Periodically:    /devkit:retro, /devkit:check
```

Plans live in `plans/<date>-<slug>/` (plan.md, research/, report.md); task specs in `docs/tasks/<ID>-<slug>/SPEC.md`. Plans, pushes, and PRs always wait for your approval. Shared conventions: `plugins/devkit/references/conventions.md`.

## Install (once per machine)

1. Install Claude Code and the VS Code extension:

   ```bash
   curl -fsSL https://claude.ai/install.sh | bash
   ```

2. Push this folder to a **private** GitHub repo (e.g. `claude-kit`) so every machine updates from the same source.
3. Add the marketplace and install the plugin:

   ```bash
   claude plugin marketplace add <github-user>/claude-kit   # or a local path: ~/claude-kit
   claude plugin install devkit@nhat-kit
   claude plugin details devkit
   ```
4. Merge `user-setup/settings.json` into `~/.claude/settings.json` (auto mode by default, blocks reading `.env`), and `user-setup/CLAUDE.md` into `~/.claude/CLAUDE.md` (chat in Vietnamese, all artifacts in English).
5. Hooks need `bash`. On Windows, use WSL or Git for Windows. JSON is parsed with `jq`, falling back to `python3`, then `node`.

## Updating (like `ck update`)

On each machine that uses the kit:

```bash
claude plugin marketplace update nhat-kit
claude plugin update devkit@nhat-kit      # restart Claude Code to apply
```

To release a new version (in the `claude-kit` repo, opened in Claude Code):

1. Edit skills/agents; log the changes under `[Unreleased]` in `CHANGELOG.md`.
2. Run `/release patch|minor|major`. It validates the plugin, runs `scripts/test-hooks.sh`, bumps `version`, finalizes the CHANGELOG, commits, tags `vX.Y.Z`, then asks before pushing.

Semver: **major** when commands are renamed/removed or the plan/SPEC format changes; **minor** when skills/agents are added; **patch** for fixes and wording.

## Tracking ClaudeKit

`/upstream-watch` is a skill that lives only in the kit repo. It reads ClaudeKit's **public** changelog and feature list plus the Claude Code docs, and compares them with `UPSTREAM.md`. It then writes proposals to `upstream/proposals/<date>.md`, sorting each item into one of four groups: add, improve, use built-in, or skip. It never edits skills. Pick the proposals you want, run `/devkit:plan` → `/devkit:cook` inside the kit repo, then `/release`.

To run it weekly, once the repo is on GitHub, open the kit repo in Claude Code and type:

```text
/schedule every Monday at 8:45am Asia/Saigon, run /upstream-watch on the claude-kit repo and open a PR with the proposals
```

Routines run in the cloud, so they can see the skills committed in the repo's `.claude/skills/`.

Rule: never obtain or copy ClaudeKit skill content or code (it's a paid product in a private repo). Learn ideas from the public docs only and write everything yourself.

## Roadmap

`UPSTREAM.md` tracks the status of each feature. Planned groups:

- **Frontend depth**: React/Next/TanStack best practices, design-token UI styling, design-to-code from Figma, web testing with Playwright.
- **Docs & project management**: docs init/update, journal, kanban for plans, project-manager.
- **Kit infrastructure**: quality-gate hooks, statusline, skill evals (`claude plugin eval`).

## Repo layout

```text
claude-kit/
├── .claude-plugin/marketplace.json
├── .claude/skills/{upstream-watch,release}/   # kit maintenance only
├── CLAUDE.md  CHANGELOG.md  UPSTREAM.md  README.md
├── scripts/{release.sh,test-hooks.sh}
├── user-setup/{settings.json,CLAUDE.md}
└── plugins/devkit/
    ├── .claude-plugin/plugin.json
    ├── skills/      14 commands
    ├── agents/      8 subagents
    ├── hooks/hooks.json, scripts/
    ├── references/conventions.md
    └── templates/   CLAUDE.md, settings.json, rules, hooks, agents, docs, PR
```
