# Stale claims and open-PR back-pressure in the task queue
Status: done · Source: P-30 and P-36 in `upstream/proposals/20261018.md` (stage 1, shared queue) · Mode: --fast

## Goal
`/devkit:task next` gets two new behaviors.
- **Stale claims (P-30).** It lists `in-progress` issues whose latest devkit claim is older than a TTL and that have no open PR referencing them. It offers to take one over, and takes it over only when the user picks it.
- **Back-pressure (P-36).** When open, non-draft PRs are at or over a limit, it suggests reviewing one first and claims new work only if the user says so.

Both limits come from `docs/devkit.md`: `claim_ttl_minutes` (default 120) and `max_open_prs` (default 5; 0 turns the check off). A deterministic script computes the queue state, so the model does no date math.

## Context found
- `plugins/devkit/references/conventions.md` "GitHub issue queue":
  - Labels: `ai`, `in-progress`, and the severity labels.
  - Claim and release comment formats: `🔒 devkit claim · host: … · task: … · <ISO-8601 UTC>` and `🔓 devkit release · …`.
  - Rules: the earlier claim wins; an issue is taken over only when the user says so, and the claim comment says so; `gh issue view` has no lag.
- `plugins/devkit/skills/task/SKILL.md:20`: `next` lists `--label ai --state open`, drops `in-progress`, sorts by severity then age, and shows the top 3 via AskUserQuestion. `:21`: claim, and an in-progress issue stops unless the user takes it over. `:73-75`: release.
- `plugins/devkit/skills/task/SKILL.md:6`: `allowed-tools` already includes `Bash(gh issue view *)`, `Bash(gh issue list *)`, `Bash(gh pr view *)`, and `Bash(bash */pr-size.sh *)`.
- `plugins/devkit/templates/docs/devkit.md`: the project settings doc (`- key: value`; the first match wins; defaults apply when missing). `pr-size.sh` already parses it, and its `cfg_get`/`cfg_int` helpers are the pattern to reuse.
- `scripts/test-hooks.sh`: the `row`/`check` helpers with temp dirs. Tests can put a stub `gh` first on `PATH`, the way the agile-squad repo tests its board script; that repo was read only as an idea source.
- `gh --jq` exists but cannot be stubbed easily. Raw `gh … --json` output plus `python3` for the logic is testable, and `python3` is already a soft dependency of the template hooks.

## Approach
- **`templates/docs/devkit.md`**: add `- claim_ttl_minutes: 120` and `- max_open_prs: 5`, each with a one-line reason.
- **New `scripts/queue-status.sh`** (bash wrapper, `python3` for the JSON):
  - Read `claim_ttl_minutes` and `max_open_prs` from `docs/devkit.md` with the same parsing as `pr-size.sh`.
  - Run `gh pr list --state open --limit 200 --json number,isDraft,body,headRefName`:
    - `open_prs` = the count of non-draft PRs.
    - `referenced` = the issue numbers named by `Closes|Fixes|Resolves #N` in PR bodies.
  - Run `gh issue list --label ai --label in-progress --state open --limit 100 --json number,title,comments`. For each issue, take the latest comment starting with `🔒 devkit claim` and the latest starting with `🔓 devkit release`. The issue is stale when the claim is older than the TTL, no release comes after it, and no open PR references the issue.
  - Output:
    - `open_prs=N max_open_prs=M pressure=ok|over|off ttl_minutes=T stale=K`
    - then one row per stale issue: `#N<TAB>host<TAB>age_minutes<TAB>title`
  - Exit codes: 0 ok, 1 when `gh` or `python3` fails, with a one-line message on stderr.
- **`task/SKILL.md` `next`** (one or two sentences):
  - First run `bash ${CLAUDE_PLUGIN_ROOT}/scripts/queue-status.sh`.
  - `pressure=over`: say how many PRs wait for review, suggest `/devkit:review #N`, and continue only if the user says so.
  - Stale rows: offer them after the top 3, labelled "stale claim · host · N min". Taking one over follows the existing takeover rule.
  - Exit 1: fall back to today's behavior (drop `in-progress`) and say why.
