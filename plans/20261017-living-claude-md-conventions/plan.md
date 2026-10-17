# Living CLAUDE.md conventions (P-23)
Status: done · Source: upstream/proposals/20261016.md (P-23), `/devkit:plan` request

## Goal
A project's `CLAUDE.md` template records its remotes/push rules and a log of reversed decisions; devkit's own conventions and `check` skill make sure CLAUDE.md stays current with convention changes instead of drifting silently. `UPSTREAM.md`'s P-23 row flips from `◐` to `✅`.

## Context found
- `plugins/devkit/templates/CLAUDE.md:1-41` — the template `/devkit:bootstrap` fills per project. Sections today: `# {{PROJECT_NAME}}`, `# Commands`, `# Stack & layout`, `# Conventions that differ from defaults`, `# Language`, `# Workflow`, `# Gotchas`. Style: plain `#`/`-` prose, `{{PLACEHOLDER}}` tokens, `<!-- TEMPLATE: ... -->` comments for fill/delete instructions, target "under 120 lines" stated in the header comment. `# Workflow` (line 36) already has `- Never push without approval` — the new remotes section restates this per-project with the hook name, it doesn't replace it.
- `plugins/devkit/hooks/hooks.json:13-21` + `plugins/devkit/scripts/block-force-push.sh` — the actual hook is named `block-force-push` (file `block-force-push.sh`), registered on `PreToolUse` / `Bash`. This is the exact name/claim the new template section must reference.
- `plugins/devkit/references/conventions.md:133-139` — "General principles", ends with "Ask before: pushing, opening/merging PRs, deleting files outside scope, running migrations, changing a public API." No existing guidance about keeping CLAUDE.md synced with convention changes or externalizing skill-tunable settings.
- `plugins/devkit/skills/check/SKILL.md:17-20` — Layer 2 bullets today: CLAUDE.md exists/under 120 lines/commands match scripts; PROJECT_BRIEF.md exists; rules have valid `paths:`; local files gitignored. `allowed-tools` is `Bash(ls *) Bash(wc *) Bash(git log *) Bash(git status *)` — `git log` is already permitted, so a new bullet reading recent commits needs no new tool grant.
- `plugins/devkit/skills/bootstrap/SKILL.md:62-67` — Step 5 (Layer 2: Memory & context) fills `templates/CLAUDE.md` from the brief and verified commands; this is where guidance for the two new sections belongs.
- `CHANGELOG.md:5-22` — `[Unreleased]` has `### Added`, `### Changed`, `### Fixed` subsections, one bullet per proposal, ending with `(P-nn)`.
- `UPSTREAM.md:116` — the exact row to flip: `| Living CLAUDE.md; rules in files skills read | \`templates/CLAUDE.md\` | ◐ | P-23 |`.
- Repo's own root `CLAUDE.md` (`/Users/nhatduong/Documents/projects/nhat-kit/CLAUDE.md`) is hand-written, not bootstrapped from the template (this repo is the kit's own source, explicitly "not an app") — out of scope, not touched by this plan.

## Approach
Treat this as a docs-only, patch-sized change across four files: the template gets two new sections (what P-23 is mainly about), `bootstrap` gets one line telling it how to fill them, `conventions.md` gets two new rules for skill/agent authors (CLAUDE.md-in-same-commit, externalize tunables), and `check` gets one new Layer-2 bullet that flags drift. Bookkeeping (`CHANGELOG.md`, `UPSTREAM.md`) closes it out. No code, no new scripts, no new hook — `check` stays pure prompt per its existing design (no executable, `allowed-tools` already covers `git log`).

