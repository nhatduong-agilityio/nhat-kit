# Personal memory in retro (P-24)
Status: done · Source: `upstream/proposals/20261016.md` P-24 ("Personal memory in retro")

## Goal
`retro` routes personal preferences to Claude Code's built-in auto memory (not `CLAUDE.local.md`) when the feature is available for the project, falling back cleanly when it isn't, and optionally folds in `/insights` output when present. `check` reports, informationally, whether this project's auto memory is unused. `UPSTREAM.md` row for P-24 flips `◐` → `✅`.

## Context found
- `plugins/devkit/skills/retro/SKILL.md:11` — step 1, the review step; needs the optional `/insights` note.
- `plugins/devkit/skills/retro/SKILL.md:12-17` — step 2's five destination buckets; only the personal-preference bullet (`:17`) changes.
- `plugins/devkit/skills/check/SKILL.md:5` — `allowed-tools: Bash(ls *) Bash(wc *) Bash(git log *) Bash(git status *)`; `ls`/`wc` already cover "does a file exist and have content", so the new bullet needs no new tool grant.
- `plugins/devkit/skills/check/SKILL.md:17-21` — Layer 2 (Memory) bullets; new bullet appends after the existing four, same read-only/informational style as the P-23 drift bullet at `:19`.
- `UPSTREAM.md:117` — the row to flip: `| Personal memory for repeated corrections | \`retro\` | ◐ | P-24 |`.
- `UPSTREAM.md:102` — existing note "`/team-onboarding`, `/insights` | ⊘; P-24 may feed `/insights` into `retro`" confirms `/insights` is a Claude Code built-in report, not something devkit builds or can invoke.
- `CHANGELOG.md:16-22` — `[Unreleased]/### Changed`, one bullet per proposal ending `(P-nn)`; P-23's bullet at `:22` is the pattern to follow for P-24.
- `/Users/nhatduong/.claude/projects/-Users-nhatduong-Documents-projects-nhat-kit/memory/` — confirmed directly during planning: no `MEMORY.md`, no memory files. Real, current state for this repo, not hypothetical; `check`'s new bullet should report "auto memory unused" for this repo today.
- Memory mechanics (confirmed first-hand in this session, not guessed): a project's memory lives at `~/.claude/projects/<sanitized-project-path>/memory/`, with an index `MEMORY.md` (one line per entry: `- [Title](file.md) — hook`) and individual files carrying YAML frontmatter (`name`, `description`, `metadata.type` ∈ `user`/`feedback`/`project`/`reference`). For personal preferences the matching type is `feedback` ("guidance the user has given about how to approach work").
- `CLAUDE.md:24` (repo root) — "Adding or renaming a skill/agent: update `README.md`, `UPSTREAM.md`, and `[Unreleased]` in `CHANGELOG.md`." This patch edits two existing skills' prompts; it adds/renames nothing, so `README.md` is not touched (verified the rule's trigger condition does not apply).
- No `.claude/rules/*.md` exist in this repo (`Glob .claude/rules/*.md` → no files), so no rule file needs updating for this change.

