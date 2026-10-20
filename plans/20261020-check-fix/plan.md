# Team checks in /devkit:check, fixes in /devkit:check-fix
Status: in-progress · Source: P-32 in `upstream/proposals/20261018.md` (v2.6.0, "Approvals and shared queue") · Mode: standard
Approved: 2026-10-20 by nhatduong-agilityio

## Goal
- `/devkit:check` stays read-only. It gains three Layer 4 team rows: gh login and token scopes, the queue labels, and leftover worktrees. The existing "Default branch protection" row now points to `/devkit:check-fix`.
- A new skill, `/devkit:check-fix` (typed by the user only), runs the same checks and lists the fixes. It applies the safe fixes (create the missing queue labels, `git worktree prune`) after one explicit yes. Each destructive fix needs its own yes: create or extend devkit's default-branch ruleset (admins only), or remove one merged worktree. Fixes it cannot make (login, scopes, no admin rights) are printed as commands or steps for the user. Then it re-runs the checks and shows the result before and after.
- No state is written on the machine. Labels and rulesets live in GitHub, and the outcome is reported in the reply.
- It ships as three stacked PRs, each usable on its own: A = login, labels, and a minimal `check-fix`; B = worktrees; C = the ruleset fix and the final docs.

## Context found
- `docs/devkit.md:9,13,17`: the PR gate in this repo is 300 lines and 25 files, tests included. `plans/**` is excluded, so this plan does not count.
- `plugins/devkit/skills/check/SKILL.md`:
  - `:5`: `allowed-tools` is read-only.
  - `:10`: the statuses are OK / Missing / Needs fix / Unknown / Not checked.
  - `:30-33`: Layer 4. `:33` is the branch-protection row, and it says "there is no `--fix` yet".
  - `:35`: the recommended actions.
- `plugins/devkit/scripts/branch-protection.sh`. This is the pattern for every new script:
  - `:2-7`: the header.
  - `:9-13`: `command -v` and `ghq()`.
  - `:28-32`: `gh api` with `{owner}/{repo}` placeholders. A failed call becomes `unknown`, not `false`.
  - `:35-82`: JSON is parsed by `python3 -I`, and `:52` strips control characters from output.
  - It prints `pr_required=` and `force_push_blocked=`, which `check-fix` uses to decide whether to offer a ruleset.
- `plugins/devkit/scripts/queue-status.sh:1-7,30`: one more example of the header, `ghq`, and `key=value` output.
- `plugins/devkit/skills/task/SKILL.md:6`: access is granted per script (`Bash(bash */queue-status.sh *)`), never as `Bash(gh *)`.
- `plugins/devkit/references/conventions.md`:
  - `:118-130` "GitHub issue queue": the labels, their colors and meanings, and "Create a missing label once, after the user confirms … Never rename or delete existing labels".
  - `:64-69` Approval: only an explicit yes counts.
- `scripts/test-hooks.sh`. New tests follow these:
  - `:17`: `expect`. `:191`: `row`.
  - `:331-337`: `pgit`, and `mkrepo` with `main` + `feat`.
  - `:476-481`: worktrees in temp repos.
  - `:585-667`: the branch-protection stub `gh` chosen by `BP_CASE`, with a stub-contract comment, a check that rejects `--jq`, `bpck`, and the "gh missing" case. That block is about 80 lines for one script, which is the basis for the test estimates below.
- `.claude/skills/release/SKILL.md:20`: this repo's `/release` pushes `main` directly. The live ruleset `kit` (id 25369692, repository source, `~DEFAULT_BRANCH`, `deletion` + `non_fast_forward`, `bypass_actors: []`) is the reason the ruleset fix asks about an Admin bypass.
- `plans/20261020-check-fix/research/rulesets-api.md`:
  - `:9-18`: the POST body.
  - `:24`: PUT replaces `rules`, so the six editable keys are merged on our side.
  - `:25`: `source_type` decides what is editable, and `includes_parents=true` lists organization rulesets too.
  - `:26-27`: admin is needed. The non-admin and Free-plan error shapes are unverified.
  - `:23`, and the docs re-read on 2026-10-20: the docs do not give the Admin role actor id, so `5` is unverified.
