# Protected branches: report GitHub protection, block local pushes
Status: done · Source: P-44 in `upstream/proposals/20261018.md` (v2.6.0, "Approvals and shared queue") · Mode: --fast
Approved: 2026-10-20 by nhatduong-agilityio

## Goal
- `/devkit:check` shows one row for the default branch: whether GitHub protects it (PR required, force push blocked), or "unknown (needs admin)" when the token cannot see it.
- A bootstrapped project gets `.claude/hooks/block-protected-push.sh`, filled with the protected branches listed in its `CLAUDE.md`. When Claude tries to push to one of them, the hook blocks with exit 2 and a reason. The user can still run `! git push` themselves (user decision, 2026-10-20: block, not ask, not warn).
- The plugin hook `block-force-push.sh` and this repo's `/release` (which pushes `main`) do not change.

## Context found
- `upstream/proposals/20261018.md:43`: P-44 has two layers. The check report is in scope; `check --fix` is P-32. `:94` says the hook "warns". The user's decision changes that to "blocks", so update the wording in Phase 4.
- `plugins/devkit/skills/check/SKILL.md:5`: `allowed-tools` is read-only (`ls`, `wc`, `git log`, `git status`). `:10` statuses are OK / Missing / Needs fix. `:12-15` Layer 1 covers settings and hooks. `:29-31` Layer 4 covers GitHub templates.
- `plugins/devkit/scripts/queue-status.sh:1-7,11,30`: this is the pattern for a read-only script backed by `gh`. It has a header with Usage/Output/Exit, checks `command -v gh`, uses a `ghq()` wrapper without colour or a forced TTY, prints one `key=value` line, and exits 0 when ok or 1 when gh fails. `task/SKILL.md:6,19` allows it as `Bash(bash */queue-status.sh *)` and calls it with no arguments.
- Live API on this repo, checked by the caller: `branches/main` returns `protected:true` while `protection.enabled:false` (a ruleset, not classic protection). `rules/branches/main` returns `deletion` and `non_fast_forward` but no `pull_request`. Classic `branches/<b>/protection` needs admin.
- `plugins/devkit/templates/hooks/check-before-commit.sh:2-5,8`: a heredoc placeholder, and an unfilled or multi-line value exits 0. `:11-12`: python3 parses the JSON, with node as a fallback (templates cannot use `json-field.sh`). `:14`: a regex for `git commit` that allows env, sudo, `-C`, and `-c` prefixes. `:16`: it runs in `$CLAUDE_PROJECT_DIR`. `:26-31`: on a block it writes the reason to stderr and exits 2.
- `scripts/test-hooks.sh:17` `expect`, `:191` `row`, `:282-325` `gate()`: these copy the template with the placeholder substituted and run cases. `:384-397`: a stub `gh` on `PATH` returns canned JSON for each subcommand. `:331-337` `mkrepo` creates temp git repos.
- `plugins/devkit/templates/settings.json:31-42`: one `PreToolUse` Bash entry (check-before-commit). `:18` has `ask` for `git push`. `:26-27` deny force push.
- `plugins/devkit/templates/CLAUDE.md:39-41`: "# Remotes & never-push rules" has `protected branches: {{PROTECTED_BRANCHES}}`. Line 41 names only `block-force-push`.
- `plugins/devkit/skills/bootstrap/SKILL.md:41-47`: step 2 settles decisions with `AskUserQuestion` (at most 4) before the plan is approved. `:57-58`: step 4 copies the hooks and fills `{{QUICK_CHECK_CMD}}`, and deletes the hook and its entry when there is nothing to fill. `:65`: step 5 fills the remotes section from the protection "the user confirms". That confirmation comes after step 4 copies the hooks, so the order is a problem. `:21`: never overwrite. `:87`: step 8 tests the hooks with sample JSON.
- `plugins/devkit/agents/git-manager.md:19` already says "never push to the main branch". In bootstrapped projects the new hook now enforces that, so the agent text does not change.
- `README.md:48` lists the template hooks ("format, context-restore, and commit quality-gate hooks"). `:27` has the `/devkit:check` row. `UPSTREAM.md:150` is ⏳ P-44. `CHANGELOG.md:5-10` `[Unreleased]` has only `### Changed`.

