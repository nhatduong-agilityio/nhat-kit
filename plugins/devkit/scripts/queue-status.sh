#!/usr/bin/env bash
# Report the shared task queue state: open-PR pressure and stale claims.
# Usage: queue-status.sh
# Limits come from docs/devkit.md at the repo root (claim_ttl_minutes, max_open_prs); defaults apply when missing.
# Output: "open_prs=N max_open_prs=M pressure=ok|over|off ttl_minutes=T stale=K review=#A,#B,#C|-", then one
# "#N<TAB>host<TAB>age_minutes<TAB>title" row per stale issue. Never prints comment bodies.
# Exit: 0 ok, 1 when gh or python3 fails.
d_ttl=120; d_max=5

command -v python3 >/dev/null 2>&1 || { echo "queue-status: python3 required" >&2; exit 1; }
command -v gh >/dev/null 2>&1 || { echo "queue-status: gh required" >&2; exit 1; }

top="$(git rev-parse --show-toplevel 2>/dev/null)" || top=""
cfg="$top/docs/devkit.md"
cfg_get() { # cfg_get <key>: value of the first "- key: value" line, trimmed; empty when missing
  [ -n "$top" ] && [ -f "$cfg" ] || return 0
  sed -n "s/^[[:space:]]*-[[:space:]]*$1:[[:space:]]*//p" "$cfg" | head -n 1 | tr -d '\r' | sed 's/[[:space:]]*$//'
}
cfg_int() { # cfg_int <key> <default> <min>: an integer >= min from the doc, else the default
  local v; v="$(cfg_get "$1")"
  case "$v" in ''|*[!0-9]*) echo "$2"; return ;; esac
  [ "${#v}" -le 9 ] && [ "$((10#$v))" -ge "$3" ] && echo "$((10#$v))" || echo "$2"
}
ttl="$(cfg_int claim_ttl_minutes "$d_ttl" 1)"
max="$(cfg_int max_open_prs "$d_max" 0)"

tmp="$(mktemp -d 2>/dev/null)" || { echo "queue-status: mktemp failed" >&2; exit 1; }
trap 'rm -rf "$tmp"' EXIT
# Plain output only: no colour or forced-TTY formatting in the JSON.
ghq() { ( unset CLICOLOR_FORCE GH_FORCE_TTY; NO_COLOR=1 gh "$@" ); }
ghq pr list --state open --limit 200 --json number,isDraft,body,headRefName >"$tmp/prs" 2>/dev/null \
  || { echo "queue-status: gh pr list failed" >&2; exit 1; }
ghq issue list --label ai --label in-progress --state open --limit 100 --json number,title,comments >"$tmp/issues" 2>/dev/null \
  || { echo "queue-status: gh issue list failed" >&2; exit 1; }

python3 -I -c '
import sys, json, re, datetime as dt
ttl, mx = int(sys.argv[1]), int(sys.argv[2])
try:
    with open(sys.argv[3]) as f: prs = json.load(f)
    with open(sys.argv[4]) as f: issues = json.load(f)
    assert isinstance(prs, list) and isinstance(issues, list)
except Exception:
    sys.stderr.write("queue-status: unexpected gh output\n"); sys.exit(1)
now = dt.datetime.now(dt.timezone.utc)
def parse(s):
    try:
        return dt.datetime.strptime(s, "%Y-%m-%dT%H:%M:%SZ").replace(tzinfo=dt.timezone.utc)
    except Exception:
        return None
def clean(s): return re.sub(r"[\x00-\x1f\x7f]", " ", s)
open_prs = 0; ref = set(); review = []
for p in prs:
    if not isinstance(p, dict): continue
    if not p.get("isDraft"):
        open_prs += 1
        if isinstance(p.get("number"), int): review.append(p["number"])
    for m in re.finditer(r"\b(?:close[sd]?|fix(?:e[sd])?|resolve[sd]?):?\s+#(\d+)\b", p.get("body") or "", re.I):
        ref.add(int(m.group(1)))
review = ",".join("#%d" % n for n in sorted(review)[:3]) or "-"
rows = []
for i in issues:
    try:
        n = i["number"]
        if n in ref: continue
        ev = []
        for c in i.get("comments") or []:
            b = c.get("body") or ""; t = parse(c.get("createdAt") or "")
            if t is None: continue
            first = b.split("\n", 1)[0]
            kind = 0 if b.startswith("\U0001F512 devkit claim") else 1 if b.startswith("\U0001F513 devkit release") else None
            if kind is None: continue
            m = re.search(r"host:\s*([^\s\u00b7]+)", first)
            # Sort key puts a release after a claim made in the same second.
            ev.append((t, kind, m.group(1) if m else "unknown"))
        if not ev or not any(e[1] == 0 for e in ev): continue
        ev.sort(key=lambda e: (e[0], e[1]))
        active = {}  # host -> claim time
        for t, kind, h in ev:
            if kind == 0: active[h] = t
            else: active.pop(h, None)
        if active:
            newest = max(active.values())
            age = int((now - newest).total_seconds() // 60)
            host = max(active.items(), key=lambda kv: kv[1])[0]  # owner = latest active claim (conventions); the loser of a race has released
        else:
            # All released but still labelled in-progress: the leftover label hides the issue.
            age = int((now - ev[-1][0]).total_seconds() // 60)
            host = "-"
        if age <= ttl: continue
        rows.append("#%d\t%s\t%d\t%s" % (n, clean(host), age, clean(i.get("title") or "")))
    except Exception:
        continue
pressure = "off" if mx == 0 else ("over" if open_prs >= mx else "ok")
print("open_prs=%d max_open_prs=%d pressure=%s ttl_minutes=%d stale=%d review=%s" % (open_prs, mx, pressure, ttl, len(rows), review))
for r in rows: print(r)
' "$ttl" "$max" "$tmp/prs" "$tmp/issues" || { echo "queue-status: python3 failed" >&2; exit 1; }
