# Evidence as an artifact
Status: done · Source: P-22 in `upstream/proposals/20261016.md` · Decisions: user, 2026-10-16

## Goal
When a change is visible in the UI, `/devkit:ship` and `/devkit:task` prove it in the running app:
- a screenshot per AC state, and a GIF for multi-step flows when the browser tool supports it;
- all of it published as one artifact;
- the artifact linked from the PR's *Screenshots / GIF* section.

Reviewers see the change without running it. If the Artifact tool is not available, the PR lists the evidence files instead.

## Decisions (from the user)
| # | Question | Answer |
| --- | --- | --- |
| D1 | Linking a private artifact in the PR | Link it, marked "private — shared on request"; the final message reminds the user to share it with reviewers |
| D2 | Where evidence files live | Next to the plan or SPEC: `plans/<…>/evidence/` or `docs/tasks/<ID>-<slug>/evidence/`. Gitignored with `**/evidence/` |

## Context found
- `plugins/devkit/skills/ship/SKILL.md:18`: gate 5 "Real app": the `verify` skill, plus `ui-verifier` for UI. Nothing is collected or published.
- `ship/SKILL.md:21`: gate 8 opens the PR through the `/devkit:git pr` procedure (`git-manager`).
- `plugins/devkit/skills/task/SKILL.md:56-61`: step 7 runs `verify` and `ui-verifier` ("with screenshots"), and requires evidence for every AC.
- `task/SKILL.md:67`: step 8 has `git-manager` open the PR with the AC → evidence table.
- `plugins/devkit/templates/agents/ui-verifier.md:1-19`: a project template agent with the Playwright MCP inline.
  - It takes a screenshot per AC and returns a table.
  - It doesn't say where the files go or how they are named.
  - As a subagent it can't publish artifacts; only the main session has the Artifact tool.
- `plugins/devkit/agents/git-manager.md:22`: the PR body follows `.github/pull_request_template.md`. The template has a *Screenshots / GIF* section (P-21).
- `plugins/devkit/templates/gitignore-additions.txt`: Claude-local paths only. `**/evidence/` goes here.
- `plugins/devkit/references/conventions.md:55-63`: the "Evidence" section already counts "a screenshot or observation of the running app" as valid evidence.
- Tool availability varies by project and session:
  - The Artifact tool needs claude.ai artifacts enabled.
  - GIF recording exists only in Claude in Chrome.
  - Playwright MCP gives screenshots, not GIFs.

## Approach
1. **Conventions → a "UI evidence" subsection under Evidence**, so `ship`, `task` and `ui-verifier` share one definition:
   - **Folder:** `<plan or SPEC folder>/evidence/`. **Names:** `AC<n>-<state>.png`, plus `before-`/`after-` prefixes when comparing, and `<flow>.gif`.
   - **Artifact:** one page per change, titled `<slug> evidence`. It holds:
     - the AC table (AC, Pass/Fail, observation), with each screenshot or GIF inline;
     - console and network errors, if any;
     - the commit SHA it was taken at.

     Publish it with the Artifact tool, passing the images as `files`. It is private until the user shares it.
   - **PR:** the *Screenshots / GIF* section gets `[Evidence](<url>) (private — shared on request)` and up to 2 key images described in words. The final reply reminds the user to share the artifact with reviewers.
   - **No Artifact tool:** the PR section lists the evidence file paths and asks the user to drag the key images into the PR on GitHub.
   - **No browser tool at all:** say so in the PR, and use the `verify` skill's text output as evidence.
2. **`ui-verifier` template:** save each screenshot into the evidence folder it is given, with the names from the conventions, and return the file paths in its table. Unless told otherwise, the folder is the one next to the path in `.claude/current-task`.
3. **`ship` gate 5 and `task` step 7:** when the change touches UI, run `ui-verifier`, or `/claude-in-chrome` in the main session when a GIF of a multi-step flow is useful. Then publish the evidence artifact in the main session, per the conventions.
4. **`ship` gate 8, `task` step 8 and `git-manager`:** pass the artifact link, or the file list, into the PR's *Screenshots / GIF* section.
5. **`templates/gitignore-additions.txt`:** add `**/evidence/`, which `bootstrap` already appends.

Rejected alternatives:
- Committing the images (rejected in D2).
- Uploading images to GitHub with `gh`: there is no CLI or API path for attaching images to a PR body.
- A new `/devkit:evidence` skill: this is a step inside two existing flows, not a command anyone would run alone.

## Phases

