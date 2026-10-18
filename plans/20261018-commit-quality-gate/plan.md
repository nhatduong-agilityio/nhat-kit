# Commit quality-gate hook template
Status: done · Source: P-7a in `upstream/proposals/20261009b.md` (status review 2026-10-17: keep P-7a as a per-project hook template; drop P-7b) · Mode: --fast

## Goal
Projects set up by `/devkit:bootstrap` get a PreToolUse `Bash` hook that runs the project's quick check (typecheck + lint) before any `git commit` Claude runs, including commits made by subagents such as `git-manager`. A failing check blocks the commit (exit 2) and shows Claude the tail of the output. Everything else passes straight through, and the hook never breaks a session.

## Context found
- `plugins/devkit/templates/hooks/format-on-edit.sh:1-8`: template hook pattern. It reads `tool_input` with inline `python3`, falls back to `node`, exits 0 on any problem, and runs from `${CLAUDE_PROJECT_DIR:-$PWD}`.
- `plugins/devkit/templates/settings.json:30-52`: the `hooks` block registers PostToolUse `Edit|Write` → `format-on-edit.sh` and SessionStart → `reinject-context.sh`. It has no PreToolUse entry yet.
- `plugins/devkit/templates/CLAUDE.md:10`: "Quick check after each batch of changes: `{{TYPECHECK_CMD}} && {{LINT_CMD}}`". Bootstrap fills this only with commands that ran successfully (`bootstrap/SKILL.md:22`).
- `plugins/devkit/skills/bootstrap/SKILL.md:58`: copies `templates/hooks/*.sh` to `.claude/hooks/`, `chmod +x`, and keeps the format hook only if a formatter exists. `:86` tests each hook with sample JSON.
- `plugins/devkit/scripts/block-force-push.sh:10-14`: fast-path pattern (`case "$cmd" in *git*push*) ;; *) exit 0`). Its full parser is a plugin script that a project-copied hook can't reach, so the template gets a simpler matcher.
- `scripts/test-hooks.sh`: per-case `expect <script> <exit> <name> <json>` rows. Today it tests only plugin hooks.
- Plugin hooks must be "safe and fast" (repo `CLAUDE.md`). That is why this ships as a project template, which the project opts into through bootstrap, not as a plugin hook.

## Approach
- New `templates/hooks/check-before-commit.sh` (plain bash, ≤ 40 lines):
  - The first line after the shebang holds `CHECK_CMD='{{QUICK_CHECK_CMD}}'`, which bootstrap fills with the same verified command as `CLAUDE.md`'s Quick check. If it is empty or still the placeholder, exit 0.
  - Read `tool_input.command` with the `format-on-edit.sh` inline-python/node pattern. Any parse failure exits 0.
  - Fast path: no `commit` substring → exit 0.
  - Match `git commit` as a command: `(^|[;&|({]|&&|\|\|)[[:space:]]*(env [^;&|]*)?git([[:space:]]+-[Cc][[:space:]]+[^[:space:]]+)*[[:space:]]+commit([[:space:]]|$)`, run with `grep -qE` per line.
    - Text inside a heredoc or a quoted message can false-match. The only cost is running the check one extra time; it never blocks wrongly unless the check really fails.
  - Run `CHECK_CMD` from the project root, capture combined output to a temp file, and remove it on exit.
    - Pass (exit 0) → exit 0.
    - Fail → print to stderr: "Blocked by devkit: the quick check failed, so the commit did not run. Fix the errors below and commit again. If they were already there before this change, tell the user instead of fixing unrelated code." Then the last 30 lines of output. Exit 2.
    - Check command not found (exit 127) → exit 0 with a one-line stderr note, so a broken setup never blocks.
  - No bypass flag. The user can always commit with `! git commit …`.
- `templates/settings.json`: add a `PreToolUse` entry, matcher `Bash`, command `"$CLAUDE_PROJECT_DIR"/.claude/hooks/check-before-commit.sh`, `"timeout": 300`.
- `bootstrap/SKILL.md:58`: append one clause. Fill `check-before-commit.sh`'s `CHECK_CMD` with the verified Quick check command; delete the hook and its settings entry when the project has neither typecheck nor lint.
- Tests in `scripts/test-hooks.sh`: copy the template to a temp file with `CHECK_CMD` substituted by `true`, `false`, and a missing command, then run it with sample JSON.

Rejected:
- A plugin hook: it would run on every project, including ones with slow or missing checks, which breaks the "safe and fast" rule.
- Parsing `CLAUDE.md` at run time to find the command: fragile markdown parsing on every Bash call. A value filled in once at bootstrap is simpler.
- Checking only staged files: lint tools differ in how they accept file lists. The project's own quick check is what CLAUDE.md already treats as the gate.
- An env-var bypass: Claude could set it itself. `! git commit` keeps the bypass with the user.

## Phases

