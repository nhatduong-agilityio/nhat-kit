# Deploy guardrails for any platform (P-45)
Status: approved · Source: upstream/proposals/20261018.md:44 (P-45); decisions D-12, D-13, D-14 in plans/20261027-autonomous-run/decisions.md
Approved: 2026-10-27 by nhatduong-agilityio (autonomous run, pre-authorized 2026-10-27)

## Goal
Deploys and platform writes go through one plugin script, `deploy-cli.sh <platform> <subcommand>`, which never takes a secret value. A new plugin hook blocks direct `railway`/`vercel`/`fly` write commands and ends its message with `! <cmd>` so a person can still run them. `/devkit:deploy` runs its staging and production deploys through the wrapper. P-31 (log scan) and P-38 (environments) build on `deploy-cli.sh <p> logs` and the Gate 5 call later.

## Context found
- `plugins/devkit/scripts/block-force-push.sh:7-15`: reads the command through `json-field.sh`, then a fast path (`*git*push*|*gh*pr*`).
- `block-force-push.sh:19-24`: `block()` prints `Blocked by devkit: '<cmd>' <reason> ! <cmd>` and exits 2.
- `block-force-push.sh:79-98`: skips env assignments, keywords and wrappers (`env nice sudo xargs timeout time command exec nohup`).
- `block-force-push.sh:100-104`: dispatches on `${w[$i]##*/}`, so full paths work.
- `block-force-push.sh:138-326`: the generic tokenizer (segments on `; & | \``, `( )`, `$( )` even inside `"…"`, heredoc bodies skipped, comments, redirects, `$'…'`, arithmetic). Its only rule-specific line is the line fast path at `:214` (`*git*|*gh*|…`). It calls a global `check_segment`.
- `block-force-push.sh` has no `cd` handling and needs none here. Segmentation already splits `cd x && fly deploy` into its own segment. The `cd` tracking in `templates/hooks/block-protected-push.sh:54-59` exists only because git remotes depend on the directory.
- `plugins/devkit/hooks/hooks.json:13-20`: the one PreToolUse `Bash` entry. The new hook is a second command in the same `hooks` array.
- `plugins/devkit/scripts/pr-size.sh:94`: `git diff --numstat --no-renames`. A file move counts twice, so the tokenizer extraction needs two PRs (see Approach).
- `pr-size.sh:33-37`: `cfg_get` reads `- key: value` from `$top/docs/devkit.md`. deploy-cli.sh reads `deploy_*` keys the same way.
- `plugins/devkit/skills/deploy/SKILL.md`:
  - `:20-33` Gate 2 detection table (npm, vercel, fly, railway, compose, deploy.sh)
  - `:35` `--dry-run`
  - `:37-46` and `:54-60` Gates 3 and 5 delegate a raw command to `devkit:deployer`
  - `:67` suggests `timeout 300`
  - it has no `allowed-tools`
- `plugins/devkit/agents/deployer.md:8-27`: runs exactly one command. Its Result block includes Command and Exit code.
- `allowed-tools` precedent: `plugins/devkit/skills/check-fix/SKILL.md:5` (`Bash(bash */team-fix.sh *)`).
- `scripts/test-hooks.sh`:
  - `:17-33` `expect`
  - `:35-39` `bash_cmd` (clone it as `deploy_cmd`)
  - `:54-188` block-force-push rows (~130, the regression proof for Phase 2)
  - `:191` `row()`
  - stub-on-PATH sections at `:525` (queue-status) and `:710` (team-fix)
- Docs to touch:
  - `README.md:3` (3 hooks listed) and `README.md:25` (deploy row)
  - `UPSTREAM.md:151` (P-45 ⏳) and `UPSTREAM.md:80` (hooks list)
  - `CHANGELOG.md:5` `[Unreleased]`
  - `plugins/devkit/templates/docs/devkit.md:5` ("Do not use these exact `- key:` forms in prose")
  - `plugins/devkit/templates/CLAUDE.md:41` (hook sentence)