- Red-team facts used here: gh 2.102 `gh auth status --json hosts` has a `scopes` field. `git worktree remove` without `--force` exits 0 and deletes ignored files. On a new branch with no commits, `git merge-base --is-ancestor` succeeds.
- Docs to update:
  - `README.md:27` (the `/devkit:check` row) and `:30` (the "only when you type them" list).
  - `UPSTREAM.md:138` (⏳ P-32).
  - `CHANGELOG.md:5-9` (`[Unreleased]` / `### Added`).
  - `upstream/proposals/20261018.md:85,91,94`. `:85` carries the uncommitted P-44 "PRs #30, #31" edit.

## Approach
- **Plain-bash scripts, granted by name.** Reads and writes stay in separate scripts, so `check` can never reach a write. Every script follows `branch-protection.sh`: a header, `command -v`, `ghq()`, and `python3 -I` for JSON and path handling. Output is `key=value` with control characters stripped. Each script exits 0 when it reported something and 1 when a tool is missing or the output is unexpected.
  - **`scripts/team-status.sh` (read-only, gh).** The six queue labels and their colors and meanings are hard-coded in this script, and only here. A comment points to conventions "GitHub issue queue". It prints three lines:
    - `auth=ok|none login=<l>|- scopes=<csv>|unknown missing_scopes=repo|-|unknown`. All of it comes from `gh auth status --json hosts`: the active entry for `github.com`, or for `$GH_HOST`. An empty or absent `scopes` field (for example a fine-grained token) gives `unknown`, never "missing". Only `repo` is required.
    - `repo=<owner/name> visibility=<…> permission=ADMIN|MAINTAIN|WRITE|TRIAGE|READ|unknown`, from `gh repo view --json nameWithOwner,visibility,viewerPermission`.
    - `labels_missing=<csv>|-|unknown`, from `gh label list --limit 500 --json name`.
    - With `auth=none`, the other two lines print `unknown`.
    - `team-status.sh --missing-labels` prints one `name<TAB>color<TAB>description` row per missing label and nothing else. `team-fix.sh labels` reads it, so the table has one home.
  - **`scripts/worktree-status.sh` (read-only, git, plus optional gh).**
    - Parsing: it reads `git worktree list --porcelain -z`. It skips the main worktree. Paths are compared after `realpath` normalization (macOS `/tmp` vs `/private/tmp`).
    - Header line: `worktrees=N prunable=N merged=N kept=N gh=ok|unavailable`.
    - One row per extra worktree: `<state>\t<branch|->\t<ignored_count>\t<ignored_top_names csv|->\t<path>`.
    - It then prints `prune_preview\t<line>`, one row per output line of `git worktree prune -n -v` (read-only). This preview goes into the safe-fix question, because a prune also drops the metadata of worktrees on unmounted drives.
    - There are three states only:
      - `prunable`: git marks it `prunable`.
      - `merged`: all of these hold:
        - `gh pr list --state merged --head <branch> --json headRefOid` returns a PR whose `headRefOid` equals the local tip.
        - `git -C <wt> status --porcelain` is empty, so there are no tracked changes and no untracked, non-ignored files.
        - It is not locked, not detached, and not the worktree the script runs in.
      - `kept`: everything else. This includes gh being missing or failing, a path with control characters (printed sanitized), and a new branch with no commits (no merged PR has its tip).
    - The ignored count comes from `git -C <wt> ls-files -o -i --exclude-standard --directory`: the number of entries, plus up to five top-level names.
    - It never fetches and never uses an ancestor test.
  - **`scripts/team-fix.sh <action>` (the only script that writes).** Each line starts `action=<a> result=<r>`. Each action checks its preconditions again itself. Nothing uses `--force`. Every known outcome, refusals included, exits 0. A gh write error becomes `result=failed detail=<gh stderr, first line, control chars stripped, at most 200 chars>`.
    - `labels`:
      - It runs `team-status.sh --missing-labels` and creates only those labels, with `gh label create <name> --color <hex> --description "<meaning>"`.
      - It prints one line per label: `label=<n> result=created|failed detail=…`. A label that already exists (a race) is a `failed` line with gh's message.
      - When none are missing, it prints `result=none_missing`.
    - `prune`: `git worktree prune -v`, then `result=done pruned=N`.
    - `remove-worktree <path>`. The checks:
      - It refuses a path with control characters (`refused reason=unsafe_path`).
      - It realpath-normalizes the argument, re-runs `worktree-status.sh`, and proceeds only when that path's row is `merged`. Otherwise it prints `refused reason=<state>|not_a_worktree`.
      - It refuses the worktree it runs in (`refused reason=current`).
      - Then it runs `git worktree remove -- "$path"` and prints `result=removed path=<p> branch_kept=<b>`. The branch is never deleted.
    - `ruleset [--admin-bypass] [--dry-run]` is described below. It is the only action with `--dry-run`. For the other actions, the status scripts are the preview.
