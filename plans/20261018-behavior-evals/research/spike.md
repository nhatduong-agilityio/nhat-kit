# Spike: one eval case end to end (2026-10-18)

Case `evals/review-delegates`, `claude plugin eval plugins/devkit --case review-delegates --trust-plugin --scaffold --ablation none --runs 1 --max-cost-usd 3 --no-publish` (CLI 2.1.292).

| Question | Answer | Evidence |
| --- | --- | --- |
| Does a devkit slash command run as the prompt (incl. `disable-model-invocation`)? | Yes | `/devkit:review main` ran the skill; score 1.0, both graders passed (2 runs) |
| Does `tool_used` see the main session's Agent call? | Yes | "Agent called 1x (expected 1..∞)" |
| Does the trace include tool calls inside subagents? | Yes, with `parent_tool_use_id` | kept trace: 8 tool_use, 5 inside the subagent (`sub:Read` 4, `sub:Glob` 1) |
| Agent input shape for `input_match` | `{"subagent_type": "devkit:code-reviewer", "description": …, "run_in_background": false, "prompt": …}`; `model` appears only when passed | trace; regexes must allow optional spaces after `:` |
| Cost / time | $0.20–0.25 per run, ~45 s | `costUsd` 0.250 and 0.199 |
| Bash in evals on this machine | **Blocked** | With `--allow-tools "Bash(git *)"` the run aborted: "the Docker (~/.docker, DOCKER_CONFIG) credential store … holds a symbolic link inside it, so the Bash sandbox cannot reliably exclude it — a Bash-granting evaluation cannot run here" |

Consequences: cases that need Bash (`ship-stops-oversized` runs `pr-size.sh`; `cook-retries-tier-up` runs `sh check.sh`) cannot run here until `~/.docker` holds no symlink (or `DOCKER_CONFIG` points at a plain directory). Unknown: whether `tool_used` counts subagent-internal calls (not needed: every planned grader targets main-session calls).
