---
name: review
description: Review the current change or a PR against its plan/SPEC (correctness, requirements, security, tests, scope); optionally fix the important findings.
argument-hint: "[base-branch | #PR | path] [--fix]"
---

# Review

Input: `$ARGUMENTS`

1. Determine scope:
   - `#123` → `gh pr view 123 --json title,body,headRefName,baseRefName` and `gh pr diff 123`.
   - A branch name → diff `<branch>...HEAD`. A path → only that file/folder. Empty → changes against the main branch, including uncommitted ones.
2. Find the target document: `.claude/current-task`, or a plan/SPEC mentioned in the PR body or branch name. None → review against the PR description or commit messages.
3. Delegate to the `devkit:code-reviewer` subagent with the scope and target document. Large changes (> 20 files or several modules) → run several reviewers in parallel, one per file group, then merge and deduplicate.
4. Re-check every **Critical** finding yourself by reading the code at `file:line`; drop false positives.
5. Without `--fix`: present the report by severity.
   With `--fix`: fix Criticals and reasonable Warnings following the `/devkit:fix` procedure, re-run the related tests, and report what was fixed and what was skipped (with reasons).

Note: the bundled `/code-review` hunts general bugs and `/security-review` focuses on security; this skill adds the check against the plan/SPEC and the project's rules.
