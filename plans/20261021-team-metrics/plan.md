# /devkit:report — team metrics from GitHub data only
Status: in-progress · Source: P-37 in `upstream/proposals/20261018.md:41` (v2.6.0, last item) · Mode: standard
Approved: 2026-10-21 by nhatduong-agilityio

## Goal
- `/devkit:report [since]` writes `reports/<YYYYMMDD>.md` in the project repo. The file covers:
  - merged PRs and their sizes, counted the P-27 way
  - cycle time from the devkit claim comment to merge
  - two send-back numbers, kept separate
  - open bugs by severity
  - queue depth and in-flight work
- Every number comes from one read-only script, `metrics.sh`, which reads only from `gh`. Items with missing data are excluded and counted, never estimated.
- The skill offers a published artifact. It publishes only after an explicit yes.

## Context found
- `docs/devkit.md:9,13,17`: the PR gate in this repo is 300 lines and 25 files. `plans/**` is excluded.
- `plugins/devkit/scripts/pr-size.sh`:
  - `:7-8`: defaults.
  - `:11`: accepts at most one argument.
  - `:14`: the HEAD check, and `:16-21`: the base and merge-base checks. Both run before the config and pattern block at `:23-41`.
  - `:43-58`: the `excluded()` matcher.
  - `:74`: uses `--no-renames`, so a rename counts as a delete plus an add. gh's `files` has one entry per rename: the new path and only the changed lines. This is a known difference from P-27's counting and is not emulated.
- `scripts/test-hooks.sh:327-382`: the pr-size cases (`mkrepo`, `psck`). Any change to `pr-size.sh` must keep them all `ok`.
- `plugins/devkit/scripts/queue-status.sh`. This is the pattern for the new script:
  - `:1-7`: the header, which promises that comment bodies are never printed.
  - `:10-11`: `command -v`.
  - `:27-30`: mktemp, trap, and `ghq`.
  - `:36-97`: one `python3 -I -c` parser.
  - `:51`: `clean()` removes control characters.
  - `:68-71`: claim and release detection, by prefix match on the body plus the comment's `createdAt`.
- `scripts/test-hooks.sh`:
  - `:484-529`: the queue-status stub, its fixture builders, and `qsck`.
  - `:669-806`: the team-status stub, with `TS_CASE`, a stub-contract comment, `tsck`, and the gh-missing case at `:801-806`.
  - New cases go before the summary at `:1063`.
- `plugins/devkit/references/conventions.md`:
  - `:134-136`: the claim and release comment formats.
  - `:122-128`: the queue labels.
  - `:140`: a claim race makes the loser post a release.
  - `:9`: escape `|` as `\|` inside table cells.
  - `:25`: dates use local time.
- `plugins/devkit/skills/issue/SKILL.md:20-23`: bugs carry `bug` plus one `severity:*` label. `skills/task/SKILL.md:19`: the queue is open issues labelled `ai`.
- `plugins/devkit/skills/security-scan/SKILL.md:4-5`: the precedent for a skill that writes a report file. It has `disable-model-invocation: true` and `allowed-tools` limited to named scripts plus `Bash(mkdir *)`, and Write is not pre-granted.
- `conventions.md:85-86` and `render-report.mjs`: the PR report artifact builder. It is not reused (decision 3).
- Verified on gh 2.102 (live):
  - `gh pr list --state merged --search "merged:>=D" --json number,title,mergedAt,additions,deletions,changedFiles,files,reviews,closingIssuesReferences` works.
  - `files[]` = `{path, additions, deletions, changeType}`. It can be truncated (about 100 entries).
  - Search returns at most 1000 results.
  - macOS has no `timeout`.
- Docs to update:
  - `README.md:3` (the "19 commands" count), the `:9-29` table, the `:31` "only when you type them" list, and the `:62` "Periodically" line.
  - `UPSTREAM.md:143` (P-37 ⏳).
  - `CHANGELOG.md` `[Unreleased]` / `### Added`.
  - `upstream/proposals/20261018.md:85,91,94`. The uncommitted "#34" edit at `:85` rides along unchanged.

