#!/usr/bin/env bash
# PreToolUse (Bash): block git pushes that rewrite remote history.
# exit 2 + stderr = block and tell Claude why. exit 0 = no objection.
# A guardrail, not a sandbox: `bash -c "..."` and git aliases are not inspected.
here="$(cd "$(dirname "$0")" && pwd)"
input="$(cat)"
cmd="$(printf '%s' "$input" | "$here/json-field.sh" tool_input.command)"

# Fast path: most Bash calls are not pushes.
case "$cmd" in
  *git*push*) ;;
  *) exit 0 ;;
esac

block() {
  echo "Blocked by devkit: '$1' rewrites remote history. If you really mean it, ask the user to run it with: ! $1" >&2
  exit 2
}

# One command per line: split on ; & | ( ) and newlines.
segments="$(printf '%s' "$cmd" | tr ';&|()' '\n\n\n\n\n')"

while IFS= read -r seg; do
  read -ra tok <<< "$seg"
  i=0
  n=${#tok[@]}

  # Skip env assignments and harmless prefixes before the command name.
  while [ "$i" -lt "$n" ]; do
    case "${tok[$i]}" in
      *=*|'{'|'!'|time|command|exec|nohup|sudo|then|do|else) i=$((i + 1)) ;;
      *) break ;;
    esac
  done
  [ "$i" -lt "$n" ] || continue
  [ "${tok[$i]##*/}" = git ] || continue
  i=$((i + 1))

  # Skip git's global options (-C <dir>, -c <k=v>, --git-dir=..., --no-pager, ...).
  while [ "$i" -lt "$n" ]; do
    case "${tok[$i]}" in
      -C|-c) i=$((i + 2)) ;;
      -*) i=$((i + 1)) ;;
      *) break ;;
    esac
  done
  [ "${tok[$i]:-}" = push ] || continue
  i=$((i + 1))

  while [ "$i" -lt "$n" ]; do
    case "${tok[$i]}" in
      --force|--force=*|--force-with-lease|--force-with-lease=*|--force-if-includes) block "${tok[*]}" ;;
      --*) ;;
      -*f*) block "${tok[*]}" ;;          # short-flag cluster such as -f or -uf
      +*) block "${tok[*]}" ;;            # forced refspec such as +main
    esac
    i=$((i + 1))
  done
done <<< "$segments"

exit 0
