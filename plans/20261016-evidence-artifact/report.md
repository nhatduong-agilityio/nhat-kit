# Report: Evidence as an artifact

## Result
- Status: done (one item open: the PR line, see Phase 5)
- Done:
  - Conventions: a "UI evidence" section covering the folder, file names, GIF via Claude in Chrome, a no-secrets rule, the artifact content (main session only), the PR line "(private — shared on request)", the reminder to share, and fallbacks
  - `ui-verifier` template: saves `AC<n>-<state>.png` into the evidence folder using the screenshot `filename`, returns the paths, never publishes, and stops at once with a clear trust message when it has no browser tools
  - `ship` gate 5/8/reply and `task` step 7/8/end: collect the evidence (falling back to the main session's browser tools when `ui-verifier` can't), publish the artifact or record the fallback, link it in the PR, remind the user to share
  - `git-manager`: fills *Screenshots / GIF* only from what it is given, and never invents one
  - `gitignore-additions.txt`: `**/evidence/`, `.playwright-mcp/`
  - README (`ship` and `task` rows), UPSTREAM ✅ P-22, CHANGELOG
- Files: `plugins/devkit/references/conventions.md`, `plugins/devkit/templates/agents/ui-verifier.md`, `plugins/devkit/templates/gitignore-additions.txt`, `plugins/devkit/skills/{ship,task}/SKILL.md`, `plugins/devkit/agents/git-manager.md`, `README.md`, `UPSTREAM.md`, `CHANGELOG.md` (modified); `plans/…/research/flow.md` (created)

## Evidence
Full findings are in `research/flow.md`.
- **Phase 1 fixture** (a static Profile page with a Save toggle, a SPEC with 2 UI ACs):
  - Playwright's screenshot `filename` writes into `docs/tasks/T-1-save/evidence/` as given. Both PNGs were checked visually: AC1 is the initial state, AC2 shows "Saved as Grace".
  - The Artifact tool is **not** available in headless `-p` runs.
  - In the interactive session it published a private page with both PNGs passed as `files`: https://claude.ai/artifact/Q5Cdwz3tUaxsq9prkjwDRb.
- **Found:** a project agent's inline MCP servers are skipped in folders that aren't trusted. The debug log says `Skipping frontmatter MCP servers for agent 'ui-verifier': … not trusted`. The template now says so clearly, and a probe with the refreshed agent returned exactly: "No browser tools — open Claude Code in this project folder once and accept the trust prompt, so this agent's Playwright server can start."
- **Phase 3 rerun** with the real `task` step 7 wording (headless, Playwright via `--mcp-config`): `ui-verifier` was blocked, so the main session drove the app itself and wrote `AC1-initial.png` and `AC2-saved.png`. With no Artifact tool it produced the fallback *Screenshots / GIF* text (the file list plus "drag the key images into the PR"). The first rerun found two wording gaps (no fallback to the main session in `task`, and `ui-verifier` trying Bash browsers); both are fixed, and the second rerun passed.
- `claude plugin validate plugins/devkit --strict && claude plugin validate .` → both "✔ Validation passed"; `scripts/test-hooks.sh` → "All hooks passed."

## Phase 5: interactive run by the user (2026-10-16)
- **`ui-verifier` with a real browser:** after the folder trust prompt, it retook both screenshots at 15:11 on `627d2bd`.
- **The skill flow published the artifact itself:** [T-1 UI evidence](https://claude.ai/artifact/6wvG4Nvd79LoVfhJakmCbE), private.
  - Per AC: criterion, a Pass label, observation and inline screenshot; console and network (favicon 404); commit SHA; "Test data only".
- **Reminder to share:** the final message said "It's private, so share it with the reviewers from its Share menu when you open the PR."
- **Not checked:** the PR *Screenshots / GIF* line "(private — shared on request)". The run covered step 7 only; `git-manager` writes that line at step 8.
- **Follow-up from that run's review:** screenshot paths are now absolute in the conventions and `ui-verifier`. Relative paths worked in all three runs, but they depend on where the browser server resolves them.
