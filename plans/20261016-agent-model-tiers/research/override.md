# How a subagent's model is chosen

Source: https://code.claude.com/docs/en/sub-agents, read 2026-10-16.

- The frontmatter `model:` accepts an alias (`sonnet`, `opus`, `haiku`, `fable`), a full model ID (same values as `--model`), or `inherit`.
- Precedence, highest first:
  1. the per-invocation `model` parameter of the Agent tool;
  2. the agent's frontmatter `model:` (`inherit` means the main conversation's model);
  3. the `CLAUDE_CODE_SUBAGENT_MODEL` env var;
  4. the main conversation's model.
- `CLAUDE_CODE_SUBAGENT_MODEL_FORCE=1` together with `CLAUDE_CODE_SUBAGENT_MODEL=<model>` makes that model win over both the per-call parameter and the frontmatter. `FORCE` alone does nothing.

**For devkit:** once the agents set a model in frontmatter, `CLAUDE_CODE_SUBAGENT_MODEL` alone no longer overrides them. To run every agent on one model, a user must set both variables.
