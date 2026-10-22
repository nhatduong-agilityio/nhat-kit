# Requirements ingestion with saved sources (P-28)
Status: in-progress · Source: `upstream/proposals/20261018.md:28` (P-28), research `plans/20261021-requirements-ingestion/research/converters.md`, user decisions 2026-10-21, red-team 2026-10-22
Approved: 2026-10-22 by nhatduong-agilityio

## Goal
`/devkit:bootstrap` and `/devkit:task` turn BA documents (docx, pptx, xlsx, pdf, md/txt, links) into committed `docs/requirements/<slug>/sources/<name>.md` files. Each file has a provenance header and has emails and phone numbers redacted, so the whole team works from the same traceable text. Done when `scripts/test-hooks.sh` covers the new `ingest.sh`, both skills call it, and no source is committed before the user has reviewed it.

## Context found
Line numbers refer to this repo's files. For conventions that means `plugins/devkit/references/conventions.md`, not the installed 2.5.0 cache copy, which lacks the `reports/` row.
- `plugins/devkit/skills/bootstrap/SKILL.md`
  - `:6`: `allowed-tools` has no script entry.
  - `:13`: how input docs are found.
  - `:21`: hard rule "Never overwrite".
  - `:36`: step 1 gives all docs to `requirements-analyst`, which writes `docs/PROJECT_BRIEF.md`/`BACKLOG.md` before the step-2 approval gate (`:47`).
  - `:49-53`: step 3 (GREENFIELD only) runs `git init` and commits `chore: scaffold project` (`:53`). Before that step a greenfield folder may have no repo.
  - `:91`: step 8 asks before the final commit.
- `plugins/devkit/skills/task/SKILL.md`
  - `:6`: `allowed-tools`.
  - `:23`: the hook point ("A file path (PDF, MD, image) → read the file").
  - `:24`: `TASK_ID` and slug are set after the input is read.
  - `:48`: the branch is created, with a worktree suggested.
  - `:66`: the git-manager commit.
- `plugins/devkit/agents/requirements-analyst.md`
  - `:4`: tools include no Bash, so conversion runs in the skill.
  - `:8`: the quote rule redacts names.
  - `:14`: claims it reads DOCX, which is false today.
- `plugins/devkit/references/conventions.md`: `:9` is the Language/quote rule. `:13-24` is the Directories table. `:26` is the slug rule (ASCII only, at most 5 words).
- Templates: `plugins/devkit/templates/docs/PROJECT_BRIEF.md:3` has `Sources: {{SOURCE_DOCUMENTS}}`. `templates/docs/tasks/_TEMPLATE/SPEC.md:3` has `Source:`.
- `plugins/devkit/scripts/metrics.sh`: the pattern to follow.
  - `:1-27`: header with Usage/Output/Exit.
  - `:29`: `die`.
  - `:52-58`: inline `python3 -I -c` with a fail-closed excepthook and `clean()` for control characters.
- `scripts/test-hooks.sh`
  - `:191`: the `row` helper.
  - `:1104-1129`: a stub binary on PATH.
  - `:1130`: a python fixture builder (`mxfix`).
  - `:1247`: restricted PATH (only `python3` symlinked).
  - The new section goes before `:1252`.
- PR size gate (`plugins/devkit/scripts/pr-size.sh:3`, `pr-size.sh [base]`; limits in `docs/devkit.md:9,13,17`): 300 lines and 25 files. Only `plans/**` is excluded, so test rows count.
- `plugins/devkit/templates/gitignore-additions.txt`: nothing matches `docs/requirements/`, so the sources are committed.
- darwin has no `timeout` and no `sha256sum`. pandoc and pdftotext are not installed on this machine. The red-team verified that `/usr/bin/python3` 3.9.6 (expat 2.2.8) expands entities in a UTF-16 part, so a byte check for `<!DOCTYPE` is not enough.
- Docs to update: `README.md:9-10` (bootstrap/task rows), `UPSTREAM.md:134` (P-28 is ⏳), `upstream/proposals/20261018.md:86,91,94` (v2.7.0 line, Done list, next command), `CHANGELOG.md:5` (`[Unreleased]` is empty).

## Approach
Add one script, `plugins/devkit/scripts/ingest.sh`.
- It is a thin bash wrapper around one inline `python3 -I -c` block, as in metrics.sh.
- It handles one input per call and never prints document text.
- The bash part calls no external command other than `python3` (no `dirname`), so it runs under the restricted test PATH.
- Python does all the work: hashing, dates, directories, writes, and running converters with a timeout. This avoids the missing `timeout` and `sha256sum` on darwin.

