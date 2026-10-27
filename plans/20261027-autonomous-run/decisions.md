# Autonomous run — decisions log

Started 2026-10-27. The user asked: finish every remaining item in `upstream/proposals/20261018.md` without asking or waiting for acceptance, and log every question, answer and choice here for one review at the end ("chốt và fix 1 lần").

## Authorization boundary (set at the start)
- Allowed and used without asking: self-approving plans (`Approved: <date> by nhatduong-agilityio (autonomous run, pre-authorized 2026-10-27)`), commit, push, PR, rebase-merge of my own PRs in nhat-kit, deleting merged branches.
- Not done; logged under "Pending for the user" with exact commands: `/release` and tag pushes, changes to real GitHub settings (rulesets, environments, org, creating repos), force pushes, deleting unmerged branches.
- Quality rules: each plan states its acceptance bar before cooking; reviewers are judged against it; cook's 3-round cap stays — an item with a bar-level Critical left is not merged, it is logged and skipped.

## Progress
| Item | Status | PRs | Notes |
| --- | --- | --- | --- |
| P-28 ingestion, phase 1 (core) | done | #43 | |
| P-28 phase 2 (zip/XML safety, docx) | done | #44 | |
| P-28 phase 3 (pptx, xlsx) | done (merging) | | review: 0 Critical |
| P-28 phase 4 (pandoc, pdftotext) | todo | | |
| P-28 phase 5 (links) | todo | | |
| P-28 phase 6 (skills, docs) | todo | | |
| P-45 deploy guardrails | planned (6 phases) | | `plans/20261027-deploy-guardrails/plan.md` |
| P-31 post-deploy error scan | todo | | |
| P-38 production approval | todo | | |
| v2.7.0 release | pending for the user | | |
| P-39 machine-readable agent results | todo | | |
| P-40 per-task worktree | todo | | |
| P-41 dependency waves | todo | | |
| P-42 orchestrated run | todo | | grill first (self-answered) |
| P-43 agents stay in their lane | todo | | verify hook input first |

## Decisions (status: needs-review unless noted)
Format: ID · item · question · options · choice and why · how to reverse.

- **D-01 · P-28 · Redaction scope.** Q: is best-effort redaction (emails and phone numbers; names and addresses not redacted; listed body gaps) acceptable to ship? Options: (a) ship best effort with Risks; (b) block until more formats are covered. Choice: (a) — the user had chosen auto-redaction with names kept (decision 3), and the remaining gaps are listed in the plan Risks. Reverse: extend `RX` / `hit()` in `plugins/devkit/scripts/ingest.sh`; add corpus rows.
- **D-02 · P-28 · Decision A.** Q: when a PDF is skipped (no pdftotext), may the model read it directly for the SPEC? Choice: yes, but the SPEC `Source:` must say "original PDF read directly; no saved source". Reverse: phase 6 skill text.
- **D-03 · P-28 · Decision B.** Q: a task file with no ticket key — where does the slug come from? Choice: `ingest.sh --slug <file>` (redacted). Reverse: phase 6 task skill text.
- **D-04 · P-28 · Name redaction design.** Q: after five review rounds of regex patches, how to redact names? Choice: a name or folder with `@` or a 9–15 digit `+`/`0` run (any separators, NFKC-matched) drops its whole stem; identity reused only for a byte-identical origin. Trade-off: harmless names like `v1.0 20241021.md` become `[redacted]`. Reverse: `hit()`/`seg()` in ingest.sh.
- **D-05 · P-28 · OPC leading `/`.** Q: refuse absolute rels targets, or treat a leading `/` as the package root? Choice: package root (OPC rule; real files use `/word/document.xml`). Reverse: one line in `docx()`.
- **D-06 · P-28 · Converter ids.** Choice: `stdlib-<format>-<n>` with no space (stdout fields are space-separated); pandoc/pdftotext ids follow the same rule in phase 4.
- **D-07 · P-46 · Defaults.** Choices: cross-repo links not tested; org repo cited as `<org-repo>`; branch `docs/p46-squad-task-state`; org verification out of scope (user decision, recorded). Reverse: re-run the probe plan on an org repo.
- **D-08 · P-37 · Header deviation.** Q: list Phase 3 keys in the metrics.sh header before they existed? Choice: header lists only what the script prints (it was later extended). No action needed.
- **D-09 · housekeeping · Issues #41, #42.** Two open `retro` issues (created 2026-10-22 outside this session): "cook: allow commits that the approved plan includes" and "pr-size: daily-report PRs always exceed the limit because of plans/". Not part of the upstream plan; left untouched. Review them separately.

