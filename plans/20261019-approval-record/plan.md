# Record who approved a plan, and only an explicit yes counts
Status: done · Source: P-33 in `upstream/proposals/20261018.md` (v2.6.0, "Approvals and shared queue") · Mode: --fast
Approved: 2026-10-19 by nhatduong-agilityio

## Goal
- An approved plan carries a line `Approved: YYYY-MM-DD by <name>` under its `Status:` line, so a teammate opening the plan sees who agreed and when.
- `/devkit:cook`, `/devkit:ship`, and `/devkit:deploy` treat only an explicit yes as approval. Silence, a hedge ("probably", "I guess"), a question, or an edit request is not a yes; they ask again.

## Context found
- `plugins/devkit/references/conventions.md:26-45`: the plan.md format block, with `Status: draft | approved | in-progress | done · Source: …` on line 2. No approval line yet.
- `plugins/devkit/skills/plan/SKILL.md:51`: "On approval: set `Status: approved` and write the plan path to `.claude/current-task`". Nothing about what counts as approval or who gave it.
- `plugins/devkit/skills/cook/SKILL.md:16-18`: `Status: approved` → use it; `draft` → ask (unless `--auto`); a request → plan, then wait for approval (unless `--auto`).
- `plugins/devkit/skills/ship/SKILL.md:15` (gate 1): oversized → "continue only if the user says so". `:22` (gate 8): "Ask for confirmation before pushing".
- `plugins/devkit/skills/deploy/SKILL.md`: Gate 1 asks to confirm a non-default branch; Gate 3 and Gate 5 ask before staging and production.
- `plugins/devkit/evals/cook-refuses-draft/`: a single-prompt eval pattern (`case.yaml`, `fixture.sh`, `prompt.md`, `graders/*.md`) tagged `core`. `plugins/devkit/evals/README.md:7-13` lists the cases.
- `UPSTREAM.md:139`: the row "Explicit-yes gates with who/when recorded" is ⏳ P-33.
- `plugins/devkit/evals/cook-retries-tier-up/fixture.sh:18`: a fixture plan with `Status: approved` and no `Approved:` line. It must gain one, or the new cook rule makes it ask instead of running.

## Approach
- **Conventions, one new short section "Approval"** (after "plan.md format"):
  - Approval is an explicit yes from the user in reply to the approval question: "yes", "approve", "go", "LGTM", or an equivalent. Silence, a hedge, a question, a conditional ("yes if…"), or a change request is not approval. Ask again in plain words; never proceed on an assumed yes.
  - `--auto` on cook counts as the user's explicit approval for that run, since the user typed it.
  - Who: the GitHub login from `gh api user --jq .login`; if that fails, `git config user.name`; if both fail, `unknown`. Never guess a name. When: the local date `YYYY-MM-DD`.