## Approach
**Shared tokenizer, two hooks.**
- Move `block-force-push.sh:138-326` into a sourced library, `plugins/devkit/scripts/shell-segments.sh`. It is not a hook and not registered.
- Interface:
  - `scan_segments <cmd>` strips `\r`, sets `LC_ALL=C`, and calls the caller's `check_segment <word>...` once per simple command.
  - The caller also defines `line_relevant <line>`, which returns 0 when a line may hold a checked command. It replaces the hard-coded `*git*|*gh*` at `:214`; the quote, paren and backslash triggers stay in the library.
  - Each hook keeps its own pre-tokenizer fast path, `block()` and rules.
  - A missing library makes the hook exit 0 (`[ -r "$lib" ] || exit 0`).
  - Library state uses a `_seg_` prefix (`_seg_i`, `_seg_line`, `_seg_ctx`, …). Callbacks (`check_segment`, `line_relevant` and their helpers) declare every variable `local`. Under bash's dynamic scoping this keeps a callback from overwriting the tokenizer loop's state.
- `block-direct-deploy.sh` holds only the deploy rules:
  - It reuses the wrapper-skipping loop shape of `:79-98`.
  - It adds unwrapping of `npx`/`bunx`/`npm exec`/`npm x`/`pnpm dlx`/`yarn dlx`. Their options (`-y`, `--yes`, `-p <pkg>`, `--package=…`, `--`) are skipped and `@version` is stripped from the binary.
  - It dispatches on the basename: `railway`, `vercel`, `fly`, `flyctl`.
- A deploy-cli.sh call passes because its first word is `bash` (or the script path), not a platform binary. deploy-cli.sh runs the platform CLI as a child process, which no hook sees.

**Hook write table (D-13).** The value-taking global flags listed here are skipped before the subcommand.
- railway: `up`, `redeploy`, `down`, `variables` with `--set`/`--set=…`, `variables set`.
- vercel: `deploy`, `redeploy`, `promote`, `rollback`, `env add|rm|remove|update`, and the default command.
  - The default command is bare `vercel`, `vercel --prod`, or a first positional that is not a known subcommand (a path). It deploys.
  - Only `--version`/`-v`/`--help`/`-h` alone are allowed.
  - Known non-deploy subcommands (one array, not live-verified): `alias`, `bisect`, `build`, `certs`, `dev`, `dns`, `domains`, `env` (writes listed above), `git`, `help`, `init`, `inspect`, `link`, `list`, `login`, `logout`, `logs`, `ls`, `project`, `projects`, `pull`, `rm`, `remove`, `secrets`, `switch`, `teams`, `whoami`. Any other first positional is treated as a deploy path (fails closed). Every vercel subcommand in the must-allow corpus must be in this array.
  - Value flags: `--scope`/`-S`, `--token`/`-t`, `--cwd`, `-A`/`--local-config`, `-Q`/`--global-config`, `--team`/`-T`.
  - `--prod` blocks on every deploy form. `vercel build --prod` and `vercel pull --environment=production` deploy nothing and are allowed. This is the reading of D-13's `--prod`.
- fly/flyctl: `deploy`, `secrets set|unset|import|deploy`, `scale` except `scale show`, `apps destroy|delete`, `destroy`. Value flags: `-a`/`--app`, `-c`/`--config`, `-t`/`--access-token`, `-o`/`--org`.
- docker: never blocked.

**deploy-cli.sh contract.**
- Usage: `deploy-cli.sh [--dry-run] <platform> <subcommand> [args]`. It is plain bash with no python. Commands from the built-in tables run as argv arrays, never through `eval`.
- Platforms:
  - `railway`, `vercel`, `fly` (`flyctl` is an alias; it uses whichever binary is on PATH), `compose`
  - `npm` (deploy = `npm run deploy`) and `script` (deploy = `bash deploy.sh`), so Gate 2 rows 1 and 6 keep working with no setup
  - `custom` (keys only)
- Resolution per subcommand:
  1. A `- deploy_<sub>: <command>` key in `docs/devkit.md` wins for any platform. `set-var` maps to the key `deploy_set_var`; this mapping is documented in the template. The key's command runs with `bash -c`, never with extra arguments.
  2. Otherwise the platform table.
  3. Otherwise exit 3 (`unsupported`).