Rejected alternatives:
- **Add a `check-claude-md-freshness.sh` script instead of a prompt bullet.** Rejected: `check` is deliberately a read-only, tool-light prompt skill today (`allowed-tools: Bash(ls *) Bash(wc *) Bash(git log *) Bash(git status *)`, no script file); adding a script changes that design for a one-rule check and is out of proportion for an S-sized patch.
- **Retrofit all 17 existing skills to externalize their hardcoded tunables into project docs now.** Rejected: that's a cross-cutting refactor across every skill, not an S/patch change; the proposal asks only for forward-looking guidance in conventions.md. Explicitly out of scope (see below).
- **Make N (commits looked back) a user-configurable setting (e.g., a `.claude/` config value).** Rejected: adds a new config surface for a soft heuristic; a documented constant (10) is enough for a patch-sized change and matches `check`'s existing style of hardcoded thresholds (e.g. "under 120 lines").
- **Touch the repo's own root CLAUDE.md to add the two new sections for consistency.** Rejected: it's explicitly hand-written and out of scope per the task description; only the template devkit ships to other projects is in scope.

## Phases

### Phase 1 — Template: two new CLAUDE.md sections
- [x] In `plugins/devkit/templates/CLAUDE.md`, after `# Workflow` and before `# Gotchas`, add:

  ```markdown
  # Remotes & never-push rules
  - Remote: `{{REMOTE_NAME}}` → `{{REMOTE_URL}}`; protected branches: `{{PROTECTED_BRANCHES}}`
  - Force-push is blocked on every branch by the `block-force-push` hook; normal pushes still need the user's approval
  - {{OTHER_PUSH_RULE}}
  <!-- TEMPLATE: delete {{OTHER_PUSH_RULE}} if there is none -->

  # Removed / reversed
  <!-- TEMPLATE: one line per reversed decision, newest first; delete the example once something real is logged -->
  - {{DATE}} — removed/reversed {{THING}}: {{WHY}}
  ```

- [x] Keep both sections short: 3-4 lines each, matching the existing density of `# Conventions that differ from defaults` and `# Gotchas`, so a typical filled file does not approach the 120-line budget (current template is 41 lines; +7 lines keeps it near 48, well under 120).
- Verify: `claude plugin validate plugins/devkit --strict && claude plugin validate .` exits 0; `wc -l plugins/devkit/templates/CLAUDE.md` shows the file grew by ~7 lines (from 41 to ~48).

### Phase 2 — Bootstrap: fill guidance for the two new sections
- [x] In `plugins/devkit/skills/bootstrap/SKILL.md`, Step 5 (Layer 2: Memory & context), add one bullet after the existing `CLAUDE.md` bullet:
  `- Fill "Remotes & never-push rules" from \`git remote -v\` and the branch protection the user confirms (which branch(es) are push-protected); restate that \`block-force-push\` already blocks every force-push. Leave "Removed / reversed" as the template's placeholder line until a decision is actually reversed — never invent an entry.`
- Verify: `claude plugin validate plugins/devkit --strict && claude plugin validate .` exits 0 (frontmatter and skill body still parse); manual read-through confirms the new bullet sits under Step 5 and references only the two new template sections.

### Phase 3 — Conventions: CLAUDE.md-in-same-commit + externalize tunables
- [x] In `plugins/devkit/references/conventions.md`, append to "General principles" (after the existing "Ask before: ..." line):

  ```markdown
  - A skill or agent that changes a project convention (a build/test command, a per-module rule in `.claude/rules/`, a workflow rule) updates that project's `CLAUDE.md` in the same commit. A convention change and a stale `CLAUDE.md` never ship separately.
  - A skill's changeable, project-tunable settings (label names, severity thresholds, area lists, and similar) belong in a project-level file the skill reads at run time, not hardcoded in the skill's own prompt. A user customizing the behavior edits that doc, not devkit's skill files. This is forward-looking guidance for new and changed skills; it does not require retrofitting existing skills (see Out of scope).
  ```

- Verify: `claude plugin validate plugins/devkit --strict && claude plugin validate .` exits 0; `grep -n "same commit" plugins/devkit/references/conventions.md` returns the new line.

### Phase 4 — check: flag a stale CLAUDE.md
- [x] In `plugins/devkit/skills/check/SKILL.md`, Layer 2, add one bullet after the existing `CLAUDE.md` line:
  `- Whether any of the last 10 commits that touched a convention-changing file (\`package.json\` scripts, lint/format config, CI config, \`.claude/rules/*.md\`) also touched \`CLAUDE.md\`. Report: Status = Needs fix with the commit SHA(s) and one-line subject(s) that changed a convention without a matching \`CLAUDE.md\` commit; Status = OK if every such commit also touched \`CLAUDE.md\`, or if there were fewer than 10 commits total. N (10) is a fixed default in this patch, not user-configurable.`
