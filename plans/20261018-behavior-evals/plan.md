# Behavior evals for devkit
Status: done · Source: P-26 in `upstream/proposals/20261018.md` (replaces the dropped P-7b; also the proof P-29 still lacks)

## Goal
`plugins/devkit/evals/` holds 5 behavior cases that check devkit's most important rules by running the real plugin:
- cook refuses a draft plan;
- plan sync refuses a draft;
- review delegates to `code-reviewer`;
- ship stops an oversized change (P-27);
- cook retries a red phase one tier up (P-29).

They run by hand with `claude plugin eval`, with fixtures from scaffold scripts and a cost cap. `/release` runs them with the right flags. Each case passes on at least 1 run. The P-29 case gives the first real evidence for the escalation rule.

## Context found
- **CLI.** `claude plugin eval` exists in 2.1.292 (`--help` read this session). It finds cases at `<eval dir>/**/case.yaml` or `prompt.md` + `graders/*.md`; the default eval dir is `evals/`.
  - Default flags: `--runs` 3, `--ablation with-without` when a plugin resolves, `--threshold` 1.0.
  - Other flags this plan uses: `--scaffold` (off by default), `--allow-tools`, `--max-cost-usd`, `--no-publish`, and `--json`.
  - Results go to `<plugin>/<eval dir>/results/<timestamp>/`.
  - `claude plugin eval init --bare <name>` writes `prompt.md` (frontmatter `max_turns`, `allowed_tools`) plus `graders/criteria.md` (`type: llm`, `weight`). This was tried in a scratch copy.
- **Format** (`research/plugin-eval-format.md`, from code.claude.com/docs/en/plugin-evals.md):
  - **Grader types:** `regex`, `tool_used` (`tool`, `input_match` is a regex over the JSON input, `min`/`max`), `tool_order`, `file_exists`, `llm` (2-of-3 judge votes, `focus`/target), and `baseline`. `weight` defaults to 1. `arm: with-only|both`.
  - **Scaffold:** runs in an empty workspace for up to 120 s; the agent's cwd is that workspace.
  - **Tool permissions:** gated tools (Bash, Write, Edit) need operator `--allow-tools`; patterns are supported.
  - **Unverified:** whether `tool_used` sees tool calls *inside* subagents, and whether a plugin slash command (including `disable-model-invocation` skills) works as the prompt.
- **Prior art** (agile-squad, read only as an idea source): slash-command prompts (`/squad:review 57`), `tool_used` on `Agent` with `input_match: 'squad:reviewer'`, `max: 0` graders for "never did X", and `fixture.sh` scaffolds. A manual `workflow_dispatch` CI runs `--trust-plugin --scaffold --ablation none --runs N --max-cost-usd X --no-publish`.
- **Rules under test:**
  - `skills/cook/SKILL.md:16-18`: a draft plan → present it and ask, unless `--auto`.
  - `skills/plan/SKILL.md` §7: sync refuses `Status: draft`.
  - `skills/review/SKILL.md:15`: review delegates to `devkit:code-reviewer`.
  - `skills/ship/SKILL.md:14`: pr-size gate 1.
  - `references/conventions.md` "Retry one tier up" (P-29, unproven: `plans/20261018-retry-tier-up/report.md`).
- `.claude/skills/release/SKILL.md:17`: "If `plugins/devkit/evals/` exists: `claude plugin eval plugins/devkit`". This needs the scaffold, ablation, tools, and cost flags.
- The P-29 lesson: a self-contradictory fixture is refused, and a visible verify gets satisfied on the first try. The retry fixture must fail the first attempt for a legitimate, discoverable-after-failure reason.

## Approach
**Changed during cook (user decision, 2026-10-18):** on this machine the eval Bash sandbox refuses to start (`~/.docker` holds a symlink; see `research/spike.md`). So 3 cases that need no Bash are tagged `core` and run now. The 2 cases that need Bash (`ship-stops-oversized`, `cook-retries-tier-up`) are written and tagged `needs-bash`. The run command is split by tag, with caps of $3 and $5 instead of one $10 run. The Goal's "each case passes" holds for the core cases only; see `report.md`.

- One folder per case under `plugins/devkit/evals/<case>/`: `prompt.md` (frontmatter `max_turns`, `runs: 1`, `allowed_tools`, `tags`), `fixture.sh` when state is needed, and `graders/*.md`. Prefer deterministic graders (`tool_used`, `regex`, `file_exists`). Use `llm` only for the reply's meaning.
- Ablation `none`: every case is a devkit slash command, so a no-plugin arm only measures "command not found".
- One documented run command, used by `/release` and by hand:
  ```
  claude plugin eval plugins/devkit --trust-plugin --scaffold --ablation none --runs 1 --max-cost-usd 10 --no-publish \
    --allow-tools Write Edit "Bash(git *)" "Bash(sh check.sh)" "Bash(bash *pr-size.sh *)"
  ```