- **`task/SKILL.md` allowed-tools**: add `Bash(bash */queue-status.sh *)` and `Bash(gh pr list *)`.
- **Conventions**: two sentences in "GitHub issue queue" defining a stale claim and back-pressure, both pointing to `docs/devkit.md`.

Rejected:
- Editing the claim comment to "released" (the agile-squad style): devkit already posts a release comment, and the claim-race rule already counts releases. Editing adds API calls for no new behavior.
- Automatic takeover of stale claims: a long task can legitimately exceed the TTL. The user decides.
- A heartbeat that refreshes the claim during long tasks: no need yet. Taking over still needs the user's word.
- Counting only the current user's PRs: the queue is shared, and review load is what matters.

## Phases

### Phase 1: settings and `queue-status.sh`, tests first
- [x] Write the `scripts/test-hooks.sh` cases first, with a stub `gh` on `PATH` that returns canned JSON per subcommand. Show they fail. Cases:
  - 2 open PRs (one draft), limit 5 → `open_prs=1 … pressure=ok`.
  - 5 non-draft PRs → `pressure=over`.
  - `max_open_prs: 0` in `docs/devkit.md` → `pressure=off`.
  - A claim 3 hours old, no release, no PR → 1 stale row with the host and an age ≥ 180.
  - The same claim with a later release → not stale.
  - The same claim with an open PR saying `Closes #N` → not stale.
  - A 10-minute-old claim → not stale.
  - `claim_ttl_minutes: 30` and a 45-minute claim → stale.
  - A failing `gh` (stub exits 1) → exit 1.
  - A malformed comment time → the issue is skipped, not a crash.
- [x] Create `plugins/devkit/scripts/queue-status.sh` (chmod +x). Add the two keys to `plugins/devkit/templates/docs/devkit.md`.
- Verify:
  - `/bin/bash -n plugins/devkit/scripts/queue-status.sh` → exit 0.
  - `scripts/test-hooks.sh; echo "exit=$?"` → all `queue-status` rows `ok`, `exit=0`.
  - Run `bash plugins/devkit/scripts/queue-status.sh` against this repo (real `gh`): it prints a summary line and exits 0.

### Phase 2: wire into task and conventions, then docs
- [x] `task/SKILL.md` `next` sentence and the allowed-tools additions.
- [x] `references/conventions.md` "GitHub issue queue": two rule sentences.
- [x] `CHANGELOG.md` `[Unreleased]` (Added: the script; Changed: `next`, the settings doc). `UPSTREAM.md` P-30 and P-36 → ✅. Note in the proposal under v2.6.0.
- Verify:
  - `grep -c 'queue-status.sh' plugins/devkit/skills/task/SKILL.md` → ≥ 1. `grep -c 'claim_ttl_minutes\|max_open_prs' plugins/devkit/references/conventions.md` → ≥ 1.
  - `git diff --numstat -- plugins/devkit/skills/task/SKILL.md` → ≤ 3 added.
  - `claude plugin validate plugins/devkit --strict && claude plugin validate .` → pass. `scripts/test-hooks.sh` → exit 0.
  - `bash plugins/devkit/scripts/pr-size.sh main` → `status=ok` under this repo's `docs/devkit.md`.

## Risks
| Risk | Signal | Mitigation |
| --- | --- | --- |
| A long, legitimate task looks stale | Another machine offers a takeover mid-task | Only an offer; the takeover rule requires the user's word, and the new claim comment says so |
| `python3` is missing | Exit 1 "python3 required" | The skill falls back to today's behavior (drop `in-progress`) and says why |
| A PR references the issue in another form (`fix #N`, a branch name) | A stale claim is shown although work is in review | Match `Closes/Fixes/Resolves #N` case-insensitively. The user still decides; noted as a guardrail |
| The `gh` JSON shape differs (comment `createdAt`, `author`) | Parse errors | Stub fixtures copy the real `gh` field names; the Phase 1 real-repo run checks them |
| API cost on big queues | Slow `next` | `--limit 100` issues and `--limit 200` PRs; one call each |

## Out of scope
- Heartbeats, automatic takeover, editing claim comments, per-author PR counts, `/devkit:check` queue checks (P-32), and a release.
