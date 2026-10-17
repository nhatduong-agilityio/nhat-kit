# PR report artifact for every PR — report

Plan: `plans/20261017-pr-evidence-report/plan.md` · Branch: `feat/pr-evidence-report` · Follow-up to P-22

## Phases completed

| Phase | File(s) | Verify |
| --- | --- | --- |
| 1 — Conventions | `plugins/devkit/references/conventions.md` | `claude plugin validate` → pass; all 10 required strings confirmed (heading, title, visualization, placeholder, scrubbing, `Closes #N` rule, body shape, sub-section) |
| 2 — Orchestrators + git-manager | `ship/SKILL.md`, `task/SKILL.md`, `git/SKILL.md`, `git-manager.md` | `claude plugin validate` → pass; all 8 checks confirmed, including: no content-list re-enumeration (structurally prevented), checklist-summary handoff reaches all 4 files, precedence + guard present |
| 3 — Slim both PR templates | `.github/pull_request_template.md`, `plugins/devkit/templates/github/pull_request_template.md` | `claude plugin validate` → pass; byte-identical confirmed; `Risks and impact` kept in place; fallback breadcrumb present in both |
| 4 — Bookkeeping | `CHANGELOG.md`, `UPSTREAM.md`, `README.md` | `grep` confirms all three; `claude plugin validate` + `scripts/test-hooks.sh` → pass |

## Red-team

Both technical and scope passes ran before implementation. 9 findings, all valid, all applied (none rejected) — see the plan's own "Red-team notes" section. The two most significant: **`Risks and impact` was being moved to the artifact by default even though only What/Why/How-tests/Screenshots were named for moving — fixed, it stays inline in both templates**; and **`git-manager` would have silently lost the ability to tick checklist boxes once it only receives a URL it has no tool to open — fixed, a condensed checklist summary now travels alongside the link in every call path**. Also fixed: a new secrets-exposure risk (verification output now published externally for every PR, scrubbing rule extended), a missing "given both" precedence rule, and content-list drift already present in the plan's own draft text (fixed structurally — orchestrators reference the conventions section by name instead of re-enumerating it).

## Code review

`devkit:code-reviewer`: Critical 0 / Warning 0 / Optional 1 (non-blocking — a note that `artifact-design` wasn't found in the repo's own skill directories; this is expected, since it's a Claude Code–bundled skill, not a repo-local one). All 9 red-team findings independently re-verified as landed in the real diff, not just plan prose. Can merge as-is.

## Files changed

- `plugins/devkit/references/conventions.md` — `### UI evidence` renamed/restructured into `### PR report artifact`, generalized to every PR
- `plugins/devkit/skills/ship/SKILL.md` — gate 5/8 + final reply ungated and rewired
- `plugins/devkit/skills/task/SKILL.md` — step 7/8 + final reply, same shape
- `plugins/devkit/skills/git/SKILL.md` — `pr` mode builds+publishes the report, prepares checklist summary + risks text
- `plugins/devkit/agents/git-manager.md` — two-branch PR body logic (artifact-link slim / fallback full), precedence rule, hard `Closes #N` rule, missing-input guard
- `.github/pull_request_template.md` + `plugins/devkit/templates/github/pull_request_template.md` — identically slimmed, `Risks and impact` kept, fallback breadcrumb added
- `CHANGELOG.md` — `[Unreleased]/### Changed` entry (follow-up to P-22)
- `UPSTREAM.md` — P-22 row's Notes cell amended (no new row)
- `README.md` — two lines reworded to reflect every-PR coverage

## Out-of-scope items discovered

None beyond what the plan already excluded (`ui-verifier` mechanics unchanged, `bootstrap/SKILL.md` untouched, no charts/graphs, no new UPSTREAM row, Risks and impact stays in the body, actually building the runtime artifact page is a future `ship`/`task`/`git pr` run's job — all confirmed respected by the code review).

Status: done
