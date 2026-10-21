# P-46 findings: where squad task state lives

Evidence: `live-probe.md` (personal private throwaway repo, writes; org, read-only), `schema-probe.txt` (read-only GraphQL introspection and `gh --help`), and the three docs reports (`sub-issues.md`, `dependencies.md`, `types-and-fields.md`). Run on 2026-10-21 with gh 2.102.0.

## Verdict

**Native works.** All three criteria fixed in the plan hold on a personal private repo, through `gh` alone:

- (a) Epic → task tree. Written with `gh issue create --parent` and `gh issue edit --add-sub-issue`, three levels deep, and read back from one `gh issue list --json number,parent,subIssuesSummary` call (W2, W3). GitHub rejects sub-issue loops (W3).
- (b) "Blocked by" edges. Written with `gh issue edit --add-blocked-by` and read back with `gh issue view --json blockedBy,blocking`. Each blocker node carries its current `state` at once, so "ready = open and every blocker CLOSED" can be computed (W5, W6).
- (c) No Projects board is involved. The tree was read from one `gh issue list --json` call and blockers from `gh issue view --json`; `gh issue list --json blockedBy` also returns `{nodes, totalCount}` (checked read-only on a public repo, shape only).

So GitHub issues stay the single source of truth for squad task state. Per-task values that issues cannot hold natively on personal repos fall back to labels or one machine-readable comment, which the criteria allow.

## Store per need

| Need | Personal repo store | Org repo store | Evidence |
| --- | --- | --- | --- |
| Epic → task | Sub-issues: `gh issue create --parent <epic>`; read `parent`, `subIssues {nodes, totalCount}`, `subIssuesSummary` | Same (docs; not live-verified on an org repo) | W2, W3; `schema-probe.txt` (`--parent`, `--add-sub-issue`, `issue list --json parent,subIssues`) |
| Waves / depends on | Issue dependencies: `gh issue edit <task> --add-blocked-by <dep>`; read `blockedBy {nodes{number,state}}` | Same (docs; not live-verified on an org repo) | W5, W6 |
| Size (XS/S/M) | Label `size:XS\|S\|M` | Label, or the org `Effort` field once an admin adds XS/S/M options (today it has High/Medium/Low) | W7; Org read-only |
| Complexity | Label `complexity:<level>` | Label; no number or text org field exists, so an admin would need to add one | W7; Org read-only |
| Attempts | Machine-readable comment (one line per attempt, like the claim comments), counted on read | Same; an org number field would need an admin | W7; Org read-only |
| Expected files | Machine-readable comment in the task body or a comment (a list of paths) | Same | W7 (no field store on personal repos) |
| Serial flag | Label `serial` | Same | W7 |
| Kind | Label `bug` / `enhancement` (current conventions) | Issue types `Task` / `Bug` / `Feature` are defined (setting one is out of scope); a label stays as the shared fallback | W7; Org read-only |
| Claim / in progress | Label `in-progress` plus claim and release comments (unchanged) | Same | conventions "GitHub issue queue" |
| Agent result | Comment with the P-39 JSON line | Same | P-39 proposal |

Labels and comments work the same on both kinds of repo, so the design does not depend on org-only features; org issue types and fields are optional upgrades, never required. Org repos are out of scope (user decision, 2026-10-21).

## Projects board

Not needed as a store. A Projects board may be added later as an optional one-way view that devkit writes and never reads. Writing to it needs the `project` scope, which the current token does not have (`schema-probe.txt`), so it stays out of scope until someone asks for a board. Relink is not needed, because nothing reads from a board; the "Board relink" item stays skipped.

## Must handle in P-41/P-42

- **Detect dependency cycles.** GitHub accepted the cycle B → T1 → T2 → B (W5); it rejects only a self-edge and sub-issue loops. The wave computation must find cycles itself and stop with a clear message.
- **Read readiness from node states.** Right after a blocker closes, the `blockedBy` nodes already show `CLOSED`, but `issueDependenciesSummary`, `subIssuesSummary`, and `is:blocked` search lag by seconds (W6). Compute "ready" from `blockedBy.nodes[].state`, never from summaries or search.
- **Filter closed blockers.** `blockedBy` keeps closed blockers in the list (W6); a task is ready when every listed blocker is `CLOSED`.
- **Use exact search syntax when searching.** Only full `owner/repo#n` refs and the singular `has:sub-issue` / `no:sub-issue` work; a bare number or the plural form silently returns nothing or everything (S1). Prefer `gh issue list --json` reads over search.
- **Parse the JSON shapes.** In `gh issue view --json`, `subIssues`, `blockedBy`, and `blocking` are objects `{nodes: [...], totalCount}`, not arrays (W3, W5).
- **Closing an epic does not touch its tasks.** GitHub allows closing a parent with open children and leaves them open (W6). `/devkit:run` must not treat a closed epic as finished work.
- **Never query `issueFieldValues` on a personal repo.** It returns a server error rather than null (W7). Guard on the repo owner type (`Organization` vs `User`); `viewerCanSetFields` only reports the viewer's permission.
- **Permissions.** Writing dependencies needs triage permission or higher (`dependencies.md`); a teammate's or an Actions token must have it.
- **Truncated lists.** Compare `blockedBy.nodes` length with `totalCount` before calling a task ready; how `gh` pages long lists is unverified.
- **REST ids.** The REST sub-issue endpoints take the issue's database `.id`, not its number (W4); `gh issue edit` flags take numbers.
- **Limits, from docs (not brute-forced):** 100 sub-issues per parent and 8 nesting levels (`sub-issues.md`); 50 dependencies per relationship type (`dependencies.md`). A plan with more tasks than that must split epics.

## Unverified

- **Org repos: out of scope** (user decision, 2026-10-21: no org connection needed). The design uses only features proven on a personal repo (sub-issues, dependencies, labels, comments); org issue types and fields stay optional and untested. Only the org's type and field definitions were read, before this decision.
- **Cross-repo links.** Sub-issues and dependencies between two repos of the same owner were not tried; squad tasks live in one repo.
- **Limits.** The 100 / 8 / 50 caps come from docs only.
- **Behavior after GA.** Cycle acceptance, search qualifiers, and summary lag were observed on 2026-10-21; P-41 and P-42 should re-check them before relying on them.
- **`GITHUB_TOKEN` in Actions.** Only a user token was used.
