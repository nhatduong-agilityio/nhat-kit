#!/usr/bin/env bash
# A repo on branch feat with one small change against main.
set -euo pipefail
g() { git -c user.name=eval -c user.email=eval@example.com -c commit.gpgsign=false -c core.hooksPath=/dev/null "$@"; }
git init -q -b main
printf 'export function add(a, b) {\n  return a + b;\n}\n' > math.js
g add -A && g commit -q -m "add math"
g checkout -q -b feat
printf 'export function add(a, b) {\n  return a + b;\n}\n\nexport function div(a, b) {\n  return a / b;\n}\n' > math.js
g commit -q -am "add div"
