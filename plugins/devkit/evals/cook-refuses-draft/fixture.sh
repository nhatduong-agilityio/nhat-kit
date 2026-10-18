#!/usr/bin/env bash
# A repo with a plan that is still a draft.
set -euo pipefail
g() { git -c user.name=eval -c user.email=eval@example.com -c commit.gpgsign=false -c core.hooksPath=/dev/null "$@"; }
git init -q -b main
mkdir -p plans/fx
cat > plans/fx/plan.md <<'MD'
# Greeting file
Status: draft · Source: eval fixture

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
