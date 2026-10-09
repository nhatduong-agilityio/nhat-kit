# Changelog — devkit

Follows [Semantic Versioning](https://semver.org): MAJOR when commands are renamed/removed or the plan/SPEC format changes; MINOR when skills/agents/features are added; PATCH for bug fixes and wording.

## [Unreleased]

### Fixed

- `README.md`: added "Getting started" section with step-by-step flows for new (greenfield) and existing projects; updated version badge to 2.1.0; corrected repo layout counts to 15 commands / 9 subagents.
- `upstream-watch`: `llms.txt` is now the primary source; skill fetches `https://docs.claudekit.cc/llms.txt` first to discover the current doc structure before reading individual pages.
- `UPSTREAM.md`: marked P-1 through P-4 and P-8 as ✅ (applied in 2.1.0); updated matching devkit version to 2.1.0; added `security-scan` (P-14) and Hook Diagnostics Dashboard (P-15) entries; added llms.txt checkpoint row.
- Added `upstream/proposals/20261009b.md`: second-pass proposal table ranking P-6, P-7, P-9, P-10, P-14, P-15 with four v2.2.0 space options (recommended: Space A — Security + Discoverability).

## [2.1.0] - 2026-10-09

### Added

- `/devkit:deploy`: new skill for post-merge deployment to staging then production. Auto-detects platform from config files (Vercel, Fly.io, Railway, Docker Compose, or a custom `deploy` script); asks for confirmation before each environment; reports deployment URLs as evidence. Supports `--dry-run` to preview without deploying.
- `deployer` agent: executes a single deployment command, captures full output, extracts the deployment URL, and reports exit code and last 20 lines.

### Fixed

- `README.md`: updated version badge to 2.0.1; replaced "push this folder" install step with `git clone` from the live repo; replaced `<github-user>/claude-kit` placeholder with `nhatduong-agilityio/nhat-kit`; expanded `user-setup/` merge instructions with concrete steps.
- `bootstrap`: Layer 3 now calls `/run-skill-generator` (built-in since Claude Code v2.1.215) instead of copying the generic verify template. Resolves ND-2: the template's `name: verify` shadowed the built-in `/verify` command. Removed `templates/skills/verify/SKILL.md`.
- `check`: re-added `/doctor prompt-audit` (confirmed built-in since v2.1.283) alongside `/doctor` in the recommendations line; includes version caveat.
- `cook`: added `/batch` escalation note for codebase-wide changes spanning 10+ independent modules.
- `plan`: added `/advisor fable` suggestion in step 6 for High/Critical risk plans.
- `ship`: added `/autofix-pr` suggestion after gate 8 opens the PR.
- All 8 agents: added expert-persona role titles to the opening instruction line (Staff Engineer, Senior SRE, QA Lead, etc.), matching the ClaudeKit v2.14.0 agent upgrade pattern.

## [2.0.1] - 2026-10-09

### Fixed

- `check`: replaced unknown `/doctor prompt-audit` reference with `/devkit:review` (CLAUDE.md review) and `/doctor` (Claude Code built-in health-check, confirmed in docs).
- `requirements-analyst`: replaced custom `## Return` section with the standard hand-off contract Result block format from conventions.md.
- `conventions.md`: added optional `## Red-team notes` section to the plan.md format template so it matches what `plan` produces after red-teaming.
- `README.md`: corrected always-on token estimate from "~2,000" to "~1,300" (measured via `claude plugin details`); added blank lines around fenced code blocks and before bullet list to fix MD031/MD032 markdownlint warnings.

## [2.0.0] - 2026-10-09

### Added

- Core skills: `plan` (scouting, parallel research, red-team), `cook` (phased implementation, TDD, review, report), `fix`, `debug`, `test` (diff-aware, gaps), `review` (against plan/SPEC, `--fix`), `git` (cm, cp, pr, sync), `ship` (8 gates), `scout`, `brainstorm`.
- Agents: `planner`, `researcher`, `fullstack-developer`, `tester`, `debugger`, `git-manager` (Haiku).
- `references/conventions.md`: shared conventions for plans, evidence, commits, the agent hand-off contract, and English-only artifacts.
- Kit maintenance: `UPSTREAM.md`, `upstream-watch` skill, `release` skill, `scripts/release.sh`, `scripts/test-hooks.sh`.

### Changed

- All kit content is in English; generated artifacts are English too.
- `code-reviewer` reviews against the plan or SPEC.
- `task` uses `tester`, `fullstack-developer`, and `git-manager`.

### Removed

- Agent `test-writer` (merged into `tester`, `write-first` mode).

## [1.0.0] - 2026-10-09

### Added

- Skills `bootstrap`, `task`, `retro`, `check`; agents `requirements-analyst`, `code-reviewer`, `test-writer`.
- Plugin hooks: block edits to sensitive files, desktop notifications.
- 4-layer project templates.
