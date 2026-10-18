# Report: retry a sent-back phase one model tier up (P-29)

Plan: `plan.md` (2 phases, --fast). Branch `feat/retry-tier-up`, not committed.

## Phases completed
| Phase | Result |
| --- | --- |
| 1: rule and pointers | done (written by the main session: four one-clause edits plus a 6-line section) |
| 2: prove the retry escalates | **inconclusive**; docs done |

## Files changed
- `plugins/devkit/references/conventions.md`: new section "Retry one tier up".
- `plugins/devkit/skills/cook/SKILL.md:26`, `:37`, and `plugins/devkit/skills/task/SKILL.md:53`, `:60`: pointers at the send-back sentences.
- `README.md` model tiers paragraph, `CHANGELOG.md` `[Unreleased]` Changed, `UPSTREAM.md` P-29, and the proposal's v2.5.0 note.

## Evidence
| Command | Result |
| --- | --- |
| `grep -c 'Retry one tier up' plugins/devkit/references/conventions.md` | 1 |
| `grep -lc 'Retry one tier up' plugins/devkit/skills/{cook,task}/SKILL.md \| wc -l` | 2 |
| `git diff --numstat` cook / task | `2 2` / `2 2` |
| `claude plugin validate plugins/devkit --strict && claude plugin validate .` | `✔ Validation passed` ×2 |
| `scripts/test-hooks.sh` | All hooks passed |
| Headless `/devkit:cook` run 1 (plan said "write `hi`", verify expected `hi there`) | The session refused the contradictory plan and asked; 1 developer call, no retry |
| Headless run 2 ("a greeting of your choice", verify `hi there`) | The developer read the verify and passed first try; 1 developer call (`model` unset), no retry; 0 retries to observe |

## Review
1 round: 0 Critical, 2 Warning, 4 Optional. All fixed:
- W1: the tier note now says `report.md` (cook) or the PR report (task).
- W2: the inconclusive runs are recorded in the plan and here; UPSTREAM keeps ✅ with an "unproven by a run" note.
- O1: the FORCE interaction is now "expected to win (not verified)" in conventions and README.
- O2: "same agent type".
- O3: the task pointer is explicit about red checks.
- O4: "e.g. `sonnet` → `opus`".

## Out of scope / open
- Proving escalation needs a forced-red fixture and a tool-call grader: add it as a P-26 eval case.
- Whether `CLAUDE_CODE_SUBAGENT_MODEL_FORCE=1` overrides a per-call `model` is not verified.
