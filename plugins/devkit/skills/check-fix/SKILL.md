---
name: check-fix
description: Use after /devkit:check reports team setup gaps (gh login or scopes, missing queue labels). Shows what is wrong, asks one yes, then creates the missing labels.
disable-model-invocation: true
allowed-tools: Bash(bash */team-status.sh *) Bash(bash */team-fix.sh *)
---

# Fix team setup gaps

1. Run `bash ${CLAUDE_PLUGIN_ROOT}/scripts/team-status.sh`. Keep the output as "before". If it exits 1: report "Not checked" with its stderr and stop.
2. Login or scope gaps (`auth=none`, `auth=error`, `missing_scopes=repo`): show the manual step for the user to type, `! gh auth login -h <host>` or `! gh auth refresh -h <host> -s repo` (host: `$GH_HOST`, else `github.com`). Never run auth commands.
3. `labels_missing=unknown`: report it; do not retry.
4. If `labels_missing` lists labels: offer the fix only when `auth=ok`, `missing_scopes` is not `repo`, and `permission` is ADMIN, MAINTAIN or WRITE; otherwise list them under "Manual: ask a repo admin". To offer, ask one question, "Create these labels on <repo>?". Follow "Approval" in `${CLAUDE_PLUGIN_ROOT}/references/conventions.md`. Run nothing that changes GitHub before an explicit yes.
5. On yes, run `bash ${CLAUDE_PLUGIN_ROOT}/scripts/team-fix.sh labels` and report each `label=` line; on `action=labels result=failed`, report the detail and do not retry. Anything other than yes: change nothing.
6. Re-run `team-status.sh` and show a before/after table: Item · Before · After.

Nothing is stored on this machine; all state stays in GitHub.
