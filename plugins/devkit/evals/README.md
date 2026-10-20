# devkit behavior evals

Each folder is one case for `claude plugin eval`: a slash-command prompt, a `fixture.sh` that builds a small repo, and graders. They check rules that must not regress. Each run calls the model, so they run by hand and at release, not in CI.

| Case | Tag | Proves |
| --- | --- | --- |
| `review-delegates` | core | `/devkit:review` hands the diff to `devkit:code-reviewer` |
| `cook-refuses-draft` | core | `/devkit:cook` asks for approval of a draft plan; no developer call, no Write/Edit, no file |
| `cook-asks-unrecorded-approval` | core | `/devkit:cook` asks again when a plan says `approved` but has no `Approved:` line (P-33); same tool graders |
| `plan-sync-refuses-draft` | core | `/devkit:plan sync` refuses a draft plan and says why (judged from the reply) |
| `ship-stops-oversized` | needs-bash | `/devkit:ship` runs `pr-size.sh` and stops an oversized change (P-27) |
| `cook-retries-tier-up` | needs-bash | a red phase goes back to `fullstack-developer` on `opus` (P-29) |

## Run

Core cases (about $0.50 and 80 s for all four):

```bash
claude plugin eval plugins/devkit --tag core --trust-plugin --scaffold --ablation none --runs 1 --max-cost-usd 3 --no-publish --allow-tools Write Edit
```

Cases that need Bash:

```bash
claude plugin eval plugins/devkit --tag needs-bash --trust-plugin --scaffold --ablation none --runs 1 --max-cost-usd 5 --no-publish \
  --allow-tools Write Edit "Bash(git *)" "Bash(sh check.sh)" "Bash(bash *pr-size.sh *)"
```

The eval's Bash sandbox refuses to start when the Docker credential store (`~/.docker` or `$DOCKER_CONFIG`) contains a symbolic link. In that case, keep the store in a plain directory first.

- Keep `--allow-tools Write Edit` on the core command: the two cook cases only mean something when cook *could* write.
- `cook-retries-tier-up` stores the expected line gzip+base64-encoded, so reading `check.sh` does not reveal it. Together the two graders show a later developer call on opus. A run with only one developer call (the developer ran the check itself and fixed it) is inconclusive, not a failure of the rule.
- `--ablation none`: every case is a devkit slash command, so a no-plugin arm only measures "unknown command".
- A red case is either a regression or a flaky run. Read `results/<timestamp>/report.html`, re-run that case once (`--case <name>`), and fix the skill only when it fails again. Fix a grader only when the grader is wrong.
- `results/` is gitignored.
