# Force-push guard hook
Status: done · Source: P-18 in `upstream/proposals/20261016.md`

## Goal
When Claude runs a `git push` that would rewrite remote history, the harness blocks it, in every project that has devkit installed. Today "never `--force`" is only a line in `git-manager.md` that Claude is expected to read and follow.

## Context found
- `plugins/devkit/scripts/protect-files.sh:1-33`: the pattern to follow. It reads stdin, uses `json-field.sh`, has a `block()` that prints to stderr and exits 2, and otherwise exits 0.
- `plugins/devkit/scripts/json-field.sh`: `tool_input.command` gives the Bash command string (jq → python3 → node).
- `plugins/devkit/hooks/hooks.json`: `PreToolUse` has one entry (`Edit|Write|NotebookEdit`). Add a second entry with matcher `Bash`.
- `scripts/test-hooks.sh:9-13`: `expect()` hardcodes `$guard`. It needs a script argument so a second hook can be tested.
- `plugins/devkit/agents/git-manager.md:19`: the prose rule "Never `--force`, never push to the main branch".
- `.claude/skills/release/SKILL.md:19` and `scripts/release.sh:47`: the kit's own release runs `git push --follow-tags` **on main**. So blocking every push to main would break releases.
- CLAUDE.md rule: hook scripts are plain bash and must never break a session. Errors exit 0; exit 2 only when deliberately blocking.

## Approach
Add a new PreToolUse `Bash` hook, `block-force-push.sh`:
1. Read `tool_input.command`. If it is empty, exit 0.
2. Fast path: if the command does not contain both `git` and `push`, exit 0.
3. Split the command into segments on `;`, `&&`, `||`, `|` and newlines. For each segment, tokenize with bash word-splitting (no `eval`), skip leading `VAR=value` assignments, and require `git` followed by optional global options (`-C <dir>`, `-c <k=v>`, `--git-dir=…`, `--work-tree=…`, `--no-pager`) and then `push`.
4. Block (exit 2, with the reason on stderr) if any push argument is one of the following:
   - `--force`, `--force-with-lease[=…]` or `--force-if-includes`
   - a short-flag cluster that contains `f`, such as `-f` or `-uf` (tokens starting with a single `-`)
   - a refspec starting with `+`, such as `origin +main`
5. The stderr message tells the user to run the command themselves with `! git push --force …` if it was intended.

Scope decision: block force pushes on **every** branch, and do **not** block normal pushes to main.
- Rejected: also blocking every push to main/master (as P-18 originally said). It would break `/release`, and solo repos often push to main on purpose. `git-manager` already avoids it in prose.
- Rejected: blocking force pushes only on main/master. Rebasing a feature branch is the common legitimate case, but there the user can run the push with `!`. A rule like "never force-push" is only worth enforcing as a hook if it applies to every branch.
- Rejected: an env-var bypass such as `DEVKIT_ALLOW_FORCE_PUSH`. Running the command with `!` already covers this (YAGNI).

## Phases

### Phase 1: Hook script and tests (foundational; the parsing is the riskiest part)
- [x] Create `plugins/devkit/scripts/block-force-push.sh` as described in the Approach and make it executable (`chmod +x`).
- [x] Refactor `scripts/test-hooks.sh` to `expect <script> <exit> <name> <json>`, keeping the existing cases unchanged.
- [x] Add cases that should **block** (exit 2):
  - `git push --force`
  - `git push -f origin main`
  - `git push -uf origin feat`
  - `git push --force-with-lease`
  - `git push --force-with-lease=main:abc`
  - `git push origin +main`
  - `git -C repo push -f`
  - `git fetch && git push -f`
  - `FOO=1 git push --force`
- [x] Add cases that should be **allowed** (exit 0):
  - `git push`
  - `git push -u origin feat`
  - `git push --follow-tags`
  - `git push origin main`
  - `git commit -m "push -f later"`
  - `echo git push -f`
  - `git log --format=%f`
  - `ls -f`
  - empty `{}`
  - malformed JSON
  - a command with no `tool_input.command`
- Verify: `scripts/test-hooks.sh` exits 0 and all cases print `ok`. Also run `time` on one blocking case and expect it to finish in under 100 ms.

### Phase 2: Wire it into the plugin and smoke-test it for real
- [x] Add a `PreToolUse` entry to `plugins/devkit/hooks/hooks.json` with `"matcher": "Bash"` and the command `"${CLAUDE_PLUGIN_ROOT}"/scripts/block-force-push.sh`.
- Verify:
  - `claude plugin validate plugins/devkit --strict && claude plugin validate .` passes.
  - In a throwaway repo in the scratchpad, with a local bare remote and one commit pushed, run `claude --plugin-dir plugins/devkit -p "run: git push --force origin HEAD"`.
  - Expected: Claude reports that the hook blocked the push, and the bare remote's ref is unchanged (`git -C remote.git rev-parse HEAD` matches the value before).

### Phase 3: Docs
- [x] `plugins/devkit/agents/git-manager.md:19`: note that a hook now enforces the no-force rule.
- [x] `README.md:3`: change "2 hooks" to "3 hooks", and list the hook wherever the plugin hooks are described.
- [x] `CHANGELOG.md` `[Unreleased]`: add `### Added` with "`block-force-push` hook: blocks `git push --force`/`-f`/`--force-with-lease`/`+refspec` in every project".
- [x] `UPSTREAM.md`: change the "Hooks over reminders" row to ✅ P-18. Also add the hook to the Infrastructure row "Protective hooks", which stays ◐.
- Verify: `grep -n 'block-force-push' README.md CHANGELOG.md UPSTREAM.md plugins/devkit/hooks/hooks.json` hits all four files.

## Risks
| Risk | Signal | Mitigation |
| --- | --- | --- |
| False positive blocks a legitimate non-force command (Medium) | A user reports that a normal push or another git command was blocked | Only flag tokens that come after a `push` subcommand; the allow cases in Phase 1 cover near-misses (`--follow-tags`, `%f`, `-m "push -f"`) |
| Bypass through `bash -c "…"`, git aliases (`git pf`), or scripts (Low) | Never seen during tests | Documented limit: the hook is a guardrail, not a sandbox. The prose rule in `git-manager` stays |
| Hook error breaks the session (Medium) | Non-0/2 exit, or stderr noise on every Bash call | No `set -e`; every path that does not block ends with `exit 0`; malformed JSON is a test case |
| Latency on every Bash call (Low) | Visible slowdown | Fast-path exit before any tokenizing; a timing check in Phase 1 |

## Out of scope
- Blocking normal pushes to main/master.
- Other dangerous commands (`git reset --hard`, `rm -rf`, branch deletion). These could be a follow-up proposal.
- Adding the hook to `templates/hooks` for bootstrap. The plugin hook already runs in every project.