- Built-in tables (CLI flags not live-verified):
  - status: `railway status` · `vercel ls` · `fly status` · `docker compose ps`
  - logs: `railway logs` · `vercel logs [<target>]` · `fly logs --no-tail` · `docker compose logs --no-color --tail N [--since D]`
  - deploy: `railway up --ci` · `vercel deploy --prod` · `fly deploy` · `docker compose up -d --build`. This matches today's single command for staging and prod; P-38 adds environments.
  - rollback: `vercel rollback [<target>]`. Every other platform exits 3 unless `deploy_rollback` is set.
  - set-var: printed, never run. The value is a placeholder: `railway variables --set "NAME=<value>"` · `vercel env add NAME production` · `fly secrets set NAME=<value>`. compose exits 3 with a note to use its env file.
- Logs are bounded:
  - `--lines N` (1–1000, default 200) and `--since <n>[smhd]` (passed only where the table supports it).
  - The command runs in the background in its own process group (`set -m`) with output to a temp file. A 15 s timer kills the group (`kill -- -$pid`), and then `tail -n N` is printed.
  - There is no follow mode. macOS has no `timeout`, so this is plain bash.
- Arguments:
  - `set-var` takes `NAME` (`^[A-Za-z_][A-Za-z0-9_]*$`). An argument containing `=`, a second argument, or an unknown argument → exit 1 with usage.
  - The error names the argument's position, never its text.
- Output:
  - Platform output is passed through. Deploy streams live rather than being captured.
  - The last stdout line is always `deploy-cli: platform=<p> subcommand=<s> result=<ok|failed|dry-run|printed|unsupported|missing-cli> exit=<n>`.
  - `--dry-run` prints `deploy-cli: command=<cmd>` before it and runs nothing.
  - `set-var` prints `! <cmd>`, then a line saying that a value typed after `!` enters the session transcript and that the same command can be run in your own terminal instead.
  - Any printed `deploy_*` command has `--token[= ]x`, `-t x` and `*TOKEN|SECRET|PASSWORD|KEY*=x` masked as `[redacted]`.
  - Environment values are never printed. There is no `set -x`.
- Exit codes:
  - 0: ok, dry-run, or printed
  - 1: usage
  - 3: unsupported or not configured
  - 4: platform CLI not on PATH
  - 5: the platform command failed (its code is in `exit=`)
- Writes: only `deploy` and `rollback` run a write, and only when that subcommand was asked for (D-14: the explicit yes in `/devkit:deploy` is the gate; there is no role check). `allowed-tools` pre-approves only the read and `--dry-run` forms, so a write still shows a permission prompt.

**Rejected alternatives**
- A second full tokenizer in `block-direct-deploy.sh` would mean ~190 duplicated lines that drift from the push guard.
- Folding the deploy rules into `block-force-push.sh` (one hook, one pass) mixes two concerns under a misleading name and breaks the requested separate hook.
- Sourcing `block-force-push.sh` in a "library mode" set by an env var would let an inherited variable change a guard's behavior, and the override order is fragile.
- Moving the tokenizer in one PR is ~385 counted lines (`--no-renames`), over the gate.
- Requiring a `deploy_deploy` key for npm and deploy.sh projects would regress every existing user of Gate 2 rows 1 and 6.
- Letting deploy-cli.sh take a value for set-var contradicts D-12 and puts the secret in argv and the transcript.
- Making `--prod` alone always block also blocks `vercel build --prod`, a local build.

## Acceptance bar
Reviews are judged only against this bar. A **Critical** is one of these:
1. The hook exits 2 on a row of the must-allow corpus.
2. The hook exits 0 on a row of the must-block corpus.
3. Either hook (`block-direct-deploy.sh`, or `block-force-push.sh` after Phase 3) exits with a code other than 0 or 2, or prints a traceback or a bash error on any input (including `{}`, `not json`, and a missing `shell-segments.sh`).
4. A secret value leaks from deploy-cli.sh:
   - A value it was given (its own arguments, such as `set-var A=value`) or a random value exported in the environment appears in the argv it passes to the platform CLI, or in its stdout or stderr.
   - A token inside a `deploy_*` key appears unmasked in a printed form (dry-run, usage, the result line). The key's own text is passed through as written when it runs, so the key's command line itself is not a leak.
   App output that passes through `logs` is excluded (P-31 scrubs it).
