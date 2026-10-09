---
name: task
description: Take a task from the BA (text, file, GitHub issue, Jira key, or link) through spec → plan → code → verify → review → PR, following the project's standards.
argument-hint: "<task text | file path | #issue | JIRA-123 | URL>"
disable-model-invocation: true
allowed-tools: Bash(git status *) Bash(git diff *) Bash(git log *) Bash(gh issue view *) Bash(gh pr view *)
---

# BA task → PR

Input: `$ARGUMENTS`

Spec template: the project's `docs/tasks/_TEMPLATE/SPEC.md`; if missing, use `${CLAUDE_PLUGIN_ROOT}/templates/docs/tasks/_TEMPLATE/SPEC.md` and suggest the user run `/devkit:bootstrap`.

Conventions: `${CLAUDE_PLUGIN_ROOT}/references/conventions.md`. Use a task list for the 8 steps below.

## 1. Intake — get the task content

- `#123` or a GitHub issue URL → `gh issue view`.
- A key like `ABC-123`, or a Jira/Linear/Notion URL → use the matching MCP tool if connected; if not, say which connector is needed and ask the user to paste the content.
- A file path (PDF, MD, image) → read the file. Plain text → use it verbatim.
- Set `TASK_ID` (the ticket key, or `T-<yyyymmdd>-<slug>` if there is none) and a short `slug`.

## 2. Spec — write `docs/tasks/<TASK_ID>-<slug>/SPEC.md`

Fill in the template: context, user story, acceptance criteria as Given/When/Then numbered `AC1…ACn`, out of scope, affected code areas, test plan, open questions.

Write the spec path to `.claude/current-task` (one line) so the hook can restore context after compaction.

## 3. Gap check — before writing any code

Have the `devkit:requirements-analyst` subagent check the SPEC against `docs/PROJECT_BRIEF.md`, `CLAUDE.md`, and the current code: ambiguous ACs, conflicts with existing behavior, missing edge cases (empty, network failure, permissions, i18n, accessibility, mobile).

- **Blocking** questions (can't be done correctly without an answer) → stop, draft a ready-to-send message to the BA (bullets, each with a proposed answer), save it under "Open questions" in the SPEC, and wait for the user.
- **Non-blocking** questions → record the chosen assumption in the SPEC and continue.

## 4. Plan

- Use `Explore` subagents to find the relevant files and existing patterns to follow.
- Write the "Plan" section of the SPEC: files to change, order, risks, how each AC will be verified.
- Small tasks (the diff fits in one sentence) need only a 3-line plan.
- **Present the plan and wait for the user's approval.** Suggest `Ctrl+G` to edit it directly.

## 5. Branch

If on the main branch, create a branch following the convention in CLAUDE.md (default `feat/<TASK_ID>-<slug>` or `fix/...`). If the working tree has unrelated changes, ask first; suggest `claude -w <TASK_ID>` to work in a separate worktree.

## 6. Implement against the ACs (tests first)

1. Have the `devkit:tester` subagent run in `write-first` mode on the SPEC; the tests must fail for the right reason.
2. Code until the tests pass: for a multi-phase plan, give each phase to `devkit:fullstack-developer`; for a small change, do it yourself. Follow the patterns found in step 4; no new libraries without asking.
3. After each batch of changes, run the check commands from CLAUDE.md (lint, typecheck, related tests).

## 7. Verify and review

- Run the project's `verify` skill (if any) or `/verify`.
- UI changes: have the `ui-verifier` subagent (if the project has one) check each AC in a browser, with screenshots.
- Have the `devkit:code-reviewer` subagent review the diff against the SPEC. Fix only findings that affect correctness or ACs; list the rest as optional.
- Repeat until every AC has evidence (test output, command and result, screenshot).

## 8. Ship

- Update the SPEC: mark each AC as met with its evidence; record the assumptions used.
- Commit through the `devkit:git-manager` subagent (operation `commit`, `Refs: <TASK_ID>`).
- **Ask before pushing.** Then have `devkit:git-manager` run `push` and `pr` using `.github/pull_request_template.md`: summary, AC → evidence table, risks, manual test steps, ticket link.
- Update the item's status in `docs/BACKLOG.md` if present.
- Delete `.claude/current-task`.
- End with: the PR link, which ACs still rest on assumptions the BA must confirm, and a suggestion to run `/devkit:retro` if the user had to correct Claude's direction during the task.
