---
Status: done
---

# Plan: add /devkit:deploy skill

## Goal

Add a `/devkit:deploy` skill that deploys the current branch to staging then production after a PR merges. Auto-detects the platform from config files (Vercel, Fly.io, Railway, Docker, or a custom script), runs staging first, asks for explicit confirmation before production, and reports deployment URLs as evidence. Adds a `deployer` agent to execute individual deploy commands and capture output.

## Context found

- Skills live in `plugins/devkit/skills/<name>/SKILL.md`; adding a folder is enough for discovery — `plugin.json` does not list skills explicitly.
- Agents live in `plugins/devkit/agents/<name>.md`; same auto-discovery.
- `ship/SKILL.md` — closest pattern: `disable-model-invocation: true`, gate-based table, stops at first failure, asks before pushing, delegates to agents.
- `git/SKILL.md` — `allowed-tools` restriction example; delegates everything to `git-manager`.
- Conventions: `${CLAUDE_PLUGIN_ROOT}/references/conventions.md` (hand-off contract, Result block).
- No existing skill covers post-merge deployment.

## Approach

Three phases:
1. Write `deploy/SKILL.md` (the new command).
2. Write `agents/deployer.md` (executes one deploy command, reports evidence).
3. Update README commands table, CHANGELOG, UPSTREAM.

## Phases

### Phase 1 — `plugins/devkit/skills/deploy/SKILL.md` (M)

Frontmatter:
```
name: deploy
description: Deploy to staging then production after a PR merges. Auto-detects Vercel, Fly, Railway, Docker, or a custom deploy script; asks before each environment.
argument-hint: "[staging|prod] [--dry-run]"
disable-model-invocation: true
```

Skill body — 5-gate flow:

**Gate 1 — Preflight**
- Must be on the default branch (main/master), or confirm intent.
- `git status` clean; `git pull --ff-only` succeeds.

**Gate 2 — Deploy config**
Auto-detect platform in this order (first match wins):
1. `deploy` key in `package.json` scripts → `npm run deploy`
2. `vercel.json` or `.vercel/` → `vercel deploy --prod`
3. `fly.toml` → `fly deploy`
4. `railway.json` or `railway.toml` → `railway up`
5. `Dockerfile` + `docker-compose.yml` → `docker compose up -d --build`
6. `deploy.sh` → `bash deploy.sh`

If nothing found → stop; tell user to add a `deploy` script to `package.json` or a supported config file.

If `--dry-run`: print detected platform + command, then stop with exit 0.

**Gate 3 — Staging deploy**
- Show the staging command; ask confirmation before running.
- Delegate to `devkit:deployer` agent with: platform, command, environment=staging.
- Agent captures stdout/stderr; extracts deploy URL from output (e.g. `https://…vercel.app`).
- On failure → stop; show last 20 lines of output.

**Gate 4 — Staging smoke test** *(optional)*
- If the project has a `verify` skill, run it against the staging URL.
- Skip with a note if no verify skill exists.

**Gate 5 — Production deploy**
- Show production command and staging URL side by side.
- **Ask explicit confirmation** with the exact command before running.
- Delegate to `devkit:deployer` with environment=prod.
- On success → report prod URL and suggest tagging: `/devkit:git cm` with a `deploy(prod): vX.Y.Z` message.

Reply with: gate table (passed / failed / skipped), staging URL, prod URL, suggested next action.

**Verify (Phase 1):** `claude plugin validate plugins/devkit --strict` — must pass. Confirm `skills/deploy/SKILL.md` exists.

---

### Phase 2 — `plugins/devkit/agents/deployer.md` (S)

```
name: deployer
description: Execute one deployment command (staging or production), capture its full output, extract the deployment URL, and report success or failure with evidence. Used by /devkit:deploy.
tools: Bash, Read
model: inherit
```

Body:
- Role: "You are a senior DevOps engineer. You execute exactly one deployment command and report what happened."
- Run the given command; capture all output (stdout + stderr).
- Extract the deployment URL from the output using common patterns (lines containing `https://`, `Deployed to`, `Live at`, `Preview:`, `Production:`).
- Result block: Status (done | blocked), Environment (staging | prod), URL (extracted or "not found"), Command run, Exit code, Last 20 lines of output.

**Verify (Phase 2):** `claude plugin validate plugins/devkit --strict` — still passes.

---

### Phase 3 — Update README, CHANGELOG, UPSTREAM (XS)

**README.md** commands table — add after `ship`:
```
| `/devkit:deploy [staging|prod] [--dry-run]` | After a PR merges: deploy to staging then prod | deployer |
```

**CHANGELOG.md** under `[Unreleased]`:
```
### Added
- `/devkit:deploy`: new skill for post-merge deployment. Auto-detects platform (Vercel, Fly, Railway, Docker, custom script), deploys staging first, asks for explicit production confirmation, reports deployment URLs.
- `deployer` agent: executes a single deploy command and extracts the deployment URL from output.
```

**UPSTREAM.md** — change `deploy (v2.14.0 upcoming)` row status from `⏳` to `✅` (P-5 done).

**Verify (Phase 3):** `claude plugin validate plugins/devkit --strict && claude plugin validate .` — both pass. Grep confirms `devkit:deploy` present in README.

---

## Risks

- **Platform coverage**: detection order covers the most common platforms; projects with unusual setups need a `deploy.sh` or `package.json` script. Mitigated: clear error message + suggestion when nothing is detected.
- **Hanging deploys**: Bash has no timeout by default. Mitigated: note in the skill to use `timeout 300 <command>` if the project's deploy is known to be slow.
- **Production safety**: Gate 5 requires explicit confirmation with the exact command shown. Risk is low.
- **`--dry-run` scope**: stops after platform detection; does not run staging. Useful for CI dry runs.

## Out of scope

- Multi-target deploys (e.g. deploy to both Vercel and Fly in one run).
- Rollback command (future proposal).
- CI/GitHub Actions integration.

## Red-team notes

*(not red-teamed — see Risks section for mitigations)*
