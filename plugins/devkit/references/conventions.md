# devkit — shared conventions

Every devkit skill and agent follows this file. When a skill says "per the conventions", it means the matching section below.

## Language

All artifacts are written in English: code, comments, commit messages, plans, specs, reports, PR descriptions, and docs. Chat replies to the user follow the user's preference (see their `CLAUDE.md`).

## Directories

| Path | Contains | Written by |
| --- | --- | --- |
| `plans/<YYYYMMDD>-<slug>/plan.md` | Plan for one change | `/devkit:plan`, agent `planner` |
| `plans/<YYYYMMDD>-<slug>/decisions.md` | Decisions and verified facts settled before planning | `/devkit:grill` |
| `plans/<YYYYMMDD>-<slug>/research/*.md` | Research reports for the plan | agent `researcher` |
| `plans/<YYYYMMDD>-<slug>/report.md` | Implementation result and evidence | `/devkit:cook` |
| `docs/tasks/<TASK_ID>-<slug>/SPEC.md` | Spec for a BA task (with ACs) | `/devkit:task` |
| `docs/PROJECT_BRIEF.md`, `docs/BACKLOG.md` | Project context | `/devkit:bootstrap` |
| `.claude/current-task` | Path of the plan or SPEC in progress (one line) | the running skill; deleted when done |

`slug`: lowercase, hyphenated, at most 5 words, ASCII only. Dates use the machine's local time.

## plan.md format

```markdown
# <Title>
Status: draft | approved | in-progress | done · Source: <request / SPEC / issue>

## Goal
1–3 sentences. A visible outcome when done.

## Context found
- `path:line` — what matters (patterns to follow, constraints)

## Approach
The chosen approach and why; one line per rejected alternative.

## Phases
### Phase 1 — <name>
- [ ] Concrete step — file: `path`
- Verify: <command or check, expected result>

## Risks
| Risk | Signal | Mitigation |

## Out of scope

## Red-team notes
*(added by `/devkit:plan` when red-teaming runs; omit if not red-teamed)*
- Rejected finding: <finding> — Reason: <why dismissed>
```

Every phase must be self-verifiable: when it ends, a command produces pass/fail. Keep a phase under ~300 changed lines.

## Evidence

Never report "done" without evidence. Valid evidence:

- The command run + exit code + the key output lines.
- Names of tests added and their results.
- A screenshot or observation of the running app (UI).

"Looks right" and "should work" are not evidence.

## Commits

Conventional Commits: `<type>(<scope>): <imperative summary, ≤ 72 chars>`.
Types: `feat`, `fix`, `refactor`, `perf`, `test`, `docs`, `build`, `ci`, `chore`, `hotfix`.
Body: why the change was made; reference the task/issue (`Refs: PROJ-123`). One commit = one idea.

Before committing: no secrets (keys, tokens, passwords, `.env`), no temporary debug files, no `console.log`/`print` added for debugging.

## GitHub issue queue

Used by `/devkit:issue` (files) and `/devkit:task` (`next`, claim, release).

| Label | Meaning | Color |
| --- | --- | --- |
| `ai` | In the AI work queue | `5319e7` |
| `bug` / `enhancement` | Kind (GitHub defaults) | — |
| `severity:critical` · `severity:high` · `severity:medium` · `severity:low` | Impact; `next` picks in this order | `b60205` · `d93f0b` · `fbca04` · `c2e0c6` |
| `area:<name>` | Part of the project; names come from the Area list in `.github/ISSUE_TEMPLATE/bug.yml`, or ask | `0e8a16` |
| `in-progress` | Claimed by one machine | `1d76db` |

Create a missing label once, after the user confirms: `gh label create <name> --color <hex> --description "<meaning>"`. Never rename or delete existing labels.

Comments (first line exactly as shown, so they can be found with a search):

```text
🔒 devkit claim · host: <hostname -s> · task: <TASK_ID> · <ISO-8601 UTC time>
🔓 devkit release · host: <hostname -s> · reason: <why> · done so far: <one line, or "nothing">
```

Rules:
- Claim before writing the SPEC: add `in-progress`, post the claim comment, then re-read the comments. If another host's claim comment is newer than the last release and older than yours, the earlier claim wins: release yours and stop.
- An issue labelled `in-progress` belongs to the host in its latest claim. Take it over only when the user says so, and say so in your own claim comment.
- `gh issue list` can lag a few seconds behind changes. Read a single issue's labels and comments with `gh issue view` (no lag), and treat the duplicate check as best effort.
- Never close a queue issue by hand. It closes when the PR with `Closes #N` merges.
- Whenever the work stops without a PR (a blocking question, the user stops, it can't be done), release: remove `in-progress` and post the release comment. Leave the issue open with its `ai` label, so it goes back to the queue.

## Agent hand-off contract

Every agent ends with this block — short, without repeating file contents:

```markdown
## Result
- Status: done | blocked | partial
- Done: <1–5 bullets>
- Files: `path` (created/modified), ...
- Evidence: <command → result>
- Open issues: <if any, with a proposal>
```

## General principles

- Read `CLAUDE.md` and the rules matching the files you touch before working.
- Follow existing patterns in the repo before creating new ones. No new dependencies without asking.
- Fix root causes, not symptoms. Never disable tests or add `@ts-ignore`/`eslint-disable` to get a pass.
- YAGNI: do exactly the assigned scope. Out-of-scope ideas go under "Open issues".
- Ask before: pushing, opening/merging PRs, deleting files outside scope, running migrations, changing a public API.