5. deploy-cli.sh runs a write (deploy, rollback, or any set-var command) when it was not called with `deploy` or `rollback`, or runs anything under `--dry-run`.

Everything else is a **Warning** recorded in Risks, including every form in the "Not inspected" list.

**Must-block corpus** (exit 2; stderr starts with `Blocked by devkit:` and ends with `! <cmd>`):
- Plain:
  - railway: `railway up` · `railway up --detach` · `railway redeploy` · `railway down` · `railway variables --set "A=b"` · `railway variables set A=b`
  - vercel: `vercel` · `vercel --prod` · `vercel ./app` · `vercel deploy` · `vercel deploy --prod` · `vercel redeploy x.vercel.app` · `vercel promote x.vercel.app` · `vercel rollback` · `vercel env add API_KEY production` · `vercel env rm API_KEY`
  - fly: `fly deploy` · `flyctl deploy` · `fly secrets set A=b` · `fly secrets unset A` · `fly scale count 2` · `fly apps destroy app`
- Global flags: `vercel --scope team deploy` · `vercel -t tok --prod` · `fly -a app deploy` · `flyctl -c fly.toml deploy`
- Wrappers: `env FOO=1 fly deploy` · `FOO=1 railway up` · `sudo railway up` · `sudo -u bob fly deploy` · `timeout 300 vercel deploy --prod` · `nohup fly deploy &` · `time fly deploy` · `command vercel deploy`
- `cd x &&` and subshells: `cd app && fly deploy` · `(cd app && vercel --prod)` · `git pull && railway up`
- Substitution: `x=$(vercel deploy)` · `echo "$(fly deploy)"` · ``echo `railway up` ``
- Full paths: `/usr/local/bin/fly deploy` · `~/.fly/bin/flyctl deploy` · `./node_modules/.bin/vercel deploy`
- Package runners: `npx vercel deploy` · `npx -y vercel@latest deploy --prod` · `npx --yes vercel deploy` · `npx -p vercel vercel deploy` · `bunx vercel deploy` · `pnpm dlx vercel deploy` · `yarn dlx vercel deploy` · `npm exec -- vercel deploy`
- Multi-line and mixed: `git status` + newline + `fly deploy` · `bash /p/scripts/deploy-cli.sh fly status && fly deploy` · `fly deploy 2>&1 | tail -20`

**Must-allow corpus** (exit 0, empty stderr):
- Reads:
  - railway: `railway status` · `railway logs` · `railway variables` · `railway link` · `railway whoami`
  - vercel: `vercel ls` · `vercel --scope team ls` · `vercel logs x.vercel.app` · `vercel inspect x.vercel.app` · `vercel env ls` · `vercel env pull .env.local` · `vercel whoami` · `vercel link` · `vercel dev` · `vercel build --prod` · `vercel --version` · `vercel -v` · `vercel --help` · `vercel -h`
  - fly: `fly status` · `fly logs --no-tail` · `fly apps list` · `fly secrets list` · `fly scale show` · `fly releases` · `fly version` · `fly auth whoami` · `npx vercel ls`
- Docker (D-13): `docker compose up -d --build` · `docker compose down` · `docker build .`
- Through the wrapper: `bash /p/scripts/deploy-cli.sh fly deploy` · `bash /p/scripts/deploy-cli.sh vercel rollback` · `/p/scripts/deploy-cli.sh railway status`
- Text mentions: `echo fly deploy` · `git commit -m "vercel deploy"` · `grep -r "railway up" .` · `cat fly.toml` · a heredoc whose body is `fly deploy` · `# fly deploy` (a comment)
- Installs and look-alikes: `npm install -g vercel` · `brew install flyctl` · `flyway migrate` · `butterfly deploy`
- Bad input: `{}` · `not json` · `{"tool_input":{"file_path":"/r/a"}}`

