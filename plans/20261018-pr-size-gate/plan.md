# PR size gate with project-doc limits
Status: done · Source: P-27 in `upstream/proposals/20261018.md` · Mode: --fast · Decisions: user, 2026-10-18 (project settings live in `docs/devkit.md`)

## Goal
Before a PR opens, `/devkit:ship` and `/devkit:task` measure the change. They count lines added and deleted plus files changed, skipping lockfiles, generated output, and snapshots. If the change is over the project's limit, they stop and propose a split. `/devkit:review` reports an oversized change as a Warning. A deterministic script does the counting. Limits and exclude globs come from a new project settings doc, `docs/devkit.md`, which also becomes the single home for later devkit tunables (P-30 claim TTL, P-36 open-PR limit). When the doc is missing, built-in defaults apply.

## Context found
- `plugins/devkit/references/conventions.md:171`: the P-23 rule says tunable settings belong in a project file the skill reads at run time. It names no file yet.
- `plugins/devkit/skills/ship/SKILL.md:14`: gate 1 "Clean" is the first gate and the natural place for a size check, before tests and build spend time.
- `plugins/devkit/skills/task/SKILL.md:56-67`: §7 "Verify and review" and §8 "Ship". The PR opens in §8 after "Ask before pushing" (`:67`), so the check goes at the start of §8.
- `plugins/devkit/skills/review/SKILL.md:11-13`: step 1 scope (`#PR` → `gh pr diff`; branch → `<branch>...HEAD`; empty → against main including uncommitted). The size line belongs in the report.
- `plugins/devkit/scripts/`: plugin scripts. `scan-secrets.sh` is the precedent for a deterministic helper a skill calls (`bash ${CLAUDE_PLUGIN_ROOT}/scripts/…`), with tests in `scripts/test-hooks.sh`.
- `plugins/devkit/templates/docs/`: `PROJECT_BRIEF.md`, `BACKLOG.md`, `tasks/`. Bootstrap copies docs templates at `bootstrap/SKILL.md:36` and `:79`.
- Source idea: agile-squad counts additions plus deletions and changed files, minus exclude globs, with limits per task size (XS 50 / S 150 / M 300 lines). devkit tasks are not sized, so one limit applies, defaulting to the M tier.

## Approach
- **`templates/docs/devkit.md`** (new). A short markdown doc with one `- key: value` line per setting and a sentence of why under each. P-27 adds:
  - `pr_max_lines: 300`
  - `pr_max_files: 10`
  - `pr_size_exclude: *.lock, package-lock.json, pnpm-lock.yaml, yarn.lock, go.sum, Cargo.lock, **/__snapshots__/**, *.snap, dist/**, build/**, *.min.*`

  Later proposals add their keys to the same file.
- **`scripts/pr-size.sh [base]`** (new plugin script, plain bash 3.2):
  - **Count:** `git diff --numstat $(git merge-base <base> HEAD)` covers committed and uncommitted tracked changes. Untracked, not-ignored files are counted too: their line count, plus one file each.
    - Binary files (`-`) count as files only.
    - A path matching an exclude glob is left out.
    - `<base>` defaults to `origin/HEAD`, else `main`.
  - **Limits:** read from `docs/devkit.md` at the repo root (`- key: value` lines); defaults when absent or malformed.
  - **Output:**
    - one line: `lines=N files=M max_lines=X max_files=Y excluded=K status=ok|over`
    - then the 5 largest files as `path<TAB>lines`
  - **Exit codes:** 0 when ok, 3 when over, 1 on usage or not-a-repo. It never prints file contents.
- **`ship` gate 1:** run the script. Over → stop: show the numbers and the largest files, and propose a split by concern (from the plan's phases or the diff's directories). Continue only if the user explicitly says so, and then add "oversized: N lines / M files" to the PR's Risks and impact.
- **`task` §8:** the same check right before "Ask before pushing".
- **`review` step 1:** run the script on the same scope. Over → report a Warning "PR is over the size limit (N lines / M files)". `#PR` scope uses `gh pr diff --name-only`/numstat via `gh pr view --json additions,deletions,changedFiles` (no exclude support; say so).
- **Conventions:**
  - New Directories row: `docs/devkit.md` · project settings for devkit skills · bootstrap, edited by the team.
  - Line 171 now names `docs/devkit.md` as that project file.
