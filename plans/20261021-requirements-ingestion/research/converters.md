# P-28 research: converters (as of 2026-10-21)

Desk research by `devkit:researcher`; items without a URL are from working knowledge and marked unverified. Not opened: ECMA-376 / Microsoft Open XML pages (section 3 is from spec knowledge).

## Conclusion
pandoc ≥ 3.8.3 (2025-12-01) reads docx, odt, pptx and xlsx; earlier 3.x reads docx and odt only, so probe `pandoc --list-input-formats` per format. `pdftotext` (poppler) covers PDFs. A Python-stdlib reader (zipfile + xml.etree) is viable for docx/pptx/xlsx if every XML part containing `<!DOCTYPE` or `<!ENTITY` is refused and size caps are enforced.

## pandoc
- Input formats include docx, odt, pptx, xlsx (https://pandoc.org/MANUAL.html); pptx and xlsx input added in 3.8.3 (https://raw.githubusercontent.com/jgm/pandoc/main/changelog.md); each xlsx sheet becomes a section with a table.
- Command: `pandoc -f <fmt> -t gfm --wrap=none --sandbox -- file` (stdout). `--sandbox` limits reader/writer IO to the named files. No media is extracted without `--extract-media`; image links may remain and should be stripped (unverified).
- Tables: pipe tables when simple; raw HTML `<table>` for block content in cells (unverified).
- Fall back on a nonzero exit or empty output.

## pdftotext
- `pdftotext -enc UTF-8 -nopgbrk -q file.pdf -` (stdout) (https://manpages.debian.org/unstable/poppler-utils/pdftotext.1.en.html; `-nopgbrk`, `-q` unverified). `-layout` keeps columns but pads lines; default reading order is better for prose.
- Exit 0 ok, 1 open error, 3 permission, 99 other (numbers unverified). Scanned PDFs give empty text (no OCR): warn when fewer than N non-space characters.

## Stdlib readers (spec knowledge, unverified)
- docx `word/document.xml`: `w:p` paragraphs, `w:r/w:t` text, `w:tab`, `w:br`; headings by `w:pStyle` `Heading1..9`/`Title`; lists by `w:numPr` (`w:ilvl`, `numId` 0 = none) → `- ` by level; tables `w:tbl/w:tr/w:tc` (first row header, merged cells ignored); `w:delText` skipped naturally.
- pptx: slide order from `ppt/presentation.xml` `p:sldIdLst` via `ppt/_rels/presentation.xml.rels` (numeric sort as fallback); `a:p` / `a:t`, `a:br`; `## Slide N`; notes from the slide's `/notesSlide` relationship; slide tables `a:tbl`.
- xlsx: `xl/workbook.xml` sheets via `xl/_rels/workbook.xml.rels`; `xl/sharedStrings.xml` `si` (all `t` descendants except `rPh`); cell types `s`, `inlineStr`, `str`, `b`, `e`, `n`; dates stay raw serials; place cells by column letters in `r`; one `### <sheet>` + pipe table per sheet.

## Safety (stdlib only; no new libraries)
- Python docs: Expat before 2.7.2 may be vulnerable to billion laughs / quadratic blowup (https://docs.python.org/3/library/xml.html; https://github.com/libexpat/libexpat/blob/master/expat/Changes). Users' Expat versions vary, so: refuse any part containing `<!DOCTYPE` or `<!ENTITY` (Office XML never needs a DTD).
- Zip bombs: `ZipInfo.file_size` can lie; read with `zf.open(name).read(CAP + 1)`. Suggested caps: input ≤ 50 MB; ≤ 2,000 entries; ≤ 20 MB per part; ≤ 100 MB total read; ratio > 100× rejected; output ≤ 5 MB; xlsx ≤ 20 sheets × 5,000 rows × 100 columns (with a "truncated" note); pptx ≤ 500 slides; ~30 s per file.
- Never extract to disk; only fixed or rels-resolved member names, normalized, never starting with `..`. Encrypted OOXML is an OLE file (`zipfile.is_zipfile` false): fail with a clear message. Run pandoc with `--sandbox`, a timeout and the same size pre-check.

## Redaction (own regexes; no standard found)
- Email: `(?i)\b[a-z0-9._%+-]+@[a-z0-9-]+(?:\.[a-z0-9-]+)*\.[a-z]{2,}\b`.
- International phone: `(?<![\w.])\+\d{1,3}[\s.-]?\(?\d{1,4}\)?(?:[\s.-]?\d{2,4}){2,4}(?!\w)`.
- Vietnamese mobile: `(?<![\d.])0(?:3|5|7|8|9)\d(?:[\s.-]?\d{3}){2}(?!\d)`; landline `(?<!\d)02\d{2}[\s.-]?\d{3}[\s.-]?\d{3,4}(?!\d)` (prefixes unverified).
- Require 9–15 digits and a `+` or leading `0`; never redact bare digit runs, dates, versions, ticket ids, xlsx numbers. Best effort: names, addresses, national ids are not caught. Log counts only, never values.

## Decisions for the plan
Converter order and fallback; pandoc version/format probe; image links stripped; PDF `-layout` opt-in; scanned/encrypted → clear failure; stdlib scope (no merged cells, simple bullets, styleId headings); pptx notes included; DOCTYPE/ENTITY refusal and caps; xlsx dates raw with truncation note; redaction placeholders, counts in the header; timeouts and output cap.
