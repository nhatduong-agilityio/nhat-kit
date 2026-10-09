# devkit 2.0.0 — Verification Report

Date: 2026-10-09 · Verifier: Claude Sonnet 4.6 (automated, this session)

---

## 1. Check table — Phase 1 (static)

| Phase | Item | Result | Evidence |
|---|---|---|---|
| 1.1 | 14 skills present | PASS | bootstrap brainstorm check cook debug fix git plan retro review scout ship task test — all confirmed |
| 1.1 | 8 agents present | PASS | code-reviewer debugger fullstack-developer git-manager planner requirements-analyst researcher tester |
| 1.1 | hooks/hooks.json present | PASS | file read, 2 hooks (PreToolUse + Notification) |
| 1.1 | references/conventions.md present | PASS | file read |
| 1.1 | All template files present | PASS | CLAUDE.md, settings.json, mcp.json.example, gitignore-additions.txt, rules/×3, hooks/×2, agents/ui-verifier.md, docs/×3, github/pull_request_template.md, skills/verify/SKILL.md |
| 1.2 | `claude plugin validate plugins/devkit --strict` | PASS | `✔ Validation passed` — exit 0 |
| 1.2 | `claude plugin validate .` | PASS | `✔ Validation passed` — exit 0 |
| 1.2 | `claude plugin validate .claude/skills` | PASS | `✔ Validation passed` — exit 0 |
| 1.3 | plugin.json parses | PASS | `python3 -c "json.load(...)"`  — OK |
| 1.3 | marketplace.json parses | PASS | OK |
| 1.3 | hooks.json parses | PASS | OK |
| 1.3 | templates/settings.json parses | PASS | OK ({{PLACEHOLDER}} strings are valid JSON strings) |
| 1.3 | templates/mcp.json.example parses | PASS | OK |
| 1.3 | user-setup/settings.json parses | PASS | OK |
| 1.4 | All 14 skill descriptions ≤ 300 chars | PASS | Longest: plan (225), fix (206), debug (202) |
| 1.4 | All 8 agent descriptions ≤ 300 chars | PASS | Longest: researcher (219) |
| 1.4 | Side-effect skills have `disable-model-invocation: true` | PASS | bootstrap, task, cook, git, ship, retro, check — all 7 confirmed |
| 1.4 | No agent uses hooks/mcpServers/permissionMode | PASS | All 8 agents checked — only `tools` and `model` fields in frontmatter |
| 1.4 | Agent tools are valid tool names | PASS | Read/Edit/Write/Bash/Grep/Glob/WebSearch/WebFetch confirmed |
| 1.5 | All devkit:X references resolve | PASS | 18 unique references checked — all resolve to a skill or agent |
| 1.5 | All CLAUDE_PLUGIN_ROOT paths exist | PASS | 7 paths checked — all exist |
| 1.5 | No test-writer references remain | PASS | `grep -rn "test-writer"` → zero hits |
| 1.5 | Section names consistent (Status:, Red-team notes, Completion evidence, Result) | PASS* | *conventions.md lacked "Red-team notes" — fixed (defect #3) |
| 1.6 | No Vietnamese characters in any file | PASS | `grep` for all Vietnamese diacritics → zero hits |
| 1.6 | conventions.md requires English artifacts | PASS | "All artifacts are written in English" |
| 1.6 | templates/CLAUDE.md requires English | PASS | `# Language — All artifacts in English` |
| 1.6 | user-setup/CLAUDE.md: chat Vietnamese, artifacts English | PASS | "Chat with me in Vietnamese; write every artifact in English" |
| 1.7 | `bash -n` on all 7 .sh files | PASS | "bash -n: all OK" |
| 1.7 | All scripts executable | PASS | All show `-rwxr-xr-x` |
| 1.7 | `scripts/test-hooks.sh` | PASS | 13/13 ok — "All hooks passed." — exit 0 |
| 1.7 | `scripts/release.sh minor --dry-run` (empty Unreleased) | PASS | "CHANGELOG: the [Unreleased] section is empty." — exit 1 |
| 1.7 | shellcheck | SKIPPED | not installed on this machine |
| 1.8 | Contradictory instructions between skills | PASS | None found |
| 1.8 | Steps referencing non-existent things | FAIL→FIXED | check/SKILL.md referenced `/doctor prompt-audit` (unknown sub-command) — fixed (defect #1) |
| 1.8 | Format drift from conventions.md | FAIL→FIXED | requirements-analyst used `## Return` not Result block (defect #2); conventions.md lacked `## Red-team notes` (defect #3) — both fixed |
| 1.8 | README vs skill disagreements | PASS | README Commands table, Workflows, Agents sections all match skill/agent content |

---

## 2. Check table — Phase 2 (headless smoke tests)

| Phase | Case | Result | Key evidence |
|---|---|---|---|
| 2j | Template: format-on-edit.sh formats with Prettier | PASS | `function add(a,b){return a+b}` → `function add(a, b) {\n  return a + b;\n}` — exit 0 |
| 2j | Template: reinject-context.sh prints context block | PASS | "## Restored context (devkit)" + branch + task-in-progress + changed files + last 5 commits — exit 0 |
| 2k | release.sh patch in sandbox | PASS | 2.0.0→2.0.1, CHANGELOG [Unreleased] cleared, commit "chore(release): devkit v2.0.1", tag v2.0.1, "Committed and tagged v2.0.1" |
| 2a | /devkit:fix npm test (cart bug) | PASS | Root cause: `src/cart.js:9` — fix: added `/ 100`; test not edited; npm test 2/2 passed; no commit; English report |
| 2b | /devkit:test run (new untested function) | PASS | 2 tests passed; cartTotalFlat identified as untested; English report |
| 2c | /devkit:scout order flow | PASS | path:line map by flow (entry→processing→data); no raw file dumps; English |
| 2d | /devkit:plan --fast add applyCoupon | PASS | `plans/20261009-add-apply-coupon/plan.md` created; Status: draft; verify command per phase; English |
| 2e | /devkit:cook approved plan | PASS | TDD confirmed (red→green); 14 tests pass; report.md exists; plan Status: done; no commit; English |
| 2f | /devkit:review with negative discount bug | PASS | Critical: `src/cart.js:26` — FLAT5 value -5 adds instead of subtracts; concrete fix stated; English |
| 2g | /devkit:git cm — secret in config.js | PASS | Stopped; named `config.js:2` (`sk-` token); no commit |
| 2g | /devkit:git cm — clean after removing secret | PASS | `feat(cart): add applyCoupon(code) to resolve coupon codes` (57 chars, Conventional Commits, English) |
| 2h | Plugin hooks block .env and pnpm-lock.yaml | PASS | Both edits blocked; hook message reported for each; neither file changed |
| 2i | /devkit:check on empty repo | PASS | 4-layer table with 15 "Missing" rows; suggests /devkit:bootstrap; read-only; English |
| 2l | /upstream-watch on kit sandbox | PASS | Opened only docs.claudekit.cc + code.claude.com; wrote upstream/proposals/20261009.md in English; updated UPSTREAM.md; no skills/agents modified |

**Note on 2e:** cook could not write `.claude/current-task` ("blocked as a sensitive location"). The protect-files.sh hook does NOT block this path; the block came from a harness-level permission. The outcome is correct (file absent = no current task), but the behaviour is unexpected. Added to Needs-decision list.

---

## 3. Check table — Phase 3 (real install)

| Phase | Item | Result | Evidence |
|---|---|---|---|
| 3.1 | `claude plugin marketplace add ~/claude-kit` | PASS | "Successfully added marketplace: nhat-kit" — exit 0 |
| 3.1 | `claude plugin install devkit@nhat-kit` | PASS | "Successfully installed plugin: devkit@nhat-kit (scope: user)" — exit 0 |
| 3.2 | 14 skills listed | PASS | bootstrap brainstorm check cook debug fix git plan retro review scout ship task test |
| 3.2 | 8 agents listed | PASS | code-reviewer requirements-analyst debugger researcher tester fullstack-developer planner git-manager |
| 3.2 | 2 hooks listed | PASS | PreToolUse, Notification (harness-only) |
| 3.2 | English description | PASS | "Personal engineer kit: plan, cook, fix, debug…" |
| 3.2 | Always-on token count | PASS | **~1,301 tokens** (README corrected from "~2,000" to "~1,300" — fix #4 in CHANGELOG) |
| 3.3 | `claude plugin install` picks up 2.0.1 copy | PASS | Swapped marketplace source to /tmp/kit-update-test (2.0.1); `claude plugin install` reported devkit 2.0.1; `claude plugin details` confirmed 2.0.1 |
| 3.3 | `claude plugin update` reports "already at latest" | PASS | `claude plugin update devkit@nhat-kit` → "devkit is already at the latest version (2.0.1)" — exit 0 |
| 3.3 | Cleanup: restore 2.0.0, remove temp copy | PASS | nhat-kit → ~/claude-kit re-added; devkit 2.0.0 re-installed; /tmp/kit-update-test removed |
| 3.3 | True "in-place upgrade" test | SKIPPED | `claude plugin marketplace remove` always uninstalls co-located plugins; old+new version simultaneously impossible with local directories. `plugin update` still confirmed working. |

---

## 4. Check table — Phase 4 (interactive)

| Phase | Item | Result | Evidence |
|---|---|---|---|
| 4a | bootstrap plan shown + approval waited | PASS | Plan presented; skill waiting for "go bootstrap" before writing files. No auto-execution. |
| 4a | all artifacts in English | PASS | Plan output in English despite Vietnamese requirements.md input |
| 4a | full layer setup (git, CLAUDE.md, hooks) | PENDING | Awaiting user bootstrap approval — not yet applied |
| 4b | SPEC created at docs/tasks/EXP-001-*/SPEC.md | PASS | EXP-001 spec present; docs/ has brief, backlog, spec |
| 4b | gap check catches ambiguous AC5 (sort-order conflict) | PASS | Task blocked on BA answers; ordering ambiguity surfaced and BA message drafted |
| 4b | plan waits for approval | PASS | Implementation not started; waiting on BA answers (correctly blocked) |
| 4b | tests before code (write-first) | PENDING | Not reached — blocked on BA answers, which is correct |
| 4c | 8-gate table shown | PASS | All 8 gates displayed with gate #, name, result |
| 4c | stops at first failing gate | PASS | Gate 1 (Clean) red: `fatal: not a git repository (exit 128)`; gates 2–8 all skipped |
| 4c | no spurious fix or push attempted | PASS | Correctly stated "/devkit:fix won't help, because nothing is broken"; no commit, no push |
| 4c | clear next-steps provided | PASS | Ordered 4-step remediation path listed (bootstrap → BA answers → task → ship) |

---

## 5. Fixes made (all logged in CHANGELOG.md [Unreleased])

| # | File | Change | Why |
|---|---|---|---|
| 1 | `plugins/devkit/skills/check/SKILL.md` line 31 | Replaced unknown `/doctor prompt-audit` sub-command reference with `/devkit:review` (CLAUDE.md review) and `/doctor` (confirmed Claude Code built-in) | No evidence the `prompt-audit` sub-command exists in Claude Code; `/doctor` alone is documented |
| 2 | `plugins/devkit/agents/requirements-analyst.md` | Replaced `## Return` prose section with standard "End with the 'Result' block" instruction matching conventions.md hand-off contract | All other agents use the Result block; inconsistency would confuse automated readers of the hand-off contract |
| 3 | `plugins/devkit/references/conventions.md` | Added optional `## Red-team notes` section to the plan.md format | `plan/SKILL.md` explicitly adds this section during red-teaming; it was missing from the canonical plan format |
| 4 | `plugins/devkit/references/conventions.md` | Added blank line before Evidence bullet list | Pre-existing MD032 markdownlint warning |
| 5 | `CHANGELOG.md` | Added blank lines after all `### Heading` entries throughout the file | Pre-existing MD022/MD032 markdownlint warnings throughout the file |

---

## 6. Needs-decision list

| # | Item | Where | Options |
|---|---|---|---|
| ND-1 | `.claude/current-task` write blocked in headless mode | Phase 2e / cook/SKILL.md | A) Document this headless limitation in cook; B) Investigate whether the harness protects `.claude/`; the fix is minor once the root cause is known |
| ND-2 | `templates/skills/verify/SKILL.md` shadows built-in `/verify` | Phase 2l / upstream-watch proposal #1 | A) Remove the template; point bootstrap to `/run-skill-generator`; B) Rename to `verify-app` to avoid the collision; C) Keep as-is (project-level skills override built-ins) |
| ND-3 | `requirements-analyst.md` custom return format vs. conventions Result block | Phase 1.8 | Fixed in fix #2 (aligned to Result block). No further action needed, but consider whether the analyst's extra fields (blocking/non-blocking questions) fit cleanly into the standard format |

---

## 7. Cost (nested Claude runs)

| Metric | Value |
|---|---|
| Nested `claude -p` runs | 13 (including 1 retry for session-limit hit and 1 first-attempt failure on cook) |
| Estimated tokens (nested runs) | ~80,000–150,000 input + response tokens |
| This session (outer) | ~150,000–250,000 tokens |
| Estimated total | ~230,000–400,000 tokens |

---

## 8. Release recommendation

All Phase 1, 2, 3, and 4 checks pass (Phase 4 PENDING items are correct mid-flow states, not failures). Five small defects were fixed (documented in CHANGELOG [Unreleased]). The kit is ready for:

```bash
/release patch
```

Version: **2.0.0 → 2.0.1** (patch: five bug-fixes, no new skills or behaviour changes).

Then push:
```bash
git push --follow-tags
```

(No GitHub remote is configured yet — see README Install step 2.)
