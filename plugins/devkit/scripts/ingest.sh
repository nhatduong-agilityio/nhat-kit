#!/usr/bin/env bash
# Turn one requirements document into a saved, redacted source file with a provenance header.
# Usage: ingest.sh <file> <out-dir>      write <out-dir>/<slug>-<ext>.md (out-dir must not contain "..")
#        ingest.sh --slug <file>         print the redacted ASCII slug of the file stem
# Output: one line, never any document text:
#   file=<redacted name> out=<path|-> converter=<id|-> status=converted|unchanged|skipped|failed reason=<code|-> redacted=<N>
#   --slug prints "slug=<s>"; <s> gets "-<sha8>" (first 8 hex of the content sha256) when redaction changed the stem.
# Handles .md/.txt (UTF-8 passthrough, converter "passthrough") and .docx (stdlib zip+XML reader, converter
# "stdlib-docx-1"). .pdf is skipped (no-pdftotext; unsupported when pdftotext exists until its converter is wired in).
# Everything else is skipped (unsupported). Input cap 50 MB (too-large).
# docx: never extracted to disk; at most 2,000 entries; each part read(20 MB + 1); 100 MB read in total (too-large).
# The main part comes from the _rels/.rels officeDocument target (else word/document.xml); one leading "/" is the
# package root (OPC), and a target that is empty or starts with ".." or "/" after posixpath.normpath is bad-ooxml.
# Every XML part goes through expat first: a DOCTYPE or ENTITY (any encoding) is unsafe-xml, a parse error bad-xml.
# Output is capped at 5 MB with a truncation note; then the same redaction, header and write path as md/txt.
# Redaction (best effort): emails and phone numbers in the body and header values, by regex; the header holds the count.
# A file name or folder with "@" or a 9-15 digit run starting with "+" or "0" (any separators, NFKC-matched) is shown as
# "[redacted]<.ext>" and slugged "source". Identity: only an origin byte-identical to the raw path is reused or
# overwritten; anything cleaned, redacted or outside the repo and cwd is written as "<name>-<sha8>.md".
# Reasons: not-utf8 not-ooxml bad-ooxml too-many-entries unsafe-xml bad-xml too-large unsupported no-pdftotext
# not-regular symlink bad-out-dir name-collision unreadable write-failed.
# Existing target: same sha256 -> unchanged; same origin (repo- or cwd-relative) -> overwritten; another source, or
# an input outside the repo and cwd (its base name cannot identify it), -> "<name>-<sha8>.md", then
# name-collision. Out-dir components that are symlinks are refused, and so is any ".." in the out-dir; root-owned
# system links outside cwd (such as /var) are allowed, which gives no protection when running as root.
# Exit: 0 whenever the line prints (including failed/skipped); 1 usage error, missing python3, internal error, or a
# --slug failure (one "ingest: <reason>" line on stderr instead of the line).
die() { echo "ingest: $*" >&2; exit 1; }
[ $# -eq 2 ] || { echo "usage: ingest.sh <file> <out-dir> | ingest.sh --slug <file>" >&2; exit 1; }
command -v python3 >/dev/null 2>&1 || die "python3 required"

exec python3 -I -c '
import sys, os, re, io, json, struct, stat, errno, shutil, hashlib, tempfile, zipfile, posixpath, unicodedata as ud, datetime as dt
import xml.parsers.expat as xp, xml.etree.ElementTree as ET
def crash(*_): sys.stderr.write("ingest: unexpected error\n"); sys.stderr.flush(); os._exit(1)
sys.excepthook = crash  # fail closed: one line, no traceback (tracebacks could echo document text)
def clean(s): return "".join(" " if c.isspace() or ud.category(c)[0] == "C" else c for c in s)
RX = [re.compile(r"(?i)(?<![^\s@<>()\[\],;:\x22\x27*\x60~/{}|])[^\s@<>()\[\],;:\x22\x27*\x60~/{}|]+@[a-z0-9-]+(?:\.[a-z0-9-]+)*\.[a-z]{2,}(?![a-z0-9])"),
      re.compile(r"(?<![A-Za-z0-9.+])\+\d{1,3}[\s.-]?\(?\d{1,4}\)?(?:[\s.-]?\d{2,4}){2,4}(?![A-Za-z0-9])"),
      re.compile(r"(?<![\d.+])0[35789]\d(?:[\s.-]?\d){7}(?!\d|[.-]\d)"),
      re.compile(r"(?<![\d.,+])\(?02\d\)?(?:[\s.-]?\d){8}(?!\d|[.,-]\d)")]
cnt = [0]
def red(s, rep="[redacted]", count=True, rxs=RX):
    for rx in rxs:
        s, k = rx.subn(rep, s); cnt[0] += k if count else 0
    return s
SAFE_EXT = (".md", ".txt", ".pdf", ".docx", ".pptx", ".xlsx", ".odt")
def hit(s):  # a contact in a name? Matched on an NFKC copy (fullwidth digits) that is never shown or used as identity
    m = ud.normalize("NFKC", s)
    if "@" in m: return True
    for g in re.finditer(r"\+?\d(?:[^A-Za-z0-9]{0,3}\d)*", m):  # digits joined by any separator, "_" included
        r = g.group()
        for i in (x.start() for x in re.finditer(r"\+?\d+", r)):  # any group starting with + or 0 ("CV 2024 0912...")
            if r[i] not in "+0": continue
            n = 0
            for x in re.finditer(r"\d+", r[i:]):
                n += len(x.group())
                if 9 <= n <= 15: return True
    return False
def seg(s, count=True):  # display form of one file name or path segment; a hit drops the whole stem (names need no fidelity)
    c = clean(s)
    if not hit(c): return c, False
    cnt[0] += 1 if count else 0; x = os.path.splitext(c)[1]
    return "[redacted]" + (x if x.lower() in SAFE_EXT else ""), True
def slug(s): return "-".join(re.findall(r"[a-z0-9]+", s.lower().encode("ascii", "ignore").decode())[:5])
cwd = os.getcwd()
def under(p, r): return p.startswith(r.rstrip(os.sep) + os.sep)
def emit(out, conv, status, reason, name):
    out = os.path.relpath(out, cwd) if under(out, cwd) else out
    print("file=%s out=%s converter=%s status=%s reason=%s redacted=%d" % (name, "/".join(seg(x, False)[0] for x in out.split("/")), conv, status, reason, cnt[0]))
    sys.exit(0)
a = sys.argv[1:]
slug_mode = a[0] == "--slug"
path = os.path.abspath(a[1] if slug_mode else a[0])
base = os.path.basename(path)
stem, ext = os.path.splitext(base)
rname, trig = seg(base)
sb = "" if trig else slug(os.path.splitext(rname)[0]); changed = rname != base  # any changed byte: content-named
def bail(reason, status="failed"):
    if slug_mode: sys.stderr.write("ingest: %s\n" % reason); sys.exit(1)
    emit("-", "-", status, reason, rname)
if not slug_mode and ".." in a[1].split(os.sep): bail("bad-out-dir")
CAP = 50 * 1024 * 1024
try: fd = os.open(path, os.O_RDONLY | os.O_NONBLOCK); st = os.fstat(fd)
except OSError: bail("unreadable")
if not stat.S_ISREG(st.st_mode): bail("not-regular")
if st.st_size > CAP: bail("too-large")
e = ext.lower()
if not slug_mode:
    if e == ".pdf":
        if shutil.which("pdftotext") is None:
            sys.stderr.write("ingest: pdftotext missing; install: brew install poppler / apt install poppler-utils\n")
            bail("no-pdftotext", "skipped")
        bail("unsupported", "skipped")  # Phase 4 wires the pdftotext converter
    if e not in (".md", ".txt", ".docx"): bail("unsupported", "skipped")
try:
    with os.fdopen(fd, "rb") as f: data = f.read(CAP + 1)
except OSError: bail("unreadable")
if len(data) > CAP: bail("too-large")
sha = hashlib.sha256(data).hexdigest(); sha8 = sha[:8]
if slug_mode:
    print("slug=" + (sb or "source") + ("-" + sha8 if changed else "")); sys.exit(0)
class Unsafe(Exception): pass
def no(*_): raise Unsafe()
def xml(b):  # expat first: it decodes any encoding (UTF-16 too) before the DOCTYPE/ENTITY handlers see the markup
    p = xp.ParserCreate(); p.StartDoctypeDeclHandler = p.EntityDeclHandler = no
    try: p.Parse(b, True)
    except Unsafe: bail("unsafe-xml")
    except (xp.ExpatError, ValueError, LookupError): bail("bad-xml")
    try: return ET.fromstring(b)
    except ET.ParseError: bail("bad-xml")
used = [0]
def part(zf, n):
    try:
        with zf.open(n) as f: b = f.read(20 * 2**20 + 1)
    except Exception: bail("bad-ooxml")  # missing member, corrupt or encrypted data, unknown compression
    used[0] += len(b)
    if len(b) > 20 * 2**20 or used[0] > 100 * 2**20: bail("too-large")
    return xml(b)
ln = lambda x: x.tag.rsplit("}", 1)[-1]  # local names: transitional and strict namespaces alike
def val(x, k="val"): return next((v for a, v in x.attrib.items() if a.rsplit("}", 1)[-1] == k), "")
def num(x, k):
    v = [val(y) for y in x.iter() if ln(y) == k]
    return min(int(v[0]), 8) if v and re.fullmatch("[0-9]{1,4}", v[0]) else 0  # bounded: ilvl drives indentation
def walk(x, stop):  # descendants in document order without recursion; does not enter a match or an mc:Fallback copy
    st = list(x)[::-1]
    while st:
        y = st.pop(); k = ln(y)
        if k == "Fallback": continue
        if k in stop: yield y
        else: st.extend(list(y)[::-1])
def para(p):  # every run of the paragraph once, nested ones included (linear: no paragraph is walked twice)
    return "".join({"t": y.text or "", "tab": "\t", "br": "\n", "cr": "\n"}.get(ln(y), "") for r in walk(p, ("r",)) for y in r)
def cell(c): return " ".join(para(p) for p in walk(c, ("p",))).replace("\n", " ").replace("|", "\\|").strip()
OCAP = 5 * 2**20  # output cap
def blocks(el):
    for c in el:
        if ln(c) == "p":
            pr = [y for y in c if ln(y) == "pPr"]; s = [val(y) for y in pr[0].iter() if ln(y) == "pStyle"] if pr else []
            h = re.match(r"(?i)heading([1-9])$", s[0]) if s else None; t = para(c).strip()
            lst = pr and [y for y in pr[0] if ln(y) == "numPr"] and num(pr[0], "numId")
            if not t: continue
            if h or s and s[0].lower() == "title": yield "#" * (int(h.group(1)) if h else 1) + " " + t
            elif lst: yield "  " * num(pr[0], "ilvl") + "- " + t
            else: yield t
        elif ln(c) == "tbl":
            rows = [[cell(x) for x in r if ln(x) == "tc"] for r in c if ln(r) == "tr"]; w = max([len(r) for r in rows] or [0])
            if w:  # pad row by row and stop at the output cap: n short rows x w cells never get built (n*w is quadratic)
                ls, size = [], 0
                for r in [rows[0], ["---"] * w] + rows[1:]:
                    ls.append("| " + " | ".join(r + [""] * (w - len(r))) + " |"); size += len(ls[-1]) + 1
                    if size > OCAP: break
                yield "\n".join(ls)
        elif ln(c) not in ("sectPr", "Fallback"): yield from blocks(c)  # sdt/sdtContent, customXml, ins; one mc copy
def docx():
    f = io.BytesIO(data)
    try: ok = zipfile.is_zipfile(f)
    except Exception: ok = False  # e.g. a zip64 locator claiming several disks
    if not ok: bail("not-ooxml")
    i = data.rfind(b"PK\x05\x06", max(0, len(data) - 65557))  # EOCD: bound entries and directory size before ZipFile
    if i < 0 or len(data) < i + 22: bail("bad-ooxml")
    cnt_e, cd = struct.unpack("<HI", data[i + 10:i + 16])
    if i >= 76 and data[i - 20:i - 16] == b"PK\x06\x07":  # zip64: zipfile takes the counts from the record before the locator
        if data[i - 76:i - 72] != b"PK\x06\x06" or struct.unpack("<Q", data[i - 12:i - 4])[0] != i - 76: bail("bad-ooxml")
        cnt_e, cd = struct.unpack("<QQ", data[i - 44:i - 28])
    if cnt_e > 2000 or cd > 2000 * 1100: bail("too-many-entries")
    try: zf = zipfile.ZipFile(f); names = zf.namelist()
    except Exception: bail("bad-ooxml")
    if len(names) > 2000: bail("too-many-entries")
    n = "word/document.xml"
    if "_rels/.rels" in names:
        for r in part(zf, "_rels/.rels"):
            if val(r, "Type").endswith("/officeDocument"):
                t = val(r, "Target"); n = posixpath.normpath(t[1:] if t.startswith("/") else t)
                if n in ("", ".") or n.startswith(("..", "/")): bail("bad-ooxml")
                break
    out, size, cap = [], 0, OCAP
    try:
        for b in blocks(part(zf, n)):
            b = red(b); k = len(b.encode()) + 2  # redact before the cap, so a cut never splits a contact
            if size + k > cap: out.append(b.encode()[:cap - size].decode("utf-8", "ignore") + "\n\n_[truncated at 5 MB]_"); break
            out.append(b); size += k
    except RecursionError: bail("bad-xml")
    return "\n\n".join(out) + "\n"
conv = "stdlib-docx-1" if e == ".docx" else "passthrough"
if e == ".docx": body = docx()
else:
    try: body = data.decode("utf-8")
    except UnicodeDecodeError: bail("not-utf8")
# origin: repo-relative (a .git entry found walking up from cwd), else cwd-relative, else the base name; never absolute
real = os.path.realpath(path); root = None; d = cwd
while True:
    if os.path.lexists(os.path.join(d, ".git")): root = d; break
    if os.path.dirname(d) == d: break
    d = os.path.dirname(d)
# identity: reuse or overwrite a target only when the origin is byte-identical to the raw repo- or cwd-relative path;
# a cleaned or redacted name or folder, or an input outside both, is always written as "<name>-<sha8>.md"
origin = rname; anchored = False
for r in (root, cwd):
    if r and under(real, os.path.realpath(r)):
        rel = os.path.relpath(real, os.path.realpath(r)).split(os.sep)
        origin = "/".join([seg(x)[0] for x in rel[:-1]] + [rname]); anchored = origin == "/".join(rel) == red(clean(origin), count=False); break
body = red(body)
q = lambda v, r=True: json.dumps(red(clean(v)) if r else v, ensure_ascii=False)  # r=False: never redact sha/date/converter (hex can look like a phone)
hdr = ["source: " + q(rname), "origin: " + q(origin), "sha256: " + q(sha, False), "converted: " + q(dt.date.today().isoformat(), False),
       "converter: " + q(conv, False),
       "redacted: " + json.dumps("%d (emails and phone numbers in the name and body; names of people are not redacted, best effort)" % cnt[0]),
       "note: " + q("Original text, verbatim apart from redaction; not translated.", False)]
text = "---\n" + "\n".join(hdr) + "\n---\n\n" + body + ("" if body.endswith("\n") else "\n")
# out-dir: create component by component, refusing symlinks (checked below cwd; elsewhere root-owned links pass)
ap = os.path.abspath(a[1]); start = cwd if ap == cwd or under(ap, cwd) else os.sep
cur = start
for comp in [p for p in os.path.relpath(ap, start).split(os.sep) if p and p != "."]:
    cur = os.path.join(cur, comp)
    try: st = os.lstat(cur)
    except FileNotFoundError:
        try: os.mkdir(cur)
        except OSError: bail("write-failed")
        continue
    if stat.S_ISLNK(st.st_mode) and not (start == os.sep and st.st_uid == 0): bail("symlink")
    if not os.path.isdir(cur): bail("write-failed")
def existing(p):  # None: absent; {}: unreadable header (counts as another source); else the first front-matter block
    try: fd = os.open(p, os.O_RDONLY | os.O_NOFOLLOW | os.O_NONBLOCK)
    except FileNotFoundError: return None
    except OSError as x:
        if x.errno == errno.ELOOP: bail("symlink")
        return {}
    if not stat.S_ISREG(os.fstat(fd).st_mode): bail("write-failed")
    with os.fdopen(fd, "rb") as f: head = f.read(65536).decode("utf-8", "replace").split("\n")
    if head[0].strip() != "---" or "---" not in [l.strip() for l in head[1:]]: return {}
    meta = {}
    try:
        for l in head[1:[l.strip() for l in head[1:]].index("---") + 1]:
            k, _, v = l.partition(": "); meta[k] = json.loads(v)
    except Exception: return {}
    return meta
b = (sb or "source") + "-" + (slug(e) or "file") + ("" if anchored and sb else "-" + sha8)
names = [b + ".md"] + ([b + "-" + sha8 + ".md"] if anchored and sb else [])  # the others already carry -sha8
for i, n in enumerate(names):
    t = os.path.join(ap, n); ex = existing(t)
    if ex is not None and ex.get("sha256") == sha: emit(t, conv, "unchanged", "-", rname)
    if ex is None or (anchored and ex.get("origin") == origin): break  # origin is the identity (repo-relative)
    if i == len(names) - 1: bail("name-collision")
try:
    fd, tmp = tempfile.mkstemp(dir=ap, prefix=".ingest.")
    try:
        with os.fdopen(fd, "w", encoding="utf-8") as f: f.write(text)
        os.chmod(tmp, 0o644); os.replace(tmp, t)
    except BaseException:
        os.unlink(tmp); raise
except OSError: bail("write-failed")
emit(t, conv, "converted", "-", rname)
' "$@"
