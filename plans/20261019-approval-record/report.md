# Report — Record who approved a plan, and only an explicit yes counts

Plan: `plans/20261019-approval-record/plan.md` (P-33) · Branch: `feat/approval-record`

## Phases completed
1. Conventions: `Approved: YYYY-MM-DD by <name>` line in the plan format, marked as added on approval; new "Approval" section (explicit yes only, `--auto`, how to get the name and date).
2. `plan` writes the line on approval; `cook` uses a plan only with a real `Approved:` line and never writes a second one; `ship`, `deploy`, and `task` point their confirmations to "Approval"; ship and task record who approved an oversized change; deploy reports who confirmed each environment.
3. New core eval `cook-asks-unrecorded-approval`; `cook-retries-tier-up` fixture gains an `Approved:` line; evals README updated.
4. `CHANGELOG.md` `[Unreleased]`, `UPSTREAM.md` P-33 row ✅, `README.md`.

The phases were wording edits in skill and convention files, so they were written directly rather than through `fullstack-developer`, and tests-first was skipped; the eval case is the behavior test.

## Files changed
`plugins/devkit/references/conventions.md`, `plugins/devkit/skills/{plan,cook,ship,deploy,task}/SKILL.md`, `plugins/devkit/evals/cook-asks-unrecorded-approval/` (new), `plugins/devkit/evals/cook-retries-tier-up/fixture.sh`, `plugins/devkit/evals/README.md`, `CHANGELOG.md`, `UPSTREAM.md`, `README.md`.

## Evidence
- `grep -n '^Approved: YYYY-MM-DD by <name>' …/conventions.md && grep -n '^## Approval' …` → lines 30 and 62.
- `grep -c 'conventions.*Approval\|"Approval"' plugins/devkit/skills/{plan,cook,ship,deploy}/SKILL.md` → 1 each.
- `claude plugin validate plugins/devkit --strict && claude plugin validate .` → ✔ both.
- Core evals after both reviews: 4/4 score 1.00 (`cook-asks-unrecorded-approval`, `cook-refuses-draft`, `plan-sync-refuses-draft`, `review-delegates`), 80 s, $0.54.
- The new case against the old skill (worktree of `main`): score 0.00. Cook implemented the plan (Write 3×, Edit 1×, `hello.txt` created), so the case tells the old and new behavior apart.
- `scripts/test-hooks.sh` → 269 cases, 0 failed.
- `needs-bash` evals were not run (no hook or script changed; only the `cook-retries-tier-up` fixture gained one line).

## Review findings
Fixed: W1 (cook now asks for any plan without a real `Approved:` line, including `in-progress`), W2 (format block marks the line as added on approval; cook requires a real date and name), W3 (`task` points to "Approval" and records who approved an oversize), S1 (cook never writes a second line or replaces one), S2 (ship covers every gate confirmation), S3 (plan text matches the shipped "ask again" rule), S4 (this status). Ship-gate review fixed: W (cook defines a valid line: `YYYY-MM-DD` and a name, `unknown` counts, so a user without `gh` auth or a git name is not asked forever), S1 (no annotation inside the format code block), S2 (plan never writes a second line), S3 (cook stops on a `done` plan), S4 (ship and deploy say "ask again, never proceed"), S5 (evals README cost). Remaining: S6, the `cook-retries-tier-up` fixture change is unverified until the `needs-bash` evals run.

## Out of scope found
- Hedge handling ("probably") cannot be checked by a single-prompt eval; it rests on the skill text.
- `task`'s SPEC flow records no `Approved:` line (SPECs have no `Status:` line).
