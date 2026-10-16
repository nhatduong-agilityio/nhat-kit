# Report: GitHub issues as an AI work queue

## Result
- Status: done
- Done:
  - Conventions: a "GitHub issue queue" section covering labels and colors, the claim and release comment formats, the rules, and a note on list lag
  - New skill `plugins/devkit/skills/issue/SKILL.md` (25 lines, description 226 chars, user-invoked only)
  - `/devkit:task`: `next`, a claim before the SPEC with a re-read for races, and a Release section; `gh issue list *` added to `allowed-tools` (edits and comments still prompt)
  - README (17 commands, table rows, user-only list, queue flow), UPSTREAM ✅ P-20, CHANGELOG (Added + Changed)
- Files: `plugins/devkit/skills/issue/SKILL.md` (created), `plugins/devkit/references/conventions.md`, `plugins/devkit/skills/task/SKILL.md`, `README.md`, `UPSTREAM.md`, `CHANGELOG.md` (modified); `plans/…/queue_check.sh` (evidence script)

## Evidence
- **Phase 1:** `bash plans/20261016-github-issue-queue/queue_check.sh` against the private scratch repo `devkit-forms-scratch` exits 0.
  - Output: labels created; `next` order `critical → high → low`; claim visible on re-read; claimed issue skipped by `next`; released issue `OPEN` without `in-progress` and first in `next` again.
  - The first run found that `gh issue list` lags a few seconds behind new issues (2 of 3 listed). The conventions now say to read single issues with `gh issue view` (no lag) and to treat the duplicate check as best effort. The test issues #1–#6 were closed as test data afterwards.
- **Phase 2:** a headless `/devkit:issue bug …` with every field given filed #7.
  - Labels: `bug, ai, severity:high, area:web`.
  - Body headings: `### Where ### Steps to reproduce ### Expected ### Actual ### Severity ### Area`.
  - Duplicate check: none found before filing.
  - A second run with similar text found #7 as a duplicate and filed nothing (open issues stayed at 1).
- **Phase 3:** a headless `/devkit:task next` (read-only `gh`, Write/Edit disabled) picked #7 as the highest-severity unclaimed issue and made no claim (`labels: bug,ai,severity:high,area:web · comments: 0`). It also refused to claim, because the scratch repo has no application code, which is sensible.
- `claude plugin validate plugins/devkit --strict && claude plugin validate .` → both "✔ Validation passed"; `scripts/test-hooks.sh` → "All hooks passed."

## Phase 5: interactive run (2026-10-16)
- **Claim and release, confirmed on GitHub for #7:**
  - Claim comment: `🔒 devkit claim · host: Nhats-Mac-mini · task: GH-7 · 2026-10-16T07:14:47Z`.
  - Release comment: `🔓 devkit release · host: Nhats-Mac-mini · reason: user stopped the task (queue test) · done so far: nothing`.
  - After the release: state `OPEN`, labels `bug, ai, severity:high, area:web` (`in-progress` removed, `ai` kept), and the issue is back at the front of `next`.
  - Re-checked with `gh issue view 7 --json state,labels,comments`.
- **Question rounds, confirmed by the user:** `/devkit:issue` with a vague description asked rounds of questions with recommended options before filing.
