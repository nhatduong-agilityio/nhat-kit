# Report: PR report artifact (in progress)

- Done:
  - Phase 0: PR #7 merged; branch `feat/pr-report`.
  - Phase 1: `references/report.md`, `scripts/render-report.mjs`, 10/10 tests; one visual check (light, dark, true 400 px); sample published at https://claude.ai/artifact/JUw7aXZFCcAwWNF7KEjwF8.
  - Phase 2: conventions "PR report" section; UI evidence now the report's `#ui` section; Directories row.
  - Phase 3: wired into `git pr`, `ship`, `task`, `git-manager` and both PR templates; `git-manager` dry run gives exact `Report:` and UI lines (link and fallback cases).
  - Phase 5: README, CHANGELOG, UPSTREAM, release script and skill, CLAUDE.md. Validation, hook tests and renderer tests pass.
- Left:
  - Phase 4 headless: the `fix` commit dry run (fixture branch `fix/T-1-blank-name` is ready) and the `docs` run. Blocked by the usage limit; rerun with `--settings` disabling the installed devkit and `--add-dir` for the plugin.
  - Phase 4 interactive: `/devkit:ship` on the fixture (user).
  - Confirm that mermaid renders in the sample artifact.
  - Commit and open the PR.

## Reconciled with main (2026-10-19)
While this branch waited, `main` shipped its own "PR report artifact" for every PR (PR #12, 2026-10-17): a slim PR body with `## Full report`, the full report inline as the fallback, and an explicit "not charts" rule. The user chose to **add the charts to main's design** instead of replacing it.
- **Kept from main:** the workflow (`ship`, `task` and `git pr` build the report, and `git-manager` shapes the body), the PR body, the fallback, and the scrubbing rules.
- **Brought over from this branch:** `render-report.mjs`, its tests and `references/report.md`, adapted to main's required contents: ✅/⚠️/❌, "X/Y ACs met", How it was verified with `<details>`, Manual test steps, and Screenshots / GIF that is never left out.
- **Changed in main's conventions:** the build step (write `report.json`, render, publish), and "Visualization" now allows the inline charts.
- **Dropped:** this branch's `Report:` line and its `git-manager`, `ship`, `task` and `git pr` wiring, which main already covers in its own way. The original branch `feat/pr-report` (`00eb6b7`) is kept locally only.
- **Still open:** the Phase 4 runs (headless `fix` and `docs` dry runs, and the interactive `/devkit:ship`) against main's flow.
