# PR report artifact
Status: in-progress (reconciled with main, see report.md) · Source: user request 2026-10-16 ("use artifact UI for the output report, more visualization for the PR") · Decisions: user · Depends on: PR #7 (P-22)

## Goal
**Every PR devkit opens**, for **every kind of task**, links one private **report artifact** built from one template. That covers `/devkit:git pr` directly, `/devkit:ship`, and `/devkit:task`, and features, bug fixes, refactors, performance changes, docs and chores, UI or not. A reviewer gets the whole picture on one page, so a reviewer gets the whole picture on one page, with visuals instead of walls of text. The page shows:
- what changed and why, with a change map by area and a diagram when the change has a flow;
- verification: gates, tests before and after, ACs with their evidence, and UI screenshots from P-22;
- review findings by severity;
- metrics with before/after charts, when the change produced numbers.

## Decisions (from the user)
| # | Question | Answer |
| --- | --- | --- |
| D1 | Contents | Change summary + diagram; verification and tests; review findings; metrics when present |
| D2 | When | On **every** `ship`/`task` PR |
| D3 | Relation to P-22 | **One report per PR**; UI evidence becomes a section of it. Built on top of PR #7 |
| D4 | Scope | The template applies to **all tasks and all PRs**: one report procedure inside `/devkit:git pr`, used by every PR path, adapting to the kind of change |

