#!/usr/bin/env bash
# Usage: scripts/release.sh <patch|minor|major> [--dry-run]
# Bumps the version in plugin.json, finalizes CHANGELOG's [Unreleased] section, commits, and tags vX.Y.Z.
set -euo pipefail
root="$(cd "$(dirname "$0")/.." && pwd)"
cd "$root"
level="${1:-}"; dry="${2:-}"
manifest="plugins/devkit/.claude-plugin/plugin.json"

case "$level" in patch|minor|major) ;; *) echo "Usage: $0 <patch|minor|major> [--dry-run]" >&2; exit 1 ;; esac

current="$(node -p "require('./$manifest').version")"
IFS=. read -r ma mi pa <<<"$current"
case "$level" in
  major) ma=$((ma+1)); mi=0; pa=0 ;;
  minor) mi=$((mi+1)); pa=0 ;;
  patch) pa=$((pa+1)) ;;
esac
next="$ma.$mi.$pa"
today="$(date +%F)"

# [Unreleased] must have content
body="$(awk '/^## \[Unreleased\]/{f=1;next} /^## \[/{f=0} f' CHANGELOG.md | grep -v '^[[:space:]]*$' || true)"
if [ -z "$body" ]; then echo "CHANGELOG: the [Unreleased] section is empty." >&2; exit 1; fi

echo "devkit $current → $next"
if [ "$dry" = "--dry-run" ]; then echo "(dry run, nothing written)"; exit 0; fi

claude plugin validate plugins/devkit --strict >/dev/null
claude plugin validate . >/dev/null
scripts/test-hooks.sh >/dev/null

node -e "
const fs=require('fs');const p='$manifest';
const j=JSON.parse(fs.readFileSync(p,'utf8'));j.version='$next';
fs.writeFileSync(p, JSON.stringify(j,null,2)+'\n');"

node -e "
const fs=require('fs');let s=fs.readFileSync('CHANGELOG.md','utf8');
s=s.replace('## [Unreleased]\n', '## [Unreleased]\n\n## [$next] - $today\n');
fs.writeFileSync('CHANGELOG.md', s);"

if git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  git add "$manifest" CHANGELOG.md
  git commit -q -m "chore(release): devkit v$next"
  git tag "v$next"
  echo "Committed and tagged v$next. Push with: git push --follow-tags"
else
  echo "Version set to $next (not a git repo, so no commit/tag)."
fi
