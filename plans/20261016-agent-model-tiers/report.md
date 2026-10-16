# Report: Model tiers for agents

## Result
- Status: done
- Done:
  - `fullstack-developer`, `tester`, `researcher` → `model: sonnet`; `deployer` → `model: haiku`; `planner`, `code-reviewer`, `debugger`, `requirements-analyst` stay `inherit`; `git-manager` stays `haiku`
  - `cook` step 1.3: the main session reads each phase's diff before moving on
  - README "Model tiers" section with the override (`CLAUDE_CODE_SUBAGENT_MODEL` + `CLAUDE_CODE_SUBAGENT_MODEL_FORCE=1`), UPSTREAM ✅ P-19, CHANGELOG
- Files: `plugins/devkit/agents/{fullstack-developer,tester,researcher,deployer}.md`, `plugins/devkit/skills/cook/SKILL.md`, `README.md`, `UPSTREAM.md`, `CHANGELOG.md` (modified); `plans/…/{benchmark.md,research/override.md,bench/}` (created)

## Evidence
- **Benchmark** (`benchmark.md`): 2 baseline + 2 tiered headless `/devkit:cook --auto` runs on the same fixture.
  - Median cost $1.82 → $1.27 (−30%).
  - Held-out tests 18/18 in all 4 runs.
  - Review Criticals 1/0 → 0/0.
  - The ship rule is met.
- **Override behavior** (`research/override.md`, from the sub-agents docs): frontmatter beats `CLAUDE_CODE_SUBAGENT_MODEL` unless `CLAUDE_CODE_SUBAGENT_MODEL_FORCE=1` is also set.
- `grep -H '^model:' plugins/devkit/agents/*.md` matches the tier map; `claude plugin validate plugins/devkit --strict && claude plugin validate .` → both "✔ Validation passed"; `scripts/test-hooks.sh` → "All hooks passed."

## Watch
- **Main-session turns went up** (6–13 → 28–34) because of the new diff review.
- **The Sonnet tester wrote fewer of its own tests** (34–37 vs 57–60).

Both are fine on this fixture. Re-check on a larger task.
