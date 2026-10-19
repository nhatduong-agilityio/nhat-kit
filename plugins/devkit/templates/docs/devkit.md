# Devkit settings

This file holds the tunable settings that devkit skills read at run time (for example the PR size gate in `/devkit:ship`, `/devkit:task`, and `/devkit:review`). Edit the values to fit your team. A key that is missing, empty, or not valid falls back to the built-in default, shown here.

Keep one `- key: value` per line. Do not use these exact `- key:` forms in prose.

- pr_max_lines: 300

Most lines (added plus deleted) one PR may change, so reviewers can read it in a single sitting.

- pr_max_files: 10

Most files one PR may touch, so a change stays about one concern.

- pr_size_exclude: *.lock, package-lock.json, pnpm-lock.yaml, yarn.lock, go.sum, Cargo.lock, **/__snapshots__/**, *.snap, dist/**, build/**, *.min.*

Comma-separated globs for files that do not count toward the limits, because they are generated and nobody reviews them line by line. Matching rule: `*` matches any characters including `/`; a glob without `/` is also matched against the file name alone (so `yarn.lock` covers `apps/web/yarn.lock`); a leading `**/` also matches zero directories. Setting this key replaces the whole default list. `dist/**` and `build/**` match only at the repo root; in a monorepo, use `**/dist/**`.

- claim_ttl_minutes: 120

How long a task claim may sit without a release before `/devkit:task next` offers it as stale. Keep it above your longest normal task, because a long task can look stale; a stale claim is only offered, never taken over automatically.

- max_open_prs: 5

Open, non-draft PRs at which `/devkit:task next` suggests reviewing one before claiming new work, so review does not pile up. `0` turns the check off.
