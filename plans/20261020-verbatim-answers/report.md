# Report: Keep the stakeholder's own words beside the English (P-34)

Plan: `plans/20261020-verbatim-answers/plan.md` · Branch: `feat/verbatim-answers`

## Phases completed
1. Conventions: stakeholder-words rule under "Language" (`plugins/devkit/references/conventions.md:9`).
2. grill step 6, task step 3, SPEC template column, requirements-analyst point to the rule.
3. Docs: CHANGELOG `[Unreleased]`, UPSTREAM row ✅, proposal order line and "Suggested next commands".

## Files changed
- `plugins/devkit/references/conventions.md`
- `plugins/devkit/skills/grill/SKILL.md`
- `plugins/devkit/skills/task/SKILL.md`
- `plugins/devkit/templates/docs/tasks/_TEMPLATE/SPEC.md`
- `plugins/devkit/agents/requirements-analyst.md`
- `CHANGELOG.md`, `UPSTREAM.md`, `upstream/proposals/20261018.md`

## Evidence
- `grep -n '(EN: <translation>)' plugins/devkit/references/conventions.md` → line 9 (Language section); `grep -c '\[redacted\]'` → 1.
- `grep -c 'EN:'` → grill 1, task 1, requirements-analyst 1; `grep -c 'verbatim + EN'` on the SPEC template → 1.
- `git diff | grep '^[-+]description:'` → empty.
- `claude plugin validate plugins/devkit --strict && claude plugin validate .` → both "✔ Validation passed".
- `scripts/test-hooks.sh` → "269 cases, 0 failed. All hooks passed." (no hook changed; sanity check).
- No tester run: the change is prompt text only, with no executable behavior; no eval, by user decision (needs a second user turn).

## Review findings
Fixed (code-reviewer, 0 Critical):
- W1 requirements-analyst inline rule made conditional and complete (English once, no paraphrase, answers only, not whole docs).
- W2 `[redacted]` now applies to the quote and its translation.
- W3 grill: a picked option plus typed notes → option, then notes in the quoted shape.
- W4 table cells: `|` → `\|`, line breaks → `<br>`, not counted as an edit.
- O5 task: a later BA reply to a non-blocking question is recorded the same way.
- O6 the conventions paragraph starts with "Exception:" so flat "English only" lines elsewhere don't read as overriding it.
- O7 `brainstorm` and `bootstrap` added to the plan's Out of scope.
Fixed (ship re-review, 0 Critical): W1 the analyst clause names private people's names in "contact details"; S1 escaping and `[redacted]` are the only allowed changes inside a quote; S2 grill example uses `<option text>`; S3 mixed-language answers are translated; S4 the plan's Approach lists the review fixes.
Remaining: none.

## Out-of-scope issues found
- `/devkit:brainstorm` and `/devkit:bootstrap` also collect typed `AskUserQuestion` answers into artifacts; they could point to the rule later.
