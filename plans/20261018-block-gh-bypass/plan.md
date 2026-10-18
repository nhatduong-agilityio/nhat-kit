# Block admin merges and self-approval in the push guard
Status: done · Source: P-35 in `upstream/proposals/20261018.md` · Mode: --fast

## Goal
The plugin hook `block-force-push.sh` also blocks (exit 2) `gh pr merge … --admin`, which bypasses branch protection, and `gh pr review … --approve`/`-a`, where an agent approves a PR. It reuses the hook's tokenizer, so text inside quotes, heredocs, and commit messages still passes. A normal `gh pr merge` and every other `gh` command still pass. All existing push cases keep their results.

## Context found
- `plugins/devkit/scripts/block-force-push.sh:1-5`: header ("block git pushes that rewrite remote history"; a guardrail, not a sandbox).
- `:10-13`: fast path `*git*push*) ;; *) exit 0`. A `gh pr` command exits here today, which is why P-35 is more than an append.
- `:18-21`: `block()` prints a force-push-specific message and exits 2.
- `:24-48`: `check_segment` skips env assignments, shell keywords, and wrappers (`env nice sudo xargs timeout time`, `command exec nohup`), then requires basename `git` (`:49`).
- `:52-83`: git global options, then `push` flag analysis.
- `:85-273`: tokenizer. It splits on `; & | && ||`, handles quotes, heredocs, and `$( )`/backticks, and calls `check_segment` per simple command (`:108-111`). It is reused unchanged.
- `scripts/test-hooks.sh`: `bash_cmd <exp> <command>` rows for this hook (about 70 cases) feed the table.
- `plugins/devkit/hooks/hooks.json`: PreToolUse `Bash` → `block-force-push.sh`. Unchanged.
- `README.md:3` lists the hook as `block-force-push`. `UPSTREAM.md` P-35 row is ⏳.

## Approach
- Fast path: `*git*push*|*gh*pr*) ;;`.
- `block <command> <reason>`. Keep the force-push wording for git. For gh, the message is: "'<cmd>' bypasses human review (admin merge or self-approval). Ask a reviewer; if the user really wants it, they can run: ! <cmd>".
- In `check_segment`, after the wrapper skip, branch on the basename:
  - `gh`: skip gh global flags (`-R`/`--repo <v>`, `--repo=<v>`, `--hostname <v>`, other `-*`). Require `pr`, then the subcommand:
    - `merge`: block on `--admin` or `--admin=<anything but false>`.
    - `review`: block on `--approve` or `--approve=<anything but false>`, and on a short-flag cluster where `a` appears before the first value-taking flag (`b`, `F`). So `-a` and `-ab "ok"` block, while `-ba` (body "a") passes.
    - Flags with values are skipped: `--body`/`-b`, `--body-file`/`-F`, `--subject`/`-t`, `--match-head-commit`, `--author-email`/`-A`, `-R`. A value that looks like a flag (`--body "--admin"`) is never read as one.
  - `git`: the existing logic, unchanged.
- The tokenizer's per-line fast skip (`*git*|…`) also lets `*gh*` lines through; without it a line holding only a `gh` command is never parsed (added during cook).
- The hook keeps its file name (`hooks.json` and the docs refer to it). Its header says it now guards review bypass too.

Rejected:
- A separate hook script: a second PreToolUse spawn on every Bash call, and a duplicate tokenizer.
- Blocking `gh api …/merge` or GraphQL calls: too many forms, so it stays out of scope. The header says it is a guardrail, not a sandbox.
- Renaming the hook: churn in `hooks.json`, README, and tests for no behavior gain.

## Phases

### Phase 1: tests first, then the gh checks
- [x] Add `scripts/test-hooks.sh` cases using `bash_cmd`, and show the block cases fail before the change.
  - **Block (2):**
    - `gh pr merge --admin`
    - `gh pr merge 13 --squash --admin`
    - `gh -R o/r pr merge --admin`
    - `gh pr merge --admin=true`
    - `git status && gh pr merge --admin`
    - `sudo gh pr merge --admin`
    - `gh pr review --approve`
    - `gh pr review 5 -a`
    - `gh pr review -ab "lgtm"`
    - `gh pr review --approve=true -b ok`
    - `/usr/local/bin/gh pr review --approve`
    - `x=$(gh pr merge --admin)`
  - **Allow (0):**
    - `gh pr merge 13 --squash`
    - `gh pr merge --admin=false`
    - `gh pr review --comment -b "approve after CI"`
    - `gh pr review -ba`
    - `gh pr review -r -b "needs --admin? no"`
    - `gh pr create --body "never use --admin"`
    - `echo "gh pr merge --admin"`
    - `gh pr view 13`
    - `gh issue create --title approve`
    - `gh pr merge --body "--admin" 13`
    - A heredoc whose body contains `gh pr merge --admin`
- [x] Implement per Approach in `plugins/devkit/scripts/block-force-push.sh`: fast path, `block` reason, gh branch in `check_segment`, header lines.
- Verify:
  - `/bin/bash -n plugins/devkit/scripts/block-force-push.sh` → exit 0.
  - `scripts/test-hooks.sh; echo "exit=$?"` → every row `ok`, `exit=0`. All pre-existing push cases are unchanged.
  - `echo '{"tool_input":{"command":"gh pr merge --admin"}}' | plugins/devkit/scripts/block-force-push.sh; echo $?` → `2`, and stderr starts with `Blocked by devkit: 'gh pr merge --admin' bypasses human review`.
  - Fast-path cost: the `npm run build` and `ls -f` rows stay in the same MS range as before (no `gh`/`git` → still exits at the fast path).

### Phase 2: docs
- [x] `README.md`: where the hooks are described, say `block-force-push` also blocks admin merges and self-approval.
- [x] `CHANGELOG.md` `[Unreleased]` → `### Changed`: the hook blocks `gh pr merge --admin` and `gh pr review --approve`/`-a` (P-35).
- [x] `UPSTREAM.md` P-35 row → ✅. In `upstream/proposals/20261018.md`, note under v2.5.0 that P-35 is done.
- Verify:
  - `grep -c 'P-35' UPSTREAM.md` → ≥ 1 with ✅ on that row.
  - `claude plugin validate plugins/devkit --strict && claude plugin validate .` → pass.
  - `scripts/test-hooks.sh` → exit 0.

## Risks
| Risk | Signal | Mitigation |
| --- | --- | --- |
| A legitimate command is blocked (false positive) | User workflow breaks, e.g. a PR body that mentions `--admin` | The tokenizer keeps quoted and heredoc text as data. Value-taking flags are skipped. Allow cases cover bodies, echo, and heredocs |
| A bypass form is missed (`gh api`, aliases, `bash -c`) | An admin merge goes through | Stated in the header: guardrail, not a sandbox. GitHub branch protection (P-44) is the real enforcement |
| The wider fast path slows every Bash call | MS column grows on unrelated rows | `*gh*pr*` only adds the tokenizer for commands that contain both substrings; check the `npm run build` row |
| The user's own merge flow breaks | `/devkit:ship` → "merge it" uses `gh pr merge N --squash` | Allowed case `gh pr merge 13 --squash`; only `--admin` blocks |

## Out of scope
- `gh api`/GraphQL merges, git aliases, renaming the hook, a release.
