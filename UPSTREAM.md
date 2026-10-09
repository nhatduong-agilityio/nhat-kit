# Comparison with ClaudeKit Engineer Kit

devkit is written entirely from scratch. ClaudeKit serves only as an **idea source** through its public docs at docs.claudekit.cc. No skill, agent, or code content from ClaudeKit is copied (it is a paid product in a private repo). Every feature is described in our own words and implemented from the Claude Code documentation.

## Review checkpoint

| Item | Value |
| --- | --- |
| Last reviewed | 2026-10-09 |
| Latest ClaudeKit release in the public changelog | v2.13.0 (2026-02-25); v2.14.0 announced as upcoming (deploy, llms, project-organization, 3-tier evals, expert-persona agents) |
| Claude Code commands reference | code.claude.com/docs/en/commands — reviewed 2026-10-09 |
| Matching devkit version | 2.0.1 |

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
| deploy (v2.14.0 upcoming) | `/devkit:deploy` | ✅ | P-5 done: staging → prod, auto-detects platform, asks before prod |
| llms (v2.14.0 upcoming) | — | ⏳ | P-6: `/devkit:llms` llms.txt generator |
| project-organization (v2.14.0) | — | ⏳ | relates to bootstrap 4-layer setup |
| backend-development | — | ⏳ | P-9: `/devkit:backend` server-side architecture skill |
| databases | — | ⏳ | P-10: `/devkit:db` or merged into P-9 |
| stitch | — | ✗ | Google Stitch design — outside current stack |
| shopify, threejs, shader, remotion, payment-integration, mobile-development, google-adk-python, cti-expert, watzup, xia, ai-artist | — | ✗ | outside current work scope |

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
| Quality gate hooks, diagnostics | — | ⏳ | P-7: extend test-hooks.sh with LLM-judge step |
| Statusline | — | ⏳ | |
| 3-tier eval system (v2.14.0 upcoming) | — | ⏳ | P-7 covers the hooks layer |

### Claude Code built-ins (new, reviewed 2026-10-09)

| Built-in | devkit impact | Status |
| --- | --- | --- |
| `/run` + `/run-skill-generator` | bootstrap should call `/run-skill-generator` instead of copying verify template | ⏳ P-1 |
| `/batch` | mention in `cook` for large parallel changes | ⏳ P-2 |
| `/advisor` | suggest in `plan` for high-risk plans | ⏳ P-3 |
| `/autofix-pr` | mention in `ship` gate 8 after PR opens | ⏳ P-4 |
| `/design` | built-in; no devkit equivalent needed | ⊘ |
| `/goal` | persistent goals across turns | ⊘ |
| `/dataviz` | data-visualization guidance | ⊘ |
| `/slides` | slide-deck creation | ⊘ |
| `/doctor prompt-audit` | confirmed built-in (v2.1.283+); re-add to `check` | ⏳ P-8 |
| `/import` | migrate from Cursor/Codex/Gemini | ⊘ |

### devkit only

`/devkit:task` (BA task → SPEC with ACs → PR with evidence), `/devkit:check`, the `requirements-analyst` agent, and 4-layer bootstrap from requirements docs.

## Review history

| Date | ClaudeKit version | Proposals | Applied in |
| --- | --- | --- | --- |
| 2026-10-09 | v2.13.0 | Initial table | devkit 2.0.0 |
| 2026-10-09 | v2.13.0 / v2.14.0 upcoming | P-1 through P-11; see upstream/proposals/20261009.md | — |
