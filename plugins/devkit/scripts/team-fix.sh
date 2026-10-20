#!/usr/bin/env bash
# The only devkit script that writes team setup to GitHub and removes local worktrees. One action per call; run only after the user said yes.
# Usage: team-fix.sh <labels|prune|remove-worktree|ruleset> [args]
#   labels  create the queue labels that team-status.sh --missing-labels reports (never --force, never touches existing labels)
#   prune   git worktree prune -v; prints "result=done pruned=N"
#   remove-worktree <path> <ignored count>  remove one worktree that worktree-status.sh reports as merged now, with the ignored
#     count the user was shown: git worktree remove -- <path>, never --force, never deletes the branch
#     result=removed path=<p> branch_kept=<b>, or result=refused
#     reason=unsafe_path|missing_count|not_a_worktree|current|<state of the row, e.g. kept>|ignored_changed
#   ruleset  not implemented yet
# Output: lines starting "action=<a> result=<r>"; labels adds one "label=<name> result=created|failed [detail=<one line>]" line per label.
#   labels: result=started before the label lines; result=none_missing when nothing is missing; result=failed detail=... when the missing list cannot be read.
# Exit: 0 for every reported outcome, 1 when git or python3 is missing (gh too for labels and ruleset), the action is unknown,
#   or the action is not implemented.

need() { local c; for c in "$@"; do command -v "$c" >/dev/null 2>&1 || { echo "team-fix: $c required" >&2; exit 1; }; done; }
need python3 git
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

do_prune() {
  local out n; out="$(LC_ALL=C git worktree prune -v 2>&1)" || { echo "action=prune result=failed detail=$(oneline "$out")"; return 0; }
  n="$(printf '%s\n' "$out" | awk '/^Removing/ { n++ } END { print n + 0 }')"
  echo "action=prune result=done pruned=$n"
}

do_remove() {
  local p="${1:-}" want="${2:-}" row st br cnt t; t="$(printf '\t')"
  case "$p" in ""|*[[:cntrl:]]*) echo "action=remove-worktree result=refused reason=unsafe_path"; return 0 ;; esac
  case "$want" in ""|*[!0-9]*|???????*) echo "action=remove-worktree result=refused reason=missing_count"; return 0 ;; esac
  p="$(python3 -I -c 'import os,sys; print(os.path.realpath(sys.argv[1]))' "$p")"
  row="$(bash "$here/worktree-status.sh" 2>/dev/null | P="$p" awk -F "$t" '$5 == ENVIRON["P"] && $1 != "prune_preview" { print $1 "\t" $2 "\t" $3; exit }')"
  [ -n "$row" ] || { echo "action=remove-worktree result=refused reason=not_a_worktree"; return 0; }
  [ "$p" != "$(python3 -I -c 'import os,sys; print(os.path.realpath(sys.argv[1]))' "$(git rev-parse --show-toplevel 2>/dev/null)")" ] \
    || { echo "action=remove-worktree result=refused reason=current"; return 0; }
  st="${row%%"$t"*}"; br="${row#*"$t"}"; cnt="${br#*"$t"}"; br="${br%%"$t"*}"
  [ "$st" = merged ] || { echo "action=remove-worktree result=refused reason=$st"; return 0; }
  want="${want#"${want%%[!0]*}"}"; [ "$cnt" = "${want:-0}" ] || { echo "action=remove-worktree result=refused reason=ignored_changed"; return 0; }
  if out="$(git worktree remove -- "$p" 2>&1)"; then echo "action=remove-worktree result=removed path=$p branch_kept=$br"
  else echo "action=remove-worktree result=failed detail=$(oneline "$out")"; fi
}

action="${1:-}"
case "$action" in
  labels) need gh; do_labels ;;
  prune) do_prune ;;
  remove-worktree) do_remove "${2:-}" "${3:-}" ;;
  ruleset) need gh; echo "action=$action result=not_implemented"; exit 1 ;;
  *) echo "team-fix: usage: team-fix.sh <labels|prune|remove-worktree|ruleset>" >&2; exit 1 ;;
esac