## Approach
- **Template hook `templates/hooks/block-protected-push.sh`**, written from scratch and kept small (≈ 80 lines). It follows the structure of `check-before-commit.sh`:
  - A `{{PROTECTED_BRANCHES}}` heredoc holds names separated by spaces or commas. `case` glob patterns such as `release/*` are allowed (user decision, 2026-10-20). An empty, unfilled, or multi-line value exits 0.
  - Quick filter `*push*`, then parse `tool_input.command` with python3, falling back to node.
  - Split the command into segments on `;`, `&`, `|`, and newlines. A segment counts when it matches the same prefix shape as the commit gate (env/sudo/path prefixes, `git -C dir`, `-c k=v`) followed by `push`. Split the segment into words with bash `read -a`; quotes are not interpreted, and the header documents that.
  - Targets:
    - `--all` or `--mirror` → block.
    - `--tags` with no refspec → allow.
    - Skip options that take a value (`--repo`, `-o`/`--push-option`, `--receive-pack`/`--exec`). Flags that take no value, such as `-u`, `-d`/`--delete`, and `--dry-run`, are skipped and do not change targets.
    - The first positional word is the remote, and the rest are refspecs.
    - For a refspec: strip a leading `+`; the destination is the part after `:`, or the whole refspec; strip `refs/heads/`; ignore `refs/tags/…`. `HEAD` as the destination means the current branch.
    - No refspec → the current branch (`git -C <dir> rev-parse --abbrev-ref HEAD`) and its upstream branch name (`@{u}` without the remote), both run from `$CLAUDE_PROJECT_DIR` or `-C`.
  - Any target that matches → stderr `Blocked by devkit: <branch> is protected (CLAUDE.md "Remotes & never-push rules"). Push a feature branch and open a PR; if the user wants this push, they run it themselves with ! git push …`, exit 2. Everything else, including errors, exits 0.
  - Like `block-force-push.sh`'s header, the header says what the hook does not inspect: quoted or escaped words, aliases, scripts that push (`npm run release`), and `push.default` or remote-mapping configuration beyond `@{u}`.
- **Read-only script `scripts/branch-protection.sh [branch]`** in the `queue-status.sh` style:
  - The branch defaults to `gh repo view --json defaultBranchRef`.
  - It reads `branches/<b>` (`protected`, `protection.enabled`) and `rules/branches/<b>` (`pull_request` → PR required; `non_fast_forward` → force push blocked).
  - Only when classic protection is on does it read `branches/<b>/protection` (`required_pull_request_reviews`, `allow_force_pushes.enabled`). A 403 or 404 there makes each item that is not already known from the rules `unknown`.
  - Output: `branch=<b> protected=true|false pr_required=true|false|unknown force_push_blocked=true|false|unknown source=rules|classic|both|none`. Exit 0 ok; exit 1 when gh is missing, the repo is not on GitHub, or the API fails.
  - `/devkit:check` calls it through `Bash(bash */branch-protection.sh *)`.
