#!/usr/bin/env bash
IFS= read -r -d '' CHECK_CMD <<'__DEVKIT_CHECK_CMD_EOF__'
{{QUICK_CHECK_CMD}}
__DEVKIT_CHECK_CMD_EOF__
CHECK_CMD="${CHECK_CMD%$'\n'}"
# PreToolUse (Bash): run the project's quick check before any `git commit`; exit 2 blocks the commit.
# Guardrail, not a sandbox. Every unexpected path exits 0. The user can still run `! git commit`.
case "$CHECK_CMD" in ""|"{{"*|*$'\n'*) exit 0 ;; esac  # unfilled, or not one line
input="$(cat)"
case "$input" in *commit*) ;; *) exit 0 ;; esac
cmd="$(printf '%s' "$input" | python3 -c 'import json,sys; print(json.load(sys.stdin).get("tool_input",{}).get("command",""))' 2>/dev/null \
  || printf '%s' "$input" | node -e 'let s="";process.stdin.on("data",d=>s+=d).on("end",()=>{try{process.stdout.write(JSON.parse(s).tool_input.command||"")}catch{}})' 2>/dev/null)"
case "$cmd" in *commit*) ;; *) exit 0 ;; esac
printf '%s\n' "$cmd" | tr -d '\r' | grep -qE '(^|[;&|({])[[:space:]]*(env[[:space:]]+)?([A-Za-z_][A-Za-z0-9_]*=[^[:space:]]*[[:space:]]+)*((sudo|time|command|nice|nohup)[[:space:]]+)*([^[:space:];&|]*/)?git([[:space:]]+(-[Cc][[:space:]]+([^[:space:]"]*"[^"]*"[^[:space:]]*|[^[:space:]]+)|--[a-z-]+(=[^[:space:]]+)?))*[[:space:]]+commit([[:space:]]|$)' || exit 0

cd "${CLAUDE_PROJECT_DIR:-$PWD}" 2>/dev/null || exit 0
out="$(mktemp 2>/dev/null)" || exit 0
trap 'rm -f "$out"' EXIT
bash -c "$CHECK_CMD" </dev/null >"$out" 2>&1
rc=$?
[ "$rc" -eq 0 ] && exit 0
if [ "$rc" -eq 127 ] || [ "$rc" -eq 126 ]; then
  echo "devkit: quick check command not found or not executable, commit allowed: $CHECK_CMD" >&2
  exit 0
fi
{
  echo "Blocked by devkit: the quick check failed, so the commit did not run. Fix the errors below and commit again."
  echo "If they were already there before this change, tell the user instead of fixing unrelated code."
  tail -n 30 "$out"
} >&2
exit 2
