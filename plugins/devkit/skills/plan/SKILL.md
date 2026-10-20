---
name: plan
description: Create a phased implementation plan for a feature or change (scout the codebase, research when needed, red-team the plan) and save it under plans/. Use before coding changes that touch many files or whose approach is unclear.
argument-hint: "<request | SPEC.md> [--fast | --hard] | red-team <plan.md> | sync <plan.md>"
---

# Plan

Input: `$ARGUMENTS`

Conventions (plan format, folders, hand-off contract): `${CLAUDE_PLUGIN_ROOT}/references/conventions.md` — pass this path to every agent you delegate to.

## Pick a mode

- `red-team <plan.md>` → run only step 5 on an existing plan.
- `sync <plan.md>` → run only step 7 (below) on an existing plan.
- `--fast`: small, clear change → skip step 2, light scouting.
- `--hard`: new architecture, many modules, unfamiliar technology → parallel research + mandatory red-team.
- No flag: choose by complexity; state the chosen mode in one line.

## 1. Understand the request and scout

- If the input is a SPEC, its ACs are the definition of done. If it is a `decisions.md` from `/devkit:grill`, its decisions are settled: ask only about something new that scouting reveals. If the request is vague, ask at most 3 questions with `AskUserQuestion` (only questions that change the plan).
- Create the folder `plans/<YYYYMMDD>-<slug>/`.
- Run 1–3 `Explore` subagents in parallel, each from one angle (entry points and data flow; similar existing patterns; related tests and config). Ask for a `path:line` map, not file dumps.

## 2. Research (when knowledge outside the repo is needed)

Split into independent questions (at most 3; at most 5 with `--hard`). Give each to its own `devkit:researcher` subagent in parallel, writing to `plans/<...>/research/<question>.md`.

## 3. Write the plan

Delegate to the `devkit:planner` subagent: the request, the scouting results, the research report paths, the path `plans/<...>/plan.md`, and the conventions path.

## 4. Check the plan before presenting it

Read the plan and check: every phase has a verify command; no phase is vague; the plan doesn't exceed the request; the first phase is the riskiest or foundational part. Fix it directly if needed.

## 5. Red-team (mandatory with `--hard`, optional otherwise)

Run 2 `general-purpose` subagents in parallel, each reading the plan from an adversarial angle and reporting only real problems:
- **Technical**: unverified assumptions, missing steps, wrong order, data/performance/security risks, verify steps that don't prove what they need to prove.
- **Scope**: unnecessary work (YAGNI), gaps against the request/ACs, a simpler approach that was overlooked.

Apply the valid findings to the plan; record rejected findings and why at the end of the plan under "Red-team notes".

## 6. Present and confirm

- Present a summary: goal, approach, phases (one line each), key risks, decisions needed. Suggest `Ctrl+G` or opening the file to edit it.
- If the plan has any High or Critical risk, suggest enabling `/advisor fable` for the cook phase so a second model gives guidance at key moments.
- **Wait for the user's approval**, an explicit yes per the conventions' "Approval" section. On approval: set `Status: approved`, add the line `Approved: YYYY-MM-DD by <name>` under it if the plan has none (never replace an existing one), and write the plan path to `.claude/current-task`.
- Next step: `/devkit:cook plans/<...>/plan.md`.

## 7. Sync (plan ↔ tracker)

Per the conventions' "Plan ↔ tracker sync" section.

- Refuse and say why if `Status: draft` — sync works on `approved`, `in-progress`, or `done` only.
- Check `gh auth status` and that the repo has a GitHub remote first. If either fails, say so and stop — never silently skip push or pull.
- **Pull first.** For each phase heading with a valid `(#N)` suffix — exactly one trailing `(#<digits>)` token; warn and skip a heading with more than one, or a malformed one, rather than guessing:
  - Run `gh issue view N --json state`.
  - `CLOSED` → tick every remaining unchecked box under that phase.
  - `OPEN` → leave it untouched; never un-tick a box.
  - A failed lookup (404, wrong repo, revoked access) skips that phase without aborting the rest of the run, and is reported as a broken link.
- **Push second.** For each phase heading with no suffix:
  - First run `gh issue list --search "<exact deterministic title>"` for an existing issue titled `<plan title>: Phase N — <phase name>` (crash-safety: a push that created the issue but died before writing `(#N)` back must not create a duplicate on retry).
  - A match: re-link it by appending `(#<number>)` to the heading.
  - No match: create one — write the body (checklist items + Verify line + a link back to the plan file path) to a temp file and pass it with `--body-file`, never inline `--body`, since phase content routinely has backticked paths — then append `(#<issue-number>)` to the heading.
  - If every checkbox under the phase was already `- [x]` before creating or re-linking its issue, close the issue right after.
- **Report**: phases pushed (new issue numbers), phases re-linked to an existing issue instead of creating a new one, phases pulled (newly ticked boxes), phases already up to date, and phases with a broken or malformed link needing manual attention.
