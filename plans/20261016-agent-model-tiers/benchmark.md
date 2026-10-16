# Benchmark: agent model tiers

Each run was a headless `/devkit:cook plans/20261016-slugify/plan.md --auto` on a fresh copy of the fixture (`bench/fixture/`).
- Main session: Opus 5.5. The installed devkit was disabled; only the `--plugin-dir` copy was loaded (verified with a probe description).
- Quality was measured with a held-out acceptance test file (`bench/heldout.test.js`, 18 tests) that cook never sees. A reference solution passes all 18.
- Harness: `bench/bench.sh <label> <plugin-dir>`. Raw lines: `bench/baseline.txt`, `bench/tiers.txt`.

| Run | Plugin | Cost | Opus | Sonnet | Duration | Main turns | Held-out | Own tests | Review Criticals |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| baseline-1 | `main` (all `inherit`) | $1.99 | $1.99 | — | 361 s | 6 | 18/18 | 60 | 1 (fixed) |
| baseline-2 | `main` (all `inherit`) | $1.64 | $1.64 | — | 320 s | 13 | 18/18 | 57 | 0 |
| tiers-1 | this branch | $1.27 | $1.06 | $0.21 | 289 s | 28 | 18/18 | 34 | 0 |
| tiers-2 | this branch | $1.26 | $0.99 | $0.27 | 246 s | 34 | 18/18 | 37 | 0 |

**Median cost:** $1.82 → $1.27 (**−30%**). The median duration also dropped, from 341 s to 268 s.

**Ship rule** (held-out tests pass in both runs, Criticals no higher than the baseline, median cost at least 25% lower): **met.**

Observations:
- The Opus output tokens per run roughly halved, from 38–45k to 19–22k. Implementation and test writing moved to Sonnet (10–13k output tokens).
- **Main-session turns rose** from 6–13 to 28–34. This is most likely the new per-phase `git diff` review in `cook` step 1.3. It is still cheaper overall.
- **The Sonnet tester wrote fewer tests of its own** (34–37 vs 57–60) and still reached the same held-out result. Worth watching on larger tasks.
- Haiku did not appear, because `cook` doesn't call `deployer` or `git-manager` in this flow.
- **Noise:** the two baseline runs differ by 19% in cost, and the two tier runs by 1%. Two runs per side is enough to see a 30% gap, but not a 5% one.
