# Add slugify
Status: approved · Source: benchmark fixture

## Goal
A `slugify(text, options)` function and a `--slug` CLI flag that print URL-safe slugs.

## Context found
- `src/cli.js:1-4` — echoes its arguments
- `test/cli.test.js` — `node --test` style

## Approach
Pure function in `src/slugify.js`, no dependencies; the CLI imports it.

## Phases
### Phase 1 — slugify()
- [ ] `src/slugify.js` exporting `slugify(text, { separator = '-', maxLength = 80 } = {})`:
  - Unicode letters are reduced to ASCII by removing diacritics (`Crème Brûlée` → `creme-brulee`); `đ`/`Đ` become `d`.
  - Lowercase. Every run of characters other than `a-z0-9` becomes one separator. No separator at the start or end.
  - When `maxLength` is set, cut at the last separator that keeps the result within `maxLength`; never cut inside a word unless the first word alone is longer, in which case cut that word at `maxLength`. No trailing separator after cutting.
  - Empty or all-symbol input → `''`.
  - The `separator` option may be any string of 1–3 characters, used for both joining and trimming.
- Verify: `node --test test/slugify.test.js` (write it first).

### Phase 2 — CLI flag
- [ ] `src/cli.js`: `--slug` prints `slugify(text)`; `--slug --sep _` uses `_`; `--max <n>` sets maxLength; without `--slug` it still echoes.
- Verify: `node --test` (all tests).

## Risks
| Risk | Signal | Mitigation |
| --- | --- | --- |
| Unicode edge cases | Tests with accents fail | Use `normalize('NFD')` and strip combining marks |

## Out of scope
- Transliterating non-Latin scripts (Cyrillic, CJK) — they are dropped.
