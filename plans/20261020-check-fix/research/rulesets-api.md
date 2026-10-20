# Rulesets API for default-branch protection via `gh api`

## Conclusion
Create one repo ruleset (`POST repos/{o}/{r}/rulesets`) targeting `~DEFAULT_BRANCH` with `pull_request`, `non_fast_forward`, `deletion`. If a ruleset already exists, never blindly PUT: GET, merge rules by `type`, PUT the whole body (PUT replaces the rules array). Needs repo admin (Administration: write).

## Details
Docs: https://docs.github.com/en/rest/repos/rules

1. CREATE (required top-level: `name`, `enforcement`; `target` defaults to branch; `rules` array):
```bash
gh api -X POST repos/$O/$R/rulesets --input - <<'J'
{"name":"devkit: protect default branch","target":"branch","enforcement":"active",
 "bypass_actors":[],
 "conditions":{"ref_name":{"include":["~DEFAULT_BRANCH"],"exclude":[]}},
 "rules":[{"type":"deletion"},{"type":"non_fast_forward"},
  {"type":"pull_request","parameters":{"required_approving_review_count":0,
   "dismiss_stale_reviews_on_push":false,"require_code_owner_review":false,
   "require_last_push_approval":false,"required_review_thread_resolution":false}}]}
J
```
   - `~DEFAULT_BRANCH` and `~ALL` are documented special include values (rules page above).
   - pull_request params: the REST page lists all five booleans/int above as required (`required_approving_review_count` 0-10; count 0 is allowed, so PR is required but no approval). The page also mentions `dismissal_restriction` object; I did not confirm it is required - send the five and let a 422 tell you (UNVERIFIED by live call).
   - Bypass: with `bypass_actors: []` nobody bypasses, INCLUDING repo admins (admins are only exempt if listed, e.g. `{"actor_id":5,"actor_type":"RepositoryRole","bypass_mode":"always"}`; 5 = Admin role id - id from community knowledge, UNVERIFIED). Bypass doc: https://docs.github.com/en/repositories/configuring-branches-and-merges-in-your-repository/managing-rulesets/about-rulesets . Since the owner's release flow pushes `main` directly, either add the Admin role bypass with `bypass_mode: "pull_request"` (admin may merge PRs past rules but direct push still blocked? semantics UNVERIFIED) or `"always"` (direct push allowed). Decide with the owner; `always` is the one that keeps direct push working.
2. UPDATE: `gh api repos/$O/$R/rulesets/$ID` then `gh api -X PUT repos/$O/$R/rulesets/$ID --input body.json`. Only `name, target, enforcement, bypass_actors, conditions, rules` are modifiable; PUT replaces the whole `rules` list, so merge client-side. Build body with jq keeping only those six keys (drops `id, source, source_type, node_id, _links, created_at, updated_at, current_user_can_bypass`). Merge sketch: `.rules |= (map(select(.type!="non_fast_forward")) + [{"type":"non_fast_forward"}])`. Keep existing `pull_request` rule untouched if present (do not weaken it). Also GET returns rule objects possibly with `parameters`; send them back as-is.
3. LIST: `gh api "repos/$O/$R/rulesets?includes_parents=true"` (default true; also `targets=branch`). List items are summaries (no rules/conditions): fetch each `.../rulesets/{id}` for `conditions.ref_name.include` (looking for `~DEFAULT_BRANCH`, `~ALL`, or `refs/heads/<default>`) and `enforcement`. `source_type` is Repository | Organization | Enterprise (read-only); only `Repository` is editable here - skip/report others. Detail GET for org rulesets works through the repo path with the same endpoint (`repos/.../rulesets/{id}`); UNVERIFIED for non-admins. Also check `GET repos/$O/$R/rules/branches/$BRANCH` (effective rules on a branch, https://docs.github.com/en/rest/repos/rules#get-rules-for-a-branch) - cheap way to see if PR/non-FF already enforced from any source (not opened in detail).
4. Permissions: fine-grained token needs Administration: write for create/update/list/get rulesets (https://docs.github.com/en/rest/authentication/permissions-required-for-fine-grained-personal-access-tokens). Classic PAT: `repo` scope is expected to suffice when the user has admin (UNVERIFIED in docs read). UI/doc: admin or custom role "edit repository rules" can create/edit/delete; anyone with read can view (https://docs.github.com/en/repositories/configuring-branches-and-merges-in-your-repository/managing-rulesets/about-rulesets). Create documents 404 and 422 (no 403 listed); a non-admin typically gets 404 (hidden) or 403 - treat both as "no permission", UNVERIFIED which.
5. Branch protection (`PUT repos/{o}/{r}/branches/{b}/protection`, same Administration: write) replaces the whole protection object on PUT, is per branch name (does not follow a renamed default), and needs a full body with required nulls; rulesets are additive, layered (most restrictive wins), have `~DEFAULT_BRANCH`, and bypass lists. Availability: rulesets are on public repos for Free; private repos need Pro/Team/Enterprise Cloud (so a private repo on Free gets an error - likely 403/422 "upgrade", UNVERIFIED message). Classic protection has the same private-free limit (known, not re-verified). Plans source: https://docs.github.com/en/repositories/configuring-branches-and-merges-in-your-repository/managing-rulesets/about-rulesets
6. `gh label create` : `--force` "update the color and description if label already exists"; without it, creating an existing label errors (inferred, docs do not state it outright; the API returns 422 already_exists). https://cli.github.com/manual/gh_label_create . Idiom: always pass `--force`, which is idempotent.
7. Scopes: `gh issue/pr/label` need `repo` (classic) or Issues/Pull requests: write (fine-grained). Reading org rulesets: `read:org` probably not needed for repo-path reads (UNVERIFIED). `gh auth status --json hosts` exists in current gh (manual: https://cli.github.com/manual/gh_auth_status; exit code is 0 with --json), but I could not confirm it exposes a `scopes` field or the gh version that added it - UNVERIFIED. Reliable alternative: `gh api -i user | grep -i '^x-oauth-scopes:'` (classic/OAuth tokens only; fine-grained tokens return no such header, so then fall back to probing the endpoint). Plain `gh auth status` prints a "Token scopes: ..." line but its format is for humans and varies by version.

## Pitfalls
- Flipping to `enforcement: active` with empty bypass locks the owner out of direct pushes (also releases/tags if tags are not in scope - they are not, target is branch). Offer `evaluate` mode first? Evaluate is Enterprise-only (UNVERIFIED).
- Max 75 rulesets per repo; multiple rulesets layer, so a new ruleset never weakens an old one: prefer CREATE-new over editing a foreign ruleset when unsure.
- Idempotency: look up own ruleset by `name` before POST, else duplicates on re-run.
- API version header `X-GitHub-Api-Version` in docs is 2026-03-10; `gh api` works without it.

## Sources
- https://docs.github.com/en/rest/repos/rules
- https://docs.github.com/en/rest/authentication/permissions-required-for-fine-grained-personal-access-tokens
- https://docs.github.com/en/repositories/configuring-branches-and-merges-in-your-repository/managing-rulesets/about-rulesets
- https://docs.github.com/en/repositories/configuring-branches-and-merges-in-your-repository/managing-rulesets/creating-rulesets-for-a-repository
- https://cli.github.com/manual/gh_label_create
- https://cli.github.com/manual/gh_auth_status
