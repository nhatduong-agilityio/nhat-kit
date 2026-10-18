# Retry a sent-back phase one model tier up
Status: done · Source: P-29 in `upstream/proposals/20261018.md` · Mode: --fast

## Goal
When `/devkit:cook` or `/devkit:task` sends work back to a cheaper subagent, the retry runs on the next model tier. This covers a red verify, and a review or test finding the subagent must fix. The tiers are `haiku → sonnet → opus`. So a second attempt by `fullstack-developer` (default `sonnet`) runs on `opus`. The first attempt and every unrelated delegation keep the agent's own `model:`. The extra cost goes only where the cheaper run failed.

## Context found
- `plugins/devkit/skills/cook/SKILL.md:25`: step 1.2 gives a phase to `devkit:fullstack-developer`.
- `plugins/devkit/skills/cook/SKILL.md:26`: step 1.3 says "Red → send it back to the developer with the failing output (at most twice); still red → `devkit:debugger`". That is the retry point.
- `plugins/devkit/skills/cook/SKILL.md:37`: after review, fixes of Critical and Warning findings loop at most 3 times.
- `plugins/devkit/skills/task/SKILL.md:53`: step 6.2 gives each phase to `devkit:fullstack-developer`. `:60`: step 7 has code-reviewer findings fixed.
- Agent `model:` frontmatter: `fullstack-developer`, `tester`, `researcher`, `security-scanner` → `sonnet`. `deployer`, `git-manager` → `haiku`. The rest → `inherit` (`agents/*.md:5`).
- The Agent tool's `model` override accepts `sonnet | opus | haiku | fable`, not `inherit` (tool schema in this session). P-29's "`model: inherit`" wording is therefore corrected to a concrete next tier.
- `README.md:35-42`: model tiers table, plus the `CLAUDE_CODE_SUBAGENT_MODEL` + `CLAUDE_CODE_SUBAGENT_MODEL_FORCE=1` override note. When forced, every agent runs on one model and escalation has no effect. That is fine; the note says so.
- `references/conventions.md`: the shared rules both skills already point to. One short section here keeps cook and task in sync, and is the place for the tier table.

## Approach
Final wording lives in the conventions' "Retry one tier up" section; the notes below are the original plan.

- New conventions section "Retry one tier up" (≤ 6 lines):
  - When work goes back to the same subagent because its verify was red or a review or test finding must be fixed, pass the Agent `model` override one tier above that agent's `model:`: `haiku → sonnet`, `sonnet → opus`.
  - Agents on `inherit`, or already on `opus`, keep their model.
  - Only the retry escalates. A new phase starts again at the agent's default.
  - Name the tier used in the progress line and in `report.md` (e.g. "Phase 2: retry 1 on opus").
  - With `CLAUDE_CODE_SUBAGENT_MODEL_FORCE=1`, the forced model wins.
- `cook/SKILL.md:26`: "send it back to the developer with the failing output, one tier up per the conventions' 'Retry one tier up' (at most twice)". `:37`: fixes delegated after review use the same rule.
- `task/SKILL.md:53` and `:60`: the same one-clause pointer where a phase or a review fix goes back to `fullstack-developer`.
- `README.md` model tiers paragraph: one sentence saying retries run one tier up.

Rejected:
- Passing `model: inherit`: not a valid Agent override value.
- Escalating every attempt (sonnet → opus → fable): the second retry already goes to `debugger` (inherit), which is the existing escalation path.
- A per-project setting to turn it off: no need yet. `CLAUDE_CODE_SUBAGENT_MODEL_FORCE` already pins one model.

## Phases

### Phase 1: rule and pointers
- [x] Add the "Retry one tier up" section to `plugins/devkit/references/conventions.md`.
- [x] Update `plugins/devkit/skills/cook/SKILL.md:26` and `:37`, and `plugins/devkit/skills/task/SKILL.md:53` and `:60`, with the one-clause pointer.
- [x] `README.md`: one sentence in the model tiers paragraph.
- Verify:
  - `grep -c 'Retry one tier up' plugins/devkit/references/conventions.md` → 1. `grep -lc 'Retry one tier up' plugins/devkit/skills/{cook,task}/SKILL.md | wc -l` → 2.
  - `git diff --numstat -- plugins/devkit/skills/cook/SKILL.md plugins/devkit/skills/task/SKILL.md` → each file ≤ 2 added and ≤ 2 deleted.
  - `claude plugin validate plugins/devkit --strict && claude plugin validate .` → pass. `scripts/test-hooks.sh` → exit 0.

### Phase 2: prove the retry escalates
- [x] Scratch fixture (not committed): `git init`, plus a one-phase approved `plans/fx/plan.md`.
  - The phase says "create `hello.txt` containing `hi`".
  - Its Verify is `grep -qx 'hi there' hello.txt`. This mismatch is deliberate, so the first attempt goes red and the failing output tells the retry what is expected.
- Verify:
  - Run `claude --plugin-dir "$KIT/plugins/devkit" -p "/devkit:cook plans/fx/plan.md --no-tdd" --output-format stream-json --verbose --permission-mode acceptEdits --allowedTools "Read,Write,Edit,Agent,Bash(grep *),Bash(git *),Read($KIT/plugins/devkit/**)" > "$OUT/cook.jsonl"`.
  - Extract the `Agent` tool_use events with `subagent_type` `devkit:fullstack-developer` (`jq`): ≥ 2 calls. The first has no `model` (or `sonnet`); a later one has `"model":"opus"`.
  - `grep -qx 'hi there' hello.txt` passes at the end.
  - `jq -s '[.[]|select(.type=="result")] | if length==1 then .[0].permission_denials|length else error("no result") end'` → 0.
  - If the model happens to write `hi there` on the first try (no retry), rerun once with a different mismatch. If it still never retries, record the run as inconclusive rather than passing.
  - **Result: inconclusive (2 runs).** Run 1: the cook session refused the self-contradictory plan and asked which content was right (no retry). Run 2: the developer read the verify and wrote `hi there` on the first try (one `fullstack-developer` call, no retry). A deterministic proof needs a forced-red fixture plus a tool-call grader, which is P-26.
- [x] Docs: `CHANGELOG.md` `[Unreleased]` → `### Changed` (P-29). `UPSTREAM.md` P-29 → ✅. Note in the proposal under v2.5.0.
- Verify: `grep -c '✅ | P-29' UPSTREAM.md` → 1. Validate passes.

## Risks
| Risk | Signal | Mitigation |
| --- | --- | --- |
| Cost rises on every phase | Opus calls on first attempts | The rule escalates only on a send-back. Phase 2 checks that the first call has no `opus` |
| The main session forgets the override on a retry | The transcript shows the retry without `model` | One rule in conventions, pointed to from both skills' retry sentences. P-26 evals can lock it in later |
| The fixture never triggers a retry | Only one developer call | A deliberate verify mismatch; rerun once, else mark inconclusive |
| A forced model env var makes escalation a no-op | — | Documented in the rule and the README |

## Out of scope
- Escalation for `tester`/`researcher` retries outside cook and task, a cost benchmark (P-19 has one), and a release.
