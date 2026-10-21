# P-46: where stage-2 squad task state lives (research)
Status: done · Source: P-46 in `upstream/proposals/20261018.md:51` (v3.x "Squad", first item)
Approved: 2026-10-21 by nhatduong-agilityio

## Goal
Use live evidence to decide whether GitHub's native issue features can hold stage-2 squad task state on personal and org repos. The features are sub-issues, "blocked by" dependencies, and issue types/fields. Deliverables:
- `research/live-probe.md`, the evidence;
- `research/findings.md`, the decision;
- an updated P-46 row, P-41/P-42 rows, and "Board relink" row in the proposal.

No kit code changes.

## Context found
- `upstream/proposals/20261018.md`. What the squad needs:
  - `:51`: the P-46 question.
  - `:52`: P-39, the agent result contract.
  - `:54`: P-41, per-task "depends on", "expected files", and "serial".
  - `:55`: P-42, which splits into XS/S/M tasks as issues and reads `#epic`.
  - `:70`: Skip "Board relink".
  - `:87`, `:91-97`: releases and next commands.
- `plugins/devkit/references/conventions.md:119-147`: today's state model is labels (`ai`, `in-progress`, `severity:*`) plus claim/release comments. `:145` says `gh issue list` lags and `gh issue view` does not.
- `UPSTREAM.md:147-148`: the P-41 and P-42 rows. `:152`: the P-46 row (⏳).
- `docs/devkit.md:9,13,17`: the PR gate is 300 lines / 25 files, and `plans/**` is excluded.
- Desk research:
  - `research/sub-issues.md`: 100 children per parent, 8 levels, REST `sub_issue_id` is `.id`, and the search qualifiers are unverified.
  - `research/dependencies.md`: 50 per relationship type. Cycles, cross-repo, and the behavior of `is:blocked` are undocumented.
  - `research/types-and-fields.md`: types and fields are org-only, and `gh issue list --json` has no field values.
- `research/schema-probe.txt` (read-only, gh 2.102.0). Already settled, so not re-tested:
  - `gh issue list --json` accepts `parent`, `subIssues`, `subIssuesSummary`, `blockedBy`, `blocking`, `issueType` (`:32`). It does not accept `issueDependenciesSummary`, so read that through `gh api graphql`.
  - The flags `--parent`, `--blocked-by`, `--add-sub-issue`, `--add-blocked-by`, and `--type` exist (`:34-64`).
  - The mutations exist (`:13-29`).
  - Personal repo `issueTypes` is `null` (`:76`).
  - Org Agility-Vietnam has types Task/Bug/Feature (`:46`) and fields Priority, Effort (single select), Start date, and Target date (`:70`). The user is a `member` (`:48`).
  - Token scopes are `gist, read:org, repo` (`:51`). There is no `delete_repo` and no `project`.
- Git: `plans/20261021-squad-task-state/` is untracked on `main`. User memory: no direct commits to main.

## Approach
Run a small live probe, writing only on a throwaway private repo on the personal account, plus read-only checks on the org. (Later cut: on 2026-10-21 the user decided no org connection is needed, so the org part stopped at type and field definitions.) Then judge the evidence against criteria fixed in advance (below).

**Decision criteria, fixed before any evidence:**
- **"Native works"** means all three of these hold through `gh` (or `gh api`) on a personal private repo:
  - (a) an epic → task tree can be written and read back;
  - (b) "blocked by" edges can be written and read back with each blocker's `state`, so "ready = open and no open blockers" is computable;
  - (c) the readback goes through `gh issue view`/`list --json` or one GraphQL query, without a Projects board.
- Per-task scalars may fall back to labels or one machine-readable comment without failing the verdict. The scalars are size, complexity, attempts, expected files, and serial. On org repos, an issue field is an optional upgrade.
- Claim/in-progress stays in labels plus comments (conventions `:141-147`), and agent results stay in comments (P-39).
- **If (a)–(c) hold:** issues are the source of truth, a Projects board is an optional one-way view (write-only, and it needs the `project` scope), and relink is unnecessary.
- **If any fails:** the Projects board is the source of truth, and `/devkit:check` gets an item that detects items missing from the listing.

Rejected:
- Docs-only research. Cycles, search qualifiers, close behavior, and personal-repo support are undocumented or contradictory in `research/*.md`.
- An org write probe. The user ruled it out (decision 2), and a member cannot create fields or types anyway.
- Projects board as the source of truth from the start. It adds a `project` scope, the 30-item default truncation (`types-and-fields.md` §3), and relink work, before we know native issues fail.

## Phases

### Phase 1 — Live write probe on a personal throwaway repo
Riskiest: GitHub writes, plus cleanup that needs a scope the token lacks.

Record every step in `plans/20261021-squad-task-state/research/live-probe.md` as a row: `step | exact command | expected | actual (exit code + key output) | verdict`.

