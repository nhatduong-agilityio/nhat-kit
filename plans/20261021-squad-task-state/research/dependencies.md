# GitHub issue dependencies ("blocked by" / "blocking") - research for P-46

Pre-probe desk notes; outcomes are in `findings.md` and `live-probe.md`.

Researched 2026-10-21 from official sources only. "unverified" = docs silent or fetch summary unclear.

## Conclusion
Issue dependencies are GA (since 2025-08-21) with full REST, GraphQL, search and gh support (gh >= 2.94.0, 2026-06). A squad can read edges with `gh issue view --json blockedBy,blocking` or REST/GraphQL, and write them with `gh issue edit --add-blocked-by`. Cross-repo, cycle handling and `gh issue list --json` field names are not documented and must be checked live.

## 1. Availability
- GA announced 2025-08-21; up to 50 issues per relationship type; needs triage permission or higher; Free, Pro, Team and Enterprise Cloud plans. Source: https://github.blog/changelog/2025-08-21-dependencies-on-issues/ (plan and permission sentence came via search snippet of the same changelog; the page fetch itself did not restate plans: treat plan/private-repo/personal-vs-org as unverified).
- No preview header on GraphQL or REST (no preview notice in schema docs). Source: https://docs.github.com/en/graphql/reference/issues
- GHES: relationships need GHES 3.19+ (gh release note). Source: https://github.com/cli/cli/releases/tag/v2.94.0
- Personal vs org repos, private repos: docs silent -> unverified.

## 2. Operation table

| Operation | REST | GraphQL | gh (>= 2.94.0) |
|---|---|---|---|
| List what blocks X | `GET /repos/{o}/{r}/issues/{n}/dependencies/blocked_by` | `Issue.blockedBy(first, after, orderBy: IssueDependencyOrder)` | `gh issue view N --json blockedBy` |
| List what X blocks | `GET .../issues/{n}/dependencies/blocking` | `Issue.blocking(...)` | `gh issue view N --json blocking` |
| Counts only | `issue_dependencies_summary` {blocked_by, blocking, total_blocked_by, total_blocking} on every issue object | `Issue.issueDependenciesSummary { blockedBy blocking totalBlockedBy totalBlocking }` | unverified as a JSON field |
| Add "N blocked by M" | `POST .../issues/{n}/dependencies/blocked_by` body `{"issue_id": <M database id>}` -> 201 | `addBlockedBy(input:{issueId: N node id, blockingIssueId: M node id})` | `gh issue edit N --add-blocked-by M` (or `gh issue create --blocked-by M`) |
| Add "N blocking M" | POST on M's blocked_by with N's id | addBlockedBy with swapped ids | `gh issue edit N --add-blocking M` |
| Remove | `DELETE .../issues/{n}/dependencies/blocked_by/{issue_id}` -> 200 | `removeBlockedBy(input:{issueId, blockingIssueId})` | `--remove-blocked-by M` / `--remove-blocking M` |

Sources: REST https://docs.github.com/en/rest/issues/issue-dependencies ; GraphQL https://docs.github.com/en/graphql/reference/issues ; REST summary fields https://docs.github.com/en/rest/issues/issues ; gh https://cli.github.com/manual/gh_issue_edit , https://cli.github.com/manual/gh_issue_create , https://cli.github.com/manual/gh_issue_view

REST details:
- POST body takes `issue_id` (the numeric database id of the blocking issue, NOT the issue number). Get it from `gh api repos/o/r/issues/M --jq .id`. The path `{issue_number}` is the blocked issue. Source: REST page above.
- DELETE path takes `issue_id` too.
- List endpoints: `per_page` default 30, max 100, `page`. Status codes: POST 201/403/404/410/422; DELETE 200/400/401/403/404/410.
- Header `X-GitHub-Api-Version: 2026-03-10` shown on the page; POST/DELETE may hit secondary rate limits if fired rapidly.
- Exact permission text per endpoint was not in the fetch -> unverified (changelog says triage+).

GraphQL details:
- `Issue.issueDependenciesSummary.blockedBy` / `blocking` count OPEN issues only; `totalBlockedBy` / `totalBlocking` include closed. This matters for waves: a closed blocker still appears in the list, so filter on `state`.
- `IssueDependencyOrder` fields: CREATED_AT, DEPENDENCY_ADDED_AT.
- Mutation returns `issue` and `blockingIssue`.

## 3. gh CLI
- Added in v2.94.0 (June 2026): `--blocked-by`, `--blocking` on create; `--add-/--remove-blocked-by` and `--add-/--remove-blocking` on edit; `gh issue view` shows "Blocked by"/"Blocking" rows. Sources: https://github.blog/changelog/2026-06-10-manage-sub-issues-types-and-dependencies-from-github-cli/ , https://docs.github.com/en/issues/tracking-your-work-with-issues/using-issues/creating-issue-dependencies
- Flags accept numbers (comma-separated) or URLs; manual says cross-repo is supported via URL (wording vague: unverified).
- `gh issue view --json` fields include `blockedBy`, `blocking`, `parent`, `subIssues`, `subIssuesSummary`. Inner object shape unverified.
- Changelog says `gh issue list` also exposes these as JSON fields, but the `gh issue list` manual page fetch did not list them -> unverified. Fallback: `gh api graphql`.
- Docs inconsistency: docs.github.com text uses `--blocked-by` for edit, cli manual shows `--add-blocked-by`; the manual is authoritative, check `gh issue edit --help` live.

## 4. Limits and behaviour
- Max 50 per relationship type per issue (changelog above). Per-direction wording: assume per issue, per type.
- Cross-repo: unverified (GraphQL takes node ids, which suggests it can work, but no doc states it).
- Cycle detection: NOT documented anywhere I found. The 422 on POST is the likely rejection path but unverified. Squad must detect cycles itself.

## 5. Search
- Filters `is:blocked`, `is:blocking`, `blocked-by:`, `blocking:` (changelog above). Usable as `gh issue list --search "is:blocked"` (search string passes through; inference, verify live). `is:blocked` presumably means has open blockers: unverified.

## Facts a plan must verify live
1. `gh --version` >= 2.94.0 and `gh issue edit N --add-blocked-by M` works on a private repo owned by the user and on an org repo.
2. Which JSON fields `gh issue list --json` accepts (`blockedBy`? summary?); shape of `blockedBy[]` entries (number, state, repository?).
3. Whether adding a cycle (A->B, B->A) and a self-dependency is rejected, and with what status/message.
4. Cross-repo edge creation and the 50-limit error response.
5. Whether closed blockers remain in `blockedBy` (docs imply yes) and whether `is:blocked` ignores them.
6. Token scopes needed for POST/DELETE (default `gh auth` repo scope vs fine-grained "Issues: write").
7. Exact semantics of `issue_id` (database id vs node id) via a real POST.
