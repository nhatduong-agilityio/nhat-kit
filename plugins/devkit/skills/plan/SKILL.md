---
name: plan
description: Create a phased implementation plan for a feature or change (scout the codebase, research when needed, red-team the plan) and save it under plans/. Use before coding changes that touch many files or whose approach is unclear.
argument-hint: "<request | SPEC.md> [--fast | --hard] | red-team <plan.md>"
---

# Plan

Input: `$ARGUMENTS`

Conventions (plan format, folders, hand-off contract): `${CLAUDE_PLUGIN_ROOT}/references/conventions.md` — pass this path to every agent you delegate to.

## Pick a mode

- `red-team <plan.md>` → run only step 5 on an existing plan.
- `--fast`: small, clear change → skip step 2, light scouting.
- `--hard`: new architecture, many modules, unfamiliar technology → parallel research + mandatory red-team.
- No flag: choose by complexity; state the chosen mode in one line.

## 1. Understand the request and scout

- If the input is a SPEC, its ACs are the definition of done. If the request is vague, ask at most 3 questions with `AskUserQuestion` (only questions that change the plan).
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
- **Wait for the user's approval.** On approval: set `Status: approved` and write the plan path to `.claude/current-task`.
- Next step: `/devkit:cook plans/<...>/plan.md`.
