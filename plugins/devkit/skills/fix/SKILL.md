---
name: fix
description: Quickly fix a specific defect (error message, stack trace, failing test, build/lint/type error, describable bug) — reproduce, find the root cause, make a minimal fix, add a regression test, prove it's gone.
argument-hint: "<error | failing command | bug description>"
---

# Fix

Defect: `$ARGUMENTS` (empty → use the latest error in the conversation, or run the typecheck/lint/test commands from `CLAUDE.md` to find one).

Conventions: `${CLAUDE_PLUGIN_ROOT}/references/conventions.md`.

1. **Reproduce**: find the command that produces the error (test, build, typecheck, request…). Run it and record the output. Can't reproduce → ask the user for reproduction steps; don't guess a fix.
2. **Classify**:
   - Obvious cause (typo, wrong import, wrong type, lint error, assertion out of date after an intentional change) → fix it in step 3.
   - Unclear, multi-layered, or a previous fix didn't hold → delegate to the `devkit:debugger` subagent with the symptom and the reproduction command; use the root cause it returns.
3. **Minimal fix** at the root cause. Never disable tests, add `@ts-ignore`/`eslint-disable`, swallow errors with try/catch, or loosen assertions.
4. **Regression test**: for a behavior bug, add a test that fails before the fix and passes after it (delegate to `devkit:tester` if needed).
5. **Prove it**: re-run the reproduction command → error gone; run related tests + typecheck/lint for the changed files.
6. **Report** in 4 lines: root cause (`path:line`), the fix, the evidence, other places that may share the bug. Don't commit.

After 3 failed fix attempts: stop, summarize what was tried, and propose `/devkit:debug` or ask the user.
