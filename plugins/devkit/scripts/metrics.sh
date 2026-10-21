#!/usr/bin/env bash
# Report team metrics for merged PRs from GitHub data only. Read-only.
# Usage: metrics.sh [--since YYYY-MM-DD]     (default: 14 days ago, UTC)
# Output: "key=value" lines, then one TSV row per PR merged on or after SINCE T00:00:00Z, newest number first:
#   since=D until=<ISO UTC> report_date=<local YYYYMMDD>
#   prs_merged=N prs_truncated=0|1                 (1 when gh returned its 1000-result limit)
#   size_n=N size_missing=K lines_median=… lines_p90=… files_median=… files_p90=… over_limit=K max_lines=… max_files=…
#   cycle_n=N cycle_missing=K no_issue=… not_fetched=… no_claim=… capped=… cycle_median_hours=… cycle_p90_hours=…
#   review_sendbacks=N queue_releases=N issues_truncated=0|1
#   bugs_open=N critical=… high=… medium=… low=… none=… bugs_truncated=0|1
#   queue_depth=N in_flight=N queue_truncated=0|1
#   capped_items=N                                 (PRs and issues with exactly 100 files, reviews or comments)
#   #N<TAB>lines|-<TAB>files|-<TAB>cycle_hours|-<TAB>changes_requested<TAB>title
# Size excludes the files that pr-size.sh excludes (same matcher and docs/devkit.md limits, read from today's
# docs/devkit.md for every PR). gh lists a rename once, while pr-size.sh counts a delete plus an add. "-" = unknown.
# Cycle = merge time minus the latest "🔒 devkit claim" before the merge (earliest of those over several closing
# issues of the same repo, matched on repo + number). No cycle -> counted once, under the first reason that applies,
# in this order: no_issue (no closing issue), not_fetched (any closing issue of this repo missing from the `ai`
# search, e.g. no `ai` label or the search was truncated; or only other-repo issues), capped (a closing issue has
# exactly 100 comments, so gh may have dropped the newest claim; no number computed), no_claim (no claim before merge).
# review_sendbacks = CHANGES_REQUESTED reviews on the PRs listed (a later-dismissed review is not counted).
# queue_releases = "🔓 devkit release" comments on `ai` issues since SINCE, posted after a claim on the same issue
# (releases on issues without the `ai` label are not seen; claim-race releases count). The two are never summed.
# Bugs = open `bug` issues by highest severity:* label (none if absent).
# queue_depth = open `ai` issues without `in-progress`; in_flight = with it. *_truncated=1 when gh returned 1000.
# Stats use the nearest-rank method. Never prints comment or review bodies.
# Exit: 0 reported; 1 usage error, missing tool, not a git repo, gh failure, or output it cannot parse.
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
die() { echo "metrics: $*" >&2; exit 1; }
usage() { echo "usage: metrics.sh [--since YYYY-MM-DD]" >&2; exit 1; }

command -v gh >/dev/null 2>&1 || die "gh required"
command -v python3 >/dev/null 2>&1 || die "python3 required"
command -v git >/dev/null 2>&1 || die "git required"

since=""
case $# in
  0) ;;
  2) [ "$1" = --since ] && [[ "$2" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}$ ]] || usage; since="$2" ;;
  *) usage ;;
esac

top="$(git rev-parse --show-toplevel 2>/dev/null)" || die "not a git repository"
cd "$top" || die "cannot enter $top"
tmp="$(mktemp -d 2>/dev/null)" || die "mktemp failed"
trap 'rm -rf "$tmp"' EXIT
# Plain output only: no colour or forced-TTY formatting in the JSON.
ghq() { ( unset CLICOLOR_FORCE GH_FORCE_TTY; NO_COLOR=1 gh "$@" ); }
ghq auth status --active >/dev/null 2>&1 || die "gh not logged in"