### Phase 1: Prove the flow on a fixture (riskiest: depends on the Artifact tool and Playwright MCP behaving headless)
- [x] Fixture in the scratchpad:
  - a static two-state page (a button toggles "Saved" text), served with `python3 -m http.server`;
  - a SPEC with 2 UI ACs;
  - `.claude/agents/ui-verifier.md` filled from the current template.
- [x] Headless (`claude -p --plugin-dir …`, `--allowedTools` limited to the dev server, Read/Write, Agent, Artifact): ask it to follow the *draft* UI evidence steps (written into the prompt) for that SPEC.
  - Find out where Playwright MCP writes screenshots, and whether `ui-verifier` can place them in `evidence/` (via the `filename` argument or by copying).
  - Find out whether the Artifact tool is available headless and accepts the images as `files`.
- Verify:
  - `ls <fixture>/docs/tasks/<ID>/evidence/` shows `AC1-*.png` and `AC2-*.png`.
  - The run prints a `claude.ai/…artifact…` URL.
  - The findings (screenshot location, how `files` behave, headless limits) are written to `plans/<…>/research/flow.md`.
  - If the Artifact tool isn't available headless, the fallback path is recorded and tested instead, and Phase 5 covers the artifact interactively.

### Phase 2: Conventions and the ui-verifier template
- [x] `plugins/devkit/references/conventions.md`: the "UI evidence" subsection, as described in the Approach and adjusted to what Phase 1 found.
- [x] `plugins/devkit/templates/agents/ui-verifier.md`: the evidence folder, file names, and file paths in the returned table.
- [x] `plugins/devkit/templates/gitignore-additions.txt`: add `**/evidence/`.
- Verify:
  - `grep -n 'UI evidence' plugins/devkit/references/conventions.md` prints a line.
  - `grep -n 'evidence/' plugins/devkit/templates/agents/ui-verifier.md plugins/devkit/templates/gitignore-additions.txt` hits both files.

### Phase 3: ship, task, git-manager
- [x] `ship/SKILL.md` gate 5 (collect and publish for UI changes) and gate 8 (pass the link or the files).
- [x] `task/SKILL.md` step 7 (collect and publish) and step 8 (pass them to the PR).
- [x] `agents/git-manager.md:22`: fill *Screenshots / GIF* from the link or file list given; never invent one.
- [x] The final replies in `ship` and `task` remind the user to share the private artifact.
- Verify:
  - `claude plugin validate plugins/devkit --strict` passes.
  - `grep -nE 'artifact|evidence/' plugins/devkit/skills/{ship,task}/SKILL.md plugins/devkit/agents/git-manager.md` shows each edit.
  - Rerun the Phase 1 fixture with the *real* `task` step 7 (no draft in the prompt): the same evidence files and an artifact URL (or the fallback list).

### Phase 4: Docs
- [x] `README.md`: one line in the `ship` and `task` rows or the workflow notes ("UI changes: screenshots/GIF published as an artifact, linked in the PR").
- [x] `UPSTREAM.md:115`: change to ✅ P-22. `UPSTREAM.md:99` (the `/verify` row): update its note.
- [x] `CHANGELOG.md` `[Unreleased]` → Changed: `ship`/`task` UI evidence artifact; `ui-verifier` evidence folder; `**/evidence/` gitignored.
- Verify: both validate commands and `scripts/test-hooks.sh` pass; `grep -n 'P-22' UPSTREAM.md` shows ✅.

### Phase 5: Interactive check (manual)
- [x] In the fixture, run `claude --plugin-dir …` and then `/devkit:task` on the fixture SPEC up to the PR body (no push).
- Verify:
  - an artifact with both AC screenshots inline;
  - the PR body draft has the link marked private;
  - the final message reminds the user to share it.

## Risks
| Risk | Signal | Mitigation |
| --- | --- | --- |
| The Artifact tool is unavailable in many sessions (Medium) | No artifact URL | The fallback is part of the design (file list in the PR); Phase 1 records the behavior |
| Playwright MCP saves screenshots to its own output folder (Medium) | No files in `evidence/` | Phase 1 finds the real location; `ui-verifier` copies the files if needed |
| A private link in a PR confuses reviewers (Low) | Reviewers can't open it | "Private — shared on request" label plus the reminder to share (D1) |
| Screenshots capture secrets or personal data (Medium) | Tokens or emails visible in an image | The conventions tell the agent to use test accounts and to blur or skip screens with secrets; the artifact stays private by default |
| Artifact size (Low) | Publish refused over 16 MB | Screenshots only per AC; GIFs only for multi-step flows |

## Out of scope
- GIF recording through Playwright (it isn't supported); GIFs only via Claude in Chrome when present.
- `cook`'s own verify step (`ship` runs after it).
- Uploading evidence into GitHub itself.
