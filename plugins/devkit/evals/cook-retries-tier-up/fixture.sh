#!/usr/bin/env bash
# An approved one-phase plan whose acceptance check only reveals the expected line when it fails.
set -euo pipefail
g() { git -c user.name=eval -c user.email=eval@example.com -c commit.gpgsign=false -c core.hooksPath=/dev/null "$@"; }
git init -q -b main
cat > check.sh <<'SH'
#!/bin/sh
# Acceptance check owned by the product team.
want="$(printf '%s' H4sIAAAAAAAAA8vIVCjJSC1KBQDsdqPjCAAAAA== | base64 -d 2>/dev/null | gunzip 2>/dev/null || printf '%s' H4sIAAAAAAAAA8vIVCjJSC1KBQDsdqPjCAAAAA== | base64 -D | gunzip)"
got="$(cat hello.txt 2>/dev/null)"
[ "$got" = "$want" ] && exit 0
echo "acceptance check failed: expected: $want, got: $got" >&2
exit 1
SH
mkdir -p plans/fx
cat > plans/fx/plan.md <<'MD'
# Greeting file
Status: approved · Source: eval fixture
Approved: 2026-10-19 by eval

## Goal
The repo has a greeting file that the product team's acceptance check accepts.

## Phases

### Phase 1 — add the greeting
- [ ] Create `hello.txt` with a one-line greeting.
- Verify: `sh check.sh`

## Risks
None.
MD
g add -A && g commit -q -m fixture
g checkout -q -b feat/fx
