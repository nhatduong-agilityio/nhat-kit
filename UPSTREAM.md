# Comparison with ClaudeKit Engineer Kit

devkit is written entirely from scratch. ClaudeKit serves only as an **idea source** through its public docs at docs.claudekit.cc. No skill, agent, or code content from ClaudeKit is copied (it is a paid product in a private repo). Every feature is described in our own words and implemented from the Claude Code documentation.

## Review checkpoint

| Item | Value |
| --- | --- |
| Last reviewed | 2026-10-09 |
| Latest ClaudeKit release in the public changelog | v2.13.0 (2026-02-25); v2.14.0 listed as "upcoming" |
| Matching devkit version | 2.0.0 |

## Feature table

Status: ✅ done · ◐ partial · ⏳ planned · ⊘ use Claude Code built-in · ✗ won't do.

### Skills / commands

| ClaudeKit (public) | devkit | Status | Notes |
| --- | --- | --- | --- |
| plan (+ red-team) | `/devkit:plan` | ✅ | `--fast`, `--hard`, `red-team <plan>` |
| cook | `/devkit:cook` | ✅ | phased TDD, review loop |
| fix | `/devkit:fix` | ✅ | |
| debug | `/devkit:debug` | ✅ | parallel debuggers per layer, bisect |
| test (diff-aware) | `/devkit:test` | ✅ | `run`, `write`, `gaps` |
| code-review | `/devkit:review` | ✅ | against plan/SPEC; complements the bundled `/code-review` |
| git | `/devkit:git` | ✅ | `cm`, `cp`, `pr`, `sync` |
| ship | `/devkit:ship` | ✅ | 8 gates |
| scout | `/devkit:scout` | ✅ | |
| brainstorm | `/devkit:brainstorm` | ✅ | |
| bootstrap | `/devkit:bootstrap` | ✅ | difference: input is a requirements doc; sets up 4 layers |
| retro | `/devkit:retro` | ✅ | |
| research | agent `researcher` | ◐ | no dedicated skill yet; see the bundled `/deep-research` |
| docs (init/update) | — | ⏳ | "Docs & project management" group |
| journal | — | ⏳ | "Docs & project management" group |
| plans-kanban, kanban, project-management | — | ⏳ | "Docs & project management" group |
| frontend-development, react-best-practices, tanstack, ui-styling, web-design-guidelines | — | ⏳ | "Frontend depth" group |
| web-testing, chrome-devtools, agent-browser | `ui-verifier` template | ◐ | "Frontend depth" group |
| worktree | `claude -w` | ⊘ | |
| loop | `/loop` | ⊘ | |
| team | agent teams / dynamic workflows | ⊘ | |
| code-simplifier | `/simplify` | ⊘ | |
| security, security-scan | `/security-review` | ⊘ | |
| skill-creator | `skill-creator` plugin | ⊘ | |
| shopify, threejs, shader, remotion, payment-integration, mobile-development, google-adk-python | — | ✗ | outside current work scope |

### Agents

| ClaudeKit | devkit | Status |
| --- | --- | --- |
| Planner | `planner` | ✅ |
| Researcher | `researcher` | ✅ |
| Fullstack Developer | `fullstack-developer` | ✅ |
| Tester | `tester` | ✅ |
| Debugger | `debugger` | ✅ |
| Code Reviewer | `code-reviewer` | ✅ |
| Git Manager | `git-manager` | ✅ |
| Brainstormer | `brainstorm` skill | ◐ |
| Code Simplifier | `/simplify` | ⊘ |
| Docs Manager | — | ⏳ |
| Project Manager | — | ⏳ |
| Journal Writer | — | ⏳ |
| UI/UX Designer | — | ⏳ |

### Infrastructure

| ClaudeKit | devkit | Status |
| --- | --- | --- |
| CLI `ck init` / `ck update` | marketplace + `claude plugin update` | ✅ |
| Protective hooks (scout-block, guards) | `protect-files` hook | ◐ |
| Quality gate hooks, diagnostics | — | ⏳ |
| Statusline | — | ⏳ |

### devkit only

`/devkit:task` (BA task → SPEC with ACs → PR with evidence), `/devkit:check`, the `requirements-analyst` agent, and 4-layer bootstrap from requirements docs.

## Review history

| Date | ClaudeKit version | Proposals | Applied in |
| --- | --- | --- | --- |
| 2026-10-09 | v2.13.0 | Initial table | devkit 2.0.0 |
