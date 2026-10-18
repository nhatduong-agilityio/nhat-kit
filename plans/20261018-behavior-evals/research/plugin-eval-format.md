# Plugin Eval Case Schema & Grader Reference

## Case Schema

**prompt.md frontmatter** (automatic `schema_version: "1.1"`):  
`name`, `description`, `tags`, `plugins`, `runs` (default 3), `expected_outcome`, `model`, `max_turns` (default 10, max 200), `timeout_seconds` (default 300, max 3600), `allowed_tools` (read-only list), `append_system_prompt`, `env` (keys must be `EVAL_[A-Z0-9_]*`).

**case.yaml** (requires `schema_version: "1.1"`, `name`):  
Top-level: description, tags, plugins, runs, expected_outcome.  
`execution:` { model, max_turns, timeout_seconds, allowed_tools, append_system_prompt, env, prompt }.  
`context:` { scaffold_script, history_file, add_dirs }, `graders:` list.

**Scaffold script**: runs as you, outside sandbox, in empty workspace, 120s limit, exit non-zero → score 0.  
**Agent cwd**: each run starts in an empty working directory.

## Grader Types & Fields

| Type | Options | Passes When |
|------|---------|-------------|
| `regex` | pattern, flags, match, target | Pattern found; `match: not_contains` or `match: "count:N"` |
| `tool_used` | tool, input_match (regex vs JSON input), min (default 1), max (default ∞) | Calls in range |
| `tool_order` | before, after (tool name or {tool, input_match}) | before precedes after |
| `file_exists` | path (glob), exists (default true) | File matches (created only) |
| `llm` | criteria, focus | Judge votes PASS ≥2/3 |
| `baseline` | baseline_file (.jsonl), criteria | Score ≥ reference |

**Frontmatter**: `type` (required), `weight` (default 1), `arm` (`with-only` or `both`).  
**Target/focus values**: `last_message` (default), `trace` (JSON lines), `files`, `{source: file, path}` (show images to llm), `mock_calls`.

## Subagent Tool Calls & Slash Commands (UNVERIFIED)

- **Tool_used inside Agent children**: Docs do not specify whether `tool_used` graders see tool calls made inside subagents spawned via the Agent tool. **UNVERIFIED—needs confirmation via example or implementation**.
- **Slash commands in prompt**: Can a `prompt.md` body be `/devkit:cook plans/x/plan.md`? Docs say "Claude receives the body exactly as you wrote it" but don't address skill invocation. **UNVERIFIED**.
- **Skills with disable-model-invocation**: Can such skills be in a prompt or case? **UNVERIFIED**.

## Defaults & Scoring

- **runs**: 3 per arm; `--runs` overrides.
- **ablation**: `with-without` (default when plugin resolves); `none` halves cost.
- **threshold**: 1.0 (perfect score); exit 1 if case < threshold.
- **judge-model**: Claude Code's background-task model; override with `--judge-model`.
- **cost ceiling**: `--max-cost-usd` checked before each run; partial exit 2.
- **results**: `<eval-dir>/results/<timestamp>/` (add to .gitignore).
- **Installed plugin targets**: results under `./evals/results/` current directory (or `./<dir>/results/` with `--eval-dir`).

## Scoring Rules

- **Weight**: any positive number (default 1).
- **with-only graders** (excluded from without-arm score, scored: false):
  - `tool_used: Skill` (always).
  - `regex` or `llm` on `mock_calls` (mocked servers only).
  - Custom `arm: with-only`.
- **Overrides**: `arm: both` forces scoring both arms; `--ablation none` disables exclusion.

## Bash Permissions in Evals

- **Case grants**: `allowed_tools: [Read, Glob, Grep, Skill]` (read-only, no grant needed).
- **CLI grant**: `--allow-tools Bash "Bash(npm test *)"` (pattern syntax; supports per-command rules).
- **Bash isolation**: OS-level sandbox confines writes to workspace/home, blocks network (except domains granted via `WebFetch(domain:...)`).
- **Windows**: WSL2 required; Linux needs `bubblewrap` + `socat`.

## Result Metadata

**aggregate-result.json** (`schemaVersion: 1`):  
- `partial`, `partialReason` (cost_ceiling, interrupted, auth_failed)
- `cases[].arms.{with,without}[].{graders[], score, error, aborted, skippedPaidGraders}`
- `aggregates.{overallScore, casesPassed, casesTotal, meanDelta}`

---

## Result

Comprehensive coverage from official docs. **Unverified gaps**: subagent tool visibility, slash-command prompts, disable-model-invocation skill behavior. All others sourced: https://code.claude.com/docs/en/plugin-evals.md.
