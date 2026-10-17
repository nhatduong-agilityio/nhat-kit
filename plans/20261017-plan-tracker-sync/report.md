# Plan ↔ tracker sync (P-25) — report

Plan: `plans/20261017-plan-tracker-sync/plan.md` · Branch: `feat/plan-tracker-sync`

## Phases completed

| Phase | File | Verify |
| --- | --- | --- |
| 1 — Conventions | `plugins/devkit/references/conventions.md` | `claude plugin validate` → pass; `(#42)` example and new "Plan ↔ tracker sync" subsection confirmed; no `plan-sync` label |
| 2 — `sync <plan.md>` mode | `plugins/devkit/skills/plan/SKILL.md` | `claude plugin validate` → pass; **live round-trip run for real** against `nhatduong-agilityio/devkit-forms-scratch` (user-confirmed) — see below |
| 3 — Bookkeeping | `CHANGELOG.md`, `UPSTREAM.md`, `README.md` | `grep` confirms all three; `claude plugin validate` + `scripts/test-hooks.sh` → pass |

## Red-team

Both technical and scope passes ran before implementation. 8 findings, all valid, all applied (none rejected) — see the plan's own "Red-team notes" section for detail. Biggest ones: dropped a write-only `plan-sync` label, added crash-safety (search-by-title before creating an issue), mandated `--body-file` over inline `--body` to avoid shell-injection from backticked paths, defined broken-link handling for a deleted/inaccessible issue.

## Live round-trip evidence (real GitHub side effects, user-confirmed before running)

Ran against `nhatduong-agilityio/devkit-forms-scratch`:
1. Push: searched by exact title (no match) → created issue #9 with `--body-file` → appended `(#9)` to the test phase heading.
2. Re-ran the exact-title search as if the suffix write had failed → found issue #9 again, confirming the crash-safety dedup path (no duplicate).
3. `gh issue close 9` → re-ran pull → issue read as `CLOSED` → phase's checkbox ticked.
4. Pointed the suffix at `(#99999)` (nonexistent) → `gh issue view 99999` failed cleanly (exit 1) → exactly the signal pull's broken-link handling catches.
5. Cleanup: `gh issue delete 9 --yes`, deleted throwaway test plan file. Confirmed via follow-up search: zero test issues remain.

## Code review

`devkit:code-reviewer`: Critical 0 / Warning 0 / Optional 2 (both minor documentation nits, no action needed — a narrow theoretical race already covered by the plan's accepted "no lock" risk, and a push-before-pull *listing* order in prose that doesn't contradict the actual pull-first execution order). Can merge as-is.

## Files changed

- `plugins/devkit/references/conventions.md` — `(#N)` phase-heading suffix rule + new "Plan ↔ tracker sync" section
- `plugins/devkit/skills/plan/SKILL.md` — `argument-hint` + `sync <plan.md>` mode + new `## 7. Sync (plan ↔ tracker)` section
- `CHANGELOG.md` — `[Unreleased]/### Changed` entry (P-25)
- `UPSTREAM.md` — P-25 status `⏳` → `✅`, devkit column filled in
- `README.md` — new row for `/devkit:plan sync <plan.md>`

## Out-of-scope items discovered

None beyond what the plan already excluded (GitHub Projects board backend, ADO/Trello, auto-closing from cook/ship, full bidirectional overwrite, concurrent-sync locking — all confirmed respected by the code review).

Status: done
