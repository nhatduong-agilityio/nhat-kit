# Issue and PR templates
Status: done · Source: P-21 in `upstream/proposals/20261016.md`

## Goal
Every project that `/devkit:bootstrap` sets up on GitHub gets bug and feature issue forms that make the reporter fill in what a stranger needs to act on. It also gets a PR template that asks for pasted verification output, screenshots, `Closes #N`, and one concern per PR. P-20 (the issue work queue) will build on these.

## Context found
- `plugins/devkit/templates/github/pull_request_template.md:1-22`: has Summary, `Ticket:`, an AC table, manual test steps, risks and a checklist. It has no verification-output section, no screenshot section, no `Closes #`, and no one-concern check.
- `plugins/devkit/skills/bootstrap/SKILL.md:15`: replaces `{{PLACEHOLDER}}` values and removes `<!-- TEMPLATE: … -->` comments; the new YAML templates need `# TEMPLATE:` comments to work the same way. `bootstrap/SKILL.md:79` copies only the PR template when the remote is GitHub.
- `plugins/devkit/skills/check/SKILL.md:28`: Layer 4 lists `.github/pull_request_template.md` but not the issue forms.
- `plugins/devkit/agents/git-manager.md:22`: the PR body follows the template, but `Closes #N` is never added, even when the task came from an issue (`task/SKILL.md:19` reads `#123` with `gh issue view`).
- `UPSTREAM.md:114`: "Issues/PRs a stranger can act on", currently ◐ P-21.
- PyYAML 6.0.3 is available to check the forms locally. GitHub validates issue forms only after they are pushed to a repo's default branch.

## Approach
1. **Issue forms** (GitHub YAML, `templates/github/ISSUE_TEMPLATE/`):
   - `bug.yml`, labelled `bug`. Required fields: where (file:line, screen or URL), steps to reproduce, expected, actual, and severity (dropdown: critical, high, medium, low). Optional fields: area (dropdown), environment and version, logs or screenshots. The title placeholder asks for the symptom, not the suspected cause.
   - `feature.yml`, labelled `enhancement`. Required fields: problem or user need, proposed behavior, and testable acceptance criteria in Given/When/Then form. Optional fields: area (dropdown), out of scope, design link.
   - `config.yml` with `blank_issues_enabled: false`, so every issue goes through a form.
2. **Area dropdown:** the options are `{{AREAS}}`, which bootstrap replaces with the project's real module names. If the project has no clear modules, bootstrap removes the field (a `# TEMPLATE:` comment says so).
3. **Labels:** use only GitHub's default labels (`bug`, `enhancement`), so nothing has to be created on the remote. Severity and area stay as fields in the issue body; P-20 can turn them into labels later.
4. **PR template:** keep the AC table. Replace `Ticket:` with `Closes #` / `Refs:`. Add a *How it was verified* section (the command and its key output, pasted) and a *Screenshots / GIF* section (UI changes only). Add "one concern per PR" to the checklist.
5. **Wiring:**
   - `bootstrap`: copy the issue forms and `config.yml` alongside the PR template, and also remove `# TEMPLATE:` comments.
   - `check`: list the issue forms in Layer 4.
   - `git-manager`: write `Closes #N` in the PR body when the task came from issue #N.

Rejected alternatives:
- Markdown issue templates: unlike forms, they can't make fields required, and required fields are what make issues actionable.
- Creating `area/*` and `severity/*` labels with `gh label create`: that is an outward-facing change on every bootstrap, and it belongs to P-20.
- Adding the templates to the nhat-kit repo itself: not requested.

## Phases

### Phase 1: Issue forms (the riskiest part: GitHub's form schema is only checked after pushing)
- [x] Create `plugins/devkit/templates/github/ISSUE_TEMPLATE/bug.yml`, `feature.yml` and `config.yml` as described in the Approach.
- Verify: a Python check (written to the scratchpad) loads each file with PyYAML. For `bug.yml` and `feature.yml` it asserts:
  - top-level `name`, `description` and `body` are present;
  - every body item has a `type` from {markdown, input, textarea, dropdown, checkboxes};
  - every item except markdown has a unique `id` and `attributes.label`;
  - dropdowns have `options`;
  - the required fields listed in the Approach have `validations.required: true`.

  For `config.yml` it asserts `blank_issues_enabled` is false. The check exits 0.

### Phase 2: PR template
- [x] Update `plugins/devkit/templates/github/pull_request_template.md` as described in the Approach, keeping it short.
- Verify: `grep -cE 'Closes #|How it was verified|Screenshots|One concern' plugins/devkit/templates/github/pull_request_template.md` prints 4.

### Phase 3: Wiring and docs
- [x] `bootstrap/SKILL.md`: line 15 also removes `# TEMPLATE:` comments; line 79 copies `ISSUE_TEMPLATE/` too and fills in `{{AREAS}}`.
- [x] `check/SKILL.md:28`: add `.github/ISSUE_TEMPLATE/`.
- [x] `git-manager.md:22`: add `Closes #N` when the task came from issue #N.
- [x] `README.md`: on the Layer 4 row (line 36), add the issue forms; in the layout (line 197), change `PR` to `issue forms, PR`.
- [x] `UPSTREAM.md:114`: change to ✅ P-21.
- [x] `CHANGELOG.md` `[Unreleased]`: add an Added line for the issue forms and a Changed line for the PR template.
- Verify:
  - `grep -n 'ISSUE_TEMPLATE' plugins/devkit/skills/{bootstrap,check}/SKILL.md README.md` finds all three files.
  - `grep -n 'Closes #' plugins/devkit/agents/git-manager.md` prints a line.
  - `claude plugin validate plugins/devkit --strict && claude plugin validate .` passes.

### Phase 4: Real render (manual, optional)
- [ ] Bootstrap a throwaway GitHub repo (or copy the three files into one), push, and open *New issue*. GitHub shows a form error banner if the schema is wrong.
- Verify: both forms render; submitting with an empty required field is blocked; blank issues are not offered.

## Risks
| Risk | Signal | Mitigation |
| --- | --- | --- |
| A form is valid YAML but invalid for GitHub (Medium) | GitHub shows an error on the New-issue page | The Phase 1 structural check mirrors GitHub's documented keys; Phase 4 is a real render |
| `{{AREAS}}` is left unfilled in a project (Low) | The dropdown shows the literal `{{AREAS}}` | bootstrap fills it or deletes the field; `check` can spot leftover `{{` |
| `blank_issues_enabled: false` annoys maintainers (Low) | Requests for a blank issue | The option is in `config.yml`, easy to flip per project |
| The PR template gets too long (Low) | People delete sections | Only 3 additions; the screenshot section is marked "UI changes only" |

## Out of scope
- Creating labels on the remote, issue de-duplication, and claiming issues (P-20).
- Templates for nhat-kit's own `.github/`.
- Issue templates for GitLab or Jira.