**Settled decisions**
- A. When a PDF is skipped (no pdftotext), the model may still Read the PDF to write the SPEC or brief. The SPEC `Source:` line or the brief's `Sources:` must then say "original PDF read directly; no saved source (pdftotext missing)". No model transcription is ever saved as a source.
- B. A task given as a file with no ticket key takes its slug from the file name, through `ingest.sh --slug`, so the slug is redacted too.

**CLI**
- `ingest.sh <file> <out-dir>`: convert one file.
- `ingest.sh --slug <file>`: print `slug=<s>`, the redacted ASCII slug of the file stem, for `/devkit:task`.
- `ingest.sh --scratch`: create a fresh 0700 `tempfile.mkdtemp(prefix="devkit-ingest.")`. Print `path=<dir>/fetch.md`, a path that does not exist yet, so the Write tool can create it.
- `ingest.sh --webfetch <url> <scratch-file> <out-dir>`: wrap text fetched with WebFetch. The guard requires all of the following:
  - `realpath(dirname)`'s parent equals `realpath(tempfile.gettempdir())`. Both sides are realpath'd for macOS `/var` → `/private/var` and `/tmp` → `/private/tmp`.
  - The dir name has the `devkit-ingest.` prefix.
  - The basename is `fetch.md`.
  - The file is a regular file (lstat).

  Anything else gives `failed reason=not-scratch` and nothing is deleted. On success, the file and its dir are deleted.

**Output**
- Exactly one line: `file=<redacted name> out=<path|-> converter=<id|-> status=converted|unchanged|skipped|failed reason=<code|-> redacted=<N>`.
- Exit 0 whenever that line is printed, including for a malformed document (`failed reason=bad-xml`).
- Exit 1 on a usage error, missing `python3`, or an internal error (fail-closed excepthook, one-line stderr).
- Converter stderr is discarded. Only reason codes are emitted, because errors can echo document text.

**Converters**
- docx, pptx, xlsx: pandoc, when `--list-input-formats` lists the format (pptx and xlsx need ≥ 3.8.3).
  - Command: `pandoc -f <fmt> -t gfm --wrap=none --sandbox -- <absolute path>`.
  - Image links are stripped.
  - On a nonzero exit, empty output or timeout, fall back to the stdlib reader.
- pdf: `pdftotext -enc UTF-8 -nopgbrk -q <absolute path> -`. The absolute path (leading `/`) blocks option injection. `--` is not passed, because it is unverified whether poppler's parser accepts it.
  - pdftotext missing: `skipped reason=no-pdftotext`, with the hint `brew install poppler` / `apt install poppler-utils` on stderr.
  - Empty text: `failed reason=no-text` (a scanned PDF).
- Converter runs: `Popen`, then read stdout up to 5 MB + 1, with a 30 s kill timer. A converter is never fully buffered past the cap.
- md/txt: UTF-8 passthrough; anything else gives `failed reason=not-utf8`.
- Input is opened with `O_NONBLOCK` and must be a regular file (`failed reason=not-regular`); the 50 MB cap is checked on `fstat` and again on `read(cap+1)`. An out-dir argument containing `..` gives `failed reason=bad-out-dir`. Other reason codes: `unreadable`, `write-failed`. `--slug` failures exit 1 with one `ingest: <reason>` stderr line.
- Any other extension: `skipped reason=unsupported`. Images are not converted; the model keeps reading them directly.

**Stdlib reader safety**
- XML: every part is first parsed with `xml.parsers.expat`.
  - Its `StartDoctypeDeclHandler` and `EntityDeclHandler` raise, giving `failed reason=unsafe-xml`.
  - `ExpatError` or an unknown encoding gives `failed reason=bad-xml`.
  - Only then is the part parsed with ElementTree, and `ET.ParseError` also gives `bad-xml`.
  - This replaces any byte check, because expat decodes UTF-16 first.
- Caps:
  - input ≤ 50 MB
  - ≤ 2,000 zip entries
  - each part read as `read(20 MB + 1)`
  - ≤ 100 MB total read
  - output ≤ 5 MB, checked inside the emit loop, so work stops early, with a truncation note
  - converter timeout 30 s
