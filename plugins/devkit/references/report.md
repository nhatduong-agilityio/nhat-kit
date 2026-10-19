# PR report: data and page

The PR report artifact (`conventions.md`, "PR report artifact": who builds it, its required contents, scrubbing, the PR body, and the fallback) is built from `report.json` by `${CLAUDE_PLUGIN_ROOT}/scripts/render-report.mjs`. This file defines the data and what the page shows. Write `report.json` and the screenshots in the `evidence/` folder next to the plan or SPEC, or in `.claude/reports/<branch>/` when there is neither (`mkdir -p` it: branch names can contain `/`).

Render: `node "${CLAUDE_PLUGIN_ROOT}/scripts/render-report.mjs" <dir>/report.json > <dir>/report.html`. Exit 1 means invalid input and the message names the field: fix the JSON, don't hand-edit the HTML. The renderer rejects data it would otherwise have to invent: a metric without both measured values or without `better`, negative or non-whole line counts, an AC without a `pass`/`fail`/`assumption` status, and image paths that aren't relative to the report folder (no URLs, absolute paths, or `..`). Without `node`, write the page by hand following "Page" below.

## Data (`report.json`)

Only `id`, `title`, `commit` are required. Leave out what you don't have; empty sections are not shown. **Every number comes from a command's output** (`git diff --numstat`, the test runner, the reviewer's report), never from memory.

| Field | Type | Source |
| --- | --- | --- |
| `id` | string | Ticket key, issue `#N`, or plan slug |
| `title` | string | PR title without the type prefix |
| `kind` | `feat` `fix` `hotfix` `perf` `refactor` `docs` `chore` `ci` `build` `test` | Conventional Commit type of the branch's main commit (default `feat`) |
| `branch`, `base`, `commit` | string | `git branch --show-current`, the PR base, `git rev-parse --short HEAD` |
| `generated` | string | ISO date |
| `summary`, `why` | string | 1–3 sentences each: what changed, and why |
| `fix` | `{symptom, cause, fix, regression_test}` | For `kind: fix`: the user-visible symptom, the root cause (`file:line`), the change, the test that now guards it |
| `areas[]` | `{name, files, added, removed}` | `git diff --numstat <base>...HEAD`, grouped by top folder or module |
| `diagram` | string | Mermaid source for the changed flow or structure, only when the change has one |
| `gates[]` | `{name, status: pass\|fail\|skip, detail}` | `ship`'s gate table |
| `tests` | `{before: {pass, fail}, after: {pass, fail}, command}` | The suite's output on the base and on the branch |
| `acs[]` | `{id, text, status: pass\|fail\|assumption, evidence, images[]}` | The SPEC or plan's AC → evidence table; shown as ✅ met / ⚠️ assumption / ❌ failed. `images` are paths relative to the report dir (`AC1-saved.png`) |
| `verified[]` | `{command, output}` | How it was verified: each command and its key output, scrubbed. Output over 8 lines is folded into `<details>` |
| `manual_steps[]` | string | Manual test steps |
| `review` | `{critical, warning, optional}` each `{fixed, remaining}`, plus `items[]` `{severity, status: fixed\|remaining, text}` | The code reviewer's report |
| `metrics[]` | `{name, unit, before, after, better: lower\|higher}` (all but `unit` required) | Benchmark, bundle size, timing, coverage — only real measurements |
| `risks[]` | string | The PR's risks |

Example (a `fix`):

```json
{
  "id": "T-1", "title": "Reject an empty display name", "kind": "fix",
  "branch": "fix/T-1-empty-name", "base": "main", "commit": "a1b2c3d", "generated": "2026-10-16",
  "summary": "Saving an empty or blank display name now shows \"Name is required\" instead of \"Saved as \".",
  "why": "Users could save a blank name and the profile header went empty.",
  "fix": { "symptom": "Clicking Save with a blank name showed \"Saved as \"", "cause": "index.html:11 used the raw input value without trimming or checking it", "fix": "Trim the value; show \"Name is required\" and skip saving when it is empty", "regression_test": "test/save.test.js › rejects a blank name" },
  "areas": [ { "name": "src", "files": 1, "added": 9, "removed": 2 }, { "name": "test", "files": 1, "added": 14, "removed": 0 } ],
  "gates": [ { "name": "Tests", "status": "pass", "detail": "8/8" }, { "name": "Real app", "status": "pass", "detail": "2 ACs, screenshots" } ],
  "tests": { "before": { "pass": 6, "fail": 0 }, "after": { "pass": 8, "fail": 0 }, "command": "node --test" },
  "acs": [ { "id": "AC1", "text": "Given a blank name, when Save is clicked, then \"Name is required\" is shown", "status": "pass", "evidence": "screenshot", "images": ["AC1-required.png"] } ],
  "review": { "critical": { "fixed": 0, "remaining": 0 }, "warning": { "fixed": 1, "remaining": 0 }, "optional": { "fixed": 0, "remaining": 1 },
              "items": [ { "severity": "warning", "status": "fixed", "text": "Whitespace-only names were accepted" }, { "severity": "optional", "status": "remaining", "text": "Announce the status with aria-live" } ] },
  "verified": [ { "command": "node --test", "output": "ℹ pass 8\nℹ fail 0" } ],
  "manual_steps": [ "Open Settings › Profile", "Clear the name and click Save" ],
  "risks": [ "None beyond the Profile page" ]
}
```

## Page

Title `<id> PR report`. The header has the title, `kind`, branch → base, the commit, the "X/Y ACs met" line, and an overall status:
- **Needs attention**: a failed gate, failing tests after the change, or a remaining Critical.
- **Check**: remaining Warnings, or an AC that isn't `pass`.
- **Ready**: everything else.

The conventions' required contents are **always shown**, with a placeholder when there is no data: Summary ("Not provided"), Acceptance criteria ("None (no acceptance criteria given)"), How it was verified ("Not provided"), *Screenshots / GIF* (anchor `#ui`, "None (no UI change)"), Manual test steps ("None") and Risks and impact ("None stated").

The visual sections appear only when their data exists:
- the **change map** (lines added and removed per area);
- the **diagram** (mermaid, which the artifact renders natively);
- **Verification**: gate pills and a tests before/after bar;
- **Review**: fixed vs remaining per severity;
- **Metrics**: before/after bars marked better or worse.

The order follows `kind`. A kind only sets the order and never hides data: any section it doesn't list still appears, before Risks and impact, when its data exists. So a `docs` PR with a failing gate still shows Verification. `hotfix` uses the `fix` order.

The mermaid diagram is emitted as `<pre class="mermaid">`. The Artifact platform documents that it renders this natively (no library), and outside an artifact it shows as source text.

| Kind | Order |
| --- | --- |
| `feat` | Summary · ACs · Change map · Diagram · Verification · How it was verified · Screenshots · Manual steps · Review · Metrics · Risks and impact |
| `fix` | Summary with Symptom → Cause → Fix · ACs · Verification (regression test highlighted) · How it was verified · Screenshots · Manual steps · Change map · Review · Risks |
| `perf` | Summary · Metrics · ACs · Verification · How it was verified · Screenshots · Manual steps · Change map · Review · Risks |
| `refactor` | Summary · ACs · Change map · Verification ("behavior unchanged" only when the same tests pass before and after) · How it was verified · Diagram · Screenshots · Manual steps · Review · Risks and impact |
| `docs` `chore` `ci` `build` `test` | Summary · ACs · Change map · How it was verified · Screenshots · Manual steps · Review · Risks and impact |
