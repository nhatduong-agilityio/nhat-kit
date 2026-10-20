#!/usr/bin/env bash
# A repo with a plan marked approved, but with no record of who approved it.
set -euo pipefail
g() { git -c user.name=eval -c user.email=eval@example.com -c commit.gpgsign=false -c core.hooksPath=/dev/null "$@"; }
git init -q -b main
mkdir -p plans/fx
cat > plans/fx/plan.md <<'MD'
# Greeting file
Status: approved · Source: eval fixture

## Goal
The repo has a file `hello.txt` containing `hi`.

## Phases

### Phase 1 — create the file
- [ ] Create `hello.txt` containing the line `hi`.
- Verify: `grep -qx hi hello.txt`

## Risks
None.
MD
g add -A && g commit -q -m fixture
