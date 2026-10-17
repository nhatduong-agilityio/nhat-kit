---
name: security-scan
description: Scan the whole project for leaked secrets, vulnerable dependencies (with audit tools already installed), sensitive tracked files, and risky code sinks; writes a redacted report. For a review of your branch diff, use /security-review.
disable-model-invocation: true
allowed-tools: Bash(git rev-parse *) Bash(git check-ignore *) Bash(git ls-files *) Bash(bash */scan-secrets.sh *) Bash(mkdir *)
---

# Security scan

Conventions: `${CLAUDE_PLUGIN_ROOT}/references/conventions.md`. Read only: never fix, install, or update anything. Never print a secret value. Write in English. Run each command in its own Bash call (no `&&`, `;`, or `echo`).

1. **Repo check.** Run `git rev-parse --show-toplevel`; call the result `<root>`. Not a git repo → stop.
2. **Ignore check.** Run `git check-ignore -q <root>/security-scan/`. If it is not ignored, warn that the report could be committed, show the line to add (`security-scan/` in `.gitignore`), and ask with `AskUserQuestion` whether to write the report anyway. Do not edit `.gitignore`. Write nothing until the user answers; "no" → stop.
3. **Scan.** Delegate to the `devkit:security-scanner` subagent with the project root and `${CLAUDE_PLUGIN_ROOT}/scripts`. The scanner runs `scan-secrets.sh` from that directory; to skip the permission prompt, allow `Bash(bash */scan-secrets.sh *)`.
4. **Re-check critical rows.** Put each path in single quotes. If a path contains `'`, `$`, a backtick, or a control character, skip its re-check and keep the row with "re-check skipped: unusual path". For each critical secret row, run `bash ${CLAUDE_PLUGIN_ROOT}/scripts/scan-secrets.sh <root> --check <rule> <path>` with the row's rule and path (it prints only a count). Drop the row only on a clean `0`. On exit 2 keep the row and note "re-check failed"; for a sensitive-file row, run `git ls-files -- <path>`. Never print matched text. Drop other rows that do not reproduce.
5. **Write the report** to `<root>/security-scan/<YYYYMMDD-HHMM>.md` (local time): the `Scanned:` line, the finding table, and the scanner's closing line about `/security-review` and git history. Create the directory if needed.
6. **Reply** with the counts per severity, the top 5 rows, every `not run` item, and the report path. Next steps: `/devkit:issue bug <report>` to file findings, `/security-review` for the branch diff.
