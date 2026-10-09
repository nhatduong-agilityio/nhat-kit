#!/usr/bin/env bash
# Notification: desktop alert when Claude is waiting for approval or idle.
# Never breaks the session: always exits 0.
here="$(cd "$(dirname "$0")" && pwd)"
msg="$("$here/json-field.sh" message)"
[ -z "$msg" ] && msg="Claude Code needs your attention"
project="$(basename "${CLAUDE_PROJECT_DIR:-$PWD}")"
title="Claude Code · $project"

if command -v osascript >/dev/null 2>&1; then
  osascript -e "display notification \"${msg//\"/\'}\" with title \"${title//\"/\'}\"" >/dev/null 2>&1
elif command -v notify-send >/dev/null 2>&1; then
  notify-send "$title" "$msg" >/dev/null 2>&1
elif command -v powershell.exe >/dev/null 2>&1; then
  powershell.exe -NoProfile -Command "[console]::beep(880,200)" >/dev/null 2>&1
else
  printf '\a'
fi
exit 0
