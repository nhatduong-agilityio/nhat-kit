#!/usr/bin/env bash
# Read JSON from stdin and print the value at a dotted path such as "tool_input.file_path".
# Uses jq if available, otherwise python3, then node. Prints an empty string if not found.
path="$1"
input="$(cat)"

if command -v jq >/dev/null 2>&1; then
  printf '%s' "$input" | jq -r ".${path} // empty" 2>/dev/null
elif command -v python3 >/dev/null 2>&1; then
  printf '%s' "$input" | python3 -c '
import json, sys
try:
    data = json.load(sys.stdin)
    for key in sys.argv[1].split("."):
        data = data.get(key) if isinstance(data, dict) else None
    print("" if data is None else data)
except Exception:
    print("")
' "$path"
elif command -v node >/dev/null 2>&1; then
  printf '%s' "$input" | node -e '
let s = "";
process.stdin.on("data", d => (s += d)).on("end", () => {
  try {
    let v = JSON.parse(s);
    for (const k of process.argv[1].split(".")) v = v == null ? undefined : v[k];
    process.stdout.write(v == null ? "" : String(v));
  } catch { process.stdout.write(""); }
});
' "$path"
fi
