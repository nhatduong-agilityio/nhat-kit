# GitHub sub-issues research (P-46)

Pre-probe desk notes; outcomes are in `findings.md` and `live-probe.md`.

Researched 2026-10-21. Official sources only. "unverified" = docs silent or I only saw a summarized fetch. I could not run `gh` here, so nothing was tested live.

## Conclusion
Sub-issues are GA (since 2025-04-09) with REST, GraphQL and `gh` (>= 2.94.0, 2026-06-10) support. The epic -> task tree can live natively on issues. The docs state a 100-sub-issues-per-parent limit, 8 nesting levels, and cross-repo links (REST: same owner only). Plan/private-repo availability is not stated in any page I opened (unverified).

## 1. Availability
- GA 2025-04-09 (sub-issues, issue types, advanced search, project limit 50k): https://github.blog/changelog/2025-04-09-evolving-github-issues-and-projects/
- The changelog does not mention plans or repo visibility. The "Adding sub-issues" page has no preview/beta label and no plan restriction (unverified for free plan, personal-account repos, private repos): https://docs.github.com/en/issues/tracking-your-work-with-issues/using-issues/adding-sub-issues
- Issue *types* need org-level config, so personal repos get no types (source: gh 2.94 write-up https://dev.classmethod.jp/en/articles/github-cli-294-issue-types-sub-issues/, third party). Sub-issues themselves are not tied to types.
- GHES: sub-issues need 3.17+; dependencies 3.19+ (same third-party article).

## 2. Operation table

| Operation | REST (`/repos/{owner}/{repo}/issues/{n}/...`) | GraphQL | gh (>= 2.94.0) |
|---|---|---|---|
| Create task under epic | create issue, then POST add | createIssue + addSubIssue | `gh issue create --parent <num\|URL>` |
| Add existing | POST `/sub_issues` body `sub_issue_id` (required), `replace_parent` (opt) | `addSubIssue(input:{issueId, subIssueId or subIssueUrl, replaceParent})` -> `issue`, `subIssue` | `gh issue edit <parent> --add-sub-issue <nums>`; or `gh issue edit <child> --parent <n>` |
| Remove | DELETE `/sub_issue` (singular) body `sub_issue_id` | `removeSubIssue(input:{issueId, subIssueId})` | `--remove-sub-issue <n>` / `--remove-parent` |
| List children | GET `/sub_issues` (`per_page`, `page`) | `Issue.subIssues` (IssueConnection) | `gh issue view N --json subIssues` |
| Get parent | GET `/parent` | `Issue.parent` | `--json parent` |
| Reorder | PATCH `/sub_issues/priority` body `sub_issue_id` + `after_id` xor `before_id` | `reprioritizeSubIssue(input:{issueId, subIssueId, afterId/beforeId})` | none seen (use api) |
| Progress | none seen | `Issue.subIssuesSummary { total completed percentCompleted }` | `--json subIssuesSummary` |

Sources: REST https://docs.github.com/en/rest/issues/sub-issues ; GraphQL https://docs.github.com/en/graphql/reference/issues (addSubIssue, removeSubIssue, reprioritizeSubIssue, SubIssuesSummary fields all listed); gh https://cli.github.com/manual/gh_issue_create and https://cli.github.com/manual/gh_issue_edit ; gh JSON fields https://github.blog/changelog/2026-06-10-manage-sub-issues-types-and-dependencies-from-github-cli/ and the classmethod article.

## 3. REST details
- `sub_issue_id` is described as "the ID of the sub-issue" (integer body field), not the issue number. Take it from the `id` field of an issue response, e.g. `gh api repos/O/R/issues/12 --jq .id`. The docs wording is terse; confirm live. Pass it with `-F` (typed int), not `-f`.
- Path `{issue_number}` is the parent's number (for `/parent`, the child's).
- Add: 201, 403, 404, 410, 422. Remove: 200, 400, 403, 404. Reprioritize: 200, 403, 404, 422, 503. Add says the sub-issue must belong to the same repo owner as the parent.
- Token permission per endpoint: not stated on the reference page (unverified). Expect Issues write for mutating calls; plain `repo` scope or Issues:write on a fine-grained PAT is the likely need.
- REST added 2024-12-12 (changelog: https://github.blog/changelog/2024-12-12-github-issues-projects-close-issue-as-a-duplicate-rest-api-for-sub-issues-and-more/), before GA.

## 4. GraphQL
- No preview header is mentioned anywhere I read. The old `GraphQL-Features: sub_issues` header is not in current docs (unverified whether still needed or accepted; gh 2.94 does not document using it).
- Mutation inputs are as in the table. Exact `ReprioritizeSubIssueInput` nullability of afterId/beforeId: unverified.

## 5. Limits
- 100 sub-issues per parent; 8 levels of nesting (adding-sub-issues page above; also in the GA changelog summary).
- Cross-repo: the UI allows picking a repo; REST says same owner only. Cross-owner not possible via REST (unverified for GraphQL).

## 6. List/search
- `gh issue list --json` and `gh issue view --json` expose `parent`, `subIssues`, `subIssuesSummary`, `blockedBy`, `blocking`, `issueType` as of 2.94.0 (changelog + classmethod). The manual page for `gh issue list` (https://cli.github.com/manual/gh_issue_list) names only blockedBy/blocking in its summarized fetch; whether `parent`/`subIssues` are in the `list` field set is unverified, so run `gh issue list --json` with no fields to see the list.
- Qualifier `parent-issue:OWNER/REPO#N` is documented for Projects views: https://docs.github.com/en/issues/planning-and-tracking-with-projects/customizing-views-in-your-project/filtering-projects . `no:parent-issue` and `has:sub-issue` appear in search-result snippets of GitHub docs but I did not open a page with them; the issue-search pages I opened do not list any. Treat all as unverified for `gh issue list --search` / REST search.

## Discrepancy
The 2.94.0 changelog mentions `--set-parent`; the CLI manual shows `--parent` (both create and edit). Use `gh issue edit --help` live.

## Verify live before planning
1. `gh --version` >= 2.94.0 and that `gh issue edit N --parent P` works in the repo.
2. Free plan, private repo and personal-account repo: create a parent and child, add and remove through REST and gh.
3. `sub_issue_id` is `.id` not `.number`; token permission needed (fine-grained vs `GITHUB_TOKEN` in Actions).
4. `gh issue list --json parent,subIssues,subIssuesSummary` works and the output shape (parent is null for roots? subIssues paging limits?).
5. Search qualifiers `parent-issue:`, `no:parent-issue`, `has:sub-issue` in `gh issue list --search`.
6. GraphQL calls work without `GraphQL-Features` header.
7. Behavior when closing a parent with open children, and whether closing the last child auto-updates `subIssuesSummary`.
8. Cross-repo parent/child inside one owner; the 100/8 limits are what the docs say.