# Shared Python parser. Modes: init, paths, report.
py() { python3 -I -c '
import sys, os, json, re, datetime as dt
mode = sys.argv[1]
def fail(m): sys.stderr.write("metrics: %s\n" % m); sys.exit(1)
def crash(*_): sys.stderr.write("metrics: unexpected gh output\n"); sys.stderr.flush(); os._exit(1)
sys.excepthook = crash  # any wrongly typed field fails closed with one line, never a traceback or a guess
def clean(s): return re.sub("[\x00-\x1f\x7f-\x9f\u2028\u2029\u200e\u200f\u202a-\u202e\u2066-\u2069]", " ", s)
def load(path, since):
    try:
        with open(path) as f: raw = json.load(f)
        assert isinstance(raw, list)
    except Exception: fail("unexpected gh output")
    start = since + "T00:00:00Z"
    if not all(isinstance(p, dict) and type(p.get("number")) is int and isinstance(p.get("mergedAt"), str)
               for p in raw): fail("unexpected gh output")
    return len(raw), [p for p in raw if p["mergedAt"] >= start]
def files_of(p): return [f for f in (p.get("files") or []) if isinstance(f, dict)]
if mode == "init":
    now = dt.datetime.now(dt.timezone.utc)
    try:
        s = sys.argv[2] or (now - dt.timedelta(days=14)).strftime("%Y-%m-%d")
        d = dt.datetime.strptime(s, "%Y-%m-%d")
        print(s); print((d - dt.timedelta(days=1)).strftime("%Y-%m-%d"))
    except Exception: fail("invalid date: " + sys.argv[2])
    print(now.strftime("%Y-%m-%dT%H:%M:%SZ")); print(dt.datetime.now().strftime("%Y%m%d"))
elif mode == "paths":
    _, prs = load(sys.argv[2], sys.argv[3])
    seen = {}
    for p in prs:
        for f in files_of(p):
            if isinstance(f.get("path"), str):
                if "\0" in f["path"]: fail("unexpected gh output")
                seen.setdefault(f["path"], len(seen))
    with open(sys.argv[4], "wb") as o:
        for path in seen: o.write(path.encode("utf-8", "surrogateescape") + b"\0")
else:
    since, until, rdate = sys.argv[3:6]
    raw_n, prs = load(sys.argv[2], since)
    try:
        with open(sys.argv[6]) as f: lines = f.read().split("\n")
        m = re.fullmatch(r"max_lines=(\d+) max_files=(\d+)", lines[0])
        max_lines, max_files = int(m.group(1)), int(m.group(2))
        excluded = set(int(x) for x in lines[1:] if x)
    except Exception: fail("unexpected pr-size output")
    index = {}
    for p in prs:
        for f in files_of(p):
            if isinstance(f.get("path"), str): index.setdefault(f["path"], len(index))
    if excluded and (min(excluded) < 0 or max(excluded) >= len(index)): fail("unexpected pr-size output")
    def size(p):
        fs, cf = files_of(p), p.get("changedFiles")
        if not isinstance(cf, int) or len(fs) < cf: return None
        keep = [f for f in fs if index.get(f.get("path")) not in excluded]
        if not all(type(f.get(k)) is int for f in keep for k in ("additions", "deletions")): fail("unexpected gh output")
        return sum(f["additions"] + f["deletions"] for f in keep), len(keep)
    def stat(v, num, den=10):
        if not v: return "-"
        return sorted(v)[(num * len(v) + den - 1) // den - 1]
    def need(c):
        if not c: fail("unexpected gh output")
    def jload(path):
        try:
            with open(path) as f: raw = json.load(f)
        except Exception: fail("unexpected gh output")
        need(isinstance(raw, list) and all(isinstance(i, dict) and type(i.get("number")) is int for i in raw))
        return raw
    def names(i):
        ls = i.get("labels")
        need(isinstance(ls, list) and all(isinstance(l, dict) and isinstance(l.get("name"), str) for l in ls))
        return [l["name"] for l in ls]
    try:
        with open(sys.argv[7]) as f: me = json.load(f)["nameWithOwner"].lower()
        need(isinstance(me, str) and me.count("/") == 1)
    except Exception: fail("unexpected gh output")
    def ts(s): return dt.datetime.strptime(s, "%Y-%m-%dT%H:%M:%SZ")
    issues, bugs, queue = jload(sys.argv[8]), jload(sys.argv[9]), jload(sys.argv[10])
    claims, rels, capped, cmap = {}, [], 0, {}
    for i in issues:
        cs = i.get("comments")
        need(isinstance(cs, list) and all(isinstance(c, dict) and isinstance(c.get("body"), str)
                                          and isinstance(c.get("createdAt"), str) for c in cs))
        if len(cs) == 100: capped += 1
        cmap[i["number"]] = len(cs)
        seen = False  # gh lists comments oldest first, so list order tells a claim posted before a release
        for c in cs:
            if c["body"].startswith("\U0001F512 devkit claim"):
                claims.setdefault(i["number"], []).append(ts(c["createdAt"])); seen = True
            elif c["body"].startswith("\U0001F513 devkit release"): rels.append((ts(c["createdAt"]), seen))
    start = ts(since + "T00:00:00Z")
    qrel = sum(1 for t, after_claim in rels if t >= start and after_claim)
    sev = {"critical": 0, "high": 0, "medium": 0, "low": 0, "none": 0}
    for b in bugs:
        ss = [k for k in ("critical", "high", "medium", "low") if "severity:" + k in names(b)]
        sev[ss[0] if ss else "none"] += 1
    infl = sum(1 for q in queue if "in-progress" in names(q))
    hours, why = [], {"no_issue": 0, "not_fetched": 0, "no_claim": 0, "capped": 0}
    def cycle(p):  # (hours, None) or (None, reason)
        refs = p.get("closingIssuesReferences")
        if refs is None: refs = []
        need(isinstance(refs, list) and all(isinstance(r, dict) and type(r.get("number")) is int and isinstance(r.get("repository"), dict)
             and isinstance(r["repository"].get("name"), str) and isinstance(r["repository"].get("owner"), dict)
             and isinstance(r["repository"]["owner"].get("login"), str) for r in refs))
        if not refs: return None, "no_issue"
        mine = [r["number"] for r in refs if (r["repository"]["owner"]["login"] + "/" + r["repository"]["name"]).lower() == me]
        if not mine or any(n not in cmap for n in mine): return None, "not_fetched"  # a missing issue may hold the earliest claim
        if any(cmap[n] == 100 for n in mine): return None, "capped"
        merged = ts(p["mergedAt"])
        best = [max(c for c in claims[n] if c < merged) for n in mine if any(c < merged for c in claims.get(n, []))]
        if not best: return None, "no_claim"
        return round((merged - min(best)).total_seconds() / 3600, 1), None
    rows, sl, sf, miss, over = [], [], [], 0, 0
    for p in sorted(prs, key=lambda p: -p["number"]):
        sz = size(p)
        revs = p.get("reviews")
        if revs is None: revs = []
        need(isinstance(revs, list) and all(isinstance(r, dict) and isinstance(r.get("state"), str) for r in revs))
        if len(files_of(p)) == 100 or len(revs) == 100: capped += 1
        hr, reason = cycle(p)
        if reason: why[reason] += 1
        else: hours.append(hr)
        if sz is None: miss += 1
        else:
            sl.append(sz[0]); sf.append(sz[1])
            if sz[0] > max_lines or sz[1] > max_files: over += 1
        cr = sum(1 for r in revs if r.get("state") == "CHANGES_REQUESTED")
        rows.append("#%d\t%s\t%s\t%s\t%d\t%s" % (p["number"], "-" if sz is None else sz[0], "-" if sz is None else sz[1],
                                            "-" if reason else "%.1f" % hr, cr, clean(p.get("title") or "")))
    print("since=%s until=%s report_date=%s" % (since, until, rdate))
    print("prs_merged=%d prs_truncated=%d" % (len(prs), 1 if raw_n == 1000 else 0))
    print("size_n=%d size_missing=%d lines_median=%s lines_p90=%s files_median=%s files_p90=%s over_limit=%d max_lines=%d max_files=%d"
          % (len(sl), miss, stat(sl, 5), stat(sl, 9), stat(sf, 5), stat(sf, 9), over, max_lines, max_files))
    hf = lambda v: "-" if v == "-" else "%.1f" % v
    print("cycle_n=%d cycle_missing=%d no_issue=%d not_fetched=%d no_claim=%d capped=%d cycle_median_hours=%s cycle_p90_hours=%s"
          % (len(hours), sum(why.values()), why["no_issue"], why["not_fetched"], why["no_claim"], why["capped"],
             hf(stat(hours, 5)), hf(stat(hours, 9))))
    print("review_sendbacks=%d queue_releases=%d issues_truncated=%d"
          % (sum(int(r.split("\t")[4]) for r in rows), qrel, 1 if len(issues) == 1000 else 0))
    print("bugs_open=%d critical=%d high=%d medium=%d low=%d none=%d bugs_truncated=%d"
          % (len(bugs), *sev.values(), 1 if len(bugs) == 1000 else 0))
    print("queue_depth=%d in_flight=%d queue_truncated=%d" % (len(queue) - infl, infl, 1 if len(queue) == 1000 else 0))
    print("capped_items=%d" % capped)
    for r in rows: print(r)
' "$@"; }

init="$(py init "$since")" || exit 1
{ read -r since; read -r search_date; read -r until; read -r report_date; } <<<"$init"
ghq pr list --state merged --search "merged:>=$search_date" --limit 1000 \
  --json number,title,mergedAt,changedFiles,files,reviews,closingIssuesReferences >"$tmp/prs" || die "gh pr list failed"
py paths "$tmp/prs" "$since" "$tmp/paths" || exit 1
"$here/pr-size.sh" --excluded-index "$tmp/paths" >"$tmp/idx" || die "pr-size.sh failed"
ghq repo view --json nameWithOwner >"$tmp/repo" || die "gh repo view failed"
ghq issue list --label ai --state all --search "updated:>=$search_date" --limit 1000 --json number,comments >"$tmp/issues" || die "gh issue list failed"
ghq issue list --label bug --state open --limit 1000 --json number,labels >"$tmp/bugs" || die "gh issue list (bugs) failed"
ghq issue list --label ai --state open --limit 1000 --json number,labels >"$tmp/queue" || die "gh issue list (queue) failed"
py report "$tmp/prs" "$since" "$until" "$report_date" "$tmp/idx" "$tmp/repo" "$tmp/issues" "$tmp/bugs" "$tmp/queue" || exit 1
