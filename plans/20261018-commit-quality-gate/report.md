# Report: commit quality-gate hook template (P-7a)

Plan: `plan.md` (2 phases, --fast). Branch `feat/commit-quality-gate`, not committed.

## Phases completed
| Phase | Result |
| --- | --- |
| 1: hook template + tests | done. Tests were written first: 8 rows failed before the hook existed |
| 2: settings, bootstrap, docs | done. The end-to-end `claude -p` check passed |

## Files changed
- New: `plugins/devkit/templates/hooks/check-before-commit.sh` (31 lines, executable).
- Changed: `plugins/devkit/templates/settings.json` (PreToolUse `Bash` entry, `timeout: 300`), `plugins/devkit/skills/bootstrap/SKILL.md` (fill rule + hook test line), `scripts/test-hooks.sh` (`commit-gate` section: 27 exit-code cases + 3 stderr assertions), `README.md:48`, `UPSTREAM.md` (P-7 rows), `upstream/proposals/20261009b.md`, `CHANGELOG.md` `[Unreleased]` Added.

## Evidence
| Command | Result |
| --- | --- |
| `scripts/test-hooks.sh; echo exit=$?` | `159 cases, 0 failed`, `All hooks passed.`, `exit=0` |
| `/bin/bash -n plugins/devkit/templates/hooks/check-before-commit.sh` | ok |
| `claude plugin validate plugins/devkit --strict && claude plugin validate .` | `✔ Validation passed` ×2 |
| `jq empty plugins/devkit/templates/settings.json` | ok; the PreToolUse command is `"$CLAUDE_PROJECT_DIR"/.claude/hooks/check-before-commit.sh` |
| End-to-end, scratch repo. Hook filled with `test -f ok.flag \|\| { echo "lint: ok.flag missing"; exit 1; } # project's check` (apostrophe comment on purpose); `claude -p "… git commit --allow-empty -m test" --permission-mode acceptEdits --allowedTools "Bash(git commit *)"` | Without `ok.flag`: 0 commits, transcript shows `Blocked by devkit` and `ok.flag missing`. With `ok.flag`: 1 commit, no block |
| Fast path: `git status` row | 8–23 ms (raw-input `*commit*` check runs before JSON parsing) |

## Deviations from the plan
- `CHECK_CMD` is read with `IFS= read -r -d '' … <<'__DEVKIT_CHECK_CMD_EOF__'`, not `CHECK_CMD='…'`.
  - Single quotes break on a filled command containing `'`.
  - A heredoc inside `$(…)` also breaks on macOS bash 3.2 (review Critical): bash scans it for quotes and comments.
  - Either form causes a syntax error, which exits 2 and blocks every Bash call.
  - A newline guard exits 0 on a multi-line fill.
- The matcher is wider than planned. It also catches `FOO=1`, `sudo`, `time`, `command`, `nice`, `nohup`, `/usr/bin/git`, `git --no-pager`, `git -C "a b"`, and `git -c k="a b"`.
- Exit 126 (check not executable) is treated like 127: commit allowed, with a note.
- `grep -c 'check-before-commit' bootstrap/SKILL.md` → 2, not 1. Bootstrap's hook-test step now also tests this hook.
- Tests substitute the fill with python, not `sed`, so `&` and `|` in a check command stay literal.

## Review
- Round 1: 1 Critical, 5 Warning, 3 Optional. All Warnings were fixed.
  - Critical: the `$(cat <<'…')` form failed on bash 3.2. It now uses `read -d ''`, with regression rows for an apostrophe comment and an unbalanced quote on `git status`.
  - Warnings fixed: terminator/multi-line guard; bootstrap fill rule (one line, verbatim, either command alone is fine, no comment) plus a test line; false negatives; `README.md:48`; this report.
  - Optionals fixed: `rm -f` before each test copy; 126 treated like 127; a timeout row added to Risks.
- Round 2: 0 Critical, 0 Warning, 2 Optional. Both fixed: an unlikely terminator name, and `git -c` with a quoted value plus `nohup`.

## Out of scope / open
- Still missed: `bash -c "git commit"`, git aliases, scripts, `git --work-tree /x commit` (long option with its value after a space). This is a guardrail, not a sandbox.
- When the 300 s timeout hits, Claude Code lets the commit through. Accepted, and listed in Risks.
- Projects bootstrapped earlier must copy the hook or re-run `/devkit:bootstrap`.
