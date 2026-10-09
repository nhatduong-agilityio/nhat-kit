---
name: verify
description: Build, run, and check this project's real app to confirm a change works, rather than relying on tests alone.
---
<!-- TEMPLATE: bootstrap records the recipe that actually worked. Update it when the build or run process changes. -->
# Verify {{PROJECT_NAME}}

## Prerequisites
- Required environment variables: {{ENV_VARS}} (sample values in `.env.example`)
- Dependent services: {{SERVICES}} (e.g. `docker compose up -d db`)

## Static checks
1. `{{TYPECHECK_CMD}}`
2. `{{LINT_CMD}}`
3. Tests related to the changed files: `{{TEST_ONE_CMD}} <path>`

## Run the app
1. Start `{{DEV_CMD}}` in the background; wait until {{DEV_URL}} responds.
2. Open the screens affected by the change (see `git diff --name-only`) and walk through the main flow.
3. UI changes: have the `ui-verifier` subagent check them against the SPEC.

## Result
Report: commands run with condensed output, screens checked, console/network errors. Stop any dev server you started.