## Approach
- **`pr-size.sh` exposes its matcher, so there is one matcher.** Add `pr-size.sh --excluded-index <file>`.
  - Input: `<file>` holds NUL-separated paths.
  - Output: line 1 is `max_lines=N max_files=M`. Then it prints one 0-based index per excluded path, one per line. Indices avoid any problem with how paths are encoded.
  - The mode needs the repo top (for `docs/devkit.md`) but no base. Keep the existing order: relax the argument check at `:11` to also accept `--excluded-index <file>`, and branch after the HEAD check (`:14`) but before the base resolution (`:16-21`); the config and pattern block (`:23-41`) is read first in that branch (factor it into a function or reorder only the base lines, whichever keeps the diff smaller). A repo with no commits is out of scope: `/devkit:report` needs merged PRs.
  - The reader accepts a final path without a trailing NUL (`|| [ -n "$p" ]`). One bash `excluded()` call per distinct path is slow for very large lists (up to ~100k paths at 1000 PRs × 100 files); accepted, stated in Risks.
  - Drift guard: a parity test runs the normal mode and the new mode on the same fixture repo and checks the **set**, not just a count: on a fixture with at least 4 excluded paths of different glob shapes (basename glob, `**/` prefix, `dir/**`, `*.min.*`) plus non-excluded look-alikes, the new mode's indices map back to exactly the expected excluded paths from the fixture's `git diff --name-only -z`, and the normal mode's `excluded=` equals the size of that set.
- **`plugins/devkit/scripts/metrics.sh [--since YYYY-MM-DD]`, read-only.**
  - `--since` defaults to 14 days ago, in UTC, computed in Python (macOS `date` differs). Any other argument shape → usage error, exit 1.
  - It runs `gh auth status` first. On failure it prints `metrics: gh not logged in` and exits 1.
  - It makes four `ghq` calls, each with `--limit 1000`:
    1. Merged PRs (the fields above).
    2. `issue list --label ai --state all --search "updated:>=D" --json number,comments`.
    3. `issue list --label bug --state open --json number,labels`.
    4. `issue list --label ai --state open --json number,labels`.
  - The search date is `since − 1 day`, so a PR at the UTC edge is never missed; the Python `mergedAt` re-filter then drops the extra day.
  - Python mode `paths`: writes each distinct PR file path once, each terminated by NUL (including the last). `"$here/pr-size.sh" --excluded-index`, with `here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"` (works under `bash metrics.sh`), then classifies them, giving the limits and the excluded set. Python maps the indices back to the paths. If that call exits non-zero, `metrics.sh` exits 1. It never treats every path as counted.
  - Python mode `report`: prints the output.
  - The script never prints comment bodies or review text. Titles pass through `clean()`.
  - Definitions:
    - **Period:** PRs whose `mergedAt` is on or after `since`T00:00:00Z. This is checked again in Python, because GitHub search may read the date in another timezone.
    - **Size:**
      - Lines = the additions plus deletions of the files that are not excluded. Files = the number of files that are not excluded.
      - When `len(files) < changedFiles`, the PR is `size_missing`: excluded from the size stats and counted.
      - `over_limit` = the PRs with lines over `max_lines` or files over `max_files`.
    - **Cycle time:**
      - For each closing issue, take the latest claim comment created before `mergedAt` (a later claim restarts the work).
      - With several closing issues, take the earliest of those claims, because the PR's work began at the first claim.
      - Cycle = `mergedAt` − claim `createdAt`, in hours with one decimal.
      - A PR with no cycle time counts as missing, with one reason:
        - `no_issue`: the PR has no closing issue.
        - `not_fetched`: the closing issue is not in fetch 2, because it has no `ai` label, lives in another repo (`closingIssuesReferences[].repository` owner/name differs from the current repo; match on repo + number, never number alone), or the fetch was truncated.
        - `no_claim`: the issue was fetched, but it has no claim before the merge.
        - `capped`: the issue has exactly 100 comments, so gh may have dropped the newest claim; no number is computed from the older ones.
    - **Send-back (a):** the count of `CHANGES_REQUESTED` reviews on PRs merged in the period. **Send-back (b):** the count of `🔓 devkit release` comments created on or after `since` that have an earlier `🔒 devkit claim` on the same issue. The two are never summed.
    - **Bugs:** open issues labelled `bug`, grouped by their highest `severity:*` label. A bug with no severity label counts as `none`.
    - **Queue:** `queue_depth` = open `ai` issues without `in-progress`. `in_flight` = open `ai` issues with it.
    - **Stats:** median and p90 by the nearest-rank method, with `n` printed next to them. When `n` is 0, they print `-`.
  - Output: `key=value` lines first, then one TSV row per merged PR.
    ```text
    since=D until=<ISO UTC> report_date=<local YYYYMMDD>
    prs_merged=N prs_truncated=0|1
    size_n=N size_missing=K lines_median=… lines_p90=… files_median=… files_p90=… over_limit=K max_lines=… max_files=…
    cycle_n=N cycle_missing=K no_issue=… not_fetched=… no_claim=… capped=… cycle_median_hours=… cycle_p90_hours=…
    review_sendbacks=N queue_releases=N issues_truncated=0|1
    bugs_open=N critical=… high=… medium=… low=… none=… bugs_truncated=0|1
    queue_depth=N in_flight=N queue_truncated=0|1
    capped_items=N
    #N<TAB>lines|-<TAB>files|-<TAB>cycle_hours|-<TAB>changes_requested<TAB>title
    ```
  - `capped_items` counts the PRs and issues with exactly 100 files, reviews, or comments.
  - Exit codes: 0 when it reported; 1 on a usage error, a missing tool, a gh failure, or gh output it cannot parse. Errors go to stderr, prefixed `metrics:`.
