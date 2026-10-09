---
Status: done
---

# Plan: re-add /doctor prompt-audit to check skill

## Goal

Re-add `/doctor prompt-audit` as a suggested action in `check/SKILL.md`. During the Phase 1 static review we removed it thinking it was an unknown sub-command; the Claude Code docs confirm it is real and ships with v2.1.283+. Add a version caveat so users on older versions aren't confused.

## Context found

- `check/SKILL.md:31` — current text suggests `/devkit:bootstrap`, `/devkit:review`, and `/doctor` (full health-check). No mention of `prompt-audit`.
- Fix #1 in v2.0.1 removed `/doctor prompt-audit` and replaced it with `/devkit:review` + `/doctor`. Both of those additions were correct and should stay; we're adding `prompt-audit` alongside them.
- Confirmed in Claude Code docs: `/doctor [prompt-audit [path]]` is a skill sub-command requiring v2.1.283+. It audits `CLAUDE.md` instructions for conflicts and redundancies, which is distinct from `/devkit:review` (which reviews CLAUDE.md against the project's conventions).

## Approach

Single-line edit on `check/SKILL.md:31`. No other file changes needed beyond CHANGELOG.

## Phases

### Phase 1 — Edit check/SKILL.md (XS, ~2 min)

Replace line 31:

> Suggest `/devkit:bootstrap` to fill gaps, `/devkit:review` to review `CLAUDE.md` for conflicting instructions, and `/doctor` (Claude Code built-in) for a full installation health-check.

With:

> Suggest `/devkit:bootstrap` to fill gaps, `/devkit:review` to review `CLAUDE.md` for conflicting instructions, `/doctor` (Claude Code built-in) for a full installation health-check, and `/doctor prompt-audit` (v2.1.283+) to audit `CLAUDE.md` instructions for internal conflicts and redundancies.

Add entry to `CHANGELOG.md [Unreleased]`.

**Verify:** `claude plugin validate plugins/devkit --strict` — must pass.

## Risks

None significant. The version caveat `(v2.1.283+)` prevents confusion on older installs. The suggestion is advisory; check is read-only.

## Out of scope

- Updating line 23 (`verify/SKILL.md` check item) — separate concern from P-1 follow-up if needed.
- Changing how `/devkit:review` works.

## Red-team notes

*(none — not red-teamed; single-line wording change)*
