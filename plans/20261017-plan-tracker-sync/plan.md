# Plan ↔ tracker sync

Status: done · Source: P-25 in `upstream/proposals/20261016.md`

## Goal

`/devkit:plan sync <plan.md>` keeps a plan's phases and their GitHub issues in step: every phase not yet synced gets one GitHub issue (a phase already fully checked off gets an issue created and immediately closed), and every synced phase whose issue has closed gets its remaining checkboxes ticked — without ever un-ticking a phase a human already finished. The plan keeps owning scope and order; the tracker only reports status back, one way.

## Context found

- `plugins/devkit/references/conventions.md:38-53` — the `plan.md format` section: the `### Phase N — <name>` heading pattern and the "every phase must be self-verifiable" rule. The `(#N)` suffix is a one-line addition to this section, right after the fenced template (line 51) and the self-verifiable sentence (line 53); the addition must include a concrete example like `(#42)` written into the file itself, not just the placeholder notation `(#N)` used here to describe it generically, so a later verify step can grep for literal text that is actually there.
- `plugins/devkit/references/conventions.md:92-104` — the existing "GitHub issue queue" section, including the rule at line 117 ("Never close a queue issue by hand... it closes when the PR with `Closes #N` merges"). The new "Plan ↔ tracker sync" subsection goes directly after this one (before "Agent hand-off contract" at line 120). It needs no label of its own: push never checks one before creating an issue, pull locates a phase purely by its `(#N)` heading suffix, and `/devkit:task next` already excludes anything without the `ai` label regardless — a human identifies a sync issue by its deterministic title (`<plan title>: Phase N — <phase name>`) instead.
- `plugins/devkit/skills/issue/SKILL.md:21` — the `gh issue list --state all --search "<words>" --json number,title,state,url` duplicate-check pattern. Push's "search by exact title before creating" step (needed so a push interrupted between creating an issue and writing its `(#N)` back to the plan doesn't double-create on retry) reuses this same `gh issue list --search` call, matched against the phase's own deterministic title instead of free-text keywords.
- `plugins/devkit/skills/task/SKILL.md:19` — the `gh issue list --json ...` pattern for reading issue state in bulk; sync's pull step uses the single-issue form, `gh issue view N --json state`. That single-issue lookup can itself fail (404, wrong repo, revoked access) — nothing upstream handles that case today, so sync's pull step must handle it itself (see Phase 2).
- `plugins/devkit/skills/plan/SKILL.md:4` — current `argument-hint`: `"<request | SPEC.md> [--fast | --hard] | red-team <plan.md>"`. Needs ` | sync <plan.md>` appended.
- `plugins/devkit/skills/plan/SKILL.md:13-18` — "Pick a mode": `red-team <plan.md>` is already a mode that runs only one step of this file; `sync <plan.md>` is added the same way, pointing at a new numbered section.
- `plugins/devkit/skills/plan/SKILL.md:38-44` — step 5 ("Red-team"): the structural pattern (short imperative bullets, a clear boundary of what the mode does and doesn't touch) the new sync section should match.
- `README.md:14-15` — the commands table already gives `/devkit:plan red-team <plan.md>` its own row, directly under the base `/devkit:plan <request>` row. `sync <plan.md>` is a sibling mode of the same skill, so it gets a row the same way; P-20's own bookkeeping phase (`plans/20261016-github-issue-queue/plan.md`, phase 4) updated README as a matter of course for a new mode/skill.
- `UPSTREAM.md:113` — the P-20 row, already ✅, with its devkit column filled in (`\`/devkit:issue\` + \`/devkit:task #N|next\``). P-25's row (`UPSTREAM.md:118`) currently reads `| Markdown plan ↔ tracker two-way sync | — | ⏳ | P-25 |`; matching the established pattern means filling the devkit column too, not just flipping the status glyph.
- `CHANGELOG.md:3` — semver note: "MINOR when skills/agents/features are added." P-25 is `minor` per the proposal table, so the entry needs no extra caveat.
- `CHANGELOG.md:16-23` — `[Unreleased]/### Changed` style to match: one bullet per proposal, skill name in backticks, ending `(P-NN)`.
- `plans/20261016-github-issue-queue/plan.md` (P-20, done) — precedent for this exact shape of work: conventions phase first, skill-behavior phase second, docs/bookkeeping phase last; and precedent for a live-GitHub verify step run against a real or scratch repo with explicit cleanup (`gh issue delete`/label checks), which this plan's phase 2 verify follows.

## Approach

Implement the GitHub Issues backend only (no Projects board, no side file for linkage), with pull as a one-way ratchet:

- **Backend**: GitHub Issues, reusing P-20's `gh issue` patterns. The proposal offers a Projects board as an alternative ("or"), not a requirement, and Issues needs no new infrastructure.
- **Linkage**: the issue number lives inline in the phase's own heading as a trailing, exactly-one `(#N)`-shaped token (e.g. `### Phase 1 — <name> (#42)`), written only by sync itself. A heading carrying more than one such token, or a malformed one, is reported rather than acted on. No sibling file, no new entry in the conventions' Directories table.
- **Push**: one issue per unsynced phase, found by first searching for its exact deterministic title (title = `<plan title>: Phase N — <phase name>`) so an interrupted push never double-creates on retry; created only if no match exists, with its body written to a temp file and passed via `--body-file` (never inline `--body`, since phase content routinely has backticked paths). A phase that was already fully checked off before its first sync (or re-link) gets its issue closed in the same push, so the tracker starts truthful. No dedicated label: a phase is identified by its `(#N)` heading suffix and its deterministic title, not a label.
- **Pull**: for a synced phase, a `CLOSED` issue ticks every remaining checkbox under that phase; an `OPEN` issue changes nothing. A lookup that fails (deleted or inaccessible issue) skips that phase and is reported as a broken link, rather than aborting the whole run. Pull never un-ticks a checkbox. The plan's own completion state — set by whoever did the work, e.g. `/devkit:cook` — outranks "did a human remember to close the GitHub issue."
- **Order**: pull before push on every run, so a phase that is both unsynced and already done at the time push creates its issue still goes through the create-then-close special case (nothing to pull yet, since it had no issue number before this run).
- **Guard**: refuses to run on a `Status: draft` plan.

Rejected alternatives:

- **GitHub Projects board backend** — more setup than labels on issues, and the proposal only offers it as an alternative, not a requirement; Issues reuses all of P-20's infrastructure. A follow-up can add board support later.
- **A `tracker.md`-style side file holding the plan↔issue links** — adds a file and a new conventions Directories-table entry for no benefit; the inline `(#N)` suffix already satisfies the proposal's own "pull state back into the plan."
- **Full bidirectional overwrite** (un-ticking a phase when its issue is reopened) — unsafe: it could silently wipe a phase a human (or `/devkit:cook`) already finished, just because nobody closed the issue yet.
- **Auto-closing a phase's issue from `/devkit:cook`/`/devkit:ship`** — a bigger, cross-skill change than asked for; sync stays one manually invoked command.
- **ADO and Trello backends** — excluded by the proposal itself.

## Phases

### Phase 1 — Conventions: phase-heading suffix + "Plan ↔ tracker sync" section

- [x] `plugins/devkit/references/conventions.md`, `plan.md format` section: append sentences to the paragraph after the fenced template (near line 53, "Every phase must be self-verifiable…") defining the phase-heading suffix precisely: it is exactly one trailing `(#<digits>)`-shaped token — e.g. the literal text `(#42)` — as the LAST thing on the heading line, written only by `/devkit:plan sync` itself when it links a phase to an issue (e.g. `### Phase 1 — <name> (#42)`); a heading without it is simply unsynced. State that a heading carrying more than one such trailing token, or a malformed one, is not something sync acts on silently — it is reported instead (see Phase 2). Use the concrete example `(#42)` in the prose itself, not a placeholder.
- [x] `plugins/devkit/references/conventions.md`: add a new `## Plan ↔ tracker sync` subsection directly after `## GitHub issue queue` (before `## Agent hand-off contract`), covering:
  - linkage: no side file and no dedicated label; the `(#N)`-shaped suffix on the phase heading (defined above) is the only state, and a phase's deterministic issue title (`<plan title>: Phase N — <phase name>`) is what a human uses to find it on GitHub.
  - push: for a phase with no heading suffix, first search `gh issue list --search "<exact title>"` for an existing issue with that exact deterministic title (so a push interrupted after creating the issue but before writing `(#N)` back never double-creates on retry); re-link a match by appending its number, otherwise create one with body = the phase's checklist items + its Verify line + a link back to the plan file path, written to a temp file and passed as `--body-file` (never inline `--body`, to avoid a shell-injection risk from backticked paths in the phase content); a phase whose checkboxes are already all `- [x]` at push time gets its issue closed immediately after creation or re-linking.
  - pull: `gh issue view N --json state`; `CLOSED` → tick every remaining unchecked box under that phase; `OPEN` → change nothing; a failed lookup (404, wrong repo, revoked access) skips that phase without aborting the run and is reported as a broken link needing manual attention, not retried silently.
  - the ratchet rule stated as its own sentence: pull only ever moves a phase toward done, and never un-ticks a checkbox because its linked issue is open — the plan's own completion state is the stronger signal.
  - one sentence contrasting this with the queue rule just above: unlike a queue issue, a sync-created issue is meant to be closed by hand on purpose (there is no `Closes #N`-via-PR workflow for it) — that manual close is exactly what pull is watching for.
  - the guard: refuse to run on a `Status: draft` plan; works for `approved`, `in-progress`, `done`.
- Verify: `claude plugin validate plugins/devkit --strict && claude plugin validate .` exits 0; `grep -n '(#42)' plugins/devkit/references/conventions.md` shows the concrete phase-heading example; `grep -n 'Plan ↔ tracker sync' plugins/devkit/references/conventions.md` shows the new subsection heading; `grep -n 'plan-sync' plugins/devkit/references/conventions.md` prints nothing (confirms no label was added).

### Phase 2 — `/devkit:plan sync <plan.md>`

- [x] `plugins/devkit/skills/plan/SKILL.md`: change `argument-hint` (line 4) to `"<request | SPEC.md> [--fast | --hard] | red-team <plan.md> | sync <plan.md>"`.
- [x] Add a `sync <plan.md> → run only step 7 (below) on an existing plan.` bullet under "## Pick a mode", next to the existing `red-team` bullet.
- [x] Add a new `## 7. Sync (plan ↔ tracker)` section (after step 6), in the file's existing terse imperative style, spelling out:
  - refuse and say why if `Status: draft`;
  - check `gh auth status` and that the repo has a GitHub remote first; if either fails, say so and stop — never silently skip push or pull;
  - pull first: for each phase heading with a valid `(#N)` suffix — exactly one trailing `(#<digits>)` token; warn and skip a heading with more than one, or a malformed one, rather than guessing — run `gh issue view N --json state`; `CLOSED` ticks every remaining unchecked box under that phase; `OPEN` leaves it untouched (never un-tick); a failed lookup (404, wrong repo, revoked access) skips that phase without aborting the rest of the run and is reported as a broken link;
  - push second: for each phase heading with no suffix, first run `gh issue list --search "<exact deterministic title>"` for an existing issue titled `<plan title>: Phase N — <phase name>` (crash-safety: a push that created the issue but died before writing `(#N)` back must not create a duplicate on retry); re-link a found match by appending `(#<number>)` to the heading, otherwise create one — body written to a temp file and passed with `--body-file`, never inline `--body`, since phase content routinely has backticked paths — and append `(#<issue-number>)` to the heading; if every checkbox under the phase was already `- [x]` before creating or re-linking its issue, close the issue right after;
  - report: phases pushed (new issue numbers), phases re-linked to an existing issue instead of creating a new one, phases pulled (newly ticked boxes), phases already up to date, and phases with a broken or malformed link needing manual attention.
- Verify:
  - `claude plugin validate plugins/devkit --strict && claude plugin validate .` exits 0.
  - `grep -nE 'sync <plan.md>|never un-tick|body-file|broken link' plugins/devkit/skills/plan/SKILL.md` shows the new content.
  - `grep -n 'plan-sync' plugins/devkit/skills/plan/SKILL.md` prints nothing (no label reference leaked in).
  - [x] **Live round-trip** — ran against `nhatduong-agilityio/devkit-forms-scratch` (user-confirmed). All 6 steps passed:
    1. Wrote a one-phase throwaway test plan (`Status: approved`) to the scratchpad.
    2. Push: searched by exact title (no match), created issue #9 with `--body-file`, appended `(#9)` to the phase heading.
    3. Re-ran the exact-title search with the suffix hypothetically unwritten: found issue #9 again instead of creating a duplicate — confirms the crash-safety path.
    4. `gh issue close 9`, re-ran pull: issue read as `CLOSED`, phase's checkbox ticked.
    5. Pointed the suffix at `(#99999)` (nonexistent): `gh issue view 99999` failed cleanly (exit 1, GraphQL "could not resolve") — exactly the signal pull's broken-link handling catches, without aborting.
    6. Cleanup: `gh issue delete 9 --yes`, deleted the throwaway test plan and body files. Confirmed via a follow-up search: zero "Sync test plan" issues remain in the scratch repo.

### Phase 3 — Bookkeeping

- [x] `CHANGELOG.md`, `[Unreleased]/### Changed`: add a bullet for P-25, e.g. "`/devkit:plan` gains `sync <plan.md>`: pushes unsynced phases as GitHub issues (matched by exact title first, so a retry after a crash never double-creates) and pulls closed issues' state back as ticked checkboxes, never un-ticking a phase whose issue is still open; a broken or malformed link is reported, not silently retried; refuses on a draft plan; conventions gain a "Plan ↔ tracker sync" section (P-25)." — no extra semver caveat needed, since `minor` is already the default for an added feature per the note at the top of the file.
- [x] `UPSTREAM.md:118`: change `| Markdown plan ↔ tracker two-way sync | — | ⏳ | P-25 |` to `| Markdown plan ↔ tracker two-way sync | \`/devkit:plan sync\` | ✅ | P-25 |`, matching how every other ✅ row in that table fills in the devkit column.
- [x] `README.md`: add one row directly under the existing `/devkit:plan red-team <plan.md>` row (`README.md:15`), e.g. `` | `/devkit:plan sync <plan.md>` | Push unsynced phases as issues, pull closed ones back | — | ``, matching that row's style (no agents in the third column).
- Verify: `grep -n 'P-25' UPSTREAM.md` shows the row with `✅`; `grep -n 'Plan ↔ tracker sync' CHANGELOG.md` shows the new bullet; `grep -n 'devkit:plan sync' README.md` shows the new row; `claude plugin validate plugins/devkit --strict && claude plugin validate .` and `scripts/test-hooks.sh` both pass.

## Risks

| Risk | Signal | Mitigation |
| --- | --- | --- |
| Ratchet-only pull (never un-ticking an open-but-reopened issue) is the one design choice most worth a red-team pass: it could leave a plan showing a phase as done while its issue is open again, with no way for sync itself to flag the mismatch | A phase's checkboxes are all `- [x]` but its linked issue shows `OPEN` after a reopen | By design: the plan's own completion signal, set by whoever did the work, outranks "did a human close the issue." The report step (phase 2) still surfaces each phase's issue state on every run, so the mismatch is visible even though sync won't act on it; flagged here explicitly for red-team review rather than silently accepted |
| The phase 2 live verify step creates and deletes a real issue on an externally visible GitHub repo | None by default — this is a hard rule, not a detector | Get the user's explicit confirmation and their choice of repo before running it; default to the P-20 scratch repo when available; delete the test issue and the throwaway plan file immediately after |
| `gh` isn't authenticated, or the repo has no GitHub remote | `gh auth status` or `gh issue view/create` exits non-zero | Sync checks both before doing anything and fails with a clear message; it never silently skips the push or pull half of a run |
| Two people run `sync` on the same plan around the same time, each pushing the same still-unsynced phase | Two GitHub issues referencing the same phase | Out of scope for this patch (no lock); call out in Out of scope below |

## Out of scope

- GitHub Projects board backend — the proposal offers it only as an alternative, not a requirement; Issues reuses P-20's existing infrastructure and keeps this patch to one tracker backend. A follow-up can add Projects board support later.
- ADO and Trello — excluded by the proposal itself.
- Auto-closing a phase's issue from `/devkit:cook` or `/devkit:ship` when the phase completes — sync stays a separate, manually invoked command; teaching other skills to close tracker issues is a bigger change than this patch, and not what was asked.
- Recovering a plan's sync state if its `(#N)` suffixes are manually deleted, or a `tracker.md`-style side file is lost — there is no side file; all state lives inline in the phase headings, so this situation doesn't apply by construction.
- Full bidirectional overwrite, including un-ticking a completed phase because its linked issue is still open — the explicit ratchet safety rule above.
- Locking against two people syncing the same plan concurrently — noted as a risk, not solved here.

## Red-team notes

Technical + scope passes returned 8 findings; all 8 were valid and applied directly to the phases above, none rejected:

1. Dropped the `plan-sync` label entirely (write-only, redundant with the `(#N)` suffix and the `ai`-label exclusion already in `/devkit:task next`) — Context found, Approach, Phase 1, and Phase 2 updated; verify steps now also grep that no `plan-sync` reference leaked back in.
2. Added a search-by-exact-title step before creating an issue, so a push interrupted between creating the issue and writing `(#N)` back doesn't double-create on retry — Approach, Phase 1, Phase 2 (including a dedicated live-verify step for the retry case).
3. Defined behavior for a stale/deleted/inaccessible `(#N)` link: skip that phase, report it as a broken link, never abort the whole run — Approach, Phase 1, Phase 2 (including a dedicated live-verify step).
4. Mandated writing the issue body to a temp file and passing `--body-file`, never inline `--body`, to avoid shell-injection risk from backticked paths in phase content — Approach, Phase 1, Phase 2.
5. Defined the heading suffix precisely as exactly one trailing `(#<digits>)` token written only by sync, with a malformed/duplicate token reported instead of acted on — Approach, Phase 1, Phase 2.
6. Pinned Phase 1's conventions.md addition to use the literal example `(#42)`, and changed its verify grep to match that literal text instead of the placeholder `(#N)` — Phase 1.
7. Added a sentence contrasting sync issues (closed by hand on purpose) with the existing "never close a queue issue by hand" rule, so the two sit side by side without contradicting each other — Phase 1.
8. Added a README.md row for `/devkit:plan sync <plan.md>` under the existing `/devkit:plan red-team <plan.md>` row, matching the pattern P-20 itself followed — Context found, Phase 3.