- Not cap-limited: no ratio cap and no per-sheet, row, column or slide caps (see Red-team notes).
- An xlsx cell column beyond `XFD` (16,384) gives `bad-xml`. This is validation, not tuning: it stops a crafted `r="ZZZZZZZ1"` from allocating a huge row.
- Member names come only from fixed names or rels targets, normalized, never starting with `..`. Nothing is extracted to disk.
- A non-zip file (for example, encrypted OOXML) gives `failed reason=not-ooxml`.

**Header** (YAML front matter; each value goes through `clean()`, then redaction, then `json.dumps(ensure_ascii=False)` so it is a valid YAML double-quoted scalar)
- `source`: the original file name, redacted.
- `origin`:
  - for files: the path relative to the repo root if there is one, else to the cwd if under it, else the base name; never an absolute path.
  - The repo root is found by Python walking up from the cwd to a `.git` entry (a dir, or a file for worktrees). No `git` binary is needed, which matters for greenfield before `git init` and for the restricted-PATH tests.
  - for links: the URL without userinfo, query or fragment.
  - Redacted in both cases.
- `sha256`: of the original bytes, or of the fetched text for links.
- `converted`: the local date.
- `converter`: `pandoc <ver>` | `pdftotext <ver>` | `stdlib <reader-version>` | `passthrough` | `webfetch`.
- `redacted`: `<N> (emails and phone numbers in the name and body; names of people are not redacted, best effort)`.
- `note`: "Original text, verbatim apart from redaction; not translated." For links: "WebFetch output; may be summarized, not verbatim."
- Reading an existing file: only the first front-matter block (the first line is `---`, up to the next `---` line), with each value parsed by `json.loads`. If it cannot be parsed, the file counts as another source's file.

**Redaction**
Acceptance bar (fixed after five review rounds; redaction is best effort by user decision 3): a review Critical is a leak of a corpus format below into committed output (file name, `--slug`, `file=`/`out=`, header, body), an overwrite of another source's file, or a hang. Anything else is a Warning recorded in Risks.
Must-redact corpus (each has a test row): emails incl. non-ASCII local parts (`nguyễn@x.vn`) and digit domains (`nguyen90@163.com`); `+84 912 345 678`, `+84912345678`; `0912345678` with space, dot, dash separators; landlines `028 3823 4567`, `(028) 3823 4567`; in names also zero-width/`·`/en-dash/`_` separators and fullwidth digits; `_`-adjacent values in names and bodies; phone- or email-named folders. Must-keep: dates, versions, ticket ids, `12345678`, `09123456`, `091234567890` in bodies, `1.025.000.000 VND`, sha256 in the header.
Own regexes, applied to the body, the file name before slugifying, and the header values. The header records the count, never the values.
- Email: research regex.
- International: the research `+` regex.
- Vietnamese mobile: `(?<![\d.+])0[35789]\d(?:[\s.-]?\d){7}(?!\d|[.-]\d)`. That is 10 digits, matching `0912345678`, `0912 345 678`, `0912.345.678` and `0912-345-678`.
  - The lookarounds use digits, not `\w`, and `-` is allowed before the number, so `CV_0912345678` and `CV-0912345678` still match.
- File names and folders (P1 redesign after five review rounds): a name or path segment with `@`, or a run of 9–15 digits starting with `+` or `0` joined by any separators (`_` included), matched on an NFKC copy (fullwidth digits) that is never displayed or used as identity, is shown as `[redacted]<.ext>` (ext only from the known list) and slugged `source`. Names need no fidelity, so the whole stem goes. `out=` uses the same rule per segment (not counted).
- Identity invariant: a target is reused or overwritten only when the header `origin` is byte-identical to the raw repo- or cwd-relative path. A cleaned or redacted name or folder, a lookalike (`ＣＶ.md` beside `CV.md`), or an input outside the repo and cwd is always written as `<name>-<sha8>.md`.
- Body regexes share explicit boundaries (`_` and markdown delimiters count as boundaries); the email regex only starts a match at the beginning of a non-delimiter run, which keeps `**`, backticks and `https://` intact and avoids quadratic time on long runs (base64).
- Landline: research regex.