Approvals and safety:
- Each W-step asks once and runs only after a plain yes (conventions `:65-67`).
- One yes never covers more than its own W-step.
- Nothing is written to nhat-kit's own issues or to the org.
- If GitHub accepts a loop, cycle, or self-edge (W3, W5), record it, then remove it straight away (`--remove-parent` / `--remove-blocked-by`). Re-read with `gh issue view` before the next step, so later steps see clean state.
- Readback uses `gh issue view`, which has no lag. Any `gh issue list --search` check retries once after about 10 s before a step is marked "unsupported".

- [x] P0, pre-check (read-only): `gh repo view nhatduong-agilityio/devkit-p46-probe` must fail (no name collision), and `gh --version` must be ≥ 2.94. — file: `research/live-probe.md`
- [x] W1, create the repo: `gh repo create nhatduong-agilityio/devkit-p46-probe --private --description "devkit P-46 throwaway probe; safe to delete"`.
- [x] W2, create issues: `gh issue create -R … --title E --body x` (epic), then `--title T1 --parent <E>` and `--title T2 --parent <E>`, plus T3 (no parent), G (grandchild, `--parent <T1>`), and B (blocker).
- [x] W3, sub-issue links:
  - `gh issue edit <E> --add-sub-issue <T3>`.
  - A loop attempt, `gh issue edit <E> --parent <G>`. Record whether it is rejected and the exact message.
  - Readback: `gh issue view <E> --json subIssues,subIssuesSummary`, `gh issue view <G> --json parent`, and `gh issue list --json number,parent,subIssuesSummary`. Root `parent` should be null, and the tree should have 3 levels.
- [x] W4, REST id check: run `gh api repos/…/issues/<E>/sub_issues -X POST -F sub_issue_id=<B .id>` and then remove it with `-X DELETE …/sub_issue`. Expect 201 with `.id`. Do not try `.number`: a small number read as a database id could point at someone else's issue.
- [x] W5, dependencies:
  - `gh issue edit <T2> --add-blocked-by <T1>` and `gh issue edit <T1> --add-blocked-by <B>`.
  - A cycle attempt, `gh issue edit <B> --add-blocked-by <T2>` (B→T1→T2→B), and a self-edge, `gh issue edit <T3> --add-blocked-by <T3>`. Record whether each is accepted and the exact message.
  - Readback: `gh issue view <T2> --json blockedBy,blocking`, and `gh api graphql` for `issueDependenciesSummary`.
- [x] S1, search qualifiers, read-only after W5. For each of `is:blocked`, `blocked-by:<n>`, `parent-issue:nhatduong-agilityio/devkit-p46-probe#<E>`, `no:parent-issue`, and `has:sub-issues` (also `has:sub-issue`), run `gh issue list -R … --search "<q>" --json number`. Record one issue expected to match and one expected not to. An all-empty or all-issues result counts as "not honored".
- [x] W6, close behavior:
  - Close B while T1 is open. Re-read the T1 and T2 `blockedBy` states (B should be listed with `state: CLOSED`) and the summary counts. Re-run `is:blocked` to see whether T1 drops out.
  - Close E while children are open. Record the result and E's `subIssuesSummary`.
  - Close T1 and check E's `completed` count.
- [x] W7, types and fields on the personal repo:
  - `gh issue edit <T3> --type Task`: record gh's error text.
  - `gh api graphql` for `viewerCanType`, `viewerCanSetFields`, `issueFieldValues` on T3.
  - `gh api repos/…/issues/<T3>/issue-field-values`: record the status code (expect 404/422).
- [x] Cleanup:
  - C1, scope (the user runs it): `! gh auth refresh -h github.com -s delete_repo`. Alternative: delete the repo in the web UI (Settings → Danger Zone). The user picks the path when C2 is reached.
  - C2, delete, after its own yes: `gh repo delete nhatduong-agilityio/devkit-p46-probe --yes`.
  - Record which path was used. Optionally drop the scope afterwards with `gh auth refresh -h github.com --remove-scopes delete_repo`.
- Verify:
  - `test -s plans/20261021-squad-task-state/research/live-probe.md && grep -cE '^\| (P0|S1|W[1-7]|C[12])' plans/20261021-squad-task-state/research/live-probe.md` must print ≥ 11.
  - `gh repo view nhatduong-agilityio/devkit-p46-probe` must exit non-zero, meaning the repo is gone.

### Phase 2 — Read-only org checks (Agility-Vietnam)
Struck items below were dropped, not done (user decision, 2026-10-21). No repo created and no config changed. Record only field and type names, value types, options, and booleans. No org issue titles, bodies, or other repo names. Cite the org repo as `<org-repo>`; never its name.

