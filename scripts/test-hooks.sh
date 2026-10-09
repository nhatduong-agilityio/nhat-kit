#!/usr/bin/env bash
# Test the plugin hooks with sample JSON. Exits 0 when every case matches.
set -u
root="$(cd "$(dirname "$0")/.." && pwd)"
guard="$root/plugins/devkit/scripts/protect-files.sh"
notify="$root/plugins/devkit/scripts/notify.sh"
fail=0

expect() { # expect <expected exit> <name> <json>
  printf '%s' "$3" | "$guard" >/dev/null 2>&1
  local got=$?
  if [ "$got" -eq "$1" ]; then echo "ok   $2"; else echo "FAIL $2 (expected $1, got $got)"; fail=1; fi
}

expect 2 ".env blocked"            '{"tool_input":{"file_path":"/r/.env"}}'
expect 2 ".env.local blocked"      '{"tool_input":{"file_path":"/r/.env.local"}}'
expect 0 ".env.example allowed"   '{"tool_input":{"file_path":"/r/.env.example"}}'
expect 2 "pnpm-lock blocked"       '{"tool_input":{"file_path":"/r/pnpm-lock.yaml"}}'
expect 2 "package-lock blocked"    '{"tool_input":{"file_path":"/r/package-lock.json"}}'
expect 2 ".git/ blocked"           '{"tool_input":{"file_path":"/r/.git/config"}}'
expect 2 "node_modules blocked"    '{"tool_input":{"file_path":"/r/node_modules/x/index.js"}}'
expect 2 "key file blocked"       '{"tool_input":{"file_path":"/r/certs/server.pem"}}'
expect 0 "source allowed"         '{"tool_input":{"file_path":"/r/src/App.tsx"}}'
expect 0 "notebook allowed"       '{"tool_input":{"notebook_path":"/r/a.ipynb"}}'
expect 0 "empty input allowed"     '{}'
expect 0 "malformed JSON allowed"      'not json'

printf '%s' '{"message":"test"}' | "$notify" >/dev/null 2>&1
if [ $? -eq 0 ]; then echo "ok   notify always exits 0"; else echo "FAIL notify"; fail=1; fi

[ "$fail" -eq 0 ] && echo "All hooks passed." || echo "Some hooks failed."
exit "$fail"