**Naming and idempotence**
- Name: the ASCII slug of the redacted stem plus the extension, e.g. `srs-v2-docx.md`. Non-ASCII characters are dropped (no NFKD or `đ` mapping in v1), with at most 5 words. An empty slug gives `source-<sha8>`.
- Links: `link-<sha8 of the cleaned URL>.md`.
- `sha8` is the first 8 hex digits of the content sha256. A hash of the original name is never used: it would be a brute-forceable hash of a phone number.
- If redaction changed the file name, `-<sha8>` is always appended. Two files like `CV_0912….docx` and `CV_0987….docx` then never share a name.
- Target exists:
  - same `sha256:` → `unchanged`, untouched (no date churn), whatever the converter.
  - same `origin:` (the identity; repo- or cwd-relative), different sha → overwrite in place, `converted`; git diff shows the change.
  - different `origin:` or an unreadable header → write `<name>-<sha8>.md` instead (same rules). An input outside the repo and the cwd has only its base name as origin, which cannot identify it, so it is always written as `<name>-<sha8>.md`. If that also exists with a different sha, `failed reason=name-collision`. Another source's file is never overwritten.
- Writes:
  - Create the out-dir one component at a time, refusing any component that is a symlink (lstat), with `failed reason=symlink`.
  - Read an existing target with `O_NOFOLLOW`; a symlinked target is refused.
  - Write to `mkstemp(dir=out-dir)`, then `os.replace`.

**Where sources go**
- bootstrap: `docs/requirements/<project-slug>/sources/`. The project slug is the repo folder name, slugified.
- task: `docs/requirements/<TASK_ID>-<slug>/sources/`, the same name as the SPEC folder. Tickets keep their key. With a file and no key (decision B), the slug comes from `ingest.sh --slug <file>`.

