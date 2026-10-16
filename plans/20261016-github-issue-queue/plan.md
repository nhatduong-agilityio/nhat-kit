# GitHub issues as an AI work queue
Status: done · Source: P-20 in `upstream/proposals/20261016.md` · Decisions: user, 2026-10-16

## Goal
Findings become GitHub issues that a stranger can act on, labelled `ai` + `severity:*` + `area:*`. `/devkit:issue` files them only once every field is pinned down, and only after a duplicate check. `/devkit:task #N` or `/devkit:task next` claims an issue so only one machine works on it. An issue is closed only through the PR's `Closes #N`, and a task that can't finish releases the issue back to the queue instead of closing it.

## Decisions (from the user)
| # | Question | Answer |
| --- | --- | --- |
| D1 | Labels | `ai` + `severity:<critical\|high\|medium\|low>` + `area:<name>`, plus `bug`/`enhancement`. Missing labels are created once with `gh label create` after the user confirms |
| D2 | Claim lock | An `in-progress` label plus a claim comment naming the host, task and time. Another machine stops unless the user overrides. Release removes the label and comments why |
| D3 | Queue pick | `/devkit:task next`: open `ai` issues without `in-progress`, highest severity first, oldest first on ties; the user confirms before the claim |

## Context found
- `plugins/devkit/skills/task/SKILL.md:1-6`:
  - The frontmatter has `disable-model-invocation: true`.
  - `allowed-tools` pre-approves only read commands (`gh issue view *`, …). The new read-only `gh issue list *` can be added there; edits and comments should still prompt.
- `task/SKILL.md:17-22`: Step 1 (intake) reads `#123` with `gh issue view`. This is where `next` and the claim go.
- `task/SKILL.md:30-35`: Step 3 (gap check) can stop on blocking questions. That is a release point.
- `task/SKILL.md:58-66`: Step 8 (ship). `git-manager` already writes `Closes #N` (P-21, `agents/git-manager.md:22`).
- `plugins/devkit/templates/github/ISSUE_TEMPLATE/bug.yml` and `feature.yml` (P-21) define the fields and the severity values. A bootstrapped project's `.github/ISSUE_TEMPLATE/bug.yml` holds its Area list, which is the single source for `area:*` names.
- `plugins/devkit/skills/grill/SKILL.md`: the pattern for "pin every field down with `AskUserQuestion`, recommended option first, look facts up instead of asking".
- `plugins/devkit/references/conventions.md`: holds the shared conventions; the queue's label set and claim format go here, so `issue` and `task` read one definition.
- Labels on nhat-kit today: GitHub defaults only. The private scratch repo `nhatduong-agilityio/devkit-forms-scratch` (from P-21) has the issue forms and can be used for the end-to-end check.

