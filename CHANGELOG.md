# Changelog — devkit

Follows [Semantic Versioning](https://semver.org): MAJOR when commands are renamed/removed or the plan/SPEC format changes; MINOR when skills/agents/features are added; PATCH for bug fixes and wording.

## [Unreleased]

### Changed

- Scope: devkit is described as a kit for one engineer or a team sharing a GitHub issue queue, with squad orchestration as the next stage (README, plugin and marketplace descriptions, repo `CLAUDE.md`). `UPSTREAM.md` and `upstream/proposals/20261018.md` record the `agile-squad` review: P-26–P-46 in two stages.

## [2.4.0] - 2026-10-18

### Added

- `templates/hooks/check-before-commit.sh`: a per-project PreToolUse `Bash` hook that runs the project's Quick check (typecheck + lint) before any `git commit` Claude or a subagent runs, and blocks the commit (exit 2, last 30 lines of output) only when the check fails; every other path exits 0. `/devkit:bootstrap` fills its command from the verified Quick check and deletes it when a project has neither typecheck nor lint; existing projects can copy it or re-run `/devkit:bootstrap`, which merges (P-7a).

### Fixed

- `scripts/release.sh` creates an annotated tag, so the suggested `git push --follow-tags` pushes it; the lightweight tag it made before was skipped, and v2.3.0 had to be pushed by hand.

## [2.3.0] - 2026-10-18

### Added

- `/devkit:security-scan` and the `security-scanner` agent (sonnet, read-only): a whole-project scan. The deterministic part runs in the plugin's `scripts/scan-secrets.sh` (one allowable command): secret patterns in the tracked tree (POSIX regex rules with a self-test, values masked to 4 chars before they reach context), sensitive tracked files (the `protect-files` hook is the oracle), and not-ignored `.env` files; `--sinks` lists risky code sinks as `path:line` + rule name only, skipping flagged files; `--check <rule> <path>` re-checks a row by count. The agent adds dependency advisories through already-installed audit tools that don't run repo code (`npm`/`pnpm`/`yarn` classic audit, `cargo audit --file`, else `osv-scanner -L`, else `not run`) and reads ±5 lines around each sink to keep plausible review candidates. The skill re-checks critical rows and writes a redacted, gitignored `security-scan/<YYYYMMDD-HHMM>.md` and points to `/security-review` for the branch diff and `gitleaks git` for history (P-14).

### Changed

- `/devkit:review` and `/devkit:check` point to `/devkit:security-scan` for a whole-project scan; conventions gain a Directories row for `security-scan/`; `templates/gitignore-additions.txt` ignores `security-scan/`.
- `scripts/test-hooks.sh` prints one fixed-width row per case (result, hook, case, expected/got exit, ms, first stderr line on failure) and a footer with case, failure, and total-time counts; timing uses bash's `time` keyword so it works on macOS `/bin/bash` 3.2; exit semantics are unchanged (P-15).

## [2.2.0] - 2026-10-17

### Added

- `block-force-push` hook: blocks `git push --force`/`-f`/`--force-with-lease`/`--force-if-includes`/`+refspec`/`--mirror` in every project; quote-, heredoc-, `$( )`- and comment-aware, so commit messages and PR bodies that mention force pushes are not blocked; normal pushes are untouched (P-18).
- `/devkit:grill`: interviews the user in rounds (each question with a recommended answer), looks facts up instead of asking, and writes `plans/<…>/decisions.md` (P-17).
- `/devkit:plan` treats a `decisions.md` as settled input; `/devkit:brainstorm` offers `/devkit:grill` when details are still open.
- GitHub issue forms (`bug.yml`, `feature.yml`, `config.yml`) in `templates/github/ISSUE_TEMPLATE/`: required where/steps/expected/actual/severity for bugs and testable Given/When/Then criteria for features; `/devkit:bootstrap` copies them and fills the Area dropdown (P-21).
- `/devkit:issue`: files a GitHub issue only once every required field is set, checks for duplicates, and labels it for the AI queue (`ai`, `severity:*`, `area:*`, creating missing labels after confirmation); can file confirmed findings from a review report (P-20).
- `upstream/proposals/20261016.md`: review of the team-practices deck, proposals P-17–P-25.

### Changed

- `/devkit:task`: `next` picks the highest-severity unclaimed `ai` issue; GitHub issues are claimed (`in-progress` label + claim comment, re-read to catch races) and released with a comment when the task stops without a PR; conventions gain a "GitHub issue queue" section (P-20).
- Agent model tiers: `fullstack-developer`, `tester` and `researcher` run on `sonnet`, and `deployer` on `haiku`; the judgment roles keep `inherit`. A `/devkit:cook` benchmark showed −30% median cost ($1.82 → $1.27) with 18/18 held-out tests on both sides. `cook` now has the main session read each phase's diff before moving on. Override with `CLAUDE_CODE_SUBAGENT_MODEL` + `CLAUDE_CODE_SUBAGENT_MODEL_FORCE=1` (P-19).
- UI evidence: for UI changes, `/devkit:ship` (gate 5) and `/devkit:task` (step 7) take a screenshot per AC state (GIF via Claude in Chrome for multi-step flows) into `evidence/` next to the plan or SPEC, publish them as one private artifact, and link it in the PR's *Screenshots / GIF* ("private — shared on request"); without the Artifact tool the PR lists the files instead. `ui-verifier` saves named screenshots and reports untrusted folders clearly; `git-manager` keeps every PR template section, writes exact *Screenshots / GIF* lines from what it is given, and ticks only checklist boxes it has evidence for; `**/evidence/` and `.playwright-mcp/` are gitignored (P-22).
- PR template: `Closes #`, a pasted "How it was verified" section, Screenshots / GIF for UI changes, and a one-concern-per-PR check; `git-manager` writes `Closes #N` when the task came from an issue (P-21).
- `templates/CLAUDE.md`: new "Remotes & never-push rules" and "Removed / reversed" sections; `bootstrap` fills them from `git remote -v` and confirmed branch protections. `conventions.md`: a convention change updates the project's `CLAUDE.md` in the same commit; a skill's tunable settings belong in a project doc the skill reads, not hardcoded in the skill. `check` flags a `CLAUDE.md` none of the last 10 convention-changing commits touched (P-23).
- `retro`'s personal-preference bucket routes to Claude Code's auto memory (`metadata.type: feedback`, read-before-write against `MEMORY.md`, link related entries with `[[name]]`) instead of `CLAUDE.local.md`, falling back to `CLAUDE.local.md` when auto memory isn't available; `retro` step 1 reads `/insights` output as extra input when already present; `check` gains an informational Layer 2 bullet reporting whether the project's auto memory is unused (P-24).
- `/devkit:plan` gains `sync <plan.md>`: pushes unsynced phases as GitHub issues (matched by exact title first, so a retry after a crash never double-creates) and pulls closed issues' state back as ticked checkboxes, never un-ticking a phase whose issue is still open; a broken or malformed link is reported, not silently retried; refuses on a draft plan; conventions gain a "Plan ↔ tracker sync" section (P-25).
- PR report artifact: `/devkit:ship`, `/devkit:task`, and `/devkit:git pr` now build and publish one report artifact — AC → evidence table with ✅/⚠️/❌ status, verification output, Screenshots/GIF (or `None (no UI change)`), manual test steps, risks, and the commit SHA, scrubbed of secrets/personal data the same way screenshots already are — for every PR, not only UI-visible ones; the PR body slims to Summary / Closes+Refs / Full report (the artifact link) / Risks and impact (kept inline) / Checklist, with `Closes #N` always kept in the literal body since GitHub only parses it there, and a condensed checklist summary passed alongside the link so `git-manager` can still tick boxes without an Artifact tool; without the Artifact tool, `git-manager` falls back to the full inline body as before. Conventions' 'UI evidence' section is renamed 'PR report artifact', folding the UI-only screenshot/GIF mechanics in as one of its sections (follow-up to P-22).

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
