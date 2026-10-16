# Comparison with ClaudeKit Engineer Kit

devkit is written entirely from scratch. ClaudeKit serves only as an **idea source** through its public docs at docs.claudekit.cc. No skill, agent, or code content from ClaudeKit is copied (it is a paid product in a private repo). Every feature is described in our own words and implemented from the Claude Code documentation.

## Review checkpoint

| Item | Value |
| --- | --- |
| Last reviewed | 2026-10-16 (ClaudeKit unchanged; team-practices deck added as a source) |
| Latest ClaudeKit release in the public changelog | v2.13.0 (2026-02-25); v2.14.0 upcoming (deploy ✅, llms, project-organization, 3-tier evals, expert-persona ✅, security-scan, ship ✅, retro ✅) |
| llms.txt reviewed | https://docs.claudekit.cc/llms.txt — 2026-10-16 |
| Claude Code commands reference | code.claude.com/docs/en/commands — reviewed 2026-10-16 |
| Matching devkit version | 2.1.0 |

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
| security-scan (v2.14.0 upcoming) | — | ⏳ | P-14: vulnerability scan, OWASP checks, secrets detection |
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
| Protective hooks (scout-block, guards) | `protect-files`, `block-force-push` hooks | ◐ |
| Quality gate hooks, diagnostics | — | ⏳ | P-7: extend test-hooks.sh with LLM-judge step |
| Hook Diagnostics Dashboard (CLI v3.36.0 upcoming) | — | ⏳ | P-15: execution logs, timing, and error output from test-hooks.sh |
| Statusline | — | ⏳ | |
| 3-tier eval system (v2.14.0 upcoming) | — | ⏳ | P-7 covers the hooks layer |

### Claude Code built-ins (new, reviewed 2026-10-09)

| Built-in | devkit impact | Status |
| --- | --- | --- |
| `/run` + `/run-skill-generator` | bootstrap now calls `/run-skill-generator`; verify template removed (ND-2) | ✅ P-1 (2.1.0) |
| `/batch` | mentioned in `cook` for large parallel changes | ✅ P-2 (2.1.0) |
| `/advisor` | mentioned in `plan` for high-risk plans | ✅ P-3 (2.1.0) |
| `/autofix-pr` | mentioned in `ship` gate 8 after PR opens | ✅ P-4 (2.1.0) |
| `/design` | built-in; no devkit equivalent needed | ⊘ |
| `/goal` | persistent goals across turns | ⊘ |
| `/dataviz` | data-visualization guidance | ⊘ |
| `/slides` | slide-deck creation | ⊘ |
| `/doctor prompt-audit` | re-added to `check` with v2.1.283+ caveat | ✅ P-8 (2.1.0) |
| `/import` | migrate from Cursor/Codex/Gemini | ⊘ |
| `/verify` | `task`/`ship` verification step; UI evidence published as an artifact (P-22) | ⊘ |
| `/background`, `/rename`, `/resume`, `/remote-control` | long-lived sessions; replaces tmux launcher scripts | ⊘ |
| `/fork`, `/subtask` | background research copies | ⊘ |
| `/team-onboarding`, `/insights` | usage-history reports; P-24 may feed `/insights` into `retro` | ⊘ |

### Team-practices deck (Oct 2026, reviewed 2026-10-16)

Practices from another team's seven-week report, used as an idea source. See `upstream/proposals/20261016.md`.

| Practice | devkit | Status | Notes |
| --- | --- | --- | --- |
| Grill-before-plan question rounds | `/devkit:grill` | ✅ | P-17 |
| Hooks over reminders (never force-push) | `block-force-push` hook | ✅ | P-18 |
| Opus advises, Sonnet builds, Haiku runs | agent `model:` tiers | ✅ | P-19: −30% median cook cost, same held-out results |
| GitHub issues as AI work queue (file, claim, fix, release) | `/devkit:issue` + `/devkit:task #N\|next` | ✅ | P-20 |
| Issues/PRs a stranger can act on | `ISSUE_TEMPLATE/` forms + `pull_request_template.md` | ✅ | P-21 |
| Verification evidence as an artifact (screenshots, GIF) | `ship` gate 5 / `task` step 7 + `ui-verifier` | ✅ | P-22 |
| Living CLAUDE.md; rules in files skills read | `templates/CLAUDE.md` | ◐ | P-23 |
| Personal memory for repeated corrections | `retro` | ◐ | P-24 |
| Markdown plan ↔ tracker two-way sync | — | ⏳ | P-25 |
| Subagents for searching | `/devkit:scout` | ✅ | |
| Plan mode as the gate | `/devkit:plan`, `/plan` | ✅ | |
| Connectors (Slack, Drive, Gmail, Trello, Calendar) | `mcp.json.example` | ✗ | per-user setup |
| docx/pptx deliverables, timesheets, ADO sync | — | ✗ | domain-specific |

### devkit only

`/devkit:task` (BA task → SPEC with ACs → PR with evidence), `/devkit:check`, the `requirements-analyst` agent, and 4-layer bootstrap from requirements docs.

## Review history

| Date | ClaudeKit version | Proposals | Applied in |
| --- | --- | --- | --- |
| 2026-10-09 | v2.13.0 | Initial table | devkit 2.0.0 |
| 2026-10-09 | v2.13.0 / v2.14.0 upcoming | P-1–P-11 proposed; P-12/P-13 skipped; P-1–P-8, P-11 applied | devkit 2.1.0 |
| 2026-10-09 | v2.14.0 upcoming; llms.txt | Second pass: P-14 (security-scan), P-15 (hook diagnostics); see upstream/proposals/20261009b.md | — |
| 2026-10-16 | v2.13.0 / v2.14.0 still upcoming | ClaudeKit unchanged; team-practices deck → P-17–P-25; see upstream/proposals/20261016.md | — |