- **Bootstrap:** copy `templates/docs/devkit.md` to `docs/devkit.md` (never overwrite; merge missing keys), next to the other docs templates.

Rejected:
- Limits per task size: devkit plans and SPECs have no Size field. One limit plus a split proposal is enough for now.
- Counting in the prompt: models miscount diffs. The script is deterministic and testable.
- A hook that blocks `gh pr create`: hard to scope the base, and the skill flow is the place to propose a split.

## Phases

### Phase 1: settings doc and counting script, tests first
- [x] Write `scripts/test-hooks.sh` cases for `pr-size.sh` first, in a temp repo with `main` plus a feature branch, and show they fail.
  - Small change → `status=ok`, exit 0.
  - 400 added lines → `status=over`, exit 3.
  - 11 one-line files → over on files.
  - A 5,000-line `package-lock.json` alone → `excluded=1`, ok.
  - A binary file → counted as 1 file, 0 lines.
  - An untracked new file → counted.
  - `docs/devkit.md` with `pr_max_lines: 1000` → the 400-line case becomes ok.
  - A malformed `docs/devkit.md` → defaults.
  - Not a repo → exit 1.
- [x] Create `plugins/devkit/scripts/pr-size.sh` (chmod +x) and `plugins/devkit/templates/docs/devkit.md`.
- Verify:
  - `/bin/bash -n plugins/devkit/scripts/pr-size.sh` → exit 0.
  - `scripts/test-hooks.sh; echo "exit=$?"` → all `pr-size` rows `ok`, `exit=0`.
  - Run on this repo: `bash plugins/devkit/scripts/pr-size.sh main` → one `lines=… status=…` line and exit 0 or 3, consistent with `git diff --numstat main` by hand.

### Phase 2: wire into ship, task, review, conventions, bootstrap
- [x] `ship/SKILL.md` gate 1: one sentence per Approach.
- [x] `task/SKILL.md` §8: one sentence per Approach.
- [x] `review/SKILL.md` step 1: one sentence per Approach.
- [x] `references/conventions.md`: the Directories row, plus line 171 naming `docs/devkit.md`.
- [x] `bootstrap/SKILL.md`: copy and merge `templates/docs/devkit.md`.
- Verify:
  - `grep -c 'pr-size.sh' plugins/devkit/skills/{ship,task,review}/SKILL.md` → 1 each.
  - `grep -c 'docs/devkit.md' plugins/devkit/references/conventions.md plugins/devkit/skills/bootstrap/SKILL.md` → ≥ 1 each.
  - `git diff --numstat -- plugins/devkit/skills/` → each skill file ≤ 3 added.
  - `claude plugin validate plugins/devkit --strict && claude plugin validate .` → pass. `scripts/test-hooks.sh` → exit 0.

### Phase 3: docs
- [x] `README.md`: mention the size gate in the ship/task rows or the workflow notes, and `docs/devkit.md` in the 4-layer templates list.
- [x] `CHANGELOG.md` `[Unreleased]` → `### Added`: `pr-size.sh` + `templates/docs/devkit.md`. `### Changed`: ship/task/review gate, bootstrap (P-27).
- [x] `UPSTREAM.md` P-27 → ✅. Add a proposal note under v2.5.0.
- Verify: `grep -c '✅ | P-27' UPSTREAM.md` → 1. Validate passes.

## Risks
| Risk | Signal | Mitigation |
| --- | --- | --- |
| Legit large changes (generated code, migrations, renames) get stopped | Ship stops on a mechanical change | Exclude globs live in `docs/devkit.md`; the user can say "continue", which is recorded in Risks and impact |
| Base detection is wrong (no `origin/HEAD`, unusual default branch) | Counts include unrelated commits | Base is an argument; skills pass the PR base; fallback `main`; the output names the base |
| `#PR` review scope can't apply excludes | Review reports a size that differs from ship | Review states that the `#PR` count comes from GitHub totals without excludes |
| `docs/devkit.md` parsing drifts as more keys are added | Wrong limits | Keep the format `- key: value`; a test covers malformed input → defaults |

## Out of scope
- Per-task size tiers, a hook on `gh pr create`, P-30/P-36 keys (added by their own plans), and a release.
