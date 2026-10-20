#!/usr/bin/env bash
# The only devkit script that writes team setup to GitHub. One action per call; run only after the user said yes.
# Usage: team-fix.sh <labels|prune|remove-worktree|ruleset> [args]
#   labels  create the queue labels that team-status.sh --missing-labels reports (never --force, never touches existing labels)
#   prune, remove-worktree, ruleset  not implemented yet
# Output: lines starting "action=<a> result=<r>"; labels adds one "label=<name> result=created|failed [detail=<one line>]" line per label.
#   labels: result=started before the label lines; result=none_missing when nothing is missing; result=failed detail=... when the missing list cannot be read.
# Exit: 0 for every reported outcome, 1 when gh, git or python3 is missing, the action is unknown, or the action is not implemented.

for c in python3 gh git; do command -v "$c" >/dev/null 2>&1 || { echo "team-fix: $c required" >&2; exit 1; }; done
# Plain output only: no colour or forced-TTY formatting.
ghq() { ( unset CLICOLOR_FORCE GH_FORCE_TTY; NO_COLOR=1 gh "$@" ); }
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# The first line of $1, without control characters, at most 200 chars.
oneline() { printf '%s\n' "$1" | head -n 1 | tr -d '\n' | tr '\r\t' '  ' | tr -d '\000-\010\013\014\016-\037\177' | head -c 200; }

do_labels() {
  local rows rc name color desc err detail t; t="$(printf '\t')"
  err="$(mktemp 2>/dev/null)" || { echo "action=labels result=failed detail=mktemp failed"; return 0; }
  rows="$(bash "$here/team-status.sh" --missing-labels 2>"$err")"; rc=$?; detail="$(oneline "$(cat "$err")")"; rm -f "$err"
  if [ "$rc" -ne 0 ]; then echo "action=labels result=failed detail=$detail"; return 0; fi
  if [ -z "$rows" ]; then echo "action=labels result=none_missing"; return 0; fi
  echo "action=labels result=started"
  while IFS="$t" read -r name color desc; do
    [ -n "$name" ] || continue
    case "$color" in [0-9a-fA-F][0-9a-fA-F][0-9a-fA-F][0-9a-fA-F][0-9a-fA-F][0-9a-fA-F]) ;; *) desc="" ;; esac
    case "$desc" in ""|*"$t"*) echo "label=$name result=failed detail=bad row"; continue ;; esac
    if err="$(ghq label create "$name" --color "$color" --description "$desc" 2>&1 >/dev/null)"; then
      echo "label=$name result=created"
    else
      echo "label=$name result=failed detail=$(oneline "$err")"
    fi
  done <<EOT
$rows
EOT
  return 0
}

action="${1:-}"
case "$action" in
  labels) do_labels ;;
  prune|remove-worktree|ruleset) echo "action=$action result=not_implemented"; exit 1 ;;
  *) echo "team-fix: usage: team-fix.sh <labels|prune|remove-worktree|ruleset>" >&2; exit 1 ;;
esac