- **`plugins/devkit/skills/report/SKILL.md`.**
  - Frontmatter:
    - `disable-model-invocation: true`, because it writes a file.
    - `allowed-tools: Bash(bash */metrics.sh *) Bash(mkdir *)`.
    - The `description` is under 300 characters.
  - Steps:
    0. `argument-hint: "[since YYYY-MM-DD, default 14 days ago]"`; the report header states the window (UTC) and the default when used.
    1. Run `metrics.sh` with the optional `since`. On exit 1, show the stderr line and stop. When gh is not logged in, say so and stop.
    2. Run `mkdir -p reports`, then write `reports/<report_date>.md` from the script output only. A same-day rerun overwrites that day's file; the skill says so before writing. The file has:
       - Summary tables: size, cycle, the two send-back rows, bugs, and queue.
       - A per-PR table, with titles escaped `|` → `\|`.
       - A "Missing data" section listing every missing count, reason, and truncation flag.
       - No estimates.
    3. Show a 5-line summary and suggest committing the file through `/devkit:git cm`, so the team shares it.
    4. Offer an artifact: a simple HTML page built from the numbers in the `.md` only. Publish only after an explicit yes (conventions "Approval"). With no Artifact tool, say that the `.md` is the shareable file.
- **Four stacked PRs, one per phase** (red-team: 290 lines for script + tests was not credible; the stub-gh sections in `test-hooks.sh` run ~140 lines each). Estimates include tests; the plan file is excluded.
  - **PR A0, ~80 lines:** Phase 1 (`pr-size.sh` mode). Isolates the gate-script regression risk.
  - **PR A1, ~250 lines:** Phase 2 (`metrics.sh` skeleton: args, auth, PR fetch, sizes, PR rows).
  - **PR A2, ~250 lines:** Phase 3 (cycle time, send-backs, bugs, queue).
  - **PR B, ~110 lines in 5 files:** Phase 4. It adds the skill and its README, UPSTREAM, and CHANGELOG entries together, as the repo rule requires.
  - Adjacent PRs may be combined only when `pr-size.sh` reports `status=ok` for the combined diff.

Rejected:
- Calling GraphQL directly (`gh api graphql`): `gh pr list --json` already returns every field, and paging and query text would add code to test.
- A Python `fnmatch` copy of the matcher: close (`*` crosses `/` there too) but its escapes differ. It would be a second matcher needing its own parity tests.
- Extending `render-report.mjs` for metrics: overruled by decision 3. Its schema is per-PR, and the page is simple.
- Summing the two send-back numbers: overruled by decision 1. They measure different events.
- Estimating size from `additions + deletions` when `files` is truncated: excludes cannot be applied, so the PR counts as missing.
- A separate `reports.json` cache: one script output feeds the `.md`, and the HTML is built from the `.md`.

