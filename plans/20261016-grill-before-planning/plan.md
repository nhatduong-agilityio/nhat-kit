# Grill before planning
Status: in-progress · Source: P-17 in `upstream/proposals/20261016.md`

## Goal
`/devkit:grill <idea>` interviews the user in rounds until no assumption about the idea is left unstated. It writes the decisions to `plans/<YYYYMMDD>-<slug>/decisions.md`, and `/devkit:plan` takes them as settled input. Today `plan` and `brainstorm` each stop after 3 questions, so unasked questions become silent assumptions in the plan.

## Context found
- `plugins/devkit/skills/brainstorm/SKILL.md:1-20`: the pattern to follow. It has short imperative steps, uses `AskUserQuestion`, `/devkit:scout` for code and `devkit:researcher` for outside facts, writes one file under `plans/<…>/`, and ends by suggesting `/devkit:plan <file>`.
- `plugins/devkit/skills/plan/SKILL.md:22`: "ask at most 3 questions with `AskUserQuestion`". It needs to treat a decisions file as already answered.
- `plugins/devkit/references/conventions.md:11-18`: the Directories table, which needs a row for `decisions.md`.
- `README.md:3` and `README.md:191`: "15 commands" becomes 16. Also update `README.md:11` (commands table), `README.md:26` (model-invocable vs user-only lists), and `README.md:42` and `README.md:81` (workflow lines).
- `UPSTREAM.md:110`: the row "Grill-before-plan question rounds", currently ⏳ P-17.
- CLAUDE.md rules: skills are imperative and short; `description` is under 300 characters and says when to use the skill; a new skill updates README, UPSTREAM and the `[Unreleased]` section of CHANGELOG.

## Approach
Add one new skill file and make small edits to `plan`, `brainstorm` and conventions. No agent, hook or script is needed.

How the skill works:
1. Restate the idea in 1–2 sentences. Build an **assumption ledger**: every point the plan would otherwise have to guess, such as scope, behavior, data, edge cases, errors, UX states, rollout and non-goals.
2. **Facts are looked up, not asked.** Anything the code, docs or config can answer is checked with `/devkit:scout` or by reading files, and with `devkit:researcher` for outside knowledge. The result is recorded with its source (`path:line` or URL).
3. **Decisions are asked in rounds.** Each round is one `AskUserQuestion` call with up to 4 questions. Each question gives 2–4 options, with the recommended option first and labeled "(Recommended)". The most consequential questions come first, and later rounds build on earlier answers.
4. **Check in after every 3 rounds.** Offer "continue" or "stop: use the recommended answer for the rest". Defaults chosen this way are marked as such in the file.
5. **Done when** every ledger item is either a verified fact or a decision. Then write `decisions.md` and suggest `/devkit:plan plans/<…>/decisions.md`.

`decisions.md` format: Goal · Decisions (question, answer, why, who decided: user or default) · Verified facts (with source) · Deferred or open items · Out of scope.

Set `disable-model-invocation: true`, so the skill only runs when the user types it. Long rounds of questions should be the user's choice, and leaving it out of Claude's skill list keeps the always-on token cost the same.

Rejected alternatives:
- Raising the question cap in `plan`: that mixes interviewing with planning and makes every plan heavier.
- Adding a `--grill` flag to `brainstorm`: brainstorm picks a direction, while grill pins down the details of a direction that is already chosen. They are different jobs and run at different times.
- A dedicated agent: subagents can't ask the user questions, so the interviewing has to happen in the main session.

## Phases

### Phase 1: The skill (foundational)
- [x] Create `plugins/devkit/skills/grill/SKILL.md` as described in the Approach. Frontmatter: `name: grill`, `description` (under 300 characters, says when to use it), `argument-hint: "<idea | brainstorm.md | SPEC.md>"`, `disable-model-invocation: true`. Body: under about 50 lines, numbered imperative steps, the `decisions.md` template, and a rule that it writes no code.
- Verify:
  - `claude plugin validate plugins/devkit --strict` passes.
  - `awk '/^description:/{print length($0)-13}' plugins/devkit/skills/grill/SKILL.md` prints a number below 300.

### Phase 2: Hand-off into the existing flow
- [x] `plugins/devkit/skills/plan/SKILL.md` step 1: if the input is a `decisions.md`, treat its decisions as settled and ask only about anything new that scouting turns up.
- [x] `plugins/devkit/skills/brainstorm/SKILL.md` step 6: after a direction is chosen, also offer `/devkit:grill plans/<…>/brainstorm.md` when many details are still open.
- [x] `plugins/devkit/references/conventions.md`: add a Directories row for `plans/<YYYYMMDD>-<slug>/decisions.md`, written by `/devkit:grill`.
- Verify: `grep -n 'decisions.md' plugins/devkit/skills/{plan,brainstorm,grill}/SKILL.md plugins/devkit/references/conventions.md` finds all four files.

### Phase 3: Docs
- [x] `README.md`:
  - lines 3 and 191: 15 → 16 commands
  - commands table: a `/devkit:grill <idea>` row
  - line 26: add `grill` to the user-only list
  - the flows at lines 42 and 81: `brainstorm → grill → plan`
- [x] `UPSTREAM.md:110`: change to ✅ `/devkit:grill`.
- [x] `CHANGELOG.md` `[Unreleased]` → Added: one line for `/devkit:grill`, and one for `plan` accepting `decisions.md`.
- Verify:
  - `grep -c 'devkit:grill' README.md` is 3 or more.
  - `grep -n 'grill' UPSTREAM.md CHANGELOG.md` shows ✅ and the Added line.
  - `claude plugin validate plugins/devkit --strict && claude plugin validate .` passes.

### Phase 4: Real run (manual, because `AskUserQuestion` needs an interactive session)
- [ ] The user runs `claude --plugin-dir plugins/devkit` in a scratch repo and then `/devkit:grill add a dark-mode toggle to the settings page`.
- Verify:
  - The first message states facts it looked up instead of asking them.
  - Each round has at most 4 questions, each with a "(Recommended)" option.
  - After 3 rounds it offers to stop.
  - `plans/<date>-dark-mode-toggle/decisions.md` exists with all five sections.
  - Running `/devkit:plan` on that file asks no question that the file already answers.

## Risks
| Risk | Signal | Mitigation |
| --- | --- | --- |
| Too many rounds tire the user (Medium) | The user picks "stop" in the first check-in, or abandons the run | Check in every 3 rounds; ask the most consequential questions first; skip questions whose recommended answer is obvious and record them as defaults |
| It asks things it could have looked up (Medium) | Questions about how the code works today | The fact-first step comes before round 1; the manual check in Phase 4 tests for it |
| `plan` re-asks settled decisions (Low) | Duplicate questions after grilling | The Phase 2 edit; checked in Phase 4 |
| SKILL.md grows past "short" (Low) | More than about 60 lines | Keep the template compact and move nothing to references unless needed |

## Out of scope
- Issue or PR creation from the decisions (that is P-20).
- Grilling inside `/devkit:task` for BA tasks; `requirements-analyst` already covers SPEC gaps.
- Automated evals for the skill (`claude plugin eval`); the kit has none yet for other skills either.
