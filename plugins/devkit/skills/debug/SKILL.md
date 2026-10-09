---
name: debug
description: Systematically find the root cause of a hard bug (flaky, production-only, strange behavior, a regression from an unknown commit) before fixing. Diagnosis only; fix with /devkit:fix once the user agrees.
argument-hint: "<symptom | log | reproduction command>"
---

# Debug

Symptom: `$ARGUMENTS`

Conventions: `${CLAUDE_PLUGIN_ROOT}/references/conventions.md`.

1. Gather before delegating: the exact symptom, environment (local/staging/prod, browser), since when, recent changes (`git log --oneline -15`). Ask the user at most 2 questions for what you can't find yourself (production logs, user steps).
2. The bug could sit in several layers (UI, API, data, infrastructure) → run 2 `devkit:debugger` subagents in parallel, one per suspected layer. Otherwise run one.
3. A regression with a known good commit → ask the debugger to use `git bisect` with an automated reproduction command.
4. Synthesize: a hypothesis table (tested, result), the root cause with evidence, a confidence level, a proposed fix and regression test.
5. Low confidence → say exactly what's needed (logs, access, sample data); don't propose a speculative fix.
6. Ask the user whether to fix. If yes → follow the `/devkit:fix` procedure using the root cause found.