**Not inspected** (Warning by definition, listed in the hook's header comment):
- `bash -c`/`sh -c`/`eval` strings
- scripts, Makefiles, aliases, shell functions
- `npm run deploy` and other package scripts
- `pnpm vercel`/`yarn vercel` local-bin forms
- `railway run <cmd>`
- `fly launch`, `fly machine …`, `vercel remove`, and other writes outside D-13's table
- lines over 16 KB
- commands started by other programs

## Phases
Stacked PRs. Each phase branches from the previous phase's branch, and `plans/**` is excluded from the size count. Tests use stub platform binaries on PATH; nothing calls a live platform. Every report says "not live-verified".

### Phase 1 — shared tokenizer library (~240: lib ~200, tests ~40)
- [x] Copy `block-force-push.sh:138-326` into `scan_segments <cmd>` (main loop inside the function, helpers global). The line fast path calls `line_relevant "$line"` instead of `*git*|*gh*`. The header states the interface and the "not inspected" limits. File: `plugins/devkit/scripts/shell-segments.sh`
- [x] Add a segment-dump harness. It is a temp script that defines `check_segment` (print the words joined by `|`, with all variables `local`) and `line_relevant` (mode `all` always returns 0; mode `needle` matches only `*zz*`), sources the library, and runs `scan_segments "$1"`. Add ~20 `row` cases: `a && b`, `; | &`, `( )`, nested `$( )` inside `"…"`, backticks, a skipped heredoc body (`<<-` too), a comment, `2>&1`, `<<<`, a backslash continuation, `$'…'`, `(( ))`, a line skipped in `needle` mode but dumped in `all` mode, a callback that sets a local `i` without breaking the scan, and a line over 16 KB skipped. File: `scripts/test-hooks.sh`
- Verify: `bash -n plugins/devkit/scripts/shell-segments.sh && scripts/test-hooks.sh` ends in "All hooks passed.", and `bash plugins/devkit/scripts/pr-size.sh main` exits 0.

### Phase 2 — block-direct-deploy hook (riskiest; ~280: hook ~130, tests ~150)
- [ ] Add the hook with:
  - its own fast path (`*railway*|*vercel*|*fly*`, else exit 0)
  - `line_relevant`
  - wrapper skipping with `cd` treated as an ordinary segment
  - runner unwrapping and `@version` stripping
  - per-platform `check_*` functions with the write table above
  - `block()` with the `! <cmd>` ending
  - the "Not inspected" list in the header
  - errors → exit 0
  File: `plugins/devkit/scripts/block-direct-deploy.sh` (executable)
- [ ] Add a second `{"type":"command","command":"\"${CLAUDE_PLUGIN_ROOT}\"/scripts/block-direct-deploy.sh"}` to the existing `Bash` matcher. File: `plugins/devkit/hooks/hooks.json`
- [ ] Add `deploy_cmd` (a clone of `bash_cmd`) with one row per corpus entry above. Block rows also check that stderr starts with `Blocked by devkit:` and ends with `! <cmd>`. Allow rows check that stderr is empty. Add the bad-input rows. Add a missing-library row: copy the hook and `json-field.sh` (not the library) into a temp dir, send `fly deploy` (which passes the fast path), and expect exit 0 with empty stderr. File: `scripts/test-hooks.sh`
- Verify: `bash -n plugins/devkit/scripts/block-direct-deploy.sh && scripts/test-hooks.sh` ends in "All hooks passed.", `claude plugin validate plugins/devkit --strict && claude plugin validate .` passes, and `bash plugins/devkit/scripts/pr-size.sh <phase-1 branch>` exits 0.

### Phase 3 — block-force-push uses the library (~200, mostly deletions)
- [ ] Delete `:138-326`. Add `line_relevant` (`*git*|*gh*`), `[ -r "$here/shell-segments.sh" ] || exit 0`, `. "$here/shell-segments.sh"` and `scan_segments "$cmd"`. Remove the now-duplicate `\r`/`LC_ALL` lines. The rules and messages are unchanged. File: `plugins/devkit/scripts/block-force-push.sh`
- [ ] Add one missing-library row: copy the hook and `json-field.sh` (not the library) into a temp dir, send `git push -f` (which passes the fast path), and expect exit 0 with empty stderr. File: `scripts/test-hooks.sh`
- Verify: `scripts/test-hooks.sh` ends in "All hooks passed." with every existing `push:` row unchanged, and `bash plugins/devkit/scripts/pr-size.sh <phase-2 branch>` exits 0.

### Phase 4 — deploy-cli.sh core: tables, reads, dry-run, custom keys (~270: script ~160, tests ~110)
- [ ] Add:
  - argument parsing and usage (exit 1, never echoing argument text)
  - the platform tables (with `fly`/`flyctl` resolution)
  - `cfg_get` from `pr-size.sh:33-37` and the `deploy_<sub>` override (`set-var` → `deploy_set_var`)
  - `--dry-run`
  - `status`
  - bounded `logs` (`--lines`, `--since`, process-group timer, `tail`)
  - the final `deploy-cli:` line
  - exit codes 0/1/3/4
  - masking of printed custom commands
  File: `plugins/devkit/scripts/deploy-cli.sh` (executable)
- [ ] Add a stub-on-PATH section (pattern at `:525`). The stubs for `railway`, `vercel`, `fly`, `flyctl`, `docker` and `npm` append their argv to a log. One stub `logs` mode never exits, to test the timer. Rows:
  - unknown platform or subcommand → 1 plus usage
  - `--dry-run` prints `command=` and the stub log stays empty
  - status and logs argv per platform
  - `--lines 5` bounds the output
  - a hanging logs command ends within the timer, with no leftover process
  - a custom key overrides the table
  - a missing CLI → 4
  - an unsupported subcommand → 3
  - a masked `--token` in a dry-run of a custom key
  File: `scripts/test-hooks.sh`
- Verify: `bash -n plugins/devkit/scripts/deploy-cli.sh && scripts/test-hooks.sh` ends in "All hooks passed.", and `bash plugins/devkit/scripts/pr-size.sh <phase-3 branch>` exits 0.

### Phase 5 — deploy-cli.sh writes and secret safety (~200: script ~70, tests ~130)
- [ ] Add:
  - `deploy` (live passthrough, exit 5 with `exit=<n>` on failure)
  - `rollback` (vercel table; others need the key, else 3)
  - `set-var NAME` (prints `! <cmd>` and the own-terminal note; runs nothing; rejects `=`, extra or unknown arguments with 1)
  File: `plugins/devkit/scripts/deploy-cli.sh`
- [ ] Add these rows. File: `scripts/test-hooks.sh`
  - Deploy argv per platform, plus a failing stub → 5 with `exit=7`.
  - Secret rows: export `DEVKIT_T_SECRET=<random>`, then run every platform × subcommand (and `set-var A=<random2>`, `--dry-run` of a custom key holding `--token <random3>`). Grep stdout, stderr and the stub log for each random value: no match.
  - No-unrequested-write rows: for status, logs, `--dry-run deploy`, `--dry-run rollback` and set-var on every platform, the stub log has no write argv (`up`, `deploy`, `rollback`, `secrets`, `env add`, `variables --set`).
- Verify: `scripts/test-hooks.sh` ends in "All hooks passed.", and `bash plugins/devkit/scripts/pr-size.sh <phase-4 branch>` exits 0.

### Phase 6 — skill, agent, docs (~130)
- [ ] In `plugins/devkit/skills/deploy/SKILL.md`:
  - Add `allowed-tools: Bash(bash */deploy-cli.sh * status) Bash(bash */deploy-cli.sh * logs *) Bash(bash */deploy-cli.sh --dry-run *)`.
  - Gate 2's table gains a Platform column (npm, vercel, fly, railway, compose, script), plus a last row "a `deploy_deploy` key in `docs/devkit.md` → `custom`". `deploy_*` keys override any row per subcommand.
  - `--dry-run` runs `deploy-cli.sh --dry-run <platform> deploy`.
  - Gates 3 and 5 pass `bash "${CLAUDE_PLUGIN_ROOT}/scripts/deploy-cli.sh" <platform> deploy` to the deployer after the explicit yes.
  - A variable the deploy needs: run `deploy-cli.sh <platform> set-var NAME` and show the printed command; never ask for the value.
  - Drop the `timeout 300` note (macOS has no `timeout`).
  - Mark the post-Gate 3 and Gate 5 spots where P-31 and P-38 attach with one comment line each.
- [ ] Deployer: it runs the given deploy-cli.sh command unchanged. Exit code and status come from the final `deploy-cli:` line. It never runs a platform CLI directly. File: `plugins/devkit/agents/deployer.md`
- [ ] README: `README.md:3` says 4 hooks and adds `block-direct-deploy`; `README.md:25` deploy row mentions the wrapper and the hook. File: `README.md`
- [ ] UPSTREAM: P-45 row ⏳ → ✅ at `:151`; add the hook at `:80`. File: `UPSTREAM.md`
- [ ] CHANGELOG `[Unreleased]`: Added (deploy-cli.sh, block-direct-deploy hook, shell-segments.sh) and Changed (`/devkit:deploy` runs through the wrapper). File: `CHANGELOG.md`
- [ ] devkit.md template: a "Deploy commands" prose section. It names `deploy_status`, `deploy_logs`, `deploy_deploy`, `deploy_rollback` and `deploy_set_var` (the key for `set-var`, holding a `NAME` placeholder). It shows one example written without the leading `- ` (for example `deploy_deploy: npm run deploy`). `cfg_get` (`pr-size.sh:36`) ignores code fences, so a `- deploy_…:` line in the template, even fenced, would become live in every bootstrapped project and override the detected platform. It says these commands must never contain secrets. File: `plugins/devkit/templates/docs/devkit.md`
- [ ] CLAUDE.md template: one sentence in "Remotes & never-push rules". Direct `railway`/`vercel`/`fly` writes are blocked by `block-direct-deploy`. Deploys go through `/devkit:deploy`, and the user can still run `! <cmd>`. File: `plugins/devkit/templates/CLAUDE.md`
- Verify: `claude plugin validate plugins/devkit --strict && claude plugin validate .` passes, `scripts/test-hooks.sh` ends in "All hooks passed.", `grep -c 'deploy-cli.sh' plugins/devkit/skills/deploy/SKILL.md plugins/devkit/agents/deployer.md` is ≥1 for each, and `bash plugins/devkit/scripts/pr-size.sh <phase-5 branch>` exits 0.

## Risks
| Risk | Signal | Mitigation |
| --- | --- | --- |
| Platform CLI flags are wrong or have changed (`railway up --ci`, `railway variables --set`, `vercel rollback`, `fly logs --no-tail`) | A user report; a stub row passes while a live run fails | Mark every table entry "not live-verified"; any subcommand can be overridden with a `deploy_<sub>` key |
| Hook misses a form outside the corpora (Not-inspected list, unknown value flags before a fly or railway subcommand) | A direct write that runs without a block | Listed in the hook header; vercel fails closed on an unknown positional; add a corpus row and a table entry on report |
| Hook blocks a legitimate read (a new vercel subcommand is read as a deploy path) | A user hits `Blocked by devkit` on a read | Keep the known-subcommand list in one array; `! <cmd>` is the escape; add a must-allow row |
| A missing `shell-segments.sh` disables both Bash guards, not only the new one | A fresh install with a partial copy | It is shipped in the same plugin directory as the hooks; the missing-library rows prove exit 0, never a broken session |
| A second Bash hook adds a json-field spawn to every Bash call | `MS` column in `test-hooks.sh` | The fast path runs before the tokenizer; the timing column is watched for the new rows |
| `allowed-tools` mid-pattern `*` may not match as written (assumption) | The read wrapper still prompts | Harmless (prompts only); adjust the patterns if validate or a manual run shows a mismatch |
| A value typed after `!` enters the session transcript | — | set-var prints the own-terminal alternative next to the `!` form (user decision below) |
| The logs timer leaves a child process behind (`bash -c` custom command) | A test row finds a leftover pid | Process-group kill via `set -m`; a row checks that no stub process remains |
| `deploy_*` keys run a project-controlled string with `bash -c` | — | Same trust as `deploy.sh` today; the template says no secrets in keys; printed forms are masked |
| `logs` passes app output through, which may hold secrets | — | Excluded from the bar; P-31 scrubs before filing issues |

## Out of scope
- The P-31 post-deploy log scan. It uses `deploy-cli.sh <p> logs`; Phase 6 only marks the spot.
- P-38 environments and required reviewers. `deploy` has no `--env` today; Gate 5 is marked as the hook.
- Separate staging and prod commands per platform.
- A role check (D-14).
- Blocking docker (D-13).
- Writes outside D-13's table (`vercel remove`, `fly machine`, `railway delete`).
- Deploy timeouts.
- Inspecting `bash -c`/package scripts.
- Live platform verification.
