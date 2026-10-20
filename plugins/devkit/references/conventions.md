# devkit — shared conventions

Every devkit skill and agent follows this file. When a skill says "per the conventions", it means the matching section below.

## Language

All artifacts are written in English: code, comments, commit messages, plans, specs, reports, PR descriptions, and docs. Chat replies to the user follow the user's preference (see their `CLAUDE.md`).

Exception: a stakeholder's own words (free-text answers, BA replies, quoted meeting notes) stay verbatim in the original language, followed by an English translation: `"<original>" (EN: <translation>)`. Use this shape in tables and lists alike; in a table cell, write `|` as `\|` and line breaks as `<br>` (this is not an edit). Quote an English answer once, with no translation; translate when any part is not English. Never paraphrase, shorten, or fix typos inside the quote; clarify in the translation or a separate note. An option Claude wrote and the user picked is not their words: record its text unquoted, followed by any notes they typed in the quoted shape. Replace contact details (private people's names, phone numbers, emails) with `[redacted]` in both the quote and its translation. Escaping and `[redacted]` are the only changes allowed inside a quote.

## Directories

| Path | Contains | Written by |
| --- | --- | --- |
| `plans/<YYYYMMDD>-<slug>/plan.md` | Plan for one change | `/devkit:plan`, agent `planner` |
| `plans/<YYYYMMDD>-<slug>/decisions.md` | Decisions and verified facts settled before planning | `/devkit:grill` |
| `plans/<YYYYMMDD>-<slug>/research/*.md` | Research reports for the plan | agent `researcher` |
| `plans/<YYYYMMDD>-<slug>/report.md` | Implementation result and evidence | `/devkit:cook` |
| `docs/tasks/<TASK_ID>-<slug>/SPEC.md` | Spec for a BA task (with ACs) | `/devkit:task` |
| `docs/PROJECT_BRIEF.md`, `docs/BACKLOG.md` | Project context | `/devkit:bootstrap` |
| `security-scan/<YYYYMMDD-HHMM>.md` | Redacted whole-project security scan (gitignored) | `/devkit:security-scan`, agent `security-scanner` |
| `docs/devkit.md` | Project settings devkit skills read at run time (`- key: value`; defaults when missing) | `/devkit:bootstrap`, then the team |
| `.claude/current-task` | Path of the plan or SPEC in progress (one line) | the running skill; deleted when done |

`slug`: lowercase, hyphenated, at most 5 words, ASCII only. Dates use the machine's local time.

## plan.md format

```markdown
# <Title>
Status: draft | approved | in-progress | done · Source: <request / SPEC / issue>
Approved: YYYY-MM-DD by <name>

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

The `Approved:` line is not part of a draft: it is added on approval and kept through `in-progress` and `done`; a draft has none. It is a line of its own, so status edits never touch it.

## Approval

Gates that wait for the user (plan approval, an oversized PR, a push, a deploy) pass only on an explicit yes in reply to the question: "yes", "approve", "go", "LGTM", or the same in the user's language. Silence, a hedge ("probably", "I guess"), a question, a conditional ("yes if…"), or a change request is not a yes: stop and ask again in plain words. Never proceed on an assumed yes.

- `--auto` on `/devkit:cook` is the user's explicit yes for that run; record it as `Approved: YYYY-MM-DD by <name> (--auto)`.
- `<name>`: `gh api user --jq .login`; if that fails, `git config user.name`; if both fail, `unknown`. Never guess a name. The date is local, `YYYY-MM-DD`.

## Evidence

Never report "done" without evidence. Valid evidence:

- The command run + exit code + the key output lines.
- Names of tests added and their results.
- A screenshot or observation of the running app (UI).

"Looks right" and "should work" are not evidence.

### PR report artifact

Used by `/devkit:ship` (gates 5/8), `/devkit:task` (steps 7/8), and `/devkit:git pr` — for every PR, not only ones visible in the UI.

- **Builder & timing**: **Artifact** (main session only; subagents and headless runs don't have the Artifact tool). The orchestrating skill builds and publishes the whole report before delegating to `git-manager`; `git-manager` never calls the Artifact tool itself.
- **How to build it**: write `report.json` (schema: `${CLAUDE_PLUGIN_ROOT}/references/report.md`), taking every number from a command's output (`git diff --numstat <base>...HEAD`, the test run, the reviewer's report), never from memory. Render and publish **after** the review and the last commit, so the change map, commit SHA, and review counts are final. Leave out what no command produced (for example `tests.before` when the base wasn't run). Render it with `node "${CLAUDE_PLUGIN_ROOT}/scripts/render-report.mjs" report.json > report.html`, then publish `report.html` with the screenshots as `files`. Exit 1 means the JSON is invalid; fix the JSON, not the HTML. Without `node`, build the page by hand following `report.md`.
- **Title**: `<ID or slug> PR report`.
- **Contents**:
  - Summary — the same What/Why as the PR body.
  - Acceptance criteria → evidence table, one row per AC, status shown as ✅ met / ⚠️ assumption / ❌ failed.
  - A one-line "X/Y ACs met" summary near the top.
  - How it was verified — command + output, long output collapsed in a `<details>` block, scrubbed per **Content (scrubbing)** below.
  - Screenshots/GIF — the per-AC screenshots/GIF when the change is UI-visible (see **Screenshots and GIF** below), or the literal placeholder `None (no UI change)` otherwise. Never a silently omitted heading.
  - Manual test steps.
  - Risks and impact.
  - The commit SHA.
- **Content (scrubbing)**: use test accounts and test data; don't paste a screenshot, a verification-output line, or a commit SHA that exposes a secret, token, internal path, or real personal data as-is — redact or omit it and say why. This scrubbing rule covers the whole report, not only screenshots.
- **Visualization**: ✅/⚠️/❌ status per AC row, the "X/Y ACs met" line, and `<details>` for long blocks. On top of that, the renderer draws inline charts (no library) when the data exists: the change map (lines added and removed per area), gate pills, tests before/after, review findings fixed vs remaining per severity, and metrics before/after, plus a mermaid diagram of the changed flow. The section order follows the kind of change (`feat`, `fix`, `perf`, `refactor`, `docs`/`chore`/…), as set out in `report.md`.
- **PR body**: slims to `## Summary` (1-3 sentences) → `Closes #` / `Refs:` → `## Full report` (one line: the artifact link, covering the Acceptance-criteria table, How-it-was-verified output, Screenshots/GIF, and Manual test steps) → `## Risks and impact` (stays its own inline section — not moved into the artifact) → `## Checklist`. `Closes #N` must stay written in the literal PR body: GitHub only parses its auto-close keywords from the PR description itself, never from a linked artifact page.
- **Fallback (no Artifact tool)**: applies to the whole report, not just screenshots. Don't slim the body: alongside the always-inline `## Risks and impact`, also write the full Acceptance-criteria table, How it was verified, Screenshots/GIF, and Manual test steps inline — same shape as before this change.

