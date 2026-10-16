# What Phase 1 found (2026-10-16)

Fixture: a static Profile page with a Save toggle (`python3 -m http.server 8765`), a SPEC with 2 UI ACs, and the `ui-verifier` template filled in.

1. **The Artifact tool is not available in headless (`claude -p`) sessions.** A headless run looked for it and reported it as missing. The **interactive** session has it. So publishing can only happen interactively, and headless runs must use the fallback: list the evidence paths in the PR.
2. **The `ui-verifier` inline Playwright MCP is skipped in folders that aren't trusted.** The debug log says: `Skipping frontmatter MCP servers for agent 'ui-verifier': the folder its definition file came from is not trusted (source: projectSettings)`.
   - The subagent then has no browser tools (it reports `NONE`), and listing `mcp__playwright` in `tools:` doesn't change that.
   - Real projects that have been opened in Claude Code once are trusted, so the template is fine. It needs a clear message: "no browser tools → open Claude Code in this folder once and accept the trust prompt".
3. **Playwright MCP's screenshot `filename` argument is resolved from the project folder.** `docs/tasks/T-1-save/evidence/AC1-initial.png` landed exactly there, so no copy step is needed.
   - Playwright also writes its own `.playwright-mcp/` folder (snapshots, logs) into the project, so it should be gitignored next to `**/evidence/`.
   - Tested with Playwright passed to the main session via `--mcp-config`, which avoids the trust gate.
4. **The screenshots are correct.** AC1 shows the initial state (name "Ada", no message), and AC2 shows "Saved as Grace". Checked by viewing both PNGs.
5. **The Artifact tool takes PNGs through `files`, referenced by relative path in `<img src>`.**
   - Published privately from the interactive session: https://claude.ai/artifact/Q5Cdwz3tUaxsq9prkjwDRb (2 screenshots inline, AC table, commit SHA).
   - The tool confirms it is private until the owner shares it from the page's Share menu, which matches D1.
6. **The console showed one 404 for `/favicon.ico`.** This is typical noise; the evidence page should list console errors without failing an AC because of them.
