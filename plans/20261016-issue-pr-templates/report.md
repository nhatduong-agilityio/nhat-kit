# Report: Issue and PR templates

## Result
- Status: done (Phase 4 partly run: the chooser renders on GitHub)
- Done:
  - Issue forms `bug.yml`, `feature.yml`, `config.yml` in `plugins/devkit/templates/github/ISSUE_TEMPLATE/`
  - PR template: `Closes #`, "How it was verified", Screenshots / GIF, one-concern check
  - `bootstrap` copies the forms and fills `{{AREAS}}` (or deletes the Area field); `check` lists them and flags leftover `{{`; `git-manager` writes `Closes #N`
  - README, UPSTREAM ✅ P-21, CHANGELOG (Added + Changed)
- Files: `plugins/devkit/templates/github/ISSUE_TEMPLATE/{bug,feature,config}.yml` (created), `plugins/devkit/templates/github/pull_request_template.md`, `plugins/devkit/skills/bootstrap/SKILL.md`, `plugins/devkit/skills/check/SKILL.md`, `plugins/devkit/agents/git-manager.md`, `README.md`, `UPSTREAM.md`, `CHANGELOG.md` (modified)

## Evidence
- `python3 plans/20261016-issue-pr-templates/check_forms.py` → "All issue form checks passed.", exit 0. It simulates both bootstrap outcomes (areas filled; Area field deleted), then checks GitHub's form keys, unique ids, labels, dropdown options, required fields, and `blank_issues_enabled: false`.
  - The first run caught a real bug: an unquoted placeholder containing `: ` made `bug.yml` invalid YAML, so GitHub would have rejected it. It's fixed by quoting.
- `grep -cE 'Closes #|How it was verified|Screenshots|One concern' …/pull_request_template.md` → 5 (all four present; "One concern" appears twice).
- `claude plugin validate plugins/devkit --strict && claude plugin validate .` → both "✔ Validation passed"; `scripts/test-hooks.sh` → "All hooks passed."

## Phase 4: real render (2026-10-16)
- I pushed the three forms, filled the way bootstrap fills them (Area set to web/api, `# TEMPLATE:` lines removed), to the private scratch repo `nhatduong-agilityio/devkit-forms-scratch`.
- The New-issue chooser lists **Bug report** and **Feature request** with their descriptions and no template error banner, so GitHub accepted both forms.
- Blank issues show only as "Blank issue — Maintainers only". That is how GitHub applies `blank_issues_enabled: false`: contributors don't get a blank issue, and repo maintainers still do.
- The GraphQL `issueTemplates` field returned `[]` for the repo, so it is not a usable check for YAML forms.
- Not checked: the individual form pages (field order, required-field blocking).