- **D-10 · P-43 · Precondition (verified from docs, 2026-10-27).** Q: does PreToolUse hook input identify the calling subagent? Answer: yes — `agent_id` and `agent_type` (e.g. `devkit:fullstack-developer`) are present when a subagent, teammate or `--agent` agent makes the call, absent for the main session; plugin `hooks/hooks.json` PreToolUse hooks apply to subagent calls (https://code.claude.com/docs/en/hooks.md). So P-43 can be a real hook, not only prompt discipline. Not yet tested live.
- **D-11 · P-40 · `claude -w` check (verified from docs, 2026-10-27).** `claude --worktree <name>` creates `.claude/worktrees/<name>/` on branch `worktree-<name>`, auto-removes clean ones, copies gitignored files listed in `.worktreeinclude`, and has `WorktreeCreate`/`WorktreeRemove` hooks (https://code.claude.com/docs/en/worktrees.md). It has no per-worktree PORT or test DB. Choice for P-40: reuse Claude Code's worktree location and naming where possible and add only what is missing (slot → PORT and DB name in `.env.local`, plus `clean`), rather than a parallel `.worktrees/<issue>` scheme. Reverse: the P-40 plan.

- **D-12 · P-45 · Platforms and shape.** Q: which platforms and where does the mapping live? Choice: built-in tables for railway, vercel, fly and docker compose; custom/cloud setups map commands with `- deploy_<sub>: <command>` keys in `docs/devkit.md` (the project settings doc); read subcommands `status`, `logs`; write subcommands `deploy`, `rollback`, `set-var` (prints the exact command for the user to type, never takes a value). Reverse: `deploy-cli.sh` tables and the docs/devkit.md template.
- **D-13 · P-45 · Hook scope.** Q: the plugin hook runs in every project — which direct commands does it block? Choice: block (exit 2) the hosted platforms' write commands — `railway` (up, redeploy, down, variables set), `vercel` (deploy, `--prod`, env add/rm, promote, rollback), `fly`/`flyctl` (deploy, secrets set/unset, scale, apps destroy) — and leave docker and read commands (status, logs, list) alone, because local development runs docker constantly. The message ends with `! <cmd>` so a person can still run it. Reverse: the hook's write table.
- **D-14 · P-45 · No role check.** The source restricts writes to a devops role; devkit has no roles, so writes are gated by `/devkit:deploy`'s explicit yes (Gates 3 and 5) instead. Reverse: add a role key later.

- **D-15 · P-45 · npm and deploy.sh projects.** Q: keep Gate 2 rows 1 (package.json deploy script) and 6 (deploy.sh)? Options: built-in `npm` and `script` platforms vs requiring a `deploy_deploy` key. Choice: built-in platforms, so existing projects keep working with no setup. Reverse: drop the two table rows in deploy-cli.sh.
- **D-16 · P-45 · set-var and `!`.** Choice: the wrapper prints the exact `!` command and a note to prefer running it in the user's own terminal, because a value typed after `!` lands in the session transcript. Reverse: wrapper text.
- **D-17 · P-45 · Vercel `--prod`.** Choice: block `--prod` only when it deploys; `vercel build --prod` and `vercel pull --environment=production` stay allowed. Reverse: the hook's vercel table.
- **D-18 · P-45 · allowed-tools.** Choice: pre-approve only the read and `--dry-run` forms of deploy-cli.sh; a real deploy still shows a permission prompt after the explicit yes. Unverified: mid-pattern `*` matching in allowed-tools rules. Reverse: the deploy skill frontmatter.
- **D-19 · P-45 · `timeout 300` note.** Choice: drop it from the deploy skill (macOS has no `timeout`); deploy-cli.sh bounds `logs` itself. Reverse: skill text.
- **D-20 · P-45 · Shared tokenizer.** Choice: move the tokenizer from block-force-push.sh into `scripts/shell-segments.sh`, used by both hooks, done in two PRs (copy, then switch) because `pr-size.sh` counts a move twice. Reverse: revert phase 3 of P-45.

- **D-21 · P-28 phase 3 · Follow-ups not done.** Reviewer Warnings 3–4: no test rows for cells/rows without an `r` attribute, or for escaping `|`/newlines in inline/`str` values and sheet names (no leak; table shape only). Left as follow-ups to keep the PR small. Reverse: add rows to the `ox` builder.
- **D-22 · P-28 phase 3 · Repeated parts are re-read.** The developer tried caching repeated sheet/slide parts and dropped it (no row needed it; the 100 MB total cap bounds the cost: ~14 s worst case). Reverse: cache by part name in `part()`.

## Pending for the user
- (filled in as items reach a release or a real-GitHub change)
