# Report: PR report artifact (in progress)

- Done (on the original branch `feat/pr-report`; the `Report:` line, the PR-template line and the `git-manager`/`ship`/`task` wiring below were **superseded**, see "Reconciled with main"):
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

## Review fixes on PR #24 (2026-10-19)
The `/devkit:review #24` findings were 0 Critical, 9 Warning, 9 Optional. Fixed:
- **W1:** the report is rendered and published after the review and the last commit (`ship` gate 8, `task` step 8). Evidence is still collected at gate 5 / step 7.
- **W2:** a kind sets the order but never hides data; other sections with data render before Risks and impact.
- **W3:** `hotfix` is accepted and renders like `fix`.
- **W4:** "Behavior unchanged" only appears when the same tests pass before and after.
- **W5, W8, O2, O3:** the renderer rejects invented or unsafe data with a clear message. That covers missing metric values or `better`, bad line counts, a missing AC status, non-relative image paths, prototype-key kinds, and non-array fields.
- **W6:** the required sections always render, with placeholders; the heading is now "Risks and impact".
- **O1:** a robust check for whether the script is being run directly.
- **O4:** a charset meta and no external font request.
- **O7, O9:** this note, and `mkdir -p`.
- **W9:** the PR body states "oversized".
- **W7:** mermaid is documented by the Artifact platform as native; seeing it drawn in a published artifact is left to the user.

Tests: 15/15. Skipped: O5 (the `artifact-design` pointer: the hand-built fallback follows `report.md`), O6 (renaming the schema file: churn across docs for little gain), O8 (`Closes #`: handled in the PR body).

## After release 2.5.0: open items resolved (2026-10-19)
- **AC4, the end-to-end run**, done headless with the repo plugin (installed devkit disabled), no remote, push and `gh` blocked. `/devkit:ship docs/tasks/T-2-blank-name/SPEC.md main` ran on a fixture with a real `fix` commit.
  - **First run:** gate 5 correctly **failed**. The fixture page loaded an ES module as a classic script, a fixture bug the gate caught. It was fixed with a `type="module"` commit.
  - **Second run:** all 8 gates ran, and `evidence/report.json` and `report.html` were written and rendered with `render-report.mjs` (exit 0). The PR body used main's inline fallback, since headless runs have no Artifact tool.
  - The `report.json` data matches the real state: `commit` = `632c616` = `HEAD` after review and the commit; `areas` equal `git diff --numstat main...HEAD` (page +3/−2, test +4/−0); `tests.before` is left out (no base run); review counts come from the reviewer; the section order is `fix`.
- **`needs-bash` evals:** both pass (`cook-retries-tier-up` 1.00, `ship-stops-oversized` 1.00, $0.67). The 32 symlinks under `~/.docker` (cli-plugins, and Model Runner dylib aliases) were moved out for the run only and restored to their exact paths and targets (32/32 verified; `docker buildx version` works). The core evals had passed at release (3/3, $0.48).
- **Mermaid rendering:** not visible from the CLI (no browser tools in this session); the user checks it in the artifact.