#### Screenshots and GIF (UI-visible changes)

- **Folder**: `evidence/` next to the plan or SPEC (`plans/<…>/evidence/`, `docs/tasks/<ID>-<slug>/evidence/`). It is gitignored (`**/evidence/`), and so is Playwright's `.playwright-mcp/`.
- **Files**: `AC<n>-<state>.png` (a screenshot per AC state; `before-`/`after-` prefix when comparing; `-mobile` suffix for the 390×844 viewport) and `<flow>.gif` for a multi-step flow. Pass the **absolute** path (`$(pwd)/…/evidence/AC1-saved.png`) as the screenshot tool's `filename`; a relative path depends on where the browser server resolves it.
- **GIF**: only when Claude in Chrome is available in the main session (`/claude-in-chrome`, with its GIF recording). Playwright gives screenshots only.
- **Content**: use test accounts and test data. Don't capture screens that show secrets, tokens, or real personal data; skip them and say why.
- **No browser at all**: say so and use the `verify` skill's output as the evidence.

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
- A claim is **stale** when it is older than `claim_ttl_minutes` in the project's `docs/devkit.md` (default 120), no release follows it, and no open PR says `Closes/Fixes/Resolves #N`; an issue whose claims are all released but which still has `in-progress` counts as stale too. `next` offers stale claims; it never takes them over on its own.
- **Back-pressure:** when open non-draft PRs reach `max_open_prs` (default 5; 0 = off), `next` suggests reviewing one first. `scripts/queue-status.sh` computes both.
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

## Retry one tier up

- When work goes back to the same agent type because its verify was red or a review/test finding must be fixed, pass the Agent `model` override one tier above that agent's `model:`: `haiku` → `sonnet`, `sonnet` → `opus`. Agents on `inherit` or `opus` keep their model.
- Only the retry escalates; the next phase or task starts again at the agent's default.
- Name the tier in the progress line and in `report.md` (cook) or the PR report (task), e.g. "Phase 2: retry 1 on opus".
- With `CLAUDE_CODE_SUBAGENT_MODEL_FORCE=1`, the forced model is expected to win, so nothing escalates (not verified).

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
- A skill's changeable, project-tunable settings (label names, severity thresholds, area lists, and similar) belong in the project's `docs/devkit.md` (or, for lists the GitHub forms already own, those forms), which the skill reads at run time, not hardcoded in the skill's own prompt. A user customizing the behavior edits that doc, not devkit's skill files. This is forward-looking guidance for new and changed skills; it does not require retrofitting existing skills (see Out of scope).