- **plan.md format**: add an optional line 3 `Approved: YYYY-MM-DD by <name>` (with ` (--auto)` when cook's `--auto` approved it). Written once and kept through `in-progress` and `done`. A separate line, not part of the `Status` line, so status edits never touch it and `grep '^Approved:'` finds it.
- **plan SKILL step 6**: on approval (per conventions "Approval"), set `Status: approved` and add the `Approved:` line.
- **cook step 0**:
  - A plan with `Status: approved` or `in-progress` and an `Approved:` line → use it.
  - `approved` without an `Approved:` line (older plans, or a hand-edited status) → present the summary and ask, like a draft.
  - `--auto` → write the line with ` (--auto)`.
  - State the "Approval" rule in one sentence: a hedge or no reply means stop and ask again, never proceed.
- **ship**: one sentence after the gate list intro: the gate 1 oversize go-ahead and the gate 8 push confirmation need an explicit yes per conventions "Approval"; anything else stops. When the user approves an oversized change, add "approved by <name> on <date>" to the Risks-and-impact note it already writes.
- **deploy**: the same sentence for Gates 1, 3, and 5. The reply table records who confirmed staging and production and when. Deploy has no plan file, and the deploy itself is the durable trace.
- **Eval `cook-asks-unrecorded-approval`** (tag `core`): the fixture plan has `Status: approved` and no `Approved:` line. PASS when cook asks for approval and does not implement. This is the one new behavior a single-prompt eval can check. Hedge handling needs a second user turn, which `claude plugin eval` cases do not have; it is checked by reading the skill text.
- **Fix the `cook-retries-tier-up` fixture**: add an `Approved:` line so that case still tests the retry and not the new gate.

Rejected:
- An approval comment on the GitHub issue as the source of truth: plans are not always linked to issues (sync is optional). The plan file is committed, so it is already shared through the PR. A tracker comment can come with the squad stage.
- Recording time to the minute: the proposal asks for a date, and the git history of the plan has the exact time.
- A hook that blocks cook when `Approved:` is missing: a skill reads the plan anyway, and hooks must stay fast and generic.
- Bumping MAJOR for the format change: the line is optional and older plans still parse; cook asks once for them. PATCH, as the proposal states.

## Phases

### Phase 1 — Conventions: the "Approval" rule and the plan line
- [x] Add the optional `Approved: YYYY-MM-DD by <name>` line to the plan.md format block, and a short "Approval" section with the explicit-yes rule, `--auto`, and how to get the name and date — file: `plugins/devkit/references/conventions.md`
- Verify: `grep -n '^Approved: YYYY-MM-DD by <name>' plugins/devkit/references/conventions.md && grep -n '^## Approval' plugins/devkit/references/conventions.md` → both match; the section is ≤ 8 lines.

### Phase 2 — plan, cook, ship, deploy point to the rule
- [x] plan step 6: on an explicit yes, set `Status: approved` and write the `Approved:` line — file: `plugins/devkit/skills/plan/SKILL.md`
- [x] cook step 0: require the `Approved:` line; ask when it is missing; `--auto` writes it with ` (--auto)`; a hedge or no reply → ask again, never proceed — file: `plugins/devkit/skills/cook/SKILL.md`
- [x] ship: the explicit-yes sentence for gate 1 (oversize) and gate 8 (push); an oversize approval records name and date in Risks and impact — file: `plugins/devkit/skills/ship/SKILL.md`
- [x] deploy: the explicit-yes sentence for Gates 1, 3, 5; the reply records who confirmed each environment and when — file: `plugins/devkit/skills/deploy/SKILL.md`
- Verify: `grep -c 'conventions.*Approval\|"Approval"' plugins/devkit/skills/{plan,cook,ship,deploy}/SKILL.md` → each ≥ 1; `claude plugin validate plugins/devkit --strict && claude plugin validate .` → passes.

### Phase 3 — Evals
- [x] New case `cook-asks-unrecorded-approval` (copy the `cook-refuses-draft` layout; the fixture plan says `Status: approved` with no `Approved:` line; the grader passes when cook asks for approval and fails when it implements or treats the existing status as approval) — folder: `plugins/devkit/evals/cook-asks-unrecorded-approval/`
- [x] Add `Approved: 2026-10-19 by eval` to the fixture plan — file: `plugins/devkit/evals/cook-retries-tier-up/fixture.sh`
- [x] Add the case to the table — file: `plugins/devkit/evals/README.md`
- Verify: `claude plugin validate plugins/devkit --strict` passes; then `claude plugin eval plugins/devkit --tag core --trust-plugin --scaffold --ablation none --runs 1 --max-cost-usd 3 --no-publish --allow-tools Write Edit` → all 4 core cases pass (re-run a red case once with `--case <name>` before calling it a regression, per the evals README).

### Phase 4 — Docs
- [x] `[Unreleased]` → `### Changed` entry for P-33 — file: `CHANGELOG.md`
- [x] Mark the row ✅ and name where it lives — file: `UPSTREAM.md:139`
- [x] README: mention the `Approved:` line where the plan/cook flow is described, if it describes approval — file: `README.md`
- Verify: `grep -n 'P-33' CHANGELOG.md UPSTREAM.md` → both match under `[Unreleased]` and the ✅ row; `scripts/test-hooks.sh` still passes (no hook changed, sanity only).

## Out of scope
- `/devkit:task` gets only a pointer to the "Approval" section and the who/when oversize note (added after review W3); its SPEC flow records no `Approved:` line.

## Risks
- **Medium: plans approved before this change.** Cook will ask once more for them. This is intended (silence is not approval) and costs one reply; the CHANGELOG says so.
- **Low: `gh api user` needs auth.** The fallback to `git config user.name`, then `unknown`, keeps the flow working. `unknown` is visible in the plan, so it is not silent.
- **Low: the eval cannot prove hedge handling.** It needs a second user turn. That rule rests on the skill text; the new eval covers the missing-line gate only.
