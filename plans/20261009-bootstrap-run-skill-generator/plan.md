---
Status: done
---

# Plan: update bootstrap Layer 3 to use /run-skill-generator

## Goal

Replace the generic `templates/skills/verify/SKILL.md` copy in `bootstrap` with an instruction to run the built-in `/run-skill-generator`. The built-in auto-generates a project-specific run+verify skill and avoids shadowing the built-in `/verify` command (resolves ND-2 from VERIFY_REPORT.md).

## Context found

- `bootstrap/SKILL.md:73` — current Layer 3 step copies `templates/skills/verify/SKILL.md` to `.claude/skills/verify/` and tells the model to fill in the build/run recipe manually.
- `templates/skills/verify/SKILL.md` — a generic template with `name: verify` frontmatter and a placeholder comment. Provides no project-specific value; the model would rewrite it from scratch anyway.
- `/run-skill-generator` (Claude Code built-in, v2.1.215+) — a skill that writes a project-tailored `verify` (and `run`) skill by probing the project's actual build/run commands. Strictly better than a static template.
- Collision: a project-level skill named `verify` shadows the built-in `/verify` command. The built-in skill avoids this by generating the correct content rather than creating a shadow.
- No other skill or agent references the verify template.

## Approach

Two-file change + CHANGELOG entry. No new skill or agent needed.

## Phases

### Phase 1 — Edit bootstrap and remove template (S, ~5 min)

**Change 1:** `plugins/devkit/skills/bootstrap/SKILL.md:73`

Replace:
> `.claude/skills/verify/SKILL.md` from `templates/skills/verify/SKILL.md`: record the build, run, and check recipe that actually worked in step 3 or was discovered in step 1. A skill named `verify` makes Claude run it before every commit.

With:
> Run `/run-skill-generator` so Claude Code writes a project-specific `verify` (and `run`) skill that knows this project's actual build and launch commands. (Built-in since Claude Code v2.1.215; if unavailable, write `.claude/skills/verify/SKILL.md` manually with the recipe from step 3.)

**Change 2:** Delete `plugins/devkit/templates/skills/verify/SKILL.md`. The template is no longer referenced; keeping it would mislead future maintainers.

**Change 3:** Add entry to `CHANGELOG.md [Unreleased]`.

**Verify:** `claude plugin validate plugins/devkit --strict && claude plugin validate .` — both must pass. Confirm `templates/skills/verify/SKILL.md` no longer exists.

## Risks

- **Claude Code version**: `/run-skill-generator` requires v2.1.215+. Mitigated: bootstrap already depends on recent Claude Code features (plugins, frontmatter). The fallback note in the instruction handles older installs gracefully.
- **Existing projects**: projects that already ran bootstrap have their own `.claude/skills/verify/SKILL.md` — those are unaffected (they live in the project repo, not in the plugin).

## Out of scope

- Changing how `ui-verifier` is installed (separate concern).
- Updating other skills or agents that reference verify.
- Removing the verify template from git history (not necessary).

## Red-team notes

*(none — not red-teamed; change is small and low-risk)*
