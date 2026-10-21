# P-46 research: issue types, issue fields, Projects fields (as of 2026-10-21)

Pre-probe desk notes; outcomes are in `findings.md` and `live-probe.md`.

## Conclusion
Native per-task values are now possible on ORG repos: issue types (one per issue, GA 2025-04-09) and issue fields (typed: single select, text, number, date; GA 2026-07-02), both org-scoped and readable/writable by REST. Neither exists on personal-account repos (types: stated by a secondary source; fields: docs say org-level only), so labels (or a machine-readable comment) remain the only store that works on both. `gh issue list --json` exposes `issueType` but NOT issue-field values (use `gh api`).

## Details
**1. Issue types**
- Org-only; up to 25 types; defaults task/bug/feature; set in org settings. Source: https://docs.github.com/en/issues/tracking-your-work-with-issues/using-issues/managing-issue-types-in-an-organization
- GA 2025-04-09 (preview Jan 2025): https://github.blog/changelog/2025-04-09-evolving-github-issues-and-projects/
- Not shown on personal-account repos: Simon Willison write-up of the preview (secondary, https://simonwillison.net/2025/Jan/16/evolving-github-issues/). Official docs say "org only". Live-verify.
- REST: `type` (name string or null) on create/update issue; response has `type` object. Needs push access, else silently dropped. https://docs.github.com/en/rest/issues/issues#create-an-issue
- REST org types CRUD `/orgs/{org}/issue-types`; read needs `read:org`, write needs `admin:org` + org admin. No repo-level list endpoint documented. https://docs.github.com/en/rest/orgs/issue-types
- gh >= 2.94.0 (2026-06-10): `--type` on `gh issue create/edit/list`; `--json issueType,parent,subIssues,blockedBy,blocking` on list/view; `--parent`, `--blocked-by`, `--blocking` flags. https://github.blog/changelog/2026-06-10-manage-sub-issues-types-and-dependencies-from-github-cli/ ; https://cli.github.com/manual/gh_issue_list ; https://cli.github.com/manual/gh_issue_create
- GraphQL mutation names for setting type (e.g. `updateIssueIssueType`): unverified; docs index pages did not list them. Not needed if REST/gh are used.

**2. Issue fields (not Projects fields)**
- Org-level fields, shown on every issue in every org repo. Public preview 2026-03-12, all orgs 2026-05-21, GA 2026-07-02 on Free/Team/Enterprise plans. https://github.blog/changelog/2026-07-02-issue-fields-are-now-generally-available ; https://github.blog/changelog/2026-05-21-issue-fields-are-now-in-public-preview-for-all-organizations/
- Types: single select (100 options max), text, number, date; max 25 fields per org; 10 pinned per issue type; defaults Priority, Effort, Start date, Target date; admin sets up in Settings > Planning > Issue fields. https://docs.github.com/en/issues/tracking-your-work-with-issues/using-issues/managing-issue-fields-in-your-organization
- Org-only ("Issue fields only apply to issues owned by the same organization"): https://docs.github.com/en/issues/planning-and-tracking-with-projects/understanding-fields/about-issue-fields . Personal-repo support: not mentioned anywhere, treat as unavailable.
- REST values: `GET|POST|PUT /repos/{o}/{r}/issues/{n}/issue-field-values`, `DELETE .../{issue_field_id}`; push access required. https://docs.github.com/en/rest/issues/issue-field-values . Also `issue_field_values: [{field_id, value}]` on create/update issue (org repos). Field defs: `GET /orgs/{org}/issue-fields` (`read:org`; write `admin:org`); API version header `2026-03-10`. https://docs.github.com/en/rest/orgs/issue-fields
- gh: no flag or `--json` field for issue fields in the 24 fields of `gh issue list` (https://cli.github.com/manual/gh_issue_list). Use `gh api`. GraphQL support is stated in the changelog but names unverified.

**3. Projects v2 fields (fallback)**
- GraphQL is the primary API; no REST for projects documented in the guide. Scopes: `read:project` (query), `project` (mutate). Single-select/text/number/date/iteration set by `updateProjectV2ItemFieldValue`. https://docs.github.com/en/issues/planning-and-tracking-with-projects/automating-your-project/using-the-api-to-manage-projects
- `gh project item-edit`: `--text/--number/--date/--value/--clear`; for non-draft issues only ONE field per call. https://cli.github.com/manual/gh_project_item-edit . Needs `gh auth refresh -s project` (https://cli.github.com/manual/gh_issue_create).
- `gh project item-list --limit` defaults to 30 (https://cli.github.com/manual/gh_project_item-list): a plain call silently truncates, the likely root of the "dropped items / relink" problem. Project cap is 50,000 items (raised from 1,200 on 2025-04-09, same changelog as above); 10,000 archived (secondary: search result for docs.github.com archiving page, unverified).
- Project field list also capped at 50 fields (incl. system + issue fields): about-issue-fields page above.

**4. Comparison**
| Store | Personal repo | Org repo | `gh issue list --json` | Write needs |
| --- | --- | --- | --- | --- |
| Labels | yes | yes | `labels` | push/triage; no extra scope (kit uses it today) |
| Issue types | no (unverified live) | yes, admin must define types | `issueType` (gh >= 2.94) | push; type name must exist |
| Issue fields | no (unverified live) | yes, admin must define fields | no; `gh api .../issue-field-values` | push; field ids from `read:org` |
| Projects fields | yes (user projects) | yes | no; use `gh project item-list --format json` | `project` scope |
| Comment with JSON | yes | yes | `comments` (body parsing) | comment rights; no scope |

## Pitfalls
- Types/fields need an org admin one-time setup; kit cannot create them without `admin:org`.
- Silent drop: type/fields/labels from a user without push access are ignored without error; read back after write.
- A kit that must work on personal repos needs a label/comment path anyway, so two code paths unless labels are used for both.
- Labels cannot hold numbers cleanly (`size:S`, `attempts:2` multiplies labels); comment JSON or issue fields are better for counters.
- Projects: set fields one call at a time; paginate item lists explicitly.

## Must verify live
1. Org Agility-Vietnam (read-only): `gh api orgs/Agility-Vietnam/issue-types` and `.../issue-fields` (do types/fields exist? Which plan? token has `read:org`?); `gh issue list -R <repo> --json issueType`; `gh --version` >= 2.94.0.
2. Personal throwaway repo (write): does `type` in create issue get dropped? does `issue-field-values` return 404/422? does `gh issue list --json issueType` work? Do `parent`, `blockedBy` work on personal repos (sub-issues/dependencies) ?
3. Whether `gh api graphql` can read issue-field values on an issue (schema names).
4. Does a project-less path suffice: `gh project item-list --limit 1000` returns all items in a small test project.

## Sources
All URLs above were opened (docs.github.com, github.blog changelog, cli.github.com manual), except the Simon Willison and archiving-page claims, which came from search snippets.
