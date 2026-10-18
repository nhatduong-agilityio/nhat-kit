---
name: task
description: Take a task from the BA (text, file, GitHub issue, Jira key, or link) through spec → plan → code → verify → review → PR, following the project's standards.
argument-hint: "<task text | file path | #issue | next | JIRA-123 | URL>"
disable-model-invocation: true
allowed-tools: Bash(git status *) Bash(git diff *) Bash(git log *) Bash(gh issue view *) Bash(gh issue list *) Bash(gh pr view *) Bash(bash */pr-size.sh *)
---

# BA task → PR

Input: `$ARGUMENTS`

Spec template: the project's `docs/tasks/_TEMPLATE/SPEC.md`; if missing, use `${CLAUDE_PLUGIN_ROOT}/templates/docs/tasks/_TEMPLATE/SPEC.md` and suggest the user run `/devkit:bootstrap`.

Conventions: `${CLAUDE_PLUGIN_ROOT}/references/conventions.md` (GitHub issues: its **GitHub issue queue** section). Use a task list for the 8 steps below.

## 1. Intake — get the task content

- `next` → pick from the queue: `gh issue list --label ai --state open --limit 100 --json number,title,labels,createdAt`, drop issues labelled `in-progress`, sort by severity (`critical`, `high`, `medium`, `low`, none) then oldest. Show the top 3 with `AskUserQuestion`, the first recommended; the choice confirms the claim. An empty queue → say so and stop.
- `#123` or a GitHub issue URL → `gh issue view`.
- **Claim** any GitHub issue before step 2, per the conventions. If it is labelled `in-progress`, show the latest claim (host, time) and stop unless the user says to take it over. Otherwise add `in-progress`, post the claim comment, re-read the comments with `gh issue view`, and release and stop if an earlier claim from another host wins. From here on, any stop without a PR means **Release** (end of this skill).
- A key like `ABC-123`, or a Jira/Linear/Notion URL → use the matching MCP tool if connected; if not, say which connector is needed and ask the user to paste the content.
- A file path (PDF, MD, image) → read the file. Plain text → use it verbatim.
- Set `TASK_ID` (the ticket key, or `T-<yyyymmdd>-<slug>` if there is none) and a short `slug`.

## 2. Spec — write `docs/tasks/<TASK_ID>-<slug>/SPEC.md`

Fill in the template: context, user story, acceptance criteria as Given/When/Then numbered `AC1…ACn`, out of scope, affected code areas, test plan, open questions.

Write the spec path to `.claude/current-task` (one line) so the hook can restore context after compaction.

## 3. Gap check — before writing any code

Have the `devkit:requirements-analyst` subagent check the SPEC against `docs/PROJECT_BRIEF.md`, `CLAUDE.md`, and the current code: ambiguous ACs, conflicts with existing behavior, missing edge cases (empty, network failure, permissions, i18n, accessibility, mobile).

- **Blocking** questions (can't be done correctly without an answer) → stop, draft a ready-to-send message to the BA (bullets, each with a proposed answer), save it under "Open questions" in the SPEC, and wait for the user. If the user won't continue in this session, **Release** the issue.
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
2. Code until the tests pass: for a multi-phase plan, give each phase to `devkit:fullstack-developer` (if a phase's checks are red, send it back one tier up per the conventions' "Retry one tier up"); for a small change, do it yourself. Follow the patterns found in step 4; no new libraries without asking.
3. After each batch of changes, run the check commands from CLAUDE.md (lint, typecheck, related tests).

## 7. Verify and review

- Run the project's `verify` skill (if any) or `/verify`.
- Build the PR report content per the conventions' "PR report artifact" section. For UI changes, collect its Screenshots/GIF sub-part: have the `ui-verifier` subagent (if the project has one) check each AC in a browser and save screenshots to `docs/tasks/<TASK_ID>-<slug>/evidence/`; if there is no `ui-verifier`, or it reports no browser tools, do the same yourself with the browser tools you have (Playwright MCP or `/claude-in-chrome`). Publish the whole report as one artifact plus a condensed checklist summary (one line per PR-template checklist item, evidenced or not), or keep the fallback full content when no Artifact tool is available.
- Have the `devkit:code-reviewer` subagent review the diff against the SPEC. Fix only findings that affect correctness or ACs (a fix sent back to a subagent follows "Retry one tier up"); list the rest as optional.
- Repeat until every AC has evidence (test output, command and result, screenshot).

## 8. Ship

- Update the SPEC: mark each AC as met with its evidence; record the assumptions used.
- Commit through the `devkit:git-manager` subagent (operation `commit`, `Refs: <TASK_ID>`).
- Run `bash ${CLAUDE_PLUGIN_ROOT}/scripts/pr-size.sh <base>` (`<base>` = the branch the PR will target, usually the default branch); exit 1 → report it and ask; over the limit → propose a split and continue only if the user says so (note it in Risks and impact).
- **Ask before pushing.** Then have `devkit:git-manager` run `push` and `pr` using `.github/pull_request_template.md`, passing either (a) the report artifact link, the condensed checklist summary, and the Risks-and-impact text, or (b), when no Artifact tool was available in step 7, the full report content for the fallback inline body.
- Update the item's status in `docs/BACKLOG.md` if present.
- Delete `.claude/current-task`.
- End with: the PR link, either a reminder to share the report artifact with the reviewers or, if no Artifact tool was available, a note that the full report is inline in the PR body, which ACs still rest on assumptions the BA must confirm, and a suggestion to run `/devkit:retro` if the user had to correct Claude's direction during the task.

## Release (GitHub issues only)

Whenever the task stops without a PR (a blocking question, the user stops it, it can't be done): remove `in-progress`, post the release comment (reason, what was done so far), and leave the issue open with its `ai` label. Never close it; it closes when the PR with `Closes #N` merges.