### Phase 1 — Hook template and tests
- [x] Write `scripts/test-hooks.sh` cases first (a `commit-gate` section), and show they fail because the template is missing. Each case builds a temp copy with `sed "s|{{QUICK_CHECK_CMD}}|<cmd>|"`:
  - `true` + `{"tool_input":{"command":"git commit -m x"}}` → 0
  - `false` + the same → 2, and stderr contains `Blocked by devkit`
  - `sh -c 'echo boom-line; exit 1'` + the same → 2, and stderr contains `boom-line`
  - `false` + `git status` → 0 (not a commit)
  - `false` + `git log --grep commit` → 0
  - `false` + `npm test && git commit -m x` → 2
  - `false` + `git -C repo commit -m x` → 2
  - `false` + `env FOO=1 git commit` → 2
  - placeholder left unfilled + `git commit` → 0
  - `no-such-cmd-xyz` + `git commit` → 0
  - `false` + malformed JSON → 0
  - `false` + `{}` → 0
- [x] Create `plugins/devkit/templates/hooks/check-before-commit.sh` per Approach, written from scratch, and `chmod +x` it.
- Verify:
  - `/bin/bash -n plugins/devkit/templates/hooks/check-before-commit.sh` → exit 0.
  - `scripts/test-hooks.sh; echo "exit=$?"` → every `commit-gate` row `ok`, `exit=0`.
  - Fast-path timing: the `git status` row's MS column ≤ the `protect-files` rows' typical value + 50.
  - `wc -l < plugins/devkit/templates/hooks/check-before-commit.sh` → ≤ 40.

### Phase 2 — Wire into settings and bootstrap; docs
- [x] `plugins/devkit/templates/settings.json`: add the PreToolUse `Bash` entry with `"timeout": 300`.
- [x] `plugins/devkit/skills/bootstrap/SKILL.md:58`: append the clause from Approach.
- [x] `UPSTREAM.md`:
  - `:80` "Quality gate hooks, diagnostics" → ◐: "P-7a: `templates/hooks/check-before-commit.sh` (per-project); P-7b LLM judge dropped".
  - `:84` 3-tier eval row: the note says P-7b was dropped.
- [x] `upstream/proposals/20261009b.md`: status note says P-7a is done and P-7b dropped; the Suggested next commands section is marked done.
- [x] `CHANGELOG.md` `[Unreleased]` → `### Added`: the template hook; bootstrap fills it from the Quick check and deletes it when a project has no typecheck/lint. Existing projects copy it, or re-run `/devkit:bootstrap`, which merges.
- Verify:
  - `python3 -c 'import json;d=json.load(open("plugins/devkit/templates/settings.json"));print([h["hooks"][0]["command"] for h in d["hooks"]["PreToolUse"]])'` prints the new command. `jq` exits 0 on the file.
  - `grep -c 'check-before-commit' plugins/devkit/skills/bootstrap/SKILL.md` → 1.
  - `claude plugin validate plugins/devkit --strict && claude plugin validate .` → pass. `scripts/test-hooks.sh` → exit 0.
  - End-to-end in a scratch repo:
    - Set up `git init`, `.claude/hooks/check-before-commit.sh` filled with `test -f ok.flag`, and `.claude/settings.json` with only the PreToolUse entry.
    - Run `claude -p "run: git commit --allow-empty -m test" --permission-mode acceptEdits --allowedTools "Bash(git commit *)"`.
    - Without `ok.flag`, `git log` stays empty and the transcript shows `Blocked by devkit`.
    - After `touch ok.flag`, one commit exists.

## Risks
| Risk | Signal | Mitigation |
| --- | --- | --- |
| A slow check (big `tsc`) makes every commit wait | Commits take > 1 min | `timeout: 300`; the project can trim `CHECK_CMD` to a faster target. It runs only on `git commit`, not on every Bash call |
| Pre-existing lint errors block every commit, and Claude "fixes" unrelated code | Repeated blocks on files outside the change | The stderr message tells Claude to report pre-existing failures to the user instead of fixing them. The user can commit with `! git commit` |
| False match (e.g. "git commit" inside a heredoc body) | The check runs when no commit happens | Harmless: it only blocks if the check really fails. Cases cover `git log --grep commit` |
| False miss (aliases, `bash -c "git commit"`, scripts) | A commit without a check | Stated as a guardrail, not a sandbox, like `block-force-push.sh:4-5` |
| The check exceeds the 300 s timeout | Claude Code treats the timeout as a non-blocking error, so the commit goes ahead with no message | Accepted; the project shortens `CHECK_CMD` if its check is that slow |
| Hook timeout or crash breaks the session | Errors in the hook output | Every unexpected path exits 0; only a real check failure exits 2 |

## Out of scope
- P-7b (LLM judge), a plugin-level hook, staged-files-only checks, a `/devkit:check` warning when the hook is missing, and a release.
