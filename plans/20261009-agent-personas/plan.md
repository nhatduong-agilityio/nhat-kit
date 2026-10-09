---
Status: done
---

# Plan: add expert-persona headers to all 8 agents

## Goal

Add a concrete role title to each agent's opening instruction line. A specific title ("Staff Engineer", "QA Lead", "Senior SRE") anchors the model's persona more firmly than a task description alone, matching the ClaudeKit v2.14.0 agent upgrade pattern. Keep every change to one sentence or less; don't alter the agents' constraints or logic.

## Context found

Current first-instruction lines per agent:

| Agent | Current first line | Has persona? |
| --- | --- | --- |
| `code-reviewer` | "You are a senior reviewer, not the author of this code." | Partial |
| `debugger` | "You diagnose; you don't cure." | No |
| `fullstack-developer` | "You implement exactly one phase." | No |
| `git-manager` | "You perform the assigned git operation, briefly and safely." | No |
| `planner` | "You are a tech lead writing a plan." | Yes (light) |
| `requirements-analyst` | "You are a business analyst and tech lead." | Yes (good) |
| `researcher` | "You answer ONE assigned research question and don't wander into others." | No |
| `tester` | "You own tests and never write business code." | No |

## Approach

One phase: 8 targeted in-line edits. Each change either upgrades the existing first sentence or prepends a role title. CHANGELOG entry added.

## Phases

### Phase 1 — Edit all 8 agent files (S, ~10 min)

Exact replacements (old → new first-instruction line):

**code-reviewer.md**
- Old: `You are a senior reviewer, not the author of this code. You only read; you never edit.`
- New: `You are a Staff Engineer acting as an independent reviewer — not the author of this code. You only read; you never edit.`

**debugger.md**
- Old: `You diagnose; you don't cure.`
- New: `You are a Senior SRE and debugging specialist. You diagnose; you don't cure.`

**fullstack-developer.md**
- Old: `You implement exactly one phase.`
- New: `You are a senior full-stack developer. You implement exactly one phase.`

**git-manager.md**
- Old: `You perform the assigned git operation, briefly and safely.`
- New: `You are a senior engineer responsible for clean, safe version control. You perform the assigned git operation briefly and safely.`

**planner.md**
- Old: `You are a tech lead writing a plan.`
- New: `You are a Staff Engineer and tech lead writing a plan.`

**requirements-analyst.md**
- Old: `You are a business analyst and tech lead.`
- New: `You are a senior business analyst and tech lead.`

**researcher.md**
- Old: `You answer ONE assigned research question and don't wander into others.`
- New: `You are a senior engineer and technical researcher. You answer ONE assigned research question and don't wander into others.`

**tester.md**
- Old: `You own tests and never write business code.`
- New: `You are a QA Lead. You own tests and never write business code.`

Add CHANGELOG entry under `[Unreleased]`.

**Verify:** `claude plugin validate plugins/devkit --strict` — must pass. Confirm all 8 agent `description` fields are still under 300 chars (unchanged).

## Risks

- Persona lines must not change agent constraints or tool lists — all edits are first-sentence only.
- `git-manager` runs on Haiku; the persona is especially useful there.
- `requirements-analyst` already has a strong persona — "senior" is a minor upgrade to stay consistent.

## Out of scope

- Adding detailed backstory or multi-sentence personas (would bloat agents).
- Changing agent `description` frontmatter, tools, or model.

## Red-team notes

*(none — not red-teamed; 8 one-line text edits)*