- **Ruleset fix: create or extend devkit's own ruleset only, and only for admins.** The ruleset is named `devkit: protect default branch`. It has target `branch`, include `~DEFAULT_BRANCH`, enforcement `active`, and the rules `pull_request` (the five required parameters, 0 approvals) and `non_fast_forward`.
  - Precondition: `gh repo view --json viewerPermission` must be `ADMIN`. Otherwise the action prints `result=refused reason=not_admin`. The skill makes the offer only on ADMIN and gives non-admins the manual steps.
  - Reading:
    - It lists `rulesets?includes_parents=true&targets=branch`.
    - It reports the other rulesets (`others=<names>|-`), so organization rulesets are visible.
    - Only entries with `source_type == "Repository"` and devkit's exact name are candidates for an edit.
  - Then:
    - More than one candidate → `result=ambiguous`, and nothing is written.
    - One candidate:
      - It GETs the ruleset.
      - `enforcement` is `disabled` or `evaluate` → `result=disabled`, and the ruleset is left alone, because someone set that on purpose.
      - It adds the missing rule types and keeps the existing rule objects and their `parameters` as they are.
      - With `--admin-bypass`, it adds `{"actor_id":5,"actor_type":"RepositoryRole","bypass_mode":"always"}` when that entry is absent. It never removes an actor.
      - Nothing to add → `result=unchanged`.
      - Otherwise it PUTs a body built from the six editable keys only, then reads the ruleset back. If the rules read back differ from what was sent → `result=conflict` (a lost update), and it does not retry.
    - No candidate: it POSTs a new ruleset. On a 422, it lists again:
      - Its own ruleset now exists → `result=existed`.
      - Else, with `--admin-bypass` → `result=bypass_rejected`.
      - Else → `result=failed detail=…`.
    - A 422 on a PUT with `--admin-bypass` also gives `bypass_rejected`.
  - After a successful write, it GETs the ruleset again and prints `bypass=verified` when `current_user_can_bypass` is `always`. Otherwise it prints `bypass=unverified` (or `bypass=none` when no bypass was asked).
  - Output line: `action=ruleset result=<…> rules_added=<csv>|- bypass=<…> others=<…> [detail=…]`.
  - `--dry-run` only reads. It prints `result=would_create|would_update|unchanged|disabled|ambiguous|refused` with the same keys. The skill shows that line inside the ruleset question.
- **`/devkit:check` rows (Layer 4, "Team" items).**
  - "gh login & scopes": Missing when `auth=none`. Needs fix when `repo` is missing. Unknown when the scopes are unknown.
  - "Queue labels": Missing, with the names.
  - "Leftover worktrees": Needs fix when `prunable` or `merged` is above 0. The notes say `kept=N`.
  - A script that exits 1 gives "Not checked" with the reason.
  - The branch-protection row and the recommended actions point to `/devkit:check-fix`.