## Phases

### Phase 1 — `pr-size.sh --excluded-index` (PR A0, gate script regression risk)
- [x] Keep the existing order; relax the argument check at `:11`, branch after the HEAD check and before the base resolution (see Approach). Add the mode: with exactly two arguments, `--excluded-index <file>`, print the limits line plus the excluded indices and exit 0. An unreadable file → exit 1. Normal behavior is unchanged. Update the header's Usage and Output lines. File: `plugins/devkit/scripts/pr-size.sh`.
- [x] Tests, after `:382`. Cases:
  - Default excludes over a NUL list (`a.lock`, `src/x.js`, `pkg/__snapshots__/s`, `dist/m.js`, `sub/yarn.lock`) → indices `0 2 3 4`, with limits `300`/`10`.
  - The custom `pr_size_exclude` from `mkrepo excl` applies.
  - Parity (set, not count): see Approach's drift guard.
  - A list whose last path has no trailing NUL → that path is still classified.
  - A missing file → exit 1.

  File: `scripts/test-hooks.sh`.
- Verify:
  - `scripts/test-hooks.sh` exits 0, with every existing `pr-size` row and the new ones `ok`.
  - `bash -n plugins/devkit/scripts/pr-size.sh` passes.
  - `bash plugins/devkit/scripts/pr-size.sh main` in this repo still prints the summary line.

### Phase 2 — `metrics.sh` skeleton: arguments, auth, PR fetch, sizes (PR A1, foundational)
- [x] Write the script's frame and size part from Approach: header (Usage/Output/Exit for the full output, keys from Phase 3 marked as added there), `die`, `ghq`, mktemp and trap, `here=` resolution, `--since` parsing, `gh auth status`, the merged-PR fetch, Python modes `paths` and `report` (period, size, `over_limit`, `prs_truncated`, `capped_items` for files/reviews, the per-PR rows with cycle `-` and `changes_requested`). File: `plugins/devkit/scripts/metrics.sh` (chmod +x).
- [x] Add a stub `gh` chosen by `MX_CASE`, routing on `"$1 $2"` plus the `--label`, `--state`, and `--search` values; its contract comment lists every call (the Phase 3 ones are added there). Fixtures come from a small python builder, times in UTC `Z`. Add an `mxck` helper. Failure cases that need a stub `pr-size.sh` copy `metrics.sh` into a temp dir beside the stub (the script resolves `pr-size.sh` from its own directory).

  Cases:
  - Two PRs, one with an excluded `package-lock.json` → its lines do not count, and `size_n=2`.
  - `files` shorter than `changedFiles` → `size_missing=1`, a `-` in that row, and `size_n` reduced.
  - A PR over 300 lines → `over_limit=1`. A `docs/devkit.md` with `- pr_max_lines: 1000` in the temp repo → `over_limit=0`.
  - 1000 PRs returned (generated by the builder) → `prs_truncated=1`. A PR with exactly 100 reviews → `capped_items=1`.
  - A PR merged before `since`, returned anyway by search (the search uses `since − 1 day`) → excluded. The stub log shows `merged:>=<since-1d>`.
  - A title with a control character → cleaned.
  - Arguments: `--since 2026-1-5` → exit 1. No argument → a `since=` dated 14 days ago (UTC). The test computes the expected date with `python3`, not with BSD or GNU `date`. `bash metrics.sh` run from the scripts directory (no slash in `$0`) still finds `pr-size.sh`.
  - Failures, each → exit 1: `auth status` fails (`not logged in` on stderr); invalid JSON from `pr list`; a stub `pr-size.sh` that fails in `--excluded-index` mode; `gh` missing from `PATH`.

  File: `scripts/test-hooks.sh`, before the summary at `:1063`.
