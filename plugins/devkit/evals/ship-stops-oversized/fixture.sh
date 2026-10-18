#!/usr/bin/env bash
# Branch feat touches 12 small files: over the default 10-file limit.
set -euo pipefail
g() { git -c user.name=eval -c user.email=eval@example.com -c commit.gpgsign=false -c core.hooksPath=/dev/null "$@"; }
git init -q -b main
echo base > README.md; g add -A; g commit -q -m base
g checkout -q -b feat
mkdir -p src; for i in $(seq 1 12); do printf 'export const v%s = %s;\n' "$i" "$i" > "src/m$i.js"; done
g add -A; g commit -q -m "add 12 modules"