- **`/devkit:check-fix` flow.** It has `disable-model-invocation: true` and `allowed-tools` limited to the named scripts. It refers to the conventions' Approval rule rather than restating it, and it writes no files. Steps:
  1. Run the reads (plus `ruleset --dry-run` when the repo is not protected and permission is ADMIN).
  2. Show three groups:
     - **Safe:** the missing labels, and prune with the `prune_preview` lines.
     - **Own yes:** the ruleset. Also each `merged` worktree, showing its path, its branch, and "N ignored entries (`<names>`) are deleted with it".
     - **Manual:** `! gh auth login`, `! gh auth refresh -h github.com -s repo`, "ask a repo admin" (permission is not ADMIN), and organization rulesets.
  3. Ask one question for all the safe fixes.
  4. Ask one question for the ruleset. It shows the dry-run line and states the consequence: every push to `<default>` must go through a PR, for the whole team. It offers three answers:
     - Yes, with an Admin bypass (admins can still push directly, as this repo's `/release` does).
     - Yes, with no bypass (direct pushes, release pushes included, stop working).
     - No.

     On `bypass_rejected`, it asks again with only "Yes, with no bypass" and "Cancel".
  5. Ask one question for each worktree.
  6. Apply only what got an explicit yes. Silence, a hedge, or a question gets the question again.
  7. Re-run the reads, and show a before/after table with each `team-fix.sh` line as evidence.
- **Three stacked PRs, each shipping usable value under the gate.** Line counts include tests, and the plan is excluded.
  - **PR A, about 275 lines in 8 files.** `team-status.sh`, `team-fix.sh labels`, the login/scopes and labels rows, and a minimal `check-fix` with the safe label fix.
    - Usable alone: a team can see its login and label gaps and fix the labels.
    - This PR also carries the small README/UPSTREAM/CHANGELOG entries that the repo rule requires whenever a skill is added, and the uncommitted P-44 proposal edit.
  - **PR B, about 265 lines in 6 files.** `worktree-status.sh`, `prune`, `remove-worktree`, the worktree row, and the `check-fix` additions.
  - **PR C, about 270 lines in 7 files.** `team-fix.sh ruleset`, the `check-fix` ruleset step, the branch-protection row pointer, and the final docs and proposal.
  - B stacks on A. C stacks on B, because it edits the same `check-fix` and `team-fix.sh` sections.
- Minor bump (a new skill and new scripts) goes under `### Added`. The bump itself happens at `/release minor`.

Rejected:
- `Bash(gh *)` or `Bash(gh api *)` in `check-fix`, with the model writing the JSON: a PUT built by hand can wipe a ruleset's `rules` array. A tested script keeps the merge deterministic, and the allow rules stay narrow.
- A `--fix` mode inside `/devkit:check`: overruled by the user (2026-10-20). `check` stays read-only.
- Extending a foreign ruleset (`kit`, or an organization ruleset): it changes rules another person owns. Our own named ruleset layers on top and cannot weaken them.
- Classic branch protection (`PUT …/branches/<b>/protection`): it replaces the whole object, is tied to one branch name, and has no `~DEFAULT_BRANCH`.
- `gh label create --force`: it changes existing labels, which the conventions forbid.
- Running `gh auth refresh` or `gh auth login` from the skill: both are interactive, so they are printed for the user to run with `!`.
- A separate `queue-labels.tsv` plus a sync test: two copies of one table in the kit, for six rows. One hard-coded table in `team-status.sh` is simpler.
- `--dry-run` on every action: only `ruleset` has a preview that the status scripts cannot give (`rules_added`).
- Detecting a merge by ancestor test, or by an upstream that is gone: a new branch with no commits passes `merge-base --is-ancestor`, which would delete a new worktree. Matching a merged PR's `headRefOid` is the only proof used.
- Reading scopes from the `X-Oauth-Scopes` header as a fallback: it is a second source for the same fact. `unknown` is honest when `--json hosts` has no scopes.
- A 403/404/plan taxonomy for ruleset errors: the shapes are unverified, so the gh message is passed on as `detail`.
- A bypass for the user (`actor_type: User`): it covers one person instead of the admin role, which does not fit a team. It stays the manual fallback when the read-back says `bypass=unverified`.
- A behavior eval for `check-fix`: single-turn graders pass trivially (the skill asks before acting by design), and `disable-model-invocation: true` already blocks self-invocation. The safety lives in the script preconditions, which the stub tests cover.

## Phases

### Phase 1 — `team-status.sh` and `team-fix.sh labels` (PR A, foundational)
- [x] Write the read script with the three lines and `--missing-labels`, as described in Approach. The label table is hard-coded with a comment pointing to conventions "GitHub issue queue". File: `plugins/devkit/scripts/team-status.sh` (chmod +x).
- [x] Write the writer skeleton:
  - A header covering the four actions, Output, and Exit.
  - `command -v gh git python3`, `ghq()`, and a dispatcher. `prune`, `remove-worktree`, and `ruleset` print `result=not_implemented` and exit 1.
  - The `labels` action, as described in Approach.

  File: `plugins/devkit/scripts/team-fix.sh` (chmod +x).
- [x] Add a stub `gh` chosen by `TS_CASE`, with a stub-contract comment as at `:586-593`. It logs its arguments to `$TS_LOG`. For a failing `label create`, it prints an "already exists" style message on stderr with exit 1 and no HTTP code, as gh does. Add a `tsck` helper. Cases:
  - Logged in with `repo, read:org, gist` → `missing_scopes=-`.
  - Scopes without `repo` → `missing_scopes=repo`.
  - Empty `scopes` → `scopes=unknown missing_scopes=unknown`.
  - Two hosts, the active one on `$GH_HOST` → that login.
  - Logged out → `auth=none`, and `permission=unknown labels_missing=unknown`.
  - `viewerPermission` WRITE.
  - Some labels present → the exact missing list. All present → `-`. The label list fails → `unknown`.
  - `--missing-labels` → exact TSV rows with the conventions' colors.
  - `labels`:
    - The log shows `label create` only for the missing names, never `--force`.
    - One create fails → that label is `result=failed detail=` with the stub message, and the others are `created`.
    - Nothing missing → `none_missing`, and no `label create` in the log.
  - `gh` missing → exit 1 for both scripts.

  File: `scripts/test-hooks.sh`.
- Verify:
  - `scripts/test-hooks.sh` exits 0, with every `team-status` and `team-fix labels` row `ok`.
  - `bash -n` passes on both scripts.
  - Running `bash plugins/devkit/scripts/team-status.sh` in this repo prints `auth=ok`, `permission=ADMIN`, and a `labels_missing=` line, and exits 0. Record the actual scopes value.

### Phase 2 — Check rows, minimal `/devkit:check-fix`, PR A docs (PR A)
- [x] Check:
  - Add `Bash(bash */team-status.sh *)` to `allowed-tools`.
  - Add the "gh login & scopes" and "Queue labels" rows to Layer 4.
  - Add `/devkit:check-fix` to the recommended actions.
  - The `description` stays the same.

  File: `plugins/devkit/skills/check/SKILL.md`.
- [x] New skill, short and imperative:
  - The `description` is under 300 characters and says when to use it ("after /devkit:check reports team setup gaps").
  - `disable-model-invocation: true`.
  - `allowed-tools: Bash(bash */team-status.sh *) Bash(bash */team-fix.sh *)`.
  - The flow in Approach, limited for now to: login/scope manual steps, the safe label fix with one yes, and the before/after table.

  File: `plugins/devkit/skills/check-fix/SKILL.md`.
- [x] Repo rule for a new skill:
  - Add a `/devkit:check-fix` row after `:27`, and add `check-fix` to the `:30` list. File: `README.md`.
  - Note "stage 1, part 1: login, labels" on row `:138`, keeping ⏳. File: `UPSTREAM.md`.
  - Add a P-32 entry under `[Unreleased]` / `### Added`. File: `CHANGELOG.md`.
- [x] Commit the uncommitted P-44 "PRs #30, #31" edit at `:85` with this PR, unchanged. File: `upstream/proposals/20261018.md`.
- Verify:
  - `claude plugin validate plugins/devkit --strict && claude plugin validate .` passes.
  - The new `description` is under 300 characters (`awk` length check).
  - `git diff main -- plugins/devkit/skills/check/SKILL.md | grep -c '^[-+]description:'` is 0.
  - `grep -c 'check-fix' README.md` is at least 2.
  - `scripts/test-hooks.sh` passes.
  - `bash plugins/devkit/scripts/pr-size.sh main` reports `status=ok`.

### Phase 3 — `worktree-status.sh`, `prune`, `remove-worktree` (PR B)
- [ ] Write the read script described in Approach. It uses `-z` porcelain parsing, realpath comparison, the merged-PR `headRefOid` match, the clean check, the ignored listing, and `prune_preview`. File: `plugins/devkit/scripts/worktree-status.sh` (chmod +x).
- [ ] Implement `prune` and `remove-worktree <path>` with the refusals described in Approach. The removal is exactly `git worktree remove -- "$path"`, never `--force`. File: `plugins/devkit/scripts/team-fix.sh`.
- [ ] Tests use temp repos from `mkrepo` and a stub `gh` for `pr list`, chosen by `WT_CASE`. Cases:
  - No extra worktrees → `worktrees=0`.
  - Worktree directory deleted → `prunable`, plus a `prune_preview` row.
  - Merged PR whose `headRefOid` equals the tip, clean tree → `merged`. Also under `.claude/worktrees/`, and with the repo under a symlinked temp dir (realpath).
  - A new branch with no commits, no PR → `kept`. This is the red-team case.
  - Merged PR whose `headRefOid` differs (a commit added after the merge) → `kept`.
  - Merged, but with an untracked non-ignored file → `kept`. With a tracked change → `kept`.
  - Locked → `kept`. Run from inside that worktree → `kept`. Detached → `kept`.
  - gh missing or failing → `gh=unavailable`, and everything not prunable is `kept`.
  - An ignored `.env.local` and an ignored `node_modules/` → count 2 and both names.
  - `prune` removes the prunable entry.
  - `remove-worktree`:
    - Removes a merged worktree, and its branch still exists.
    - Refuses a kept worktree, the main worktree, the current worktree, a path that is not a worktree, and a path with a newline.
    - Accepts the `/private`-prefixed form of a symlinked path.
    - The log of a wrapper `git` shows `worktree remove --` and no `--force`.

  File: `scripts/test-hooks.sh`.
- Verify:
  - `scripts/test-hooks.sh` exits 0, with every `worktree-status` and `team-fix worktree` row `ok`.
  - `bash plugins/devkit/scripts/worktree-status.sh` in this repo prints `worktrees=0 prunable=0 merged=0 kept=0` and exits 0.
  - Assumption check: `git worktree remove -- <path>` is accepted by the local git. The removal test passing proves it, so record the git version.

### Phase 4 — Worktree row and `check-fix` additions (PR B)
- [ ] Add `Bash(bash */worktree-status.sh *)` and the "Leftover worktrees" row. File: `plugins/devkit/skills/check/SKILL.md`.
- [ ] Add these to the skill: the same `allow` entry; prune with `prune_preview` in the safe-fix question; one question per `merged` worktree, naming its path, its branch, and its ignored entries. File: `plugins/devkit/skills/check-fix/SKILL.md`.
- [ ] Add a line to the P-32 entry: worktrees. File: `CHANGELOG.md`.
- Verify:
  - `claude plugin validate plugins/devkit --strict && claude plugin validate .` passes.
  - `grep -c 'worktree-status.sh' plugins/devkit/skills/check/SKILL.md plugins/devkit/skills/check-fix/SKILL.md` is 1 or more in each file.
  - `scripts/test-hooks.sh` passes.
  - The size check against PR A's branch reports `status=ok`.

### Phase 5 — `team-fix.sh ruleset` with stub-gh tests (PR C, riskiest write)
- [ ] Implement `ruleset [--admin-bypass] [--dry-run]` as described in Approach:
  - The ADMIN gate.
  - The list with `includes_parents=true`, filtered by `source_type` and name.
  - The `ambiguous` result, the merge, and POST or PUT.
  - The 422 re-list (`existed`) and `bypass_rejected`.
  - The read-back of the rules (`conflict`) and of `current_user_can_bypass`.

  Bodies go through a temp file passed with `--input`. File: `plugins/devkit/scripts/team-fix.sh`.
- [ ] Add a stub `gh` chosen by `TF_CASE`. It logs arguments to `$TF_LOG`, copies each `--input` file to `$TF_LOG.<n>.json`, and serves a different second GET or list response when a case needs one. Add a `tfck` helper. Cases:
  - Permission WRITE → `refused reason=not_admin`, and only `repo view` in the log.
  - No rulesets → POST. The body has both rules and `~DEFAULT_BRANCH` → `created`.
  - Only the foreign `kit` (the live shape) → POST, no PUT to its id, and `others=kit`.
  - An organization ruleset with our name → ignored, POST.
  - Two repository rulesets with our name → `ambiguous`, and no `-X` write in the log.
  - Own ruleset with `non_fast_forward` only → PUT with exactly the six keys. An existing rule's `parameters` are kept, and `pull_request` is added → `updated rules_added=pull_request`.
  - Own ruleset with both rules → `unchanged`, no write. Own ruleset `disabled` → `disabled`, no write.
  - The PUT read-back lacks a rule → `conflict`.
  - POST 422, and the second list shows our ruleset → `existed`.
  - POST 422 with `--admin-bypass`, and the second list is empty → `bypass_rejected`.
  - POST 422 without bypass → `failed detail=` with the stub message on one line.
  - POST 403 → `failed detail=…`, exit 0.
  - `--admin-bypass`:
    - The body has `"actor_id":5`, `"actor_type":"RepositoryRole"`, and `"bypass_mode":"always"`.
    - The read-back `always` → `bypass=verified`. The read-back `never` → `bypass=unverified`.
    - Existing actors are kept in the PUT body.
  - `--dry-run` → no `-X POST` and no `-X PUT` in the log. Results `would_create` or `would_update`, with `rules_added`.
  - `gh` missing → exit 1.

  File: `scripts/test-hooks.sh`.
- [ ] Assumption check: look for the Admin role actor id in the GitHub docs, or in a ruleset the user already has with an Admin bypass. Read it only; do not create one. Record the source in the script header, or write "unverified; the read-back decides".
- [ ] Manual read-only run in this repo: `bash plugins/devkit/scripts/team-fix.sh ruleset --dry-run`.
- Verify:
  - `scripts/test-hooks.sh` exits 0, with every `team-fix ruleset` row `ok` (at least 20 rows).
  - `bash -n` passes on the script.
  - The manual run prints `action=ruleset result=would_create rules_added=pull_request,non_fast_forward` with `others=kit`, and exits 0. Any other result is recorded with its line.

### Phase 6 — Ruleset step in `check-fix`, final docs (PR C)
- [ ] Add `Bash(bash */branch-protection.sh *)` and the ruleset step from Approach to the skill:
  - The dry-run line inside the question.
  - The three answers, and the re-ask on `bypass_rejected`.
  - The settings URL on `bypass=unverified`.
  - Manual steps for non-admins and for organization rulesets.

  File: `plugins/devkit/skills/check-fix/SKILL.md`.
- [ ] Change `:33` "there is no `--fix` yet" to "run `/devkit:check-fix`". File: `plugins/devkit/skills/check/SKILL.md`.
- [ ] Docs:
  - Mark row `:138` as ✅ and name where the pieces live: the three `/devkit:check` team rows, `/devkit:check-fix`, the three scripts, and the comparison with `/squad:doctor` written in our own words. Record "no eval" and why. File: `UPSTREAM.md`.
  - Finish the P-32 entry: safe fixes versus fixes that need their own yes, devkit's own ruleset with the Admin bypass question, nothing stored locally, and the test row count. File: `CHANGELOG.md`.
  - Mark P-32 done at `:85` and `:91`, and remove the command line at `:94`. File: `upstream/proposals/20261018.md`.
- Verify:
  - `claude plugin validate plugins/devkit --strict && claude plugin validate .` passes.
  - `grep -c 'check-fix' plugins/devkit/skills/check/SKILL.md` is at least 3.
  - `grep -n 'P-32' upstream/proposals/20261018.md` shows it done, with no command line left.
  - `UPSTREAM.md` row 138 shows ✅.
  - `scripts/test-hooks.sh` passes.
  - The size check against PR B's branch reports `status=ok`.

## Risks
| Risk | Signal | Mitigation |
| --- | --- | --- |
| High: a PUT drops rules from a ruleset | Rules disappear after a fix | Only devkit's own repository ruleset is ever PUT. The merge keeps every rule object. Tests check the exact PUT body. The read-back gives `conflict` when the rules differ |
| High: a ruleset without a bypass locks admins out of direct pushes (`/release` here) | A push to `main` is rejected after the fix | The ruleset has its own yes, which states the consequence and asks about the Admin bypass. The dry-run line is shown first |
| High: removing a worktree someone still needs | Lost work or a lost `.env.local` | `merged` needs a merged PR at the exact tip and a clean tree. A new branch is `kept`. The ignored entries are named in the question. A yes for each worktree. Never `--force`, never the current worktree, and the branch is kept |
| Medium: assumption that the Admin role is `actor_id: 5`. It is not in the docs (checked 2026-10-20) | `bypass_rejected`, or `bypass=unverified` | The skill re-asks with no bypass or cancel, and gives the settings URL. Phase 5 looks for a source |
| Medium: assumption about the exact stderr of `gh label create` for an existing label (exit 1, no HTTP code) | A race shows as an unclear `failed` | The `detail` is gh's own message. Only reported-missing labels are created, so a race is rare. The stub mimics the shape, but the wording is unverified |
| Medium: a concurrent edit of devkit's ruleset by another admin | Duplicate rulesets or a lost update | Re-list on 422 (`existed`), `ambiguous` when there are two, and the read-back `conflict` with no retry |
| Medium: a PR exceeds the 300-line gate (PR C is the tightest) | The size check reports over | Keep the stub cases table-driven. If C is still over, move the Phase 6 docs to a small PR D. No limit is raised |
| Medium: `team-fix.sh` is pre-approved in `check-fix`, so the model could call it without a yes | A fix happens without a question | The skill is typed by the user only. Every action re-checks its preconditions: ADMIN, `merged`, reported missing |
| Low: an older gh has no `scopes` in `--json hosts` | Scopes show as unknown | The row is Unknown, not Needs fix |
| Low: a fork PR with the same head branch name | A false `merged` | It also needs `headRefOid` to equal the local tip |
| Low: assumption that `git worktree remove --` is accepted | The removal test fails | Phase 3 verifies it on the local git and records the version |
| Low: stacked PRs need a rebase after a review change in A | B or C conflicts | Small PRs, merged in order |

## Out of scope
- Writing a ruleset in this repo during the implementation. Phase 5 makes only a `--dry-run` live call. A real run is the user's choice, through `/devkit:check-fix`.
- `area:*` labels, `bug` and `enhancement`, and renaming or recoloring existing labels.
- Deleting branches, `git fetch --prune`, and removing worktrees that are not `merged`.
- Changing token scopes or logging in for the user. Those are printed commands.
- Required review counts, status checks, signed commits, tag rulesets, and editing organization rulesets.
- Retrofitting `/devkit:issue` or `/devkit:task` to read the label table from `team-status.sh`.
- A behavior eval for `check-fix`.
- The version bump itself (`/release minor`).

## Red-team notes
- S1 PR size → applied, with one adjustment. The phases map to stacked PRs A/B/C, estimated at about 275, 265, and 270 lines. The README/UPSTREAM/CHANGELOG entries for the new skill start in PR A, not C, because the repo rule says adding a skill updates those files. PR C finalizes them.
- S2 drop `queue-labels.tsv` → applied. The table lives only in `team-status.sh`, which points to conventions. `team-fix.sh` reads `--missing-labels`.
- S3 `--dry-run` only for `ruleset` → applied. The status scripts preview labels and prune.
- S4 states `prunable` / `merged` / `kept`, merged by `headRefOid` plus a clean tree → applied. The ancestor test and the gone-upstream logic are removed. A new branch has its own test.
- S5 one scopes source → applied. The header fallback and the `read:org` rows are dropped.
- S6 drop the eval → applied. The reason is recorded under Rejected and goes into the UPSTREAM row.
- S7 ADMIN gate and collapsed errors → applied. The script refuses `not_admin`, and errors become `failed detail=`.
- T1 eval grader conflict → moot after S6.
- T2 → handled by S4.
- T3 ignored entries listed in the remove question → applied.
- T4 `-z` parsing, control-char refusal, realpath, `--`, not the current worktree, no `--force` → applied.
- T5 `ambiguous`, 422 re-list → `existed`, PUT read-back → `conflict` → applied.
- T6 `bypass_rejected` with a re-ask, `bypass=verified|unverified`, tests assert `actor_id` → applied.
- T7 only reported-missing labels, per-label `failed detail`, a stub with gh's stderr shape, the message marked unverified in Risks → applied.
- T8 `includes_parents=true` for reporting, edits filtered to `Repository` plus our name → applied.
- T9 `prune -n -v` output in the safe-fix question → applied, through `prune_preview` rows.
- Rejected findings: none.