- Verify:
  - `scripts/test-hooks.sh` exits 0, with every `metrics` row `ok`.
  - `bash -n plugins/devkit/scripts/metrics.sh` passes.
  - Live read-only run in this repo: `bash plugins/devkit/scripts/metrics.sh --since 2026-10-15` exits 0, `prs_merged` equals `gh pr list --state merged --search "merged:>=2026-10-15" --json mergedAt` re-filtered to `mergedAt >= 2026-10-15T00:00:00Z`, and PR #34's row shows the lines `pr-size.sh` would count (its `files` minus excludes). Record the actual values.
  - `bash plugins/devkit/scripts/pr-size.sh main` reports `status=ok`.

### Phase 3 — `metrics.sh`: cycle time, send-backs, bugs, queue (PR A2)
- [ ] Add fetches 2–4 and the cycle, send-back, bug and queue definitions from Approach, including the repo + number match for closing issues and the `capped` reason. File: `plugins/devkit/scripts/metrics.sh`.
- [ ] Extend the stub and add cases. File: `scripts/test-hooks.sh`.
  - Cycle: a claim, then a release, then a later claim, all before the merge → measured from the later claim. Two closing issues → the earliest of their latest claims. A claim after `mergedAt` is ignored → `no_claim`.
  - Missing reasons: one each of `no_issue`, `not_fetched` (one with no `ai` label, one in another repo with the same number as a fetched issue), `no_claim`, and `capped` (an issue with exactly 100 comments whose claims are all old) → right counts, and no cycle number for the `capped` one.
  - Send-backs: 2 `CHANGES_REQUESTED` plus 1 `APPROVED` → `review_sendbacks=2`. A release with an earlier claim → 1. A release with no earlier claim → 0. A release before `since` → 0. Both numbers print separately.
  - Bugs: `severity:high`, then `high` plus `low` (counts as high), then no severity → `high=2 none=1`.
  - Queue: 3 open `ai` issues, 1 of them `in-progress` → `queue_depth=2 in_flight=1`.
  - A comment body with `|` and a newline → never printed.
  - Invalid JSON from any `issue list` → exit 1.
- Verify:
  - `scripts/test-hooks.sh` exits 0, with every `metrics` row `ok`.
  - Live read-only run: `bash plugins/devkit/scripts/metrics.sh --since 2026-10-15` exits 0 and prints every key from Approach. This repo has no issues, so expect `cycle_n=0`, `no_issue=<prs_merged>`, `bugs_open=0`, `queue_depth=0`; the cycle and send-back logic is proven by the stub cases only (stated in the report).
  - `bash plugins/devkit/scripts/pr-size.sh main` reports `status=ok`.

### Phase 4 — `/devkit:report` skill and docs (PR B)
- [ ] Write the skill described in Approach, short and imperative. File: `plugins/devkit/skills/report/SKILL.md`.
- [ ] Repo rule for a new skill:
  - Change "19 commands" to 20 at `:3`. Add a `/devkit:report [since]` row after `:28`. Add `report` to the `:31` list. Add `/devkit:report` to `:62`. File: `README.md`.
  - Mark row `:143` ✅, in the shape of `:138`: `/devkit:report` plus `scripts/metrics.sh`, sizes through `pr-size.sh --excluded-index`, the two separate send-back numbers, and missing data counted. File: `UPSTREAM.md`.
  - Add a P-37 entry under `[Unreleased]` / `### Added`. File: `CHANGELOG.md`.
  - Mark P-37 done at `:85` and `:91`. Replace the command at `:94` with `/release minor` (v2.6.0). Keep the uncommitted "#34" edit. File: `upstream/proposals/20261018.md`.
- Verify:
  - `claude plugin validate plugins/devkit --strict && claude plugin validate .` passes.
  - The `description` is under 300 characters (`awk` length check).
  - `grep -c 'devkit:report' README.md` is at least 2.
  - `grep -n 'P-37' UPSTREAM.md` shows ✅.
  - `scripts/test-hooks.sh` passes.
  - `bash plugins/devkit/scripts/pr-size.sh main` reports `status=ok`.
  - Manual: `claude --plugin-dir plugins/devkit`, then `/devkit:report 2026-10-15` writes `reports/20261021.md` (the run date). Its numbers match the script's output line for line, and it has a "Missing data" section. Then delete that file; this repo does not keep reports.

