#!/usr/bin/env bash
# bench.sh <label> <plugin-dir> — one headless /devkit:cook run on a fresh fixture copy.
set -u
B="$(cd "$(dirname "$0")" && pwd)"
label="$1"; plugin="$2"
run="$B/runs/$label"
rm -rf "$run" && mkdir -p "$B/runs" && cp -R "$B/fixture" "$run"
cd "$run" || exit 1

start=$(date +%s)
echo "/devkit:cook plans/20261016-slugify/plan.md --auto" | claude -p \
  --plugin-dir "$plugin" \
  --settings '{"enabledPlugins":{"devkit@nhat-kit":false}}' \
  --output-format json \
  --permission-mode acceptEdits \
  --allowedTools "Bash(node:*)" "Bash(git:*)" "Bash(ls:*)" "Bash(cat:*)" "Bash(mkdir:*)" "Bash(grep:*)" "Bash(find:*)" "Bash(rm:*)" \
  --max-turns 80 > "$run/.result.json" 2> "$run/.stderr.log"
rc=$?
secs=$(( $(date +%s) - start ))

own="$(node --test 2>&1 | awk '/^ℹ (pass|fail) /{print $2"="$3}' | tr '\n' ' ')"
mkdir -p test-heldout && cp "$B/heldout.test.js" test-heldout/
held="$(node --test test-heldout/heldout.test.js 2>&1 | awk '/^ℹ (pass|fail) /{print $2"="$3}' | tr '\n' ' ')"

python3 - "$run/.result.json" "$label" "$rc" "$secs" "$held" "$own" <<'PY'
import json, sys
path, label, rc, secs, held, own = sys.argv[1:]
try:
    r = json.load(open(path))
except Exception as e:
    print(f"{label}: no JSON result ({e}); exit {rc}, {secs}s, heldout {held}"); sys.exit()
mu = r.get("modelUsage") or {}
split = ", ".join(f"{m.split('-')[1] if '-' in m else m}=${v.get('costUSD', 0):.2f}" for m, v in sorted(mu.items()))
print(f"{label}: exit {rc} · cost ${r.get('total_cost_usd', 0):.2f} · [{split}] · {secs}s · turns {r.get('num_turns')} · "
      f"heldout {held}· own tests {own}· is_error {r.get('is_error')}")
PY
