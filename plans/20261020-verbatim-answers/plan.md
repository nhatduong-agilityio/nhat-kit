# Keep the stakeholder's own words beside the English
Status: done · Source: P-34 in `upstream/proposals/20261018.md` (v2.6.0, "Approvals and shared queue") · Mode: --fast
Approved: 2026-10-20 by nhatduong-agilityio

## Goal
- When a stakeholder (the user in `/devkit:grill`, the BA in `/devkit:task`, a person quoted in requirements docs) answers a question in their own words, the artifact keeps that answer verbatim in its original language with an English translation beside it, in one fixed shape: `"<original>" (EN: <translation>)`.
- Artifacts stay English. A teammate can check the translation against the original words.

## Context found
- `plugins/devkit/references/conventions.md:5-7`: "## Language" says every artifact is English and chat follows the user's preference. It has no exception for quoted stakeholder words. The shared rule goes here, and the three places point to it.
- `plugins/devkit/skills/grill/SKILL.md:17`: step 4 asks through `AskUserQuestion` with options Claude wrote in English. The user can pick an option, type "Other" free text, or add notes. `:19-32`: step 6 writes `decisions.md` with `| # | Question | Answer | Why | By (user / default) |`. Nothing says how to record free text.
- `plugins/devkit/skills/task/SKILL.md:23`: plain-text intake "use it verbatim" (the raw task, not the answers). `:36`: blocking questions are drafted to the BA, saved under "Open questions" in the SPEC, and the skill waits for the user. The BA's reply comes back later, often in Vietnamese. There is no step that says how to record it.
- `plugins/devkit/templates/docs/tasks/_TEMPLATE/SPEC.md:21-23`: Open questions table `| Question | Blocking? | Proposed answer / assumption in use | BA's answer |`. Task uses the project's copy first (`task/SKILL.md:13`), so already-bootstrapped projects keep their old header. The skill text must carry the rule, not only the template.
- `plugins/devkit/agents/requirements-analyst.md:8`: "Write everything in English … keep original terms in quotes where precision matters." It covers terms, not answers. Both modes (project docs, SPEC gap check) can meet stakeholder answers: meeting notes and Q&A in source docs, and BA answers already in a SPEC.
- `plugins/devkit/templates/CLAUDE.md` "# Language": "All artifacts in English". Leave it as is. The conventions rule refines this line and does not contradict it.
- `UPSTREAM.md:140`: the row "Stakeholder answers verbatim + English translation" is ⏳ P-34.
- `CHANGELOG.md:5-9`: `[Unreleased]` → `### Changed` already holds P-33. P-34 is added beside it.
- `plugins/devkit/evals/README.md:5-12`: every case is one slash-command prompt with no second user turn.

## Approach
- **Conventions, one short paragraph under "Language"** (≤ 6 lines):
  - A stakeholder's own words go into artifacts verbatim, in their original language, with an English translation right after: `"<original>" (EN: <translation>)`. Stakeholder words are free-text answers, BA replies, and quoted meeting notes. The same shape is used in tables and lists.
  - An answer already in English is quoted once, with no translation.
  - Never paraphrase, shorten, or fix typos inside the quote. Put clarifications in the translation or in a separate note.
  - An option written by Claude and picked by the user is not the stakeholder's words. Record the option's text, unquoted.
  - Leave contact details (names of private people, phone numbers, emails) out of the quote; write `[redacted]` in their place.
- **grill step 6**: one sentence. When the user typed the answer ("Other" or notes), the Answer cell holds it in the conventions shape. A picked option is recorded as is.
- **task step 3**: one sentence after the blocking bullet. When the BA's reply comes back, fill the SPEC's "BA's answer" column in the conventions shape, then update the affected ACs in English. Template header: `BA's answer (verbatim + EN)`.
- **requirements-analyst line 8**: keep "write everything in English". Add that stakeholder answers and quoted decisions found in the sources, or in a SPEC's "BA's answer" column, follow the conventions shape. The agent does not get the conventions path from its prompt every time, so state the shape inline in one clause too.

- **Review fixes** (see `report.md`): `[redacted]` covers the quote and its translation; a picked option plus typed notes → option text, then the notes quoted; table cells escape `|` and line breaks; mixed-language answers are translated; escaping and `[redacted]` are the only changes allowed inside a quote; the analyst's inline clause is complete; a later BA reply to a non-blocking question is recorded the same way.

