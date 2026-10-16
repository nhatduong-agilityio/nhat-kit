# Report: Force-push guard hook

## Result
- Status: done
- Done:
  - `block-force-push.sh` PreToolUse(Bash) hook blocks `--force`, `--force-with-lease`, `--force-if-includes`, `-f` clusters, `+refspec`
  - `test-hooks.sh` takes the script as an argument; 25 new push cases (12 block, 13 allow)
  - Wired into `hooks.json`; docs updated (git-manager, README, CHANGELOG, UPSTREAM)
- Files: `plugins/devkit/scripts/block-force-push.sh` (created), `plugins/devkit/hooks/hooks.json`, `scripts/test-hooks.sh`, `plugins/devkit/agents/git-manager.md`, `README.md`, `CHANGELOG.md`, `UPSTREAM.md` (modified)

## Evidence
- `scripts/test-hooks.sh` → exit 0, "All hooks passed." (37 cases)
- Blocking case timing: 0.024 s total
- `claude plugin validate plugins/devkit --strict && claude plugin validate .` → both "✔ Validation passed"
- Live smoke in a throwaway repo with a diverged local main: `claude -p --plugin-dir plugins/devkit` asked to run `git push --force origin main` → "PreToolUse:Bash hook error: … Blocked by devkit"; remote stayed at `c5c447a` (local `a06862b`).

## Known limits
`bash -c "…"`, git aliases, and scripts that push are not inspected; the prose rule in `git-manager` stays.
