# Model tiers for agents
Status: done · Source: P-19 in `upstream/proposals/20261016.md`

## Goal
devkit's subagents run on a model that fits their role, as the deck's "Opus advises, cheaper models run" practice suggests. Judgment roles keep the main session's model, builders run on Sonnet, and mechanical runners run on Haiku. A before/after `/devkit:cook` benchmark shows lower cost with the same result quality before the change ships.

## Context found
- `plugins/devkit/agents/*.md:5`: every agent is `model: inherit` except `git-manager`, which is `model: haiku`.
- `plugins/devkit/skills/cook/SKILL.md`:
  - lines 23-27: per phase, `tester` (write-first), then `fullstack-developer`, then the main session runs the verify command;
  - lines 33-37: then `tester run/gaps`, `verify`, and the `code-reviewer` loop.
  - The main session runs the verify command but does not read the phase diff itself.
- The Agent tool's `model` parameter takes precedence over the agent's frontmatter and over "the configured default subagent model", so a per-call override is possible. The name of the global override setting still needs confirming in the docs; it is assumed to be the `CLAUDE_CODE_SUBAGENT_MODEL` env var.
- Benchmark tooling:
  - `claude -p --output-format json` reports cost, per-model usage, duration and turns.
  - `--plugin-dir` loads a specific plugin checkout.
  - Node 24 is available, so a fixture can use `node --test` with no dependencies. `pytest` is not installed.
- `UPSTREAM.md:112`: "Opus advises, Sonnet builds, Haiku runs", currently ⏳ P-19.

## Approach
**Tier map** (by what each role must get right):

| Agent | Today | New | Why |
| --- | --- | --- | --- |
| `planner` | inherit | inherit | Decides scope and sequence (advisor) |
| `code-reviewer` | inherit | inherit | Final quality gate (advisor) |
| `debugger` | inherit | inherit | Root-cause reasoning; called only when a fix didn't hold |
| `requirements-analyst` | inherit | inherit | Finds gaps in specs; mistakes are expensive later |
| `fullstack-developer` | inherit | **sonnet** | Implements an approved, scoped phase (builder) |
| `tester` | inherit | **sonnet** | Writes tests first from ACs, which takes judgment (builder, not runner) |
| `researcher` | inherit | **sonnet** | Reads and summarizes docs with sources (builder) |
| `deployer` | inherit | **haiku** | Runs one command and reports its output (runner) |
| `git-manager` | haiku | haiku | Unchanged (runner) |

- **`cook` step 1.3:** after the phase's verify command passes, the main session reads the phase diff (`git diff`) against the plan before ticking the phase. This keeps the advisor reviewing every phase, as the deck asks.
- **Escape hatch, documented in the README:** run everything on one model with the global subagent-model override (name confirmed in Phase 1), or override one call with the Agent tool's `model` parameter.

Rejected alternatives:
- `tester` on Haiku: write-first tests define "done", so cheap mistakes there cost the most later.
- `researcher` on Haiku: summarizes sources the plan relies on; Sonnet is the safer floor.
- Tiers chosen by the skill at call time instead of in frontmatter: every skill would repeat the choice. Frontmatter is one place, and per-call override still exists.

## Phases

### Phase 1: Benchmark harness and baseline (riskiest: the numbers decide whether the change ships)
- [x] Confirm the global subagent-model override setting and its precedence against frontmatter in the Claude Code docs (`code.claude.com/docs/en/sub-agents`, settings). Record it in `plans/<…>/research/override.md`.
- [x] Build a fixture in the scratchpad: a tiny Node project (`src/`, `node --test`) with an approved two-phase `plan.md`. Example: add `slugify(text)` with Unicode, separator and max-length rules, then a `--slug` CLI flag. Also write a **held-out acceptance test file** that cook never sees.
- [x] Write `bench.sh` that:
  1. copies the fixture to a fresh directory;
  2. runs `claude -p --plugin-dir <checkout> --output-format json --permission-mode acceptEdits --allowedTools "Bash(node *)" "Bash(git *)" "/devkit:cook plans/…/plan.md --auto"`;
  3. then runs the held-out tests;
  4. prints cost, the per-model usage split, duration, turns, held-out pass/fail, and the number of Critical findings from the reviewer.
- [x] Baseline: 2 runs on `main` (all `inherit`).
- Verify: `bench.sh` prints the full row for both baseline runs, and the held-out tests pass on the baseline (otherwise the fixture is too hard and must be simplified first).

### Phase 2: Apply the tiers
- [x] Set `model:` in `fullstack-developer.md`, `tester.md`, `researcher.md` (sonnet) and `deployer.md` (haiku) as in the tier map.
- [x] `cook/SKILL.md` step 1.3: add the main-session diff review.
- Verify:
  - `grep -H '^model:' plugins/devkit/agents/*.md` matches the tier map.
  - `claude plugin validate plugins/devkit --strict` passes.

### Phase 3: Benchmark after, and decide
- [x] Run `bench.sh` 2 times on this branch.
- [x] Ship rule: the held-out tests pass in both runs, Criticals are no higher than the baseline, and the median cost is at least 25% lower. If quality drops, move the role whose output failed back to `inherit` and rerun once. If the cost drop is under 25%, report the numbers and let the user decide.
- Verify:
  - `plans/<…>/benchmark.md` has a before/after table (cost, the Opus/Sonnet/Haiku usage split, duration, held-out result, Criticals) for all 4 runs.
  - The per-model split shows Sonnet and Haiku tokens in the after runs.

### Phase 4: Docs
- [x] `README.md`: a short "Model tiers" note covering the table above (condensed), the per-call override, and the global override.
- [x] `UPSTREAM.md:112`: change to ✅ P-19.
- [x] `CHANGELOG.md` `[Unreleased]` → Changed: agent model tiers, with the benchmark numbers, and the `cook` diff review.
- Verify:
  - `grep -n 'Model tiers' README.md` prints a line.
  - `grep -n 'P-19' UPSTREAM.md` shows ✅.
  - Both validate commands and `scripts/test-hooks.sh` pass.

## Risks
| Risk | Signal | Mitigation |
| --- | --- | --- |
| Sonnet builders make more mistakes (High) | The held-out tests fail, or more Criticals in the after runs | The ship rule: revert that role to `inherit`. The reviewer (advisor tier) and the new main-session diff review catch the rest |
| The benchmark is too noisy to decide on with 2 runs (Medium) | Baseline runs differ by more than 30% in cost | Report the spread; add a third run per side only if the two disagree |
| Benchmark spend (Medium) | Each cook run costs real money | Small fixture, `--max-turns` cap, 4 runs total (6 at most) |
| `--auto` cook in a scratch dir does something unexpected (Low) | Files changed outside the fixture | Fresh copy per run, scratchpad only, `acceptEdits` plus a narrow Bash allowlist, no push |
| A user's main session is Haiku, so `sonnet` builders are an upgrade (Low) | — | Fine by design; the global override covers single-model setups |

## Out of scope
- Effort levels per agent.
- Changing models inside skills other than `cook` (they inherit the frontmatter automatically).
- `/advisor` wiring (already suggested in `plan` for high-risk plans).