## Approach
1. **Conventions → a "GitHub issue queue" section** (one place, read by both skills):
   - **Labels:** `ai` (in the queue), `bug`/`enhancement`, `severity:critical|high|medium|low`, `area:<name>` (names from the project's issue form Area list), and `in-progress` (claimed). Create missing ones with `gh label create <name> --color … --description …` once, after the user confirms.
   - **Claim comment:** `🔒 devkit claim · host: <hostname -s> · task: <TASK_ID> · <ISO time>`. Release comment: `🔓 devkit release · host … · reason: … · done so far: …`.
   - **Rules:**
     - Claim before writing the SPEC.
     - Never close an issue by hand; it closes only through the PR's `Closes #N`.
     - Release whenever the task stops without a PR.
     - When two claims race, the earliest claim comment wins and the later one releases.
2. **New skill `/devkit:issue <bug|feature> [description | findings file]`** (`disable-model-invocation: true`, because it files on the remote):
   - Read the input and look up facts in the code first, such as `file:line`, the screen, and the current behavior.
   - Ask only for what is still missing, in `AskUserQuestion` rounds with recommended answers. Required for a bug: symptom-first title, where, steps, expected, actual, severity, area. Required for a feature: problem, proposed behavior, testable Given/When/Then ACs, area. It won't file until all of these are set.
   - Check for duplicates with `gh issue list --state all --search "<key words>" --limit 10`. If one matches, offer to comment on it instead of filing a new issue.
   - Show a preview (title, body with the same `### <Field>` headings the forms produce, labels). After the user confirms, ensure the labels exist and run `gh issue create`. Return the URL.
   - Input can be a review or findings file. It files one issue per finding the user confirms, which covers the deck's "review → issues" flow without a separate skill.
3. **`/devkit:task` changes** (step 1, plus a new "Release" section):
   - **`next`:**
     - Run `gh issue list --label ai --state open --json number,title,labels,createdAt --limit 100` and drop issues labelled `in-progress`.
     - Sort by severity rank, then by oldest `createdAt`.
     - Show the top 3 with the first recommended. The user picks, and that choice also confirms the claim.
   - **`#N` or a picked issue → claim:**
     - Read the issue's labels and comments. If it is labelled `in-progress`, show the latest claim (host and time) and stop unless the user overrides.
     - Otherwise add `in-progress`, post the claim comment, then re-read the comments. If an earlier claim comment from another host exists, release and stop.
   - **Release:** at a blocking gap-check stop (step 3), when the user aborts, or when the task can't be finished: remove `in-progress`, post the release comment with the reason and what was done so far. Leave the issue open and keep its `ai` label so it returns to the queue.
   - Add `gh issue list *` to `allowed-tools`. `gh issue edit` and `gh issue comment` stay prompted, because they are outward-facing.

Rejected alternatives:
- Assignee-only claims: every machine on one account looks like the same claimant (D2).
- A separate `review-to-issue` skill: covered by `/devkit:issue <findings file>`.
- GitHub Projects board fields for status: more setup than labels, and P-25 (plan ↔ tracker sync) is the place for it.
- Lock expiry by time: no reliable clock or heartbeat across machines; a user override handles stale claims.

## Phases

### Phase 1: Queue conventions (foundational; both skills depend on it)
- [x] `plugins/devkit/references/conventions.md`: add the "GitHub issue queue" section as described in the Approach: label set and colors, claim and release comment formats, and the rules.
- [x] Prove the `gh` calls and the sort work for real on the scratch repo (`devkit-forms-scratch`) with a throwaway script in the scratchpad:
  - create the labels;
  - file 3 issues with different severities;
  - run the `next` query and sort;
  - claim the top issue (label + comment), then re-read the comments;
  - release it (remove the label + comment);
  - confirm the issue is still open and back in the `next` list.
- Verify:
  - The scratchpad script exits 0 and prints the `next` order `critical → high → low`, the claim found on re-read, and the issue open and unclaimed after release.
  - `grep -n 'devkit claim' plugins/devkit/references/conventions.md` prints a line.

### Phase 2: `/devkit:issue`
- [x] Create `plugins/devkit/skills/issue/SKILL.md` as described in the Approach, under about 45 lines: imperative steps, a `description` under 300 characters, `argument-hint: "<bug|feature> [description | findings.md]"`, and `disable-model-invocation: true`.
- Verify:
  - `claude plugin validate plugins/devkit --strict` passes.
  - The description length check prints a number below 300.
  - Headless run on the scratch repo (`claude -p --plugin-dir plugins/devkit`), given a bug description that already has every field: the issue is created with labels `ai`, `bug`, `severity:*` and `area:*`, and the body has the five bug headings (`gh issue view <n> --json labels,body`).
  - Run a second time with the same text: it reports the duplicate instead of filing again.

### Phase 3: `/devkit:task next`, claim, release
- [x] `plugins/devkit/skills/task/SKILL.md`:
  - step 1 handles `next` and the claim;
  - a new "Release" section after step 8, referenced from step 3 and from any stop;
  - `argument-hint` gets `next`;
  - `allowed-tools` gets `Bash(gh issue list *)`.
- Verify:
  - `claude plugin validate plugins/devkit --strict` passes.
  - `grep -nE 'next|in-progress|devkit claim|Release' plugins/devkit/skills/task/SKILL.md` shows each part.
  - On the scratch repo, a headless `/devkit:task next` with Write/Edit disabled and `--max-turns` small shows the highest-severity unclaimed issue first, and stops before claiming because it needs confirmation.

### Phase 4: Docs
- [x] `README.md`:
  - 16 → 17 commands (two places);
  - a commands-table row for `/devkit:issue`;
  - `issue` added to the user-only list;
  - the `/devkit:task` row mentions `next` and claiming;
  - a flow line "Queue: `/devkit:issue` → `/devkit:task next` → PR `Closes #N`".
- [x] `UPSTREAM.md:113`: change to ✅ P-20.
- [x] `CHANGELOG.md` `[Unreleased]`: Added `/devkit:issue`; Changed `/devkit:task` (`next`, claim and release).
- Verify:
  - `grep -c 'devkit:issue' README.md` is 2 or more.
  - `grep -n 'P-20' UPSTREAM.md` shows ✅.
  - Both validate commands and `scripts/test-hooks.sh` pass.

### Phase 5: Interactive run (manual)
- [x] In `devkit-forms-scratch`, run `claude --plugin-dir …/plugins/devkit`:
  - `/devkit:issue bug` with a vague description: it asks rounds of questions with recommended answers and files only when every field is set.
  - Then `/devkit:task next`: it picks that issue, claims it, and the `in-progress` label and claim comment appear.
  - Stop at the plan step and say it can't continue: it posts the release comment, removes the label, and the issue stays open.
- Verify: the checklist above, from the GitHub issue page.

## Risks
| Risk | Signal | Mitigation |
| --- | --- | --- |
| Two machines claim at the same moment (Medium) | Two claim comments on one issue | Re-read after claiming; the earliest comment wins, and the later claimant releases itself |
| A stale claim blocks the queue after a crash (Medium) | `in-progress` with no activity | `next` skips claimed issues, but `#N` shows the claim's host and time and lets the user override; the release is documented in conventions |
| Labels pile up or clash with existing ones (Low) | `gh label create` fails because the label exists | Create only labels missing from `gh label list`; ask once |
| Outward-facing actions without the user noticing (Medium) | Issues filed or commented on unexpectedly | Both skills are user-invoked only; `issue` previews before filing; edits and comments are not pre-approved in `allowed-tools` |
| Tests on GitHub leave clutter (Low) | Test issues on the scratch repo | They stay in the private throwaway repo, which is deleted after P-20 |

## Out of scope
- GitHub Projects boards and plan ↔ tracker sync (P-25).
- Automatic queue draining (a loop or routine running `task next`); `/loop` or `/schedule` can wrap it later.
- Jira and Linear queues.
- Applying labels to existing issues in bulk.
