---
name: ship
description: Final quality gate before delivery — full tests, typecheck, lint, build, real-app verification, review, docs/changelog — then commit, push, and open a PR.
argument-hint: "[plan.md | SPEC.md] [base]"
disable-model-invocation: true
---

# Ship

Target document: `$ARGUMENTS` or `.claude/current-task`.

Conventions: `${CLAUDE_PLUGIN_ROOT}/references/conventions.md`. The plugin folder is `${CLAUDE_PLUGIN_ROOT}`; when you read another skill's file directly, replace the `CLAUDE_PLUGIN_ROOT` variable in it with this path. Use a task list for the gates below. **Stop at the first red gate**, report the error, and suggest `/devkit:fix`; don't run later gates.

1. **Clean**: no temporary debug files, no added `console.log`/`print`, no new TODOs without a ticket. `git status` shows no stray files.
2. **Static**: typecheck, lint, format check per `CLAUDE.md`.
3. **Tests**: the full suite (or CI's test command if it's in `.github/workflows`).
4. **Build**: the production build command.
5. **Real app**: the project's `verify` skill if present; UI → the `ui-verifier` agent if present.
6. **Review**: the `devkit:code-reviewer` subagent with the target document. Any Critical left → stop.
7. **Docs**: user-visible behavior, API, or config changed → update the related README/docs; if the repo has `CHANGELOG.md` → add an entry under "Unreleased".
8. **Deliver**: follow the `/devkit:git pr` procedure (read `${CLAUDE_PLUGIN_ROOT}/skills/git/SKILL.md`). Ask for confirmation before pushing.

Reply with: a table of the 8 gates (passed / failed / skipped with reason) and the PR link.
