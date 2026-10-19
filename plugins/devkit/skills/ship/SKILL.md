---
name: ship
description: Final quality gate before delivery — full tests, typecheck, lint, build, real-app verification, review, docs/changelog — then commit, push, and open a PR.
argument-hint: "[plan.md | SPEC.md] [base]"
disable-model-invocation: true
---

# Ship

Target document: `$ARGUMENTS` or `.claude/current-task`.

Conventions: `${CLAUDE_PLUGIN_ROOT}/references/conventions.md`. The plugin folder is `${CLAUDE_PLUGIN_ROOT}`; when you read another skill's file directly, replace the `CLAUDE_PLUGIN_ROOT` variable in it with this path. Use a task list for the gates below. **Stop at the first red gate**, report the error, and suggest `/devkit:fix`; don't run later gates.

1. **Clean**: no temporary debug files, no added `console.log`/`print`, no new TODOs without a ticket. `git status` shows no stray files. Size: run `bash ${CLAUDE_PLUGIN_ROOT}/scripts/pr-size.sh <base>` (`<base>` = the `[base]` argument; none → omit it, and the script uses `origin/HEAD`, then `main`); exit 1 (unknown base, not a repo) → report it and ask, never count it as pass; `status=over` (exit 3) → stop, show the numbers and largest files, and propose a split by concern; continue only if the user says so, and then add "oversized: N lines / M files" to Risks and impact. Limits live in the project's `docs/devkit.md`.
2. **Static**: typecheck, lint, format check per `CLAUDE.md`.
3. **Tests**: the full suite (or CI's test command if it's in `.github/workflows`).
4. **Build**: the production build command.
5. **Real app**: the project's `verify` skill if present. Collect the PR report's evidence per the conventions' "PR report artifact" section (it is rendered and published at gate 8, once review and docs are done). Keep the Screenshots/GIF sub-part conditional on the change being visible in the UI: the `ui-verifier` agent if present (if it is missing or reports no browser tools, drive the app yourself with Playwright MCP, or use `/claude-in-chrome` when a GIF of a multi-step flow helps). 
6. **Review**: the `devkit:code-reviewer` subagent with the target document. Any Critical left → stop.
7. **Docs**: user-visible behavior, API, or config changed → update the related README/docs; if the repo has `CHANGELOG.md` → add an entry under "Unreleased".
8. **Deliver**: after the last commit, write `report.json` with the gate 1–7 results, test counts, and review findings, render and publish it per the conventions (plus a condensed checklist summary, one line per PR-template checklist item, evidenced or not), or record the fallback full content when no Artifact tool is available. Then follow the `/devkit:git pr` procedure (read `${CLAUDE_PLUGIN_ROOT}/skills/git/SKILL.md`), passing `git-manager` either (a) the published report artifact's link, the condensed checklist summary, and the Risks-and-impact text (kept inline, not in the artifact), or (b), when no Artifact tool was available, the full report content for the fallback inline body. Ask for confirmation before pushing. After the PR opens, suggest `/autofix-pr` so Claude Code watches CI failures and review comments and pushes fixes automatically.

Reply with: a table of the 8 gates (passed / failed / skipped with reason), the PR link, and either a reminder that the report artifact is private until you share it with the reviewers, or, if no Artifact tool was available, a note that the full report is inline in the PR body.
