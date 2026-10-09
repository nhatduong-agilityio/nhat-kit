---
name: deploy
description: Deploy to staging then production after a PR merges. Auto-detects Vercel, Fly, Railway, Docker, or a custom deploy script; asks before each environment.
argument-hint: "[staging|prod] [--dry-run]"
disable-model-invocation: true
---

# Deploy

Target environment: `$ARGUMENTS` (default: staging then prod).

Conventions: `${CLAUDE_PLUGIN_ROOT}/references/conventions.md`. Use a task list for the gates below. **Stop at the first red gate** and report the error.

## Gate 1 — Preflight

- Confirm the current branch is the default branch (main or master). If not, ask the user to confirm they intend to deploy from this branch before continuing.
- `git status` must be clean (no uncommitted changes).
- `git pull --ff-only` must succeed (branch is up to date with remote).

## Gate 2 — Deploy config detection

Auto-detect the platform in this order (first match wins):

| Priority | Condition | Command |
| --- | --- | --- |
| 1 | `deploy` key in `package.json` scripts | `npm run deploy` |
| 2 | `vercel.json` or `.vercel/` directory | `vercel deploy --prod` |
| 3 | `fly.toml` | `fly deploy` |
| 4 | `railway.json` or `railway.toml` | `railway up` |
| 5 | `Dockerfile` + `docker-compose.yml` | `docker compose up -d --build` |
| 6 | `deploy.sh` | `bash deploy.sh` |

If nothing is found: stop and tell the user to add a `deploy` script to `package.json` or create a supported config file.

If `--dry-run`: print the detected platform and command, then stop (exit 0, nothing deployed).

## Gate 3 — Staging deploy

Show the staging command to the user and **ask for confirmation** before running.

Delegate to the `devkit:deployer` subagent with:
- `platform`: detected name
- `command`: the deploy command
- `environment`: staging

On failure: stop; show the last 20 lines of the deployer's output.

## Gate 4 — Staging smoke test *(optional)*

If the project has a `.claude/skills/verify/SKILL.md`, run it against the staging URL from Gate 3.

If no verify skill exists: skip this gate with a note ("no verify skill — smoke test skipped").

## Gate 5 — Production deploy

Show the production command and the staging URL side by side.

**Ask explicit confirmation** before running — display the exact command so the user knows what will execute.

Delegate to `devkit:deployer` with `environment`: prod.

On success: report the production URL. Suggest tagging the release:
```
/devkit:git cm   (use message: "deploy(prod): vX.Y.Z — <one-line summary>")
```

Note: if the deploy command is known to be slow, prepend `timeout 300` to avoid hanging the session.

## Reply

A table of the 5 gates (passed / failed / skipped with reason), the staging URL, the production URL, and the suggested next action.