## Approach
Keep `retro`'s existing five destination buckets (CLAUDE.md, rules, new skill, hook, personal-preference) exactly as they are, and change only the personal-preference bullet's *destination* from `CLAUDE.local.md` to auto memory (with a fallback to `CLAUDE.local.md` when auto memory isn't available for the project). Add a one-line note to `retro` step 1 so it reads `/insights` output as extra input when already present in the conversation. Add one new, informational Layer 2 bullet to `check` reporting whether this project's auto memory is unused. Update `CHANGELOG.md` and flip the `UPSTREAM.md` row.

This is the smallest change that satisfies the literal ask (route personal preferences to auto memory; `check` reports when it's off; `retro` optionally reads `/insights`) without touching anything the proposal didn't flag as broken.

Rejected alternatives:
- Collapse `retro`'s five buckets down to literally three (project facts, personal preferences, must-always-hold rules), matching the proposal's "three places" wording verbatim — rejected: this would delete the "multi-step procedure → new skill" and "100%-must-hold → hook" buckets, both working and not mentioned as broken by the proposal; "three places" in the proposal describes the typical case, not a ceiling on `retro`'s existing categories. Doing this would be a regression nobody asked for.
- Have `retro` or a devkit script implement the actual `/memory`-equivalent file-writing mechanism (compute the sanitized path, create the directory, write `MEMORY.md`) — rejected: Claude Code itself already knows how to write to its own auto-memory store via its own operating instructions; devkit only needs to change what the `retro` *prompt* instructs the agent to do, not build new tooling. Out of scope per the request's own constraint.
- Have `check` run a fixed script computing the sanitized project-path string (e.g. replacing `/` with `-`) to locate the memory directory precisely — rejected: `check` is a prompt skill reasoning over what it can see, not a fixed script; hardcoding the sanitization algorithm risks going stale if Claude Code changes its path-encoding scheme. Phrasing it as "the project's own memory directory under `~/.claude/projects/`" is accurate and resilient.
- Make `retro` force-invoke `/insights` before running — rejected: no mechanism exists for one skill to invoke another slash command; `retro` is a plain prompt skill with `disable-model-invocation: true` and no special tools. The proposal itself marks this "optionally".

## Phases

### Phase 1 — `retro`: route personal preferences to auto memory
- [x] Edit step 1 to note optional `/insights` input — file: `plugins/devkit/skills/retro/SKILL.md`
  - Append to step 1: "If `/insights` output is already present earlier in the conversation, read it too as extra input alongside the session's own corrections — `retro` has no way to invoke `/insights` itself."
- [x] Replace the personal-preference bullet in step 2 — file: `plugins/devkit/skills/retro/SKILL.md`
  - Old: `- A personal preference, not a team standard → \`CLAUDE.local.md\`.`
  - New (exact):
    ```
    - A personal preference, not a team standard → auto memory, if this Claude Code installation has it for the project (a `memory/` directory under this project's own entry in `~/.claude/projects/`). First read the existing `MEMORY.md` index to avoid duplicating an entry; if one already covers this preference, link it (`[[name]]`) or update it instead of writing a new one. Otherwise write a new memory file with frontmatter `metadata.type: feedback`, state in the body *why* — the user's correction or confirmation that produced this preference — so the memory stays interpretable later, then add a one-line pointer to `MEMORY.md` (`- [Title](file.md) — hook`). If auto memory isn't available for this project (no `memory/` directory, or the feature isn't present in this installation), fall back to `CLAUDE.local.md` as before.
    ```
  - Leave the other four bullets (CLAUDE.md, rules, skill, hook) unchanged.
- Verify: `claude plugin validate plugins/devkit --strict && claude plugin validate .` → exit 0 (frontmatter/structure still valid, nothing else touched). Then `sed -n '1,25p' plugins/devkit/skills/retro/SKILL.md` and manually confirm: the `/insights` sentence is in step 1; the personal-preference bullet mentions `metadata.type: feedback`, the `MEMORY.md` read-before-write check, and the `CLAUDE.local.md` fallback; the other four bullets are byte-identical to today.

### Phase 2 — `check`: report auto-memory usage
- [x] Add one new Layer 2 bullet after the existing four — file: `plugins/devkit/skills/check/SKILL.md`
  - New bullet (exact), placed after the `CLAUDE.local.md`/`.claude/settings.local.json` gitignore bullet:
    ```
    - Auto memory: whether the project's own memory directory under `~/.claude/projects/` has a `MEMORY.md` that exists and is non-empty. Status = OK if present with content. Otherwise, never report "Needs fix" — this is optional infrastructure, a project can be perfectly healthy without using it — report it informationally with a one-line note: "auto memory unused for this project — `retro` can start writing to it."
    ```
- Verify: `claude plugin validate plugins/devkit --strict && claude plugin validate .` → exit 0. Then manually apply the new bullet's own logic to this repo (same style as P-23 Phase 4): `ls -la "$HOME/.claude/projects/-Users-nhatduong-Documents-projects-nhat-kit/memory/" 2>&1` — expect no `MEMORY.md` (directory absent or empty), confirming the bullet currently reports "auto memory unused for this project" for this repo, a real and checkable fact.

### Phase 3 — Bookkeeping
- [x] Add `[Unreleased]/### Changed` bullet for P-24 — file: `CHANGELOG.md`
  - Pattern-match the P-23 bullet at `CHANGELOG.md:22`: one bullet, ends `(P-24)`. Content: `retro`'s personal-preference bucket routes to Claude Code's auto memory (`metadata.type: feedback`, read-before-write against `MEMORY.md`, link related entries with `[[name]]`) instead of `CLAUDE.local.md`, falling back to `CLAUDE.local.md` when auto memory isn't available; `retro` step 1 reads `/insights` output as extra input when already present; `check` gains an informational Layer 2 bullet reporting whether the project's auto memory is unused (P-24).
- [x] Flip the `UPSTREAM.md` row — file: `UPSTREAM.md:117`
  - `| Personal memory for repeated corrections | \`retro\` | ◐ | P-24 |` → `| Personal memory for repeated corrections | \`retro\` | ✅ | P-24 |`
- Verify: `grep -n "P-24" CHANGELOG.md UPSTREAM.md` shows the new Changed bullet and the UPSTREAM.md row with `✅` (not `◐`).

## Risks
| Risk | Signal | Mitigation |
| --- | --- | --- |
| User's Claude Code installation has no auto-memory feature at all | No `memory/` directory ever appears under `~/.claude/projects/<project>/` | Explicit fallback clause in the new bullet: no `memory/` directory or feature absent → use `CLAUDE.local.md` as before |
| `retro` writes a duplicate memory entry for a preference already recorded | Two memory files with near-identical content/description | Instructions explicitly require reading `MEMORY.md` first and linking/updating an existing entry instead of creating a new one |
| `check`'s new bullet gets misread as a failing check by a user or a future CI gate | Someone treats "auto memory unused" as "Needs fix" | Bullet text explicitly states "never report Needs fix — this is optional infrastructure" |
| Claude Code's memory file schema (frontmatter fields, `MEMORY.md` line format) changes in a future version | `retro`'s written files stop matching what Claude Code's own memory reader expects | Wording references the type taxonomy generically (`feedback`) rather than a pinned schema version; low-cost to update since it's only a prompt file, not code |

## Out of scope
- Implementing the actual `/memory` command, auto-memory storage engine, or any new devkit tooling/scripts for it — Claude Code itself already knows how to write memory files via its own operating instructions.
- Making `retro` force-invoke `/insights` — no mechanism exists for a skill to run another slash command; this stays strictly optional/best-effort.
- Reducing `retro`'s five destination buckets to the proposal's literal "three places" — would regress working behavior (skill and hook buckets) for no stated reason.
- Specifying or hardcoding the exact path-sanitization algorithm Claude Code uses to name a project's directory under `~/.claude/projects/` — `check` reasons over what it can see, not a fixed script.
- `README.md` changes — this patch edits two existing skills' prompts, it does not add or rename a skill or agent, so the repo's "adding/renaming" documentation rule does not apply.