**Bootstrap commit order (red-team tech #5)**
- Ingestion stays the first item of step 1, because the analyst needs the sources and its output feeds the step-2 plan (stack choice for the scaffold).
- In step 3, the scaffold commit stages with `git add -A -- . ':(exclude)docs/requirements/'`. Afterwards `git log --oneline -- docs/requirements` must print nothing. If it prints anything (for example, a scaffolder that commits on its own), stop and tell the user.
- The sources are first committed by the step-8 commit (`:91`). Its question lists every source with its redaction count and asks the user to review `docs/requirements/` (names are not redacted) before saying yes. EXISTING repos have no step-3 commit, so only step 8 applies.
- The step count stays at 8.

**Rejected alternatives**
- Ingest after step 3: the analyst (step 1) and the step-2 plan would run without sources.
- Gitignore `docs/requirements/` until step 8: it changes the project's `.gitignore` for a temporary need, and step 4 appends to `.gitignore` anyway.
- Saving a model transcription of a PDF when pdftotext is missing: not verbatim and not reproducible (user decision 1). Reading it for the SPEC is allowed (decision A).
- python-docx, openpyxl, defusedxml or other new libraries: they need the user's approval and are not on teammates' machines. Stdlib expat handlers block DTDs on any expat version.
- Converting inside `requirements-analyst`: it has no Bash (`agents/requirements-analyst.md:4`), and task needs ingestion outside the analyst.
- Committing the originals: they hold unredacted contacts and are binary and large. The header sha256 ties each source to its original.
- Links written by the model directly: no redaction and no header.
- A separate `ingest.py`: it breaks the single-script pattern of `metrics.sh`.
- `exists` / `--replace`: a teammate with another converter would get a needless prompt. Same sha → `unchanged` covers that case, and git diff shows real changes.
- One PR: does not fit the 300-line gate, since test rows count.

## Phases
Stacked PRs, one per phase. Each is measured with `pr-size.sh <previous phase branch>` (P1 against `main`). Line estimates count the script plus test rows; `plans/**` is excluded.

### Phase 1 — core CLI, header, naming, redaction, passthrough, PDF skip (~270: script ~175, tests ~95)
- [x] Script header (Usage/Output/Exit), argument parsing for `<file> <out-dir>` and `--slug`, `die`, the Python block with the fail-closed excepthook. File: `plugins/devkit/scripts/ingest.sh`
- [x] `clean()`, the redaction regexes with the count, JSON-quoted header writer, and the first-block front-matter reader. File: `plugins/devkit/scripts/ingest.sh`
- [x] sha256, origin (`.git` walk-up → cwd → base name), ASCII slug with redacted-name `-<sha8>`, and the unchanged / overwrite / `-<sha8>` / `name-collision` rules. File: `plugins/devkit/scripts/ingest.sh`
- [x] Safe writes: per-component lstat, `O_NOFOLLOW` read, `mkstemp` + `os.replace`. File: `plugins/devkit/scripts/ingest.sh`
- [x] md/txt passthrough (`not-utf8`), the 50 MB input cap, `unsupported` (docx/pptx/xlsx are `unsupported` until P2/P3), and PDF with no pdftotext giving `no-pdftotext` plus the hint. File: `plugins/devkit/scripts/ingest.sh`
- [x] Test section `# --- ingest` before `:1252`, run under a restricted PATH (only `python3`) so machines with pandoc get the same results. File: `scripts/test-hooks.sh`. Rows:
  - every header field (JSON-quoted)
  - a value with a newline or `"` stays one line
  - redaction of `a.b@x.vn`, `+84 912 345 678`, `0912345678`, `0912 345 678`, `0912.345.678`, `0912-345-678`
  - no redaction of `2026-10-21`, `v2.6.0`, `PROJ-1234`, `12345678`, `09123456`, `091234567890`
  - output and stdout never contain the redacted values or body text
  - `CV_0912345678.md` and `CV-0912345678.md` give a redacted `source:`, a name with `-<sha8>`, and a redacted `--slug`
  - `a.b@x.vn.txt` keeps its `.txt` extension and passthrough converter
  - origin is repo-relative inside a temp repo (`.git` present) and cwd-relative without one
  - re-run gives `unchanged` with the mtime kept
  - same source with changed content is overwritten (`converted`)
  - a different source with the same slug gives `-<sha8>`, and the original is untouched
  - a 6-word stem is capped at 5 words
  - a non-ASCII-only stem gives `source-<sha8>`
  - a symlinked out-dir component and a symlinked target are refused
  - non-UTF-8 `.txt` gives `not-utf8`
  - `.png` gives `unsupported`
  - `.pdf` gives `no-pdftotext`
  - an over-50 MB input (sparse file) is refused
  - usage errors exit 1
  - missing python3 exits 1
- [x] `CHANGELOG.md` `[Unreleased]` Added entry (first draft).
- Verify: `bash -n plugins/devkit/scripts/ingest.sh && scripts/test-hooks.sh` ends in "All hooks passed.", and `bash plugins/devkit/scripts/pr-size.sh main` exits 0.

### Phase 2 — zip/XML safety and the docx reader (~190: script ~110, tests ~80)
- [ ] Zip open (`not-ooxml`), entry, part and total caps, member resolution through rels, the expat pre-parse (`unsafe-xml` / `bad-xml`), then ElementTree. File: `plugins/devkit/scripts/ingest.sh`
- [ ] docx reader: headings (`Heading1..9`/`Title`), list items by `ilvl`, tables (first row is the header, `|` escaped), `w:tab`, `w:br`. The output cap is checked in the emit loop. File: `plugins/devkit/scripts/ingest.sh`
- [ ] A python zipfile fixture builder and rows. File: `scripts/test-hooks.sh`. Rows:
  - docx structure
  - a UTF-8 DOCTYPE gives `unsafe-xml`
  - a UTF-16 part (with BOM) holding a DOCTYPE and an entity gives `unsafe-xml`, and the entity text is not in the output
  - malformed `document.xml` gives `bad-xml` with exit 0
  - a non-zip `.docx` gives `not-ooxml`
  - more than 2,000 entries is refused
  - a part over the read cap (highly compressible) is refused
  - a rels target with `..` is refused
  - over-cap output is truncated with the note
- Verify: `scripts/test-hooks.sh` ends in "All hooks passed.", and `bash plugins/devkit/scripts/pr-size.sh <phase-1 branch>` exits 0.

### Phase 3 — pptx and xlsx readers (~160: script ~95, tests ~65)
- [ ] pptx: slide order from `p:sldIdLst` through the presentation rels (numeric fallback), `## Slide N`, `a:br`, `a:tbl`. No speaker notes. File: `plugins/devkit/scripts/ingest.sh`
- [ ] xlsx: sheets through the workbook rels, then cell values.
  - Value types: shared strings (all `t` text), `inlineStr`, `str`/`b`/`e`/`n`.
  - Cells are placed by column letters, sparse; a column beyond `XFD` gives `bad-xml`.
  - Each sheet is a `### <sheet>` heading plus a pipe table, with `|` escaped. Dates stay raw.
  - File: `plugins/devkit/scripts/ingest.sh`
- [ ] Rows. File: `scripts/test-hooks.sh`
  - pptx with 2 slides stored out of order
  - xlsx with shared and inline strings, sparse cells, 2 sheets, and `|` in a cell
  - `r="ZZZZZZZ1"` gives `bad-xml` quickly
  - a DOCTYPE in `sharedStrings.xml` gives `unsafe-xml`
- Verify: `scripts/test-hooks.sh` ends in "All hooks passed.", and `bash plugins/devkit/scripts/pr-size.sh <phase-2 branch>` exits 0.

### Phase 4 — pandoc and pdftotext (stubs) (~130: script ~60, tests ~70)
- [ ] `shutil.which`, the `pandoc --version` / `--list-input-formats` probe, `Popen` with a 5 MB + 1 read and a 30 s kill, image links stripped, stdlib fallback on a nonzero exit, empty output or timeout. The converter actually used is recorded. pdftotext version comes from `-v`; empty text gives `no-text`. File: `plugins/devkit/scripts/ingest.sh`
- [ ] Stub `pandoc`/`pdftotext` on PATH that log their arguments. File: `scripts/test-hooks.sh`. Rows:
  - pandoc 3.8.3 is chosen for pptx (`converter: pandoc 3.8.3`)
  - pandoc 3.1 gives stdlib for xlsx
  - pandoc exiting 1 falls back to stdlib
  - an image link is stripped
  - the logged args contain `--sandbox`, `-t gfm`, `--`, and an absolute path
  - a pandoc stub printing more than 5 MB is truncated
  - a slow stub is killed and falls back (the timeout is lowered through an env var used only by the tests)
  - pandoc output is redacted
  - a stub pdftotext gives `converted`, redacted, with an absolute-path argument
  - empty pdftotext output gives `no-text`
  - converter stderr never reaches the output
- Verify: `scripts/test-hooks.sh` ends in "All hooks passed.", and `bash plugins/devkit/scripts/pr-size.sh <phase-3 branch>` exits 0.

### Phase 5 — links: `--scratch` / `--webfetch` (~110: script ~50, tests ~60)
- [ ] `--scratch` and `--webfetch`.
  - The realpath guard as described in Approach.
  - URL cleaning: userinfo, query and fragment removed, then `clean()` and redaction.
  - Name: `link-<sha8>.md`.
  - The file and dir are deleted after a successful read.
  - File: `plugins/devkit/scripts/ingest.sh`
- [ ] Rows. File: `scripts/test-hooks.sh`
  - `--scratch` prints a non-existent `fetch.md` in a new 0700 dir
  - every link header field
  - `https://u:p@h/x?token=1#f` gives `origin: "https://h/x"`
  - WebFetch text is redacted
  - the scratch file and dir are gone after the run
  - a normal file, a symlinked `fetch.md`, and a wrong basename each give `not-scratch` and stay in place
  - with `TMPDIR` set to a symlink to a real dir, `--scratch` then `--webfetch` succeeds
- Verify:
  - `scripts/test-hooks.sh` ends in "All hooks passed.", and `bash plugins/devkit/scripts/pr-size.sh <phase-4 branch>` exits 0.
  - Manual, needs network and login; record it in the PR report: in a temp git repo, `claude -p --plugin-dir <repo>/plugins/devkit --allowedTools "WebFetch,Write,Bash(bash */ingest.sh *)" "Run ingest.sh --scratch, WebFetch https://example.com returning the full text verbatim, Write it to the printed path, then run ingest.sh --webfetch https://example.com <path> docs/requirements/x/sources"`. Expect `status=converted` and no scratch dir left under `$TMPDIR`. If Write to a path outside the project is denied in headless mode, record it and add the needed permission note to the skills in P6.

### Phase 6 — skills, agent, conventions, templates, docs (~110)
- [ ] bootstrap. File: `plugins/devkit/skills/bootstrap/SKILL.md`
  - `:6` gains `Bash(bash */ingest.sh *)`.
  - Step 1 starts with ingestion: each file goes through `ingest.sh <file> docs/requirements/<project-slug>/sources`. Each link goes through `--scratch` → WebFetch ("return the full text verbatim") → Write → `--webfetch`.
  - Show the result lines, and the hint for skipped PDFs (decision A wording in the brief's `Sources:`).
  - The analyst gets the source paths plus unconverted originals (images, skipped PDFs).
  - Step 2: the plan lists the sources.
  - `:21`: carve-out: source copies under `docs/requirements/*/sources/` are regenerated by `ingest.sh` when the original changed.
  - Step 3 (`:53`): the exclude pathspec and the `git log -- docs/requirements` check.
  - Step 8 (`:91`): source review before the commit question.
- [ ] task. File: `plugins/devkit/skills/task/SKILL.md`
  - `:6` gains `Bash(bash */ingest.sh *)`.
  - `:23`: a file path or a non-tracker URL. With no ticket key, the slug comes from `ingest.sh --slug` (decision B). The input is ingested into `docs/requirements/<TASK_ID>-<slug>/sources/` and the converted `.md` is read.
  - Show the result line. Remind the user that the sources under `docs/requirements/<TASK_ID>-<slug>/` are committed with the SPEC in the `:66` git-manager commit, so they ship in the PR (names are not redacted).
  - They are uncommitted until then, like the SPEC. If the user moves to a worktree at `:48`, both must move.
  - Images are read directly. A skipped PDF is read directly, with the decision A wording in the SPEC `Source:`.
  - The SPEC `Source:` links the source file.
- [ ] Analyst `:14`: read the converted sources under `docs/requirements/*/sources/` first and cite them per point; read unconverted originals directly. Quotes from a source still follow the `:8` quote rule. File: `plugins/devkit/agents/requirements-analyst.md`
- [ ] Conventions. File: `plugins/devkit/references/conventions.md`
  - A Directories row for `docs/requirements/<slug>/sources/<name>.md` (`bootstrap`, `task` via `scripts/ingest.sh`).
  - A Language (`:9`) carve-out: source copies are not artifacts. The body is verbatim in the original language apart from automatic email/phone redaction, and names are kept (best effort). The header is English. Quotes lifted into a brief or SPEC follow the quote rule.
- [ ] Templates: `Sources:` lists the source links; the SPEC `Source:` example mentions a source file and the decision A wording. Files: `plugins/devkit/templates/docs/PROJECT_BRIEF.md:3`, `plugins/devkit/templates/docs/tasks/_TEMPLATE/SPEC.md:3`
- [ ] Docs. Files: `README.md`, `UPSTREAM.md`, `CHANGELOG.md`, `upstream/proposals/20261018.md`
  - README `:9-10`.
  - `UPSTREAM.md:134` becomes ✅ with a note.
  - CHANGELOG `[Unreleased]`: the final entry with the test-row count.
  - Proposal `:86,91,94`: P-28 is marked done and its next command is dropped.
- Verify:
  - `claude plugin validate plugins/devkit --strict && claude plugin validate .` exits 0.
  - `scripts/test-hooks.sh` passes.
  - `bash plugins/devkit/scripts/pr-size.sh <phase-5 branch>` exits 0.
  - Manual: `claude --plugin-dir plugins/devkit`, then `/devkit:task <fixture CV_0912345678.docx>` in a temp repo writes `docs/requirements/<same folder name as the SPEC>/sources/cv-redacted-docx-<sha8>.md`, and the SPEC folder name has no digits of the phone number, and no `0912345678` appears anywhere under `docs/` (`grep -r` exits 1).

## Risks
| Risk | Signal | Mitigation |
| --- | --- | --- |
| XML entity attacks on old expat, including UTF-16 parts | A DTD fixture converts | The expat pre-parse raises on DOCTYPE/ENTITY for any encoding. UTF-8 and UTF-16 rows in P2, a sharedStrings row in P3 |
| Zip bombs, or `file_size` lying | Memory or time spikes on a fixture | `read(cap+1)` per part, a total read cap, an entry count, an XFD column bound, and an output cap checked inside the loop; all tested |
| Unredacted contacts committed (odd formats, names) | A contact in a source diff | Sources are excluded from the scaffold commit, and the step-8 question asks for a review. The task skill warns before the PR. The header says best effort. Counts are visible |
| Phone numbers in the body split by a zero-width space or `·` are not redacted (names are normalized first; the body is kept verbatim) | A reviewer sees a split number in a source diff | Known limit from the P1 fix round; Phase 6 skills tell the user to review sources before the first commit |
| Names are over-redacted: any digit run of 9–15 digits starting with `0` or `+` in a file name or folder hides the whole stem (e.g. `v1.0 20241021.md`) | A harmless name shows as `[redacted]` | Accepted: names need no fidelity; the header `sha256` still ties the source to its original |
| Origin is relative to the nearest `.git` above the cwd; nested repos with an absolute out-dir could give two files one origin | Contrived | Skills run from the project root; noted |
| Redaction false positives damage requirements | `[redacted]` where a number belongs | 10-digit VN mobile with lookarounds, 9–15 digits for others; negative rows |
| A scaffolder commits `docs/requirements/` on its own | The `git log -- docs/requirements` check prints a commit | Bootstrap stops and tells the user. Not seen in practice (assumption) |
| WebFetch text left unredacted in the scratch dir | `devkit-ingest.*` left in `$TMPDIR` after a failure | 0700 dir outside the repo, deleted by `--webfetch`; strict guard so nothing else is deleted |
| Write tool refuses or prompts for the scratch path | The P5 manual run is blocked | Found in P5. The skills say to approve that one Write, or fall back to skipping the link with a message |
| pandoc output drifts between versions | Two machines, same sha, different body | Same sha gives `unchanged` whatever the converter, so the first committed text wins; no churn |
| A stale old file after a redacted-name source changes | Two `cv-redacted-docx-*.md` files | Visible in git status. The user deletes the old one. Accepted to avoid hashing PII |
| A phase exceeds 300 lines | `pr-size.sh` exit 3 | P1 is the biggest. Move PDF-skip/unsupported to P2, or `--slug` to P5, as one more split. A later commit on the same branch does not help |

## Out of scope
- OCR, odt/rtf/doc/ppt/xls, merged cells, nested lists beyond `ilvl` indentation, images inside documents.
- pptx speaker notes, xlsx `rPh` handling, NFKD or `đ` transliteration in slugs, per-host link names.
- Jira/Linear/Notion attachments, and authenticated or private links.
- A `docs/devkit.md` setting (e.g. `pdftotext -layout`), an eval case, and the v2.7.0 release.

## Red-team notes
Applied:
- Settled A and B: recorded under Approach. The "Decisions for the user" section is removed.
- Tech 1: the expat pre-parse with raising DOCTYPE/ENTITY handlers replaces the byte check. UTF-16 fixture row in P2.
- Tech 2: the 10-digit VN mobile regex, with the positive and negative rows in P1. The lookarounds use `\d` and allow `-` before the number (not `\w`), so `CV_…`/`CV-…` file names are caught.
- Tech 3: the file stem (the extension is kept from the original), slug (`--slug`), `source`/`origin` and stdout `file=` are redacted. The URL loses userinfo, query and fragment. Redacted names always get `-<sha8>` (content hash), so two redacted names never overwrite each other and no hash of PII is stored.
- Tech 4: a different `origin:` gives `-<sha8>`, then `name-collision`. Another source's file is never overwritten (identity moved from `source:` to `origin:` in the P1 review, so the same base name from another folder is a different source).
- Tech 5: the step-3 scaffold commit excludes `docs/requirements/`, and a `git log` check follows. Sources first land in the step-8 commit after a review prompt. "Ingest after step 3" was rejected because the analyst and the step-2 plan need the sources. The false "nothing committed before step 8" claim is removed.
- Tech 6: realpath on both sides, with a symlinked-TMPDIR row.
- Tech 7: `--scratch` prints a not-yet-existing path in a fresh 0700 `mkdtemp` dir. P5 adds a manual headless `claude -p` run of the real flow; it is not in `test-hooks.sh` because it needs network and login.
- Tech 8: per-component lstat, `O_NOFOLLOW`, `mkstemp` + `os.replace`.
- Tech 9: pandoc gets `--` and an absolute path. pdftotext gets an absolute path only; poppler's support for `--` is unverified, and a leading `/` already blocks option injection.
- Tech 10: JSON-quoted values; only the first front-matter block is read.
- Tech 11: `ParseError`/`ExpatError` gives `bad-xml` with exit 0, plus a row. Only internal errors exit 1.
- Tech 12: converter stdout is capped while reading.
- Scope 1: six stacked PRs with line estimates.
- Scope 2: `exists`/`--replace` and converter-keyed `unchanged` dropped.
- Scope 3: caps reduced to input, entries, per-part, total, output and timeout. Per-sheet/row/column/slide caps are dropped, because the output cap is checked in the emit loop and stops work early. Only the XFD column bound stays, as validation against huge row allocation.
- Scope 4: the listed items moved to Out of scope.
- Scope 6: covered by decision A.

Rejected:
- Rejected finding: scope 5, drop the `--scratch` deletion — Reason: the scratch file holds unredacted WebFetch text, so it must not outlive the call. Tech 6 and 7 make the guard correct on macOS.
- Rejected finding: tech 12's ratio cap (bytes read vs `compress_size`) — Reason: the per-part `read(cap+1)` and the total-read cap already bound memory and time. A ratio check adds a test row without adding a bound.
- Rejected finding: tech 9's `--` for pdftotext — Reason: whether poppler accepts it is unverified, and the stubs cannot show it. The absolute path gives the same protection.
