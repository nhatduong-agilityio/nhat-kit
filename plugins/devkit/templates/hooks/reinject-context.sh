#!/usr/bin/env bash
# SessionStart (compact|resume): restore the in-progress task context after compaction or resume.
# Stdout is added to Claude's context.
root="${CLAUDE_PROJECT_DIR:-$PWD}"
cd "$root" || exit 0

echo "## Restored context (devkit)"
branch="$(git branch --show-current 2>/dev/null)"
[ -n "$branch" ] && echo "- Branch: $branch"

if [ -f .claude/current-task ]; then
  spec="$(head -n 1 .claude/current-task)"
  echo "- Task in progress: $spec — re-read this file before continuing."
fi

changed="$(git status --porcelain 2>/dev/null | head -n 20)"
if [ -n "$changed" ]; then
  echo "- Changed files:"
  printf '%s\n' "$changed" | sed 's/^/    /'
fi

echo "- Last 5 commits:"
git log --oneline -5 2>/dev/null | sed 's/^/    /'
exit 0
