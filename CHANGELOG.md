# Changelog — devkit

Follows [Semantic Versioning](https://semver.org): MAJOR when commands are renamed/removed or the plan/SPEC format changes; MINOR when skills/agents/features are added; PATCH for bug fixes and wording.

## [Unreleased]

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