- **Wiring**:
  - Check, Layer 4: one "Default branch protection" row. OK when both items are true; Needs fix when either is false (enable it in GitHub settings; no `--fix` yet); "Unknown" with "needs admin" for unknown; "Not checked" when the script exits 1.
  - Check, Layer 1: when `CLAUDE.md` lists protected branches, `block-protected-push.sh` exists, is wired in `PreToolUse`, and has no `{{` left.
  - Bootstrap: confirm the protected branches in the BOOTSTRAP PLAN table the user approves in step 2 (default: the remote's default branch), not as an extra question (user decision, 2026-10-20). Step 4 fills the hook from that answer, or deletes the hook and its settings entry when there is none. Step 5 fills `CLAUDE.md` from the same answer. Step 8 gets a sample push test.
- Minor bump (new script, new template hook, new check row): `### Added` in CHANGELOG.

Rejected:
- Copying or sourcing the plugin's `block-force-push.sh` shell-word parser: CLAUDE.md says write from scratch, the template must stay small, and templates cannot rely on plugin paths at run time. The template hook is a guardrail, not a sandbox.
- Making it a plugin hook that reads `CLAUDE.md` at run time: it would also fire in this repo and break `/release`, which pushes `main`. Parsing markdown on every Bash call is also slow and fragile.
- `ask` or warn-only instead of exit 2: overruled by the user (2026-10-20). `git push` is already in `ask`, so a second prompt adds nothing.
- Granting `Bash(gh api *)` to `/devkit:check`: `gh api` can write (`-X PUT`), and check is read-only. A dedicated script keeps the allow rule narrow.
- Reporting only the `protected` flag: it is true for a ruleset that only blocks deletion, as on this repo, so it would claim "PR required" falsely.
- Filling the hook in step 5 after the copy: this splits one fill across two steps, and step 4 would write a hook it might delete later. Asking in step 2 settles it before the plan is approved, which is also where bootstrap asks for decisions.
- An eval case: the hook is deterministic and fully covered by `test-hooks.sh` cases. The check row needs a live GitHub repo or a stubbed `gh`, which `claude plugin eval` fixtures do not provide.

## Phases

### Phase 1 — Template hook `block-protected-push.sh` + tests
- [x] Write the hook as described in Approach, with its header (purpose, placeholder, exit codes, what it does not inspect) — file: `plugins/devkit/templates/hooks/block-protected-push.sh` (chmod +x)
- [x] Add a `pushgate()` helper in the style of `gate()`: copy the template with `{{PROTECTED_BRANCHES}}` replaced, then run each case inside a temp repo (via `mkrepo`) where the current branch can be set, with `CLAUDE_PROJECT_DIR` pointing at it — file: `scripts/test-hooks.sh`
- [x] Cases with list `main release/*`:
  - Exit 2: `git push origin main`, `git push -u origin main`, `git push origin HEAD:main`, `git push origin feat:refs/heads/main`, `git push origin +feat:main`, `git push origin :main`, `git push --delete origin main`, `git push origin release/1.2`, `git push --all origin`, `git push --mirror`, `git -C <repo> push` on main, bare `git push` on main, bare `git push` on feat whose upstream is `origin/main`, `cd x && git push origin main`, `FOO=1 git push origin main`.
  - Exit 0: `git push origin feat`, bare `git push` on feat (no upstream), `git push --tags`, `git push origin v1.0` with `refs/tags/v1.0`, `git status`, `git log --grep push`, an unfilled placeholder, an empty list, malformed JSON, `{}`.
  - The stderr of one block case contains `Blocked by devkit` and the branch name.
- Verify: `scripts/test-hooks.sh` exits 0 and lists every new `block-protected-push` row as `ok` (≥ 25 rows); `bash -n plugins/devkit/templates/hooks/block-protected-push.sh` passes; `test -x` on the template passes.

### Phase 2 — `branch-protection.sh` + stub-gh tests
- [x] Write the script as described in Approach (header Usage/Output/Exit, `command -v gh`, a `ghq()` wrapper, JSON parsed with `gh --jq` or `python3 -I`, a single summary line) — file: `plugins/devkit/scripts/branch-protection.sh` (chmod +x)
- [x] Add a stub `gh` in the style of `qsbin` that returns canned responses for `repo view`, `api …/branches/<b>`, `api …/rules/branches/<b>`, and `api …/protection` (one 404/403 mode). Cases:
  - Ruleset with `pull_request` and `non_fast_forward` → `pr_required=true force_push_blocked=true source=rules`.
  - This repo's real shape (deletion + non_fast_forward, classic off) → `pr_required=false force_push_blocked=true`.
  - Classic on and readable → `source=classic`, values taken from it.
  - Classic on and 403 → `unknown` for items not covered by rules.
  - Unprotected → `protected=false pr_required=false force_push_blocked=false source=none`.
  - An explicit branch argument → used instead of the default.
  - gh fails → exit 1.
  
  — file: `scripts/test-hooks.sh`
- [x] Manual check: `bash plugins/devkit/scripts/branch-protection.sh` in this repo prints `branch=main protected=true pr_required=false force_push_blocked=true` (matches the live API facts)
- Verify: `scripts/test-hooks.sh` exits 0 with every new `branch-protection` row `ok`; the manual run above prints that line and exits 0.

### Phase 3 — Wire into check, bootstrap, and templates
- [x] Check: add `Bash(bash */branch-protection.sh *)` to `allowed-tools`. Add the Layer 4 "Default branch protection" row (statuses as in Approach; mention that `pr_required=false` on a ruleset means "add a pull_request rule"). Add the Layer 1 item for `block-protected-push.sh`. Add "Unknown" to the status list (user decision, 2026-10-20) — file: `plugins/devkit/skills/check/SKILL.md`
- [x] Bootstrap:
  - Step 2: add a "Protected branches" row to the BOOTSTRAP PLAN table (default: the remote's default branch, or `main`); the user's plan approval confirms it.
  - Step 4: copy and fill `{{PROTECTED_BRANCHES}}` on its one line from that answer, or delete the hook and its `PreToolUse` entry when there is none. If the hook already exists, merge rather than overwrite.
  - Step 5: fill `CLAUDE.md` from the same answer.
  - Step 8: add a sample: `echo '{"tool_input":{"command":"git push origin <protected>"}}' | .claude/hooks/block-protected-push.sh; echo $?` (expect 2).
  
  — file: `plugins/devkit/skills/bootstrap/SKILL.md`
- [x] Add a second `PreToolUse` Bash hook entry for `block-protected-push.sh` (short timeout, e.g. 10) — file: `plugins/devkit/templates/settings.json`
- [x] Line 41: normal pushes to the protected branches are blocked by the `block-protected-push` hook (the user can run `! git push`), and other pushes still need approval — file: `plugins/devkit/templates/CLAUDE.md`
- Verify:
  - `claude plugin validate plugins/devkit --strict && claude plugin validate .` passes.
  - `python3 -m json.tool plugins/devkit/templates/settings.json >/dev/null` passes.
  - `grep -c 'block-protected-push' plugins/devkit/templates/settings.json plugins/devkit/skills/bootstrap/SKILL.md plugins/devkit/skills/check/SKILL.md plugins/devkit/templates/CLAUDE.md` → each ≥ 1.
  - `grep -c 'branch-protection.sh' plugins/devkit/skills/check/SKILL.md` ≥ 2 (allowed-tools + body).
  - The check and bootstrap `description` lines are unchanged (`git diff` shows no `description:` line).
  - `scripts/test-hooks.sh` still passes.

### Phase 4 — Docs
- [x] `[Unreleased]` → new `### Added` entry for P-44: the template hook (blocks, `! git push` escape, what it does not inspect), `branch-protection.sh`, and the check rows. Note that already-bootstrapped projects can copy the hook by hand or re-run `/devkit:bootstrap` (it merges, never overwrites). Note no eval: covered by `test-hooks.sh` — file: `CHANGELOG.md`
- [x] Line 48: add "protected-branch push" to the template hooks list. Mention in the `/devkit:check` row at `:27` only if it lists items (today it does not) — file: `README.md`
- [x] Mark row `:150` ✅ and name where it lives (`/devkit:check` Layer 4 + `scripts/branch-protection.sh`; `templates/hooks/block-protected-push.sh`; blocks, by the user's decision) — file: `UPSTREAM.md`
- [x] Mark P-44 done in the v2.6.0 order line (`:85`) and the "Done:" line (`:91`). Change "warns" to "blocks" at `:94` or drop that command line, the same way P-33 and P-34 were handled — file: `upstream/proposals/20261018.md`
- Verify:
  - `grep -n 'P-44' CHANGELOG.md UPSTREAM.md upstream/proposals/20261018.md` → a match under `[Unreleased]` / `### Added`, a ✅ row, and done in the order line.
  - `grep -n 'protected-branch' README.md` → 1 match.
  - `claude plugin validate plugins/devkit --strict && claude plugin validate .` and `scripts/test-hooks.sh` both pass.

## Out of scope
- `/devkit:check --fix` (turning on protection, scopes, labels): P-32.
- Changing the plugin hook `block-force-push.sh`, or adding the template hook to this repo's own `.claude/` (`/release` must keep pushing `main`).
- Updating already-bootstrapped projects automatically.
- Checking protection for branches other than the default in `/devkit:check`. The script accepts a branch argument, but check only reports the default.
- Required status checks, review counts, signed commits, and ruleset bypass actors in the report.
- Editing `agents/git-manager.md`: its "never push to the main branch" line already agrees.

## Risks
| Risk | Signal | Mitigation |
| --- | --- | --- |
| Medium: the hook misses a push (quoted refspec, alias, a script that pushes, a `push.default`/remote mapping) | A push to a protected branch goes through in a bootstrapped project | The documented guardrail scope. `git push` stays in `ask`, and GitHub protection is the real gate, which is why check reports it |
| Medium: the hook blocks a legitimate push (a feature branch whose upstream is `main`, a pattern that is too broad) | The user is blocked on a feature push | The stderr names the branch and the `! git push` escape. Test cases cover a feature branch with no upstream. The list is explicit in `CLAUDE.md` and the hook |
| Medium: assumption, not verified for non-admin tokens: `branches/<b>` returns `protection.enabled` with read access | `protection` is missing from the non-admin JSON | Treat a missing `protection.enabled` like "classic may be on". Read `/protection` and fall back to `unknown`. Phase 2 has a stub case for it |
| Low: rulesets with conditions or bypass actors. `rules/branches/<b>` lists rules that apply, but the user may bypass them | Check says OK, yet the admin can push | Out of scope. The note says "rules that apply to the branch" |
| Low: hook latency on every Bash call | Slow sessions | Exit at the `*push*` substring check before any parsing. Git calls run only for a bare `git push` or `HEAD`. Timing shows in the `test-hooks.sh` ms column |
| Low: bootstrap step 2 already uses its 4 questions | No room for the branch question | Decided (user, 2026-10-20): a row in the BOOTSTRAP PLAN table, not a question |