## Risks
| Risk | Signal | Mitigation |
| --- | --- | --- |
| Medium: the new mode's branch breaks the gate in `ship`/`task`/`review` | An existing pr-size row fails | Existing order kept; Phase 1 ships alone (PR A0). Every existing pr-size row must stay `ok` |
| Medium: matcher drift between the gate and the report | Different excluded counts for the same paths | One matcher, plus the parity test |
| Medium: gh truncates `files` (about 100) | `len(files) < changedFiles` | That PR's size is missing and counted, never estimated |
| Medium: assumption: gh caps nested `comments` and `reviews` per item (likely 100, oldest first; unverified) | An item has exactly 100 | `capped_items=N`; an issue at 100 comments gives cycle reason `capped`, never a number from older claims |
| Medium: the 1000-result search cap on busy repos | Exactly 1000 returned | `*_truncated=1` in the report. The skill suggests a later `since` |
| Medium: time and rate limits on big repos (nested comments for up to 1000 issues) | A slow run, or gh exits 1 with a rate-limit message | A 14-day default window. The gh error passes through, and nothing is partly written |
| Low: assumption: GitHub search reads `merged:>=D` / `updated:>=D` in UTC | A PR outside the window, or one missing at the edge | Search from `since − 1 day`, then the `mergedAt` re-filter drops extras. The report states the window is in UTC |
| Low: a claim comment edited or deleted | A PR moves to `no_claim` | `createdAt` does not change on edit. A deleted or reworded claim is counted as missing, not guessed |
| Low: claim-race losers post a release (conventions `:140`), which inflates send-back (b) | Releases a few seconds after a claim | Accepted under the settled definition. The skill names the definition next to the number |
| Low: a `CHANGES_REQUESTED` review that is later dismissed shows as `DISMISSED`, which undercounts send-back (a) | A PR known to have been sent back shows 0 | Accepted under the settled definition. It is noted in the skill |
| Low: assumption: `gh auth status` exits 1 when another stored account is broken but the active one works | A false "not logged in" | Phase 2 checks this live. If it happens, read the active host from `gh auth status --json hosts`, as `team-status.sh` does |
| Low: renames count differently from `pr-size.sh` (`--no-renames`) | A renamed file has small line counts | Stated in the report's notes. Not emulated |
| Medium: cycle and send-back logic has no live data (this repo has no issues; its 34 merged PRs close none) | Live run shows only zeros | Stub cases cover every rule; the first real check is on a project that uses the queue |
| Low: one bash `excluded()` call per distinct path is slow on huge windows | A run over ~10k distinct paths takes long | Accepted; the 14-day default keeps lists small |
| Low: a PR over the 300-line gate | `pr-size.sh main` reports over | One PR per phase; split a phase's tests from its code if needed |

## Out of scope
- Changes to `render-report.mjs`, and a JSON schema for metrics.
- Trends across reports, charts in the `.md`, and per-author metrics.
- Writing a report into this repo (the Phase 4 manual run is deleted).
- A behavior eval for `/devkit:report`.
- The version bump itself (`/release minor`).

## Red-team notes
Applied: split into four stacked PRs (both reviewers: ~290 lines for script + tests was not credible); keep `pr-size.sh` order and branch after the HEAD check instead of moving the config block (no-commits case dropped as out of scope); parity test compares the excluded set, not a count; trailing-NUL-safe reader; `here=` path resolution plus test copy for the stub `pr-size.sh` case; closing issues matched on repo + number; `capped` cycle reason for issues at 100 comments; search from `since − 1 day`; `:11` argument check named; 14-day default stated in `argument-hint` and the report header; live-data gap recorded as a risk.

Rejected:
- Drop `in_flight` (scope): it comes from the same fetch as `queue_depth` and costs one line; kept, with its one existing test case.
- Collapse the missing-cycle reasons into one count (scope): the request says "excluded and counted"; without reasons a team cannot tell "PRs close no issues" from "claims are missing", which is the first thing the report reader asks. Kept, one fixture case each.
- Drop or shrink the 1000-PR truncation case (scope): the builder generates it in a loop, so it is cheap; it is the only test of the truncation flag.

