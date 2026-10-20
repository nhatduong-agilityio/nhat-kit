#!/usr/bin/env bash
# Read-only report of the team setup on GitHub: gh login and scopes, repo permission, and the queue labels.
# Usage: team-status.sh [--missing-labels]
# Output: auth=<ok|none|error> login=<l|-> scopes=<csv|unknown|-> missing_scopes=<repo|-|unknown>
#         repo=<owner/name|unknown> visibility=<v|unknown> permission=<ADMIN|MAINTAIN|WRITE|TRIAGE|READ|unknown>
#         labels_missing=<csv|-|unknown>
# Host: GH_HOST or github.com; repo and labels follow the git remote (GHE checkouts: set GH_HOST).
# auth=none (no active entry) or auth=error (token state not success) makes the last two lines unknown. Empty scopes (fine-grained token) are unknown, never missing; only `repo` is required.
# --missing-labels prints one "name<TAB>color<TAB>description" row per missing queue label and nothing else.
# Exit: 0 ok, 1 when gh, git or python3 is missing, or gh output is unexpected, e.g. empty or no hosts key (also when --missing-labels cannot list labels).

die() { echo "team-status: $1" >&2; exit 1; }
for c in python3 gh git; do command -v "$c" >/dev/null 2>&1 || die "$c required"; done
# Plain output only: no colour or forced-TTY formatting in the JSON.
ghq() { ( unset CLICOLOR_FORCE GH_FORCE_TTY; NO_COLOR=1 gh "$@" ); }
case "${1:-}" in "") mode=status ;; --missing-labels) mode=missing ;; *) die "unknown argument" ;; esac
tmp="$(mktemp -d 2>/dev/null)" || die "mktemp failed"
trap 'rm -rf "$tmp"' EXIT

# The queue labels, in order: name<TAB>color<TAB>meaning. Only copy of this table in the kit;
# keep it in sync with conventions.md "GitHub issue queue".
printf '%s\t%s\t%s\n' \
  ai 5319e7 "In the AI work queue" \
  severity:critical b60205 "Impact: critical" \
  severity:high d93f0b "Impact: high" \
  severity:medium fbca04 "Impact: medium" \
  severity:low c2e0c6 "Impact: low" \
  in-progress 1d76db "Claimed by one machine" >"$tmp/table"

# py <auth|repo|labels|missing> <json file>: prints line 1, 2, 3, or the missing TSV rows.
# Exit 1 when the JSON is unreadable (repo prints unknown fields instead).
py() {
  python3 -I -c '
import sys, json, re, os
mode, path = sys.argv[1], sys.argv[2]
def clean(s): return re.sub(r"[\x00-\x1f\x7f\s]+", "", str(s))
try:
    raw = open(path).read()
    if mode == "auth": hosts = json.loads(raw)["hosts"]
    elif mode == "repo": d = json.loads(raw); assert isinstance(d, dict)
    else: have = {l["name"].lower() for l in json.loads(raw)}
except Exception:
    if mode != "repo": sys.exit(1)
    d = {}
if mode == "repo":
    print("repo=%s visibility=%s permission=%s" % tuple(clean(d.get(k) or "") or "unknown" for k in ("nameWithOwner", "visibility", "viewerPermission")))
elif mode == "auth":
    entries = hosts.get(os.environ.get("GH_HOST") or "github.com") if isinstance(hosts, dict) else None
    act = [e for e in (entries or []) if isinstance(e, dict) and e.get("active")]
    if not act: print("auth=none login=- scopes=- missing_scopes=-"); sys.exit(0)
    login = clean(act[0].get("login") or "") or "-"
    if act[0].get("state", "success") != "success": print("auth=error login=%s scopes=- missing_scopes=-" % login); sys.exit(0)
    sc = act[0].get("scopes") or ""; scopes = [clean(s) for s in (sc if isinstance(sc, list) else str(sc).split(",")) if clean(s)]
    if not scopes: print("auth=ok login=%s scopes=unknown missing_scopes=unknown" % login)
    else: print("auth=ok login=%s scopes=%s missing_scopes=%s" % (login, ",".join(scopes), "-" if "repo" in scopes else "repo"))
else:
    rows = [l for l in open(sys.argv[3]) if l.split("\t", 1)[0].lower() not in have]
    if mode == "missing": sys.stdout.write("".join(rows))
    else: print("labels_missing=" + (",".join(l.split("\t", 1)[0] for l in rows) or "-"))
' "$1" "$2" "$tmp/table"
}

if [ "$mode" = missing ]; then
  ghq label list --json name --limit 500 >"$tmp/labels" 2>/dev/null || die "cannot list labels"
  py missing "$tmp/labels" || die "unexpected gh output"
  exit 0
fi

# gh may exit non-zero when logged out but still prints JSON; judge by the content.
ghq auth status --json hosts >"$tmp/auth" 2>/dev/null
line1="$(py auth "$tmp/auth")" || die "unexpected gh output"
echo "$line1"
case "$line1" in
  "auth=none"*|"auth=error"*) printf '%s\n' "repo=unknown visibility=unknown permission=unknown" "labels_missing=unknown"; exit 0 ;;
esac
ghq repo view --json nameWithOwner,visibility,viewerPermission >"$tmp/repo" 2>/dev/null || : >"$tmp/repo"
py repo "$tmp/repo"
{ ghq label list --json name --limit 500 >"$tmp/labels" 2>/dev/null && py labels "$tmp/labels"; } || echo "labels_missing=unknown"
exit 0
