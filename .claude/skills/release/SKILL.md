---
name: release
description: Release a new devkit version — checks, semver bump, CHANGELOG, tag, push so other machines can update.
argument-hint: "<patch | minor | major>"
disable-model-invocation: true
---

# Release devkit

Bump level: `$ARGUMENTS` (empty → propose a level based on `[Unreleased]` in `CHANGELOG.md` and the semver rule at the top of that file, then ask).

1. `[Unreleased]` in `CHANGELOG.md` must have content; if empty → stop and ask the user what changed.
2. Checks:
   - `claude plugin validate plugins/devkit --strict` and `claude plugin validate .`
   - Hook scripts: run `scripts/test-hooks.sh`.
   - Every skill/agent name referenced by another skill/agent exists (`grep -rn "devkit:" plugins/devkit`).
   - Evals: `claude plugin eval plugins/devkit --tag core --trust-plugin --scaffold --ablation none --runs 1 --max-cost-usd 3 --no-publish --allow-tools Write Edit`. A red case → stop and show its report. Also run the `needs-bash` command from `plugins/devkit/evals/README.md` when the machine's Bash sandbox can start; otherwise say it was skipped and why.
3. Run `scripts/release.sh <level>`: bumps `version` in `plugin.json`, turns `[Unreleased]` into `[x.y.z] - <date>`, commits, and tags `vX.Y.Z`.
4. Ask before `git push --follow-tags`.
5. Remind the user how to update each machine:
   ```bash
   claude plugin marketplace update nhat-kit
   claude plugin update devkit@nhat-kit   # then restart Claude Code
   ```
