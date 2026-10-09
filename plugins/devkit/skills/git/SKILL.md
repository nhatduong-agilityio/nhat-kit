---
name: git
description: Standardized git operations — cm (commit), cp (commit + push), pr (commit, push, open PR), sync — with Conventional Commits and secret scanning.
argument-hint: "cm | cp | pr [base] | sync"
disable-model-invocation: true
allowed-tools: Bash(git status *) Bash(git diff *) Bash(git log *) Bash(git branch *)
---

# Git

Command: `$ARGUMENTS`

Commit conventions: the "Commits" section of `${CLAUDE_PLUGIN_ROOT}/references/conventions.md`.

The user invokes this command directly, so `cp` and `pr` count as consent to push the current branch. Still **ask again** if the branch is the main branch or this is a first push to an unfamiliar remote.

- `cm` → have the `devkit:git-manager` subagent run `commit`. Pass the target document (`.claude/current-task`) so it can add `Refs:`.
- `cp` → `commit`, then `push`.
- `pr [base]` → `commit`, `push`, then `pr`. Build the PR body from the plan's `report.md` or the SPEC's "Completion evidence" section (requirements/AC → evidence table), risks, and manual test steps. The default base is the main branch.
- `sync` → `git fetch`, report how far the current branch is ahead/behind the base and whether conflicts are likely (`git merge-tree`); propose a rebase or merge, and do it only with the user's approval.

Reply with: commits created (hash + message), branch, PR link. If git-manager stops because of a secret, show the file and line and don't retry.