- [x] ~~Pick one org repo with issues: `gh repo list Agility-Vietnam --limit 10 --json name,hasIssuesEnabled`. — file: `research/live-probe.md` (section "Org read-only")~~ — dropped: out of scope (user decision 2026-10-21, no org connection needed).
- [x] ~~On one existing issue, run one `gh api graphql` query for `issueType { name }`, `issueFieldValues(first:10)` (typename and value), `viewerCanSetFields`, `viewerCanType`, `parent`, `subIssuesSummary`, and `issueDependenciesSummary`. This shows whether a member can read field values and whether a member may set fields or types.~~ — dropped: out of scope (user decision 2026-10-21, no org connection needed).
- [x] Read the Effort and Priority options read-only (`organization.issueFields`, options on `IssueFieldSingleSelect`). Record whether Effort can carry XS/S/M. Note that there is no number or text field, so "attempts" or "complexity" would need an org admin with `admin:org`, which a member cannot do.
- [x] ~~`gh issue list -R Agility-Vietnam/<repo> --limit 5 --json number,parent,blockedBy,issueType` must succeed. This is read support only; org writes stay unverified and are cited from docs.~~ — dropped: out of scope (user decision 2026-10-21, no org connection needed).
- Verify: `grep -c '^## Org read-only' plans/20261021-squad-task-state/research/live-probe.md` → 1, and `grep -cE 'viewerCanSetFields|viewerCanType' plans/20261021-squad-task-state/research/live-probe.md` → ≥ 2.

### Phase 3 — Findings and decision
- [x] Write `plans/20261021-squad-task-state/research/findings.md` with these sections:
  - `## Verdict`: native works or not, judged against the Approach criteria.
  - `## Store per need`: a table with one row per need: epic→task, waves/depends-on, size, complexity, attempts, expected files, serial, claim/in-progress, agent result. Columns: personal repo store | org repo store | evidence (`live-probe.md` step id or `schema-probe.txt:line`).
  - `## Projects board`: an optional one-way view, if any. It needs the `project` scope and is never read, and relink is or is not needed.
  - `## Must handle in P-41/P-42`: for example, cycle detection if GitHub accepts cycles, filtering out closed blockers, the 50/100 limits (from docs, not brute-forced), and the label/comment fallback for org-only fields.
  - `## Unverified`: cross-repo links, limits, and behavior after GA (org repos are out of scope).
- Verify: `for s in 'Verdict' 'Store per need' 'Projects board' 'Must handle in P-41/P-42' 'Unverified'; do grep -q "^## $s" plans/20261021-squad-task-state/research/findings.md || echo "missing $s"; done` prints nothing.

### Phase 4 — Proposal and bookkeeping updates
These edits go on the branch `docs/p46-squad-task-state`, not on main. Commit, push, and PR each need the user's yes.

- [x] `upstream/proposals/20261018.md`:
  - `:51`: P-46 → done, a one-line conclusion, and `plans/20261021-squad-task-state/`.
  - `:54`: P-41, where "depends on" is stored and whether cycle detection is needed.
  - `:55`: P-42, where task state is read from and written to.
  - `:70`: "Board relink", kept as Skip or moved, per the verdict.
  - `:87`, `:91-97`: release line and next commands.
- [x] `UPSTREAM.md:152`: P-46 row ⏳ → ✅ with a one-line conclusion. Adjust `:147-148` only if P-41/P-42 wording changes.
- [x] No `CHANGELOG.md` entry, because no shipped kit file changes. The `CLAUDE.md` rule covers adding or renaming skills and agents only.
- Verify:
  - `grep -c '^| P-46 .*[Dd]one' upstream/proposals/20261018.md` → 1.
  - `grep -c '✅ | P-46' UPSTREAM.md` → 1.
  - `claude plugin validate plugins/devkit --strict && claude plugin validate .` → exit 0.
  - `scripts/test-hooks.sh` → all ok.
  - `git diff --stat main...HEAD -- . ':!plans/**'` → under 300 lines and 25 files.

## Risks
| Risk | Signal | Mitigation |
| --- | --- | --- |
| Throwaway repo left behind | `gh repo view nhatduong-agilityio/devkit-p46-probe` still succeeds | Phase 1 verify fails until it is deleted. Two cleanup paths: CLI after the scope refresh, or the web UI. The description says "safe to delete". |
| Token scope gaps (`delete_repo`, `project`) | `gh` 403 or "missing scope" | The user refreshes `delete_repo` only for cleanup. Projects is not probed. |
| A negative result that only reflects a bad query | Search returns empty or everything | Positive and negative control per qualifier, one retry after the lag. Ground truth comes from `gh issue view`. |
| Personal, org, and plan features differ | Personal results differ from docs or the org read | Store table split by repo kind. Org repos out of scope (user decision 2026-10-21). |
| Behavior changes after GA (cycles, qualifiers, limits) | A later run disagrees with `live-probe.md` | Date and gh version on every probe file. P-41/P-42 re-check their own assumptions. |
| Org data leaks into committed files | Titles or repo names in `live-probe.md` | Record names, types, and booleans only. Review before commit. |
| Rate limits | Secondary-limit 403 | About 30 calls total, so negligible. Pause and retry once. |

## Out of scope
- Any kit code (skills, agents, scripts, hooks). P-41/P-42 implement whatever the findings decide.
- Writes on Agility-Vietnam or any org repo. Creating issue types or fields.
- Org issue-level reads and all org behavior beyond type and field definitions (user decision, 2026-10-21: no org connection needed).
- Probing Projects boards (`project` scope), and brute-forcing the 50/100/8 limits.
- Cross-repo sub-issue and dependency links: squad tasks live in one repo; marked unverified in findings.
- nhat-kit's own issues and labels.