Rejected:
- Separate "Original" and "English" columns in each table: this widens every table and needs a format change in three places, and a pair of columns can drift apart. One cell with both is enough.
- Quoting every source document verbatim in `PROJECT_BRIEF.md`: this turns the brief into a copy of the docs. Only answers and decisions are quoted. Terms keep the existing "original terms in quotes" rule.
- An eval case: grill and task get the stakeholder's words only from a second user turn, which `claude plugin eval` does not have. A requirements-analyst case would need a slash command that only reaches the agent through `/devkit:task` gap check, and that flow needs a claim and a full SPEC setup. That is a lot of fixture for a wording rule, so the rule is checked with grep. The risk is listed below.
- Editing `templates/CLAUDE.md` "# Language": the shared conventions already apply in every project through the plugin. A template change does not reach bootstrapped projects anyway.

## Phases

### Phase 1 — Conventions: the stakeholder-words rule
- [x] Add the paragraph above under "## Language" — file: `plugins/devkit/references/conventions.md`
- Verify: `grep -n '(EN: <translation>)' plugins/devkit/references/conventions.md` → one match inside the Language section (between lines 5 and the `## Directories` heading); `grep -n '\[redacted\]' plugins/devkit/references/conventions.md` → one match in the same section; the section grows by ≤ 6 lines (`git diff --numstat` on the file shows ≤ 7 added).

### Phase 2 — grill, task, SPEC template, requirements-analyst point to the rule
- [x] grill step 6: typed answers go in the Answer cell in the conventions shape; picked options as is — file: `plugins/devkit/skills/grill/SKILL.md`
- [x] task step 3: record the BA's reply in "BA's answer" in the conventions shape, then update the ACs — file: `plugins/devkit/skills/task/SKILL.md`
- [x] Rename the column to `BA's answer (verbatim + EN)` — file: `plugins/devkit/templates/docs/tasks/_TEMPLATE/SPEC.md`
- [x] Extend line 8: stakeholder answers and decisions are quoted verbatim with `(EN: …)` per the conventions "Language"; terms keep the existing rule — file: `plugins/devkit/agents/requirements-analyst.md`
- Verify: `grep -c 'EN:' plugins/devkit/skills/grill/SKILL.md plugins/devkit/skills/task/SKILL.md plugins/devkit/agents/requirements-analyst.md` → each ≥ 1; `grep -c 'verbatim + EN' plugins/devkit/templates/docs/tasks/_TEMPLATE/SPEC.md` → 1; `claude plugin validate plugins/devkit --strict && claude plugin validate .` → passes; the `description` lines are unchanged (`git diff` shows no `description:` line).

### Phase 3 — Docs
- [x] `[Unreleased]` → `### Changed` entry for P-34 (the shape, the three places, the template column; already-bootstrapped projects keep their old column header, and the skill text covers them) — file: `CHANGELOG.md`
- [x] Mark the row ✅ and name where it lives (conventions "Language"; grill, task, SPEC template, requirements-analyst; no eval, needs a second user turn) — file: `UPSTREAM.md:140`
- [x] Mark P-34 done in the v2.6.0 order line, the same way P-33 is marked — file: `upstream/proposals/20261018.md:85`
- Verify: `grep -n 'P-34' CHANGELOG.md UPSTREAM.md upstream/proposals/20261018.md` → matches under `[Unreleased]`, in a ✅ row, and as done in the order line; `scripts/test-hooks.sh` passes (no hook changed, sanity check only).

## Out of scope
- README: it does not describe the Language rule or the decisions/SPEC table columns (checked: `README.md:13,157`), so it does not change.
- Migrating existing `decisions.md` files or SPECs in projects.
- Translating the chat. The chat language stays the user's preference.
- Other skills that may quote people (`/devkit:retro`, `/devkit:issue`, and `/devkit:brainstorm` and `/devkit:bootstrap`, which also collect typed `AskUserQuestion` answers). They can point to the rule later if needed.

## Risks
| Risk | Signal | Mitigation |
| --- | --- | --- |
| Low: the model paraphrases or "cleans up" the original instead of quoting it | A `decisions.md` or SPEC answer reads like a summary, or has no `(EN: …)` | The rule says "never paraphrase or fix typos"; the shape is easy to grep; no eval covers it (second user turn), as stated in UPSTREAM |
| Low: bootstrapped projects keep the old `BA's answer` header | The project's SPEC template has no `(verbatim + EN)` | The task skill text carries the rule regardless of the header; noted in CHANGELOG |
| Low: real personal data quoted verbatim lands in a committed artifact | A quote contains names, phone numbers, or emails | The conventions' scrubbing rule covers only the PR report, not `decisions.md` or SPECs. The rule leaves contact details out of quotes as `[redacted]` (user decision, 2026-10-20) |
