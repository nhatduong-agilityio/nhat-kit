#!/usr/bin/env bash
# Read-only report of what GitHub enforces on a branch: PR required and force pushes blocked.
# Usage: branch-protection.sh [branch]   (default: the repository's default branch)
# Output: one line "branch=<b> protected=<true|false> pr_required=<true|false|unknown> force_push_blocked=<true|false|unknown> source=<rules|classic|both|none>".
# "unknown" means the setting could not be read (classic protection without admin access, or a failed rules call).
# source names only what was actually read. Branch names with `#`, `%`, or `@{` are not URL-encoded; pass plain names.
# Exit: 0 ok, 1 when gh or python3 is missing, the branch name is invalid, or GitHub cannot report the branch.

command -v python3 >/dev/null 2>&1 || { echo "branch-protection: python3 required" >&2; exit 1; }
command -v gh >/dev/null 2>&1 || { echo "branch-protection: gh required" >&2; exit 1; }

# Plain output only: no colour or forced-TTY formatting in the JSON.
ghq() { ( unset CLICOLOR_FORCE GH_FORCE_TTY; NO_COLOR=1 gh "$@" ); }

branch="${1:-}"
if [ -z "$branch" ]; then
  branch="$(ghq repo view --json defaultBranchRef --jq .defaultBranchRef.name 2>/dev/null)" \
    && [ -n "$branch" ] || { echo "branch-protection: cannot read the default branch" >&2; exit 1; }
fi

if command -v git >/dev/null 2>&1 && ! git check-ref-format --branch "$branch" >/dev/null 2>&1; then
  echo "branch-protection: invalid branch name" >&2; exit 1
fi

tmp="$(mktemp -d 2>/dev/null)" || { echo "branch-protection: mktemp failed" >&2; exit 1; }
trap 'rm -rf "$tmp"' EXIT

ghq api "repos/{owner}/{repo}/branches/$branch" >"$tmp/branch" 2>/dev/null \
  || { echo "branch-protection: cannot read branch $branch" >&2; exit 1; }
# A failed rules call is not "no rules": rules_ok=0 makes unproven items unknown.
rules_ok=1
ghq api "repos/{owner}/{repo}/rules/branches/$branch?per_page=100" >"$tmp/rules" 2>/dev/null || { rules_ok=0; : >"$tmp/rules"; }

# Classic protection is read only when it is on, or when the shape hides it (non-admin) on a protected branch.
need="$(python3 -I -c '
import sys, json
try:
    with open(sys.argv[1]) as f: b = json.load(f)
    p = b.get("protection")
    print("1" if (isinstance(p, dict) and p.get("enabled")) or (not isinstance(p, dict) and b.get("protected")) else "0")
except Exception:
    sys.exit(1)
' "$tmp/branch")" || { echo "branch-protection: unexpected gh output" >&2; exit 1; }
if [ "$need" = 1 ]; then
  ghq api "repos/{owner}/{repo}/branches/$branch/protection" >"$tmp/classic" 2>/dev/null || : >"$tmp/classic"
else
  : >"$tmp/classic"
fi

python3 -I -c '
import sys, json, re
branch = re.sub(r"[\x00-\x1f\x7f]", " ", sys.argv[1])
def load(p):
    try:
        with open(p) as f: return json.load(f)
    except Exception:
        return None
b = load(sys.argv[2]); rules = load(sys.argv[3]); classic = load(sys.argv[4]); need = sys.argv[5] == "1"
rules_ok = sys.argv[6] == "1" and isinstance(rules, list)
if not isinstance(b, dict):
    sys.stderr.write("branch-protection: unexpected gh output\n"); sys.exit(1)
protected = bool(b.get("protected"))
types = set()
if isinstance(rules, list):
    types = {r.get("type") for r in rules if isinstance(r, dict)}
pr = "pull_request" in types
force = "non_fast_forward" in types
if not protected and not types and rules_ok:
    print("branch=%s protected=false pr_required=false force_push_blocked=false source=none" % branch); sys.exit(0)
readable = need and isinstance(classic, dict)
if readable:
    if "required_pull_request_reviews" in classic: pr = True
    af = classic.get("allow_force_pushes")
    if isinstance(af, dict) and af.get("enabled") is False: force = True
unknown = (need and not readable) or not rules_ok
pr_s = "true" if pr else ("unknown" if unknown else "false")
force_s = "true" if force else ("unknown" if unknown else "false")
has_rules = bool(types)
has_classic = readable
source = "both" if has_rules and has_classic else "rules" if has_rules else "classic" if has_classic else "none"
print("branch=%s protected=%s pr_required=%s force_push_blocked=%s source=%s" % (branch, "true" if protected else "false", pr_s, force_s, source))
' "$branch" "$tmp/branch" "$tmp/rules" "$tmp/classic" "$need" "$rules_ok" || exit 1
