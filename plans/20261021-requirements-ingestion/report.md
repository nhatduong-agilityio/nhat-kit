# Report — requirements ingestion (P-28)
Plan: `plans/20261021-requirements-ingestion/plan.md` · Status: in progress (one PR per phase; Phase 1 = PR #43)

## Phase 1 — ingest.sh core: CLI, header, naming, redaction, passthrough, PDF skip (PR 1) ✅
- Files: `plugins/devkit/scripts/ingest.sh` (new), `scripts/test-hooks.sh` (`# --- ingest`), `CHANGELOG.md` (`[Unreleased]` P-28 first draft).
- Implemented by `devkit:fullstack-developer` (first pass, then an opus fix round); the main session fixed the header-sha redaction bug and ran the third fix round itself.

### Evidence
| Command | Result |
| --- | --- |
| `bash -n plugins/devkit/scripts/ingest.sh` | ok |
| `scripts/test-hooks.sh` | 1153 cases, 0 failed |
| `bash plugins/devkit/scripts/pr-size.sh main` | `lines=257 files=3 … status=ok` |
| Manual: `CV_0912​345678.md` (zero-width space) with an email, a mobile, a `(028)` landline and a date | `file=CV_[redacted].md out=out/cv-redacted-md-<sha8>.md … redacted=4`; body `Mail [redacted] call [redacted]; land [redacted]; keep 2026-10-21`; header sha256 intact |
| Mutation checks (copies or restored backups) | each fix's row fails when the fix is reverted (rounds 1–3); the unanchored-identity check is a backstop that no row reaches, because unanchored inputs are always `-<sha8>`-named |

### Review (devkit:code-reviewer, 6 rounds)
- Main session, before review: header `sha256`/date/converter/note were passed through redaction, so a hex sha that looks like a phone number would be corrupted; fixed with a regression row.
- Round 1: Critical C1 (phone numbers survived into names via zero-width/`·`/en-dash separators) and C2 (same base name from another folder overwrote another source) fixed; Warnings W1–W8 fixed (whole-name redaction, `/dev/zero` symlink and FIFO input, non-regular targets, `..` out-dir, root-owned-link note, landline formats, test trap, missing rows); optional out= redaction, `--slug` exit 1, CHANGELOG count, test interpreter path.
- Round 2: Critical C1' (the C1 fix broke email redaction in names like `nguyen90@163.com`) fixed by redacting emails before digit-run normalization; C2' (inputs outside the repo and cwd could still overwrite) fixed by always content-naming unanchored inputs; W1 (landline regex redacted `1.025.000.000 VND`) fixed with a `.`/`,` guard and an exact 8-digit subscriber part; W2 `..` documented in Usage; W3 `out=` uses name redaction; W4 plan Approach updated to the implemented behavior.
- Accepted limits (in plan Risks / later phases): phone numbers in the body split by a zero-width space or `·` are not redacted; `84 912…` without `+`, `0084 …` and 4-3-4 landlines are not redacted (best effort); identical content from two files maps to one output (spec: same sha → unchanged).
- Round 4 (ship gate): Critical C1'' (two files in folders named by a redacted phone or email shared one origin and overwrote each other) fixed: a redacted origin folder makes the input unanchored, so it is `-<sha8>`-named; Critical C2'' (`CV_+84912345678.md` kept its number because `_` blocked the `+` regex) fixed with a `[A-Za-z0-9.]` lookbehind; W1 the email-name rows now check `file=`, `--slug`, the out-dir listing and `source:`; W2 non-ASCII local parts (`nguyễn@x.vn`) are redacted; O1 names are NFKC-normalized, so fullwidth digits are redacted. Each fix has a row that fails when the fix is reverted. Accepted: names are redacted more eagerly than bodies (a dotted number in a name may become `[redacted]`).
- Round 5 (ship gate) found two more Criticals (`_` after an email or `+` phone in names and bodies; NFKC making `ＣＶ.md` and `CV.md` one origin) plus a quadratic email regex and swallowed markdown delimiters. Three of the recent Criticals came from the previous round's fixes, so after an advisor consult the name handling was redesigned instead of patched: names and folders with `@` or a 9–15 digit `+`/`0` run (any separators, NFKC-matched on a throwaway copy) drop the whole stem; identity is reused only for a byte-identical origin; the body email regex starts only at a run's beginning (fast, keeps `**`, backticks, `https://`). The acceptance bar and must-redact corpus are now written in the plan. Mutation checks: identity, NFKC matching, `_` separators, the body `+` lookbehind and the quadratic email class each make rows fail when reverted.
- Round 6 (against the written bar): C1 a phone number after another digit group in a name (`CV 2024 0912345678.md`) leaked into the out name and `--slug`; fixed by checking every `+`/`0`-led group within a digit run. C2 an origin changed only by the body regexes (`c/+1 234 5678/`) could be matched by a literal `[redacted]` folder; fixed by anchoring only when `red()` leaves the origin unchanged. Both fixes were proposed and tested on a copy by the reviewer; each has rows that fail when reverted. W1 body rows added for `nguyễn@x.vn`, `nguyen90@163.com`, `+84912345678`, names for landlines; W2 CHANGELOG reworded; W3 over-redaction of names recorded in Risks. S2 nested-repo origin noted in Risks; S1 (symlinked input origin) left as is: such inputs are never anchored.

## Phase 2 — zip/XML safety and the docx reader (PR 2, stacked on PR #43) ✅
- Files: `plugins/devkit/scripts/ingest.sh`, `scripts/test-hooks.sh`, `CHANGELOG.md`. 164 lines vs `main`.
- Implemented by `devkit:fullstack-developer` (opus); review fixes applied in the main session.
- `.docx` → stdlib reader (`converter: stdlib-docx-1`): main part via `_rels/.rels` (leading `/` = package root; `..`/absolute/empty → `bad-ooxml`); every XML part through expat with DOCTYPE/ENTITY handlers that raise (`unsafe-xml`, any encoding incl. UTF-16), then ElementTree (`bad-xml`); caps: 2,000 entries (checked from the EOCD before `ZipFile`), 20 MB per part, 100 MB total, 5 MB output with a truncation note; headings, lists (ilvl clamped), tables, tab/br; `mc:Fallback` copies skipped. Converted text uses the Phase 1 redaction, header, naming, identity and write path.

### Evidence
| Command | Result |
| --- | --- |
| `scripts/test-hooks.sh` | 1208 cases, 0 failed (also 1188/0 on `/usr/bin/python3` 3.9.6, expat 2.2.8, before the review fixes) |
| `bash plugins/devkit/scripts/pr-size.sh main` (Phase 1 merged as PR #43) | `lines=164 files=3 … status=ok` |
| Manual docx (title, headings, nested list, table with `|`, contacts) | headings, `- `/indented items, pipe table with `\|`, `Contact: Jane Doe, [redacted], [redacted], [redacted].`; `1.025.000.000 VND` kept |
| Mutation checks | every rule's row fails when reverted (developer: 30 mutants; main session: the 5 review fixes). Survivors: the 100 MB total cap (unreachable with docx; row in Phase 3), the ENTITY handler (DOCTYPE fires first), the ElementTree `ParseError` catch (unreachable after expat) |

### Review (devkit:code-reviewer, against the written bar)
- Critical fixed: (1) nested `w:p` inside a table cell was walked once per level (quadratic time, multiplicative memory; a 1.3 KB docx hung) → cells take outermost paragraphs and runs are collected in one non-recursive pass; (2) the 5 MB cut could split an email so the tail was never redacted → each block is redacted before measuring and cutting; (3) a zip64 locator claiming several disks made `is_zipfile` raise (exit 1) → any probe error is `not-ooxml`.
- Warning fixed: the 2,000-entry cap ran after `ZipFile` built every entry → entries and central-directory size are checked from the EOCD first, including the zip64 record when a zip64 locator precedes the EOCD (confirmation round).
- Confirmation round Critical fixed: table padding to the widest row was quadratic (one row of n cells plus n empty rows; a 529-byte docx took 20 s and 1 GB) → rows are padded one at a time and the table stops at the output cap; a 100k × 100k empty table now converts in under a second and is truncated with the note. Both fixes have rows that fail when reverted.
- Suggestions applied: `mc:Fallback` copies skipped (block and run level); converter id documented as `stdlib-docx-1` in the plan; ElementTree memory noted in Risks; the loop variable `part` renamed.
- Final confirmation (gate 6): Critical 0, Warning 0. Suggestion applied: the zip64 locator's record offset must equal the record position (EOCD − 76), else `bad-ooxml`. Not applied: the test wrapper's timeout can leave a python grandchild running after a hang (test hygiene only).
