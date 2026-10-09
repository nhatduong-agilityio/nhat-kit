---
name: test
description: Run the tests related to the current change (diff-aware), write tests for a given target, or find and fill coverage gaps.
argument-hint: "[run | write <file|module|SPEC> | gaps] [base-branch]"
---

# Test

Input: `$ARGUMENTS` (empty = `run`).

Conventions: `${CLAUDE_PLUGIN_ROOT}/references/conventions.md`.

- `run` → have the `devkit:tester` subagent run in `run` mode, with the base being the second argument or the main branch.
- `write <target>` → `devkit:tester` in `write-first` mode if the target is an unimplemented SPEC/plan; otherwise write tests for the target's existing behavior and make them pass.
- `gaps` → `devkit:tester` in `gaps` mode on the current change.

After the agent returns:
1. Re-run the test command it reported to confirm the result yourself.
2. Failing because of the new change → propose `/devkit:fix <command>`; flaky → report the test name and frequency; pre-existing failure → note it, don't fix it if out of scope.
3. Reply with: pass/fail counts, new test files, issues to handle in priority order.