## Context found
- **P-22** (PR #7, open): `conventions.md` "UI evidence" defines the `evidence/` folder (gitignored), the screenshot names, the artifact (main session only), the PR line "(private — shared on request)", and fallbacks.
  - `git-manager` writes exact *Screenshots / GIF* lines from one value passed by `ship`/`task`.
- `plugins/devkit/skills/cook/SKILL.md:39-44`: writes `plans/<…>/report.md` (phases, files, evidence, review findings, out-of-scope issues). This is the text the report page can draw on.
- **PR paths today:**
  - `plugins/devkit/skills/git/SKILL.md:19`: `pr` builds the body from the plan's `report.md` or the SPEC. This is the single PR procedure.
  - `ship/SKILL.md:21`: gate 8 follows it.
  - `task/SKILL.md:67`: step 8 calls `git-manager` **directly** and so skips it. This has to be routed through `/devkit:git pr` for the template to cover every PR.
- `plugins/devkit/skills/ship/SKILL.md`: 8 gates and a gate table in the reply. `task/SKILL.md` steps 7–8 collect the AC → evidence table.
- **Artifact limits** (artifact-design contract):
  - inline CSS and JS only; scripts from CDNs on the allowlist only;
  - mermaid renders natively (`<pre class="mermaid">`), so no library is needed for diagrams;
  - images go in `files`; the page must be theme-aware and work at 400 px;
  - the Artifact tool exists only in **interactive** sessions (`plans/20261016-evidence-artifact/research/flow.md`).
- **Tooling:**
  - `plugins/devkit/scripts/` holds plain-bash hooks only.
  - Node is the safest runtime for a renderer in frontend and full-stack projects (`node --test` works with no dependencies; Node 24 here).
  - `scripts/release.sh:31` runs `scripts/test-hooks.sh`.

## Approach
0. **One place for every PR (D4).** The report step lives in the `/devkit:git pr` procedure: build `report.json`, render, publish, then hand the links to `git-manager`.
   - `ship` gate 8 already follows that procedure; `task` step 8 is changed to follow it too, instead of calling `git-manager` directly. Every devkit PR path then produces a report.
   - **Callers add what they know:** `ship` adds its gate table and UI evidence; `task` adds the AC → evidence table and UI evidence; a direct `/devkit:git pr` uses the plan's `report.md` or the SPEC. Anything missing is left out of the page.
   - **The page adapts to the kind of change**, read from the Conventional Commit type of the branch's commits:
     - `feat`: summary, change map, diagram, ACs, UI;
     - `fix`: a "Symptom → Cause → Fix" summary block and the regression test highlighted;
     - `perf`: metrics first;
     - `refactor`: change map plus "behavior unchanged" evidence (tests before/after);
     - `docs`, `chore`, `ci`, `build`, `test`: summary and change map only.

   The renderer picks the section order from `kind`; the data decides what appears.
1. **The model writes data; a script draws the page.** The `/devkit:git pr` procedure fills a `report.json`. A dependency-free Node script, `plugins/devkit/scripts/render-report.mjs`, turns it into `report.html` with inline SVG charts. This gives the same look on every PR, costs fewer tokens than hand-written HTML, and can be unit-tested.
   - If `node` is missing, the model writes the page by hand from the same spec.
2. **`report.json` schema**, documented in a new `plugins/devkit/references/report.md`:
   - `id`, `title`, `kind` (`feat|fix|perf|refactor|docs|chore|ci|build|test`), `branch`, `base`, `commit`, `summary`, `why`
   - `fix` (for `kind: fix`): `{symptom, cause, fix, regression_test}`
   - `areas[]`: `{name, files, added, removed}`, from `git diff --numstat <base>...HEAD`, grouped by top folder or module
   - `diagram`: mermaid text or `null`
   - `gates[]`: `{name, status: pass|fail|skip, detail}`
   - `tests`: `{before: {pass, fail}, after: {pass, fail}}`
   - `acs[]`: `{id, text, status, evidence, images[]}`
   - `review`: counts per severity (`critical`, `warning`, `optional`) × (`fixed`, `remaining`), plus `items[]`
   - `metrics[]`: `{name, unit, before, after, better: lower|higher}`
   - `risks[]`
3. **What the page shows, in order:**
   - a status header (title, branch → base, commit, overall pill);
   - Summary / Why;
   - the **change map** (horizontal bars of lines added/removed per area);
   - the **diagram**, if any;
   - **Verification**: gate pills, a tests before/after bar, the AC table;
   - **UI evidence**: P-22's screenshots per AC, in the `#ui` section;
   - **Review**: a stacked bar of fixed vs remaining per severity, then the list of items;
   - **Metrics**: before/after bars marked better or worse, only when present;
   - **Risks**.

   Empty sections are left out. The page follows the artifact page contract (tokens, light and dark, 400 px, no external assets).
4. **Files:** `evidence/report.json` and `evidence/report.html` sit next to the plan or SPEC, already gitignored by P-22. When a direct `/devkit:git pr` has no plan or SPEC, they go in `.claude/reports/<branch>/`, which is gitignored too. The artifact gets the page plus the screenshots as `files`. Title: `<ID or slug> report`.
5. **PR wiring (both PR templates, so every PR carries the line):**
   - The *Summary* gets `Report: [<ID> report](<url>) (private — shared on request)`.
   - *Screenshots / GIF* gets `[UI evidence](<url>#ui) (private — shared on request)` for UI changes, otherwise `None (no UI change)`.
   - `ship` and `task` pass `git-manager` both values. Without the Artifact tool, both fall back: `Report: not published (no Artifact tool) — summary below`, and the P-22 file list.
6. **P-22's separate "UI evidence" artifact is replaced** by the `#ui` section of the report (D3). The conventions' "UI evidence" rules keep the folder, names, content rules and fallbacks, and now point to the report for publishing.

Rejected alternatives:
- The model hand-writes the HTML each time: inconsistent visuals, many tokens, nothing to test.
- A chart library from a CDN: inline SVG covers bars and pills, and mermaid is native.
- A report only when there's something to show (D2 chose every PR).
- Two artifacts per PR (D3).
- A report step in each of `ship` and `task` separately: two copies drift, and a direct `/devkit:git pr` would get no report (D4).
- A separate renderer per kind of change: one renderer with `kind`-ordered sections keeps a single template.

## Phases

### Phase 0: Base
- [ ] PR #7 is merged into `main` (user action), then branch `feat/pr-report` from `main`. If #7 is still open, branch from `feat/evidence-artifact` and open this PR against it.
- Verify: `git log --oneline -1 main` shows the P-22 commits, or the branch base is `feat/evidence-artifact`.

### Phase 1: Renderer and schema (foundational; the visuals are the riskiest part)
- [ ] `plugins/devkit/references/report.md`: the schema with one full example, and the page sections and their order.
- [ ] `plugins/devkit/scripts/render-report.mjs`: `node render-report.mjs report.json > report.html`.
  - Node built-ins only. It escapes every string, embeds images by relative path, writes inline SVG bars, and emits `<pre class="mermaid">`.
  - Exit 1 with a clear message on invalid JSON or a missing required field (`id`, `title`, `commit`).
- [ ] `plugins/devkit/scripts/render-report.test.mjs` (`node --test`). Cases:
  - a minimal report (only the required fields) renders and skips empty sections;
  - a full report contains every section;
  - HTML in the input is escaped (`<script>` in `summary` comes out as text);
  - metrics mark better or worse correctly for `lower` and `higher`;
  - invalid JSON exits 1.
- [ ] Render the full sample and publish it once as a private artifact in this interactive session. Take **one** look (preview or screenshot) at light, dark and phone width, and fix what it shows.
- Verify:
  - `node --test plugins/devkit/scripts/render-report.test.mjs` passes.
  - The sample artifact URL is recorded in `report.md` (this plan's).
  - The single look shows no horizontal overflow at 400 px and readable charts in both themes.

### Phase 2: Conventions
- [ ] `conventions.md`: a new "PR report" section covering when (every `ship`/`task` PR), the files, the data sources (`git diff --numstat`, the gate table, tests, cook's `report.md`, review output, the evidence folder), render then publish, the PR lines, and the fallbacks.
- [ ] Rewrite the "UI evidence" **Artifact** bullet to "published inside the PR report, section `#ui`". The folder, name and content rules are unchanged.
- [ ] Add a Directories row for `evidence/report.json` and `report.html`.
- Verify: `grep -n 'PR report' plugins/devkit/references/conventions.md` prints a line, and the UI evidence section no longer mentions a separate artifact.

### Phase 3: Wiring
- [ ] `git/SKILL.md` `pr`: the **report procedure** (gather the data, `kind` from the commits, `git diff --numstat` for areas, render, publish or fall back), then `git-manager` with the `Report:` value and the *Screenshots / GIF* value. The reply gives the report link and the reminder to share.
- [ ] `ship`: gate 5 collects the UI evidence (unchanged). Gate 8 passes its gate table, test counts and UI evidence into the `/devkit:git pr` procedure. The final reply gives the report link and the reminder.
- [ ] `task`: step 8 follows the `/devkit:git pr` procedure (no direct `git-manager` call), passing the AC → evidence table and UI evidence. The ending gives the link and the reminder.
- [ ] `git-manager`: a rule for the `Report:` line in Summary (exact formats for a link and for "not published"), next to the existing *Screenshots / GIF* rules.
- [ ] Both PR templates (plugin and this repo's `.github/`): `Report:` line under Summary.
- Verify:
  - `claude plugin validate plugins/devkit --strict` passes.
  - `grep -n 'git-manager' plugins/devkit/skills/task/SKILL.md` shows that step 8 no longer calls it directly for `pr`.
  - A headless dry-run of `git-manager` operation `pr` (as in P-22) with a report link and a UI link gives the exact `Report:` and *Screenshots / GIF* lines; with no Artifact tool, it gives the "not published" line.

### Phase 4: End to end on the fixture, one run per PR path and kind
- [ ] **Headless, without the Artifact tool, checking the fallback and `report.json`:** a direct `/devkit:git pr` dry run on a `fix` commit in the fixture (no UI change). It should produce:
  - `report.json` with `kind: fix` and a filled `fix` block;
  - `report.html` showing "Symptom → Cause → Fix" and no UI section;
  - the PR lines "Report: not published (no Artifact tool) — summary below" and "None (no UI change)".
- [ ] **Headless:** the same on a `docs` commit gives a page with only the summary and the change map.
- [ ] **Interactive (by the user):** in the P-22 fixture (`evfix`), make a small real change, such as trimming the name and showing "Name is required". Then run `/devkit:ship` interactively up to gate 8 with the push declined. **Manual, by the user**, because only an interactive session has the Artifact tool.
- Verify:
  - a private "<ID> report" artifact shows the change map, gates, tests, both AC screenshots in `#ui`, and the review section;
  - the PR body draft has both lines;
  - the final reply reminds the user to share.

### Phase 5: Docs and release checks
- [ ] `README.md`: one paragraph "PR report" next to Model tiers, plus the `ship` and `task` rows.
- [ ] `CHANGELOG.md` `[Unreleased]` → Added (renderer + report) and Changed (UI evidence now inside the report).
- [ ] `UPSTREAM.md` → a row under the deck table: "Capture the output as an artifact" ✅.
- [ ] `scripts/release.sh` and the release skill run `node --test plugins/devkit/scripts/render-report.test.mjs` next to `test-hooks.sh`.
- [ ] `CLAUDE.md` Commands: add the renderer test.
- Verify: both validate commands, `scripts/test-hooks.sh`, and the renderer tests pass; `grep -n 'render-report' scripts/release.sh CLAUDE.md` hits both.

## Risks
| Risk | Signal | Mitigation |
| --- | --- | --- |
| No Artifact tool in headless or CI runs (High, certain for `-p`) | No report URL | The fallback lines in the PR; the report files stay in `evidence/` for the user to publish later |
| Report noise on tiny PRs (Medium; D2 chose every PR) | One-line fixes get a near-empty page | Empty sections are dropped; the page is short when there is little to show |
| Wrong numbers on the page (Medium) | The change map or tests disagree with the PR | Numbers come from commands (`git diff --numstat`, test output), never from memory; the renderer only draws what it is given |
| XSS or broken HTML from model text (Medium) | Script tags or markup from the input rendering | The renderer escapes every string; there is a unit test for it |
| A private link that reviewers can't open (Low) | Reviewer asks for access | "Private — shared on request" plus the reminder (as in P-22) |
| Callers skip the shared procedure (Medium) | A PR without a `Report:` line | Every PR path (`git pr`, `ship`, `task`) goes through `/devkit:git pr`; both PR templates show the `Report:` line, so a missing value is visible; `git-manager` writes "not provided" rather than dropping it |
| `node` missing in a project (Low) | Renderer can't run | The hand-written fallback from `references/report.md` |
| Plugin scripts were bash-only so far (Low) | — | The renderer is not a hook; only hook scripts are bound to the bash rule in CLAUDE.md |

## Out of scope
- Posting the report into the PR as a comment, or uploading images to GitHub.
- Reports for `cook` alone (it ends with `report.md`; any PR made afterwards turns that into the page).
- PRs opened outside devkit (by hand, or with plain `gh pr create`). They still show the template's `Report:` line, for the author to fill in.
- Interactive features on the report page (filters, comments); the artifact's own comments cover feedback.