- [x] Use `git log` (already in `allowed-tools`) to find the last 10 convention-changing commits and check whether each also changed `CLAUDE.md` in the same commit, e.g. conceptually: `git log --oneline -n 10 -- package.json '**/.eslintrc*' '**/*.config.*' '.github/workflows/**' '.claude/rules/*.md'` cross-checked against `git log --oneline -n 10 -- CLAUDE.md` (same commit SHAs = OK).
- Verify: re-run `/devkit:check` against a repo with a deliberately mismatched `CLAUDE.md` — in this repo's own history (`nhat-kit`, which has `.claude/rules/*.md` and lint/CI config), confirm the new Layer 2 line appears in the output table with a concrete Status (OK or Needs fix) and, if Needs fix, cites at least one real commit SHA; also run `claude plugin validate plugins/devkit --strict && claude plugin validate .` (exit 0).

### Phase 5 — Bookkeeping: CHANGELOG and UPSTREAM
- [x] In `CHANGELOG.md`, under `## [Unreleased]` → `### Changed`, add:
  `` `templates/CLAUDE.md`: new "Remotes & never-push rules" and "Removed / reversed" sections; `bootstrap` fills them from `git remote -v` and confirmed branch protections. `conventions.md`: a convention change updates the project's `CLAUDE.md` in the same commit; a skill's tunable settings belong in a project doc the skill reads, not hardcoded in the skill. `check` flags a `CLAUDE.md` none of the last 10 convention-changing commits touched (P-23). ``
- [x] In `UPSTREAM.md`, line 116, change the P-23 row's Status cell from `◐` to `✅` (row stays otherwise identical: `| Living CLAUDE.md; rules in files skills read | \`templates/CLAUDE.md\` | ✅ | P-23 |`).
- Verify: `grep -n "P-23" CHANGELOG.md UPSTREAM.md` shows the new changelog line and the updated UPSTREAM.md row with `✅`; `claude plugin validate plugins/devkit --strict && claude plugin validate .` exits 0.

## Risks
| Risk | Signal | Mitigation |
| --- | --- | --- |
| Overall risk is low: every change is prose/template content, no code or hook logic | — | n/a — noted for the record, not a mitigation item |
| New template sections push a typical filled `CLAUDE.md` over the 120-line budget | `bootstrap` Step 8's `wc -l CLAUDE.md` check fails on a real project | Kept both new sections to 3-4 lines each (~7 lines total added to a 41-line template); re-verify on the next real `/devkit:bootstrap` run |
| `check`'s new bullet is vague about "convention-changing file" and flags noise on unrelated commits | A user reports `check` citing commits that didn't actually change a convention | File list is explicit and short (`package.json` scripts, lint/format config, CI config, `.claude/rules/*.md`); revisit the list if real runs show false positives |
| Conventions' new "same commit" rule has no enforcement mechanism (no hook, no CI) beyond `check` and prompt discipline | A convention changes and CLAUDE.md lags for several commits before `check` is run | Acceptable for a patch-sized change; `check`'s new bullet is the detection mechanism; a stronger enforcement (e.g., a pre-commit hook) is a follow-up, not in this patch |

## Out of scope
- Retrofitting any of devkit's 17 existing skills to move their current hardcoded tunables into a project-level doc. Phase 3's rule is forward-looking guidance for skill authors going forward.
- Making N (10, in `check`'s new bullet) user-configurable.
- Any change to the repo's own root `CLAUDE.md` (`/Users/nhatduong/Documents/projects/nhat-kit/CLAUDE.md`) — it is hand-written, not bootstrapped from the template, and explicitly out of scope per the task.
- A new script, hook, or CI job to enforce the "same commit" rule automatically — `check`'s prompt-only bullet is the detection mechanism for this patch.
- Changing which branches are push-protected or any `block-force-push` hook behavior — Phase 1 only restates the existing hook in the per-project template.

Status: approved
