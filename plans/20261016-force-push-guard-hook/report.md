# Report: Force-push guard hook

## Result
- Status: done
- Done:
  - `block-force-push.sh` PreToolUse(Bash) hook blocks `--force`, `--force-with-lease`, `--force-if-includes`, `-f` clusters, `+refspec`
  - `test-hooks.sh` takes the script as an argument; 25 new push cases (12 block, 13 allow)
  - Wired into `hooks.json`; docs updated (git-manager, README, CHANGELOG, UPSTREAM)
- Files: `plugins/devkit/scripts/block-force-push.sh` (created), `plugins/devkit/hooks/hooks.json`, `scripts/test-hooks.sh`, `plugins/devkit/agents/git-manager.md`, `README.md`, `CHANGELOG.md`, `UPSTREAM.md` (modified)

## Evidence
- `scripts/test-hooks.sh` → exit 0, "All hooks passed." (38 cases at first commit; 67 after the first review fixes, 82 after the second; run under macOS `/bin/bash` 3.2.57)
- Blocking case timing: 0.024 s total
- `claude plugin validate plugins/devkit --strict && claude plugin validate .` → both "✔ Validation passed"
- Live smoke in a throwaway repo with a diverged local main: `claude -p --plugin-dir plugins/devkit` asked to run `git push --force origin main` → "PreToolUse:Bash hook error: … Blocked by devkit"; remote stayed at `c5c447a` (local `a06862b`).

## Review fixes (PR #1, `/devkit:review --fix`)
- W1 fixed: commands are split by a quote-, heredoc- and comment-aware scanner instead of `tr`, so text in commit messages, PR bodies and `echo "..."` is never treated as a command. The block message now shows only the `git … push` part.
- W2 fixed: `#` comments end the command; `-o<value>` and separate-argument options (`-o`, `--push-option`, `--repo`, `--receive-pack`, `--exec`) no longer match the `f` check.
- W3 fixed: carriage returns are stripped first.
- W4 fixed: `--mirror`, `--force` abbreviations, quoted flags/refspecs, `env`/`nice`/`timeout`/`xargs`/`sudo` prefixes, `if`/`while`/`until`, `--git-dir <dir>`-style global options, backticks and `$( )`.
- Found during the fix: a backslash-newline continuation (`git push origin \` then `-f`) used to escape the check; lines are now joined.
- Redirects (`2>&1`, `> file`) are dropped from the words, so the suggested `!` command is exactly the push.
- W5 fixed: 29 new cases cover every input above.
- O1: a 20,000-line heredoc or plain script takes ~0.45 s; 20,000 lines that each contain quotes and `git` take ~4.6 s (accepted: artificial). Normal commands ~10 ms.
- O2, O3, O4 fixed (proposal note, case count, shorter message).

## Second review fixes (PR #1)
- W1 fixed: `<<<` here-strings are no longer read as heredocs (which hid every later line).
- W2 fixed: the scanner keeps a context stack (`"…"`, `$( )`, `( )`, `(( ))`), so `$( )` inside double quotes is parsed as commands and its heredoc bodies are skipped. Unbalanced `"` or `'` in a `"$(cat <<'EOF' … EOF)"` body no longer flips quote state.
- O1–O5 fixed: `$'…\'…'` strings, arithmetic `<<`, a tab after `<<`, `--mirror` abbreviations (`--mi*`), and `time -p`.
- O6: single lines over 16 KB are not inspected (scanning is quadratic); a 10–16 KB line takes ≤ 0.5 s.
- 15 new cases (82 total). The reviewer's 65 probes all match, except 4 where its expected value was wrong (`--forc` is ambiguous in git, unterminated quote/heredoc is not run by bash, `HEAD:+main` is not forced).

## Known limits
Not inspected: quoted command strings (`bash -c "…"`, `eval`), single lines over 16 KB, `git push $(…)` where the flag comes from a substitution, git aliases, scripts and other programs that push. The prose rule in `git-manager` stays.
