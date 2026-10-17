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

A phase heading may carry a trailing issue-link suffix: exactly one `(#<digits>)`-shaped token — e.g. `### Phase 1 — <name> (#42)` — as the LAST thing on the heading line. It is written only by `/devkit:plan sync` itself, when it links that phase to a GitHub issue; a heading without it is simply unsynced. A heading carrying more than one such trailing token, or a malformed one, is not something sync acts on silently — it is reported instead.

## Evidence

Never report "done" without evidence. Valid evidence:

- The command run + exit code + the key output lines.
- Names of tests added and their results.
- A screenshot or observation of the running app (UI).

"Looks right" and "should work" are not evidence.

### UI evidence

Used by `/devkit:ship` (gate 5), `/devkit:task` (step 7), and the `ui-verifier` agent whenever a change is visible in the UI.

- **Folder**: `evidence/` next to the plan or SPEC (`plans/<…>/evidence/`, `docs/tasks/<ID>-<slug>/evidence/`). It is gitignored (`**/evidence/`), and so is Playwright's `.playwright-mcp/`.
- **Files**: `AC<n>-<state>.png` (a screenshot per AC state; `before-`/`after-` prefix when comparing; `-mobile` suffix for the 390×844 viewport) and `<flow>.gif` for a multi-step flow. Pass the **absolute** path (`$(pwd)/…/evidence/AC1-saved.png`) as the screenshot tool's `filename`; a relative path depends on where the browser server resolves it.
- **GIF**: only when Claude in Chrome is available in the main session (`/claude-in-chrome`, with its GIF recording). Playwright gives screenshots only.
- **Content**: use test accounts and test data. Don't capture screens that show secrets, tokens, or real personal data; skip them and say why.
- **Artifact** (main session only; subagents and headless runs don't have the Artifact tool): publish one page titled `<ID or slug> UI evidence`. Pass the images as `files`, referenced by relative path. The page shows:
  - per AC: the criterion, Pass/Fail, a one-line observation, and its screenshot or GIF;
  - console and network errors, if any;
  - the commit SHA it was taken at.

  It is private until the user shares it.
- **PR**: the caller always passes `git-manager` one value: the artifact link, the file list, or `none (no UI change)`. The *Screenshots / GIF* section gets `[UI evidence](<url>) (private — shared on request)`. The final reply reminds the user to share the artifact with the reviewers from its Share menu.
- **Fallback**:
  - No Artifact tool: list the evidence file paths in that section and ask the user to drag the key images into the PR on GitHub.
  - No browser at all: say so and use the `verify` skill's output as the evidence.

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

## Plan ↔ tracker sync

Used by `/devkit:plan sync <plan.md>`.

- **Linkage**: no side file and no dedicated label. The `(#N)`-shaped suffix on the phase heading (see `plan.md format` above) is the only state that exists. A human finds a phase's issue on GitHub by its deterministic title: `<plan title>: Phase N — <phase name>`.
- **Push**: for a phase with no heading suffix, first search `gh issue list --search "<exact title>"` for an existing issue with that exact deterministic title — this is what keeps a push that was interrupted after creating the issue but before writing `(#N)` back from double-creating on retry. A match gets re-linked by appending its number to the heading; otherwise create one, with its body (the phase's checklist items + its Verify line + a link back to the plan file path) written to a temp file and passed as `--body-file`, never inline `--body`, to avoid a shell-injection risk from backticked paths in phase content. A phase whose checkboxes are already all `- [x]` at push time gets its issue closed immediately after creation or re-linking.
- **Pull**: for a synced phase, `gh issue view N --json state`. `CLOSED` ticks every remaining unchecked box under that phase; `OPEN` changes nothing. A failed lookup (404, wrong repo, revoked access) skips that phase without aborting the run, and is reported as a broken link needing manual attention — never retried silently.
- **Ratchet rule**: pull only ever moves a phase toward done; it never un-ticks a checkbox because its linked issue is open — the plan's own completion state is the stronger signal.
- Unlike a queue issue (above), a sync-created issue is meant to be closed by hand on purpose — there is no `Closes #N`-via-PR workflow for it — and that manual close is exactly what pull is watching for.
- **Guard**: refuses to run on a `Status: draft` plan; works for `approved`, `in-progress`, `done`.

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
- A skill or agent that changes a project convention (a build/test command, a per-module rule in `.claude/rules/`, a workflow rule) updates that project's `CLAUDE.md` in the same commit. A convention change and a stale `CLAUDE.md` never ship separately.
- A skill's changeable, project-tunable settings (label names, severity thresholds, area lists, and similar) belong in a project-level file the skill reads at run time, not hardcoded in the skill's own prompt. A user customizing the behavior edits that doc, not devkit's skill files. This is forward-looking guidance for new and changed skills; it does not require retrofitting existing skills (see Out of scope).
