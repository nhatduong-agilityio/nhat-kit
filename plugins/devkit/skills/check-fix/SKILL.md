---
name: check-fix
description: Use after /devkit:check reports team setup gaps (gh login or scopes, missing queue labels, leftover worktrees). Shows what is wrong, asks one yes for safe fixes, and a separate yes per merged worktree removal.
disable-model-invocation: true
allowed-tools: Bash(bash */team-status.sh *) Bash(bash */team-fix.sh *) Bash(bash */worktree-status.sh *)
---

# Fix team setup gaps

1. Run `bash ${CLAUDE_PLUGIN_ROOT}/scripts/team-status.sh` and `bash ${CLAUDE_PLUGIN_ROOT}/scripts/worktree-status.sh`. Keep the outputs as "before". If team-status exits 1: report the GitHub items as "Not checked" with its stderr, skip steps 2-3 and the label parts of steps 4-5, and still run the worktree steps. If worktree-status exits 1: skip the worktree steps.
2. Login or scope gaps (`auth=none`, `auth=error`, `missing_scopes=repo`): show the manual step for the user to type, `! gh auth login -h <host>` or `! gh auth refresh -h <host> -s repo` (host: `$GH_HOST`, else `github.com`). Never run auth commands.
3. `labels_missing=unknown`: report it; do not retry.
4. If `labels_missing` lists labels: offer the fix only when `auth=ok`, `missing_scopes` is not `repo`, and `permission` is ADMIN, MAINTAIN or WRITE; otherwise list them under "Manual: ask a repo admin". To offer, ask one question, "Create these labels on <repo>?". The prune is offered independent of the label conditions and of team-status: if `prunable` > 0, add it to the labels question when one is asked, else ask it alone; otherwise do not mention it. In the prune part, list the path of each `prunable` row and the `prune_preview` lines, and add: an entry on an unmounted removable or network drive loses its git metadata, so mount it and answer no. Follow "Approval" in `${CLAUDE_PLUGIN_ROOT}/references/conventions.md`. Run nothing that changes GitHub or the worktrees before an explicit yes.
5. On yes, run only what was offered: `bash ${CLAUDE_PLUGIN_ROOT}/scripts/team-fix.sh labels` and/or `team-fix.sh prune` (report `pruned=`). Report each `label=` line; on `action=labels result=failed`, report the detail and do not retry. Anything other than yes: change nothing.
6. For each `merged` worktree, ask its own question naming the path, the branch, and its ignored entries (count and names) that will be deleted with it, and ask the user to make sure no other session is using that worktree. On yes run `bash ${CLAUDE_PLUGIN_ROOT}/scripts/team-fix.sh remove-worktree <path> <ignored count shown>` and report `result=`; on `refused` or `failed` report the reason and do not retry. Never offer `kept` rows or use `--force`.
7. Re-run both status scripts and show a before/after table: Item · Before · After.

Nothing is stored on this machine; all state stays in GitHub.