- `plugins/devkit/evals/README.md` (short): what each case proves, the command, the cost note, and that a red case means a regression or a flaky model, so look at the report.
- Gitignore `plugins/devkit/evals/results/`.
- **Cases** (the original design; the final graders and fixture differ, see `report.md` Review):
  1. `review-delegates`:
     - Fixture: a git repo with one commit on `main` and a feature branch with a small diff.
     - Prompt: `/devkit:review main`.
     - Graders: `tool_used Agent input_match 'devkit:code-reviewer' min 1`, plus `llm` "the reply presents a review with severities".
  2. `cook-refuses-draft`:
     - Fixture: `plans/fx/plan.md` with `Status: draft`.
     - Prompt: `/devkit:cook plans/fx/plan.md`.
     - Graders: `tool_used Agent input_match 'fullstack-developer' max 0`, `tool_used Write max 0` on project files (or `file_exists hello.txt exists:false`), plus `llm` "asks for approval of the plan".
  3. `plan-sync-refuses-draft`:
     - Fixture: a draft plan plus a fake git remote.
     - Prompt: `/devkit:plan sync plans/fx/plan.md`.
     - Graders: `tool_used Bash input_match 'gh issue (create|list)' max 0`, plus `llm` "refuses and says why: the plan is a draft".
  4. `ship-stops-oversized`:
     - Fixture: a repo where the feature branch changes 12 small files, with no build or test commands.
     - Prompt: `/devkit:ship main`.
     - Graders: `tool_used Bash input_match 'pr-size\.sh' min 1`, `tool_used Agent input_match 'git-manager' max 0`, plus `llm` "stops and proposes a split".
  5. `cook-retries-tier-up` (P-29):
     - Fixture: an approved one-phase plan, "Create `hello.txt` with a one-line greeting".
       - Verify: `sh check.sh`.
       - `check.sh` compares the file to a base64-encoded expected line. On failure it prints `expected: hi there, got: <content>`.
       - The first attempt is very likely to write some other greeting, the verify goes red with a clear message, and the retry has what it needs.
     - Prompt: `/devkit:cook plans/fx/plan.md --no-tdd`.
     - Graders:
       - `tool_used Agent input_match '"subagent_type":"devkit:fullstack-developer"' min 2`.
       - `tool_used Agent input_match '"model":"opus"' min 1`.
       - `file_exists hello.txt`.
       - `regex` on files: `hello.txt` equals `hi there`.
- **The spike comes first** (Phase 1). It confirms that a devkit slash command runs as the prompt, that `tool_used` sees the Agent call, and which tool calls the trace includes. It also records the format details the docs left unverified.

Rejected:
- CI on every PR: each run is a paid model call, and the user wants manual runs. An optional `workflow_dispatch` workflow is left for later.
- `runs: 3`: triples cost. One run per case, re-run when red. Raise it later if flakiness shows.
- Cases for `/devkit:task` and `/devkit:issue`: they need GitHub access or network; out of scope for a local, sandboxed suite.

## Phases

### Phase 1: spike, one case end to end (riskiest)
- [x] Write `evals/review-delegates/` (prompt, fixture, 2 graders).
- [x] Run it with the documented command (`--case review-delegates --json $OUT/spike.json`). Record in `research/spike.md`:
  - whether the slash command ran;
  - the grader verdicts;
  - whether the trace contains subagent tool calls;
  - the exact JSON shape `input_match` sees for an Agent call (`subagent_type`, `model` fields);
  - cost and time.
- [x] If slash commands do not run as prompts, stop and re-plan with the user, using natural-language prompts such as "Use /devkit:review on main".
- Verify:
  - `claude plugin validate plugins/devkit --strict` passes, with the evals dir present.
  - The eval exits 0 at threshold 1.0, or the failure is explained in `spike.md`.
  - `spike.md` answers both unverified points.

### Phase 2: the other four cases
- [x] Write `cook-refuses-draft`, `plan-sync-refuses-draft`, `ship-stops-oversized`, and `cook-retries-tier-up`, using what the spike learned.
- [x] Run the full suite once with the documented command and `--json $OUT/suite.json`.
- Verify:
  - Each case scores 1.0, or a red case is re-run once. If it is still red, it is either a real regression (open issue) or a bad grader (fix the grader, not the skill), and the reason is recorded.
  - The P-29 case shows an Agent call with `"model":"opus"`. Record this in `plans/20261018-retry-tier-up/report.md` as the first real evidence, and update UPSTREAM's P-29 note.
  - Total cost is under the `--max-cost-usd 10` cap.

### Phase 3: wiring and docs
- [x] `plugins/devkit/evals/README.md` and the `.gitignore` entry for `plugins/devkit/evals/results/`.
- [x] `.claude/skills/release/SKILL.md:17`: use the documented command. A red case → stop the release and show the report.
- [x] `README.md`, a short "Evals" note with the command. `CHANGELOG.md` `[Unreleased]` → `### Added` (P-26). `UPSTREAM.md`: P-26 → ✅; the 3-tier eval row note. The proposal note under v2.5.0.
- Verify:
  - `git check-ignore -q plugins/devkit/evals/results/x` → exit 0.
  - `grep -c 'ablation none' .claude/skills/release/SKILL.md` → 1.
  - `claude plugin validate plugins/devkit --strict && claude plugin validate .` → pass. `scripts/test-hooks.sh` → exit 0.

## Risks
| Risk | Signal | Mitigation |
| --- | --- | --- |
| Slash commands don't run as eval prompts | The spike's prompt is not recognized | Phase 1 stops and re-plans with natural-language prompts |
| `tool_used` doesn't see subagent calls | Graders on subagent-internal tools never fire | Grade only main-session calls (Agent dispatch, Bash in the main flow), as every case above does |
| Model nondeterminism makes cases flaky | A case flips between runs | Deterministic graders; one re-run rule; tighten the fixture rather than loosening the grader |
| Cost per run | The suite costs dollars per release | `runs: 1`, `--max-cost-usd 10`, manual runs only |
| The P-29 fixture still passes on the first try | No second developer call | The expected line is base64-encoded, so it is only clear from the failure message. If still unproven, record it as inconclusive again, not as passed |
| Scaffold scripts run as the user | — | We author them; they only write inside the temp workspace; `--scaffold` is explicit |

## Out of scope
- CI workflow, `task`/`issue` cases (GitHub/network), mocks for MCP servers, a release.
