---
name: issue
description: File a GitHub issue a stranger can act on — pins down every required field with the user, checks for duplicates, labels it for the AI queue (ai, severity, area). Use for a bug, a feature, or confirmed findings from a review.
argument-hint: "<bug|feature> [description | findings.md]"
disable-model-invocation: true
---

# Issue

Input: `$ARGUMENTS`

Conventions, including the **GitHub issue queue** section (labels, colors): `${CLAUDE_PLUGIN_ROOT}/references/conventions.md`. Do not change code in this skill.

1. **Kind and source.** The first word is `bug` or `feature` (ask if missing). If the rest is a findings file, such as a review report, list its findings, ask which to file with `AskUserQuestion` (multi-select), and run steps 2–6 once per chosen finding.
2. **Look up facts first.** Find the place in the code (`file:line`, screen, or URL), the current behavior, and how to reproduce, by reading files or running `/devkit:scout`. Don't ask the user what the code can answer.
3. **Pin down every required field.** Ask only for what is still missing, in `AskUserQuestion` rounds with the recommended option first, ending its label with "(Recommended)". Don't file until all of them are set:
   - **bug**: title (the symptom, not a guess at the cause), Where, Steps to reproduce, Expected, Actual, Severity, Area.
   - **feature**: title, Problem or need, Proposed behavior, Acceptance criteria (testable, `AC1 Given … when … then …`), Area.

   Severity is `critical | high | medium | low`. Area names come from the Area list in `.github/ISSUE_TEMPLATE/bug.yml` if present; otherwise ask.
4. **Check for duplicates.** Run `gh issue list --state all --search "<3–5 key words>" --limit 10 --json number,title,state,url`. If one looks like the same problem, show it and offer to comment on it instead (`gh issue comment`) or to file anyway.
5. **Preview and confirm.** Show the title, the labels (`ai`, `bug`/`enhancement`, `severity:<s>`, `area:<a>`), and the body: one `### <Field>` heading per field above, in that order, like the issue forms produce. File only after the user says yes.
6. **File.** Compare `gh label list --limit 200 --json name` with the labels needed. Create the missing ones, after one confirmation, with the colors from the conventions. Then run `gh issue create --title … --body-file <tmp> --label …` and return the URL.

Finish with the issue URLs, and suggest `/devkit:task #<n>` or `/devkit:task next` to work on them.
