#!/usr/bin/env bash
# The only devkit script that writes team setup to GitHub and removes local worktrees. One action per call; run only after the user said yes.
# Usage: team-fix.sh <labels|prune|remove-worktree|ruleset> [args]
#   labels  create the queue labels that team-status.sh --missing-labels reports (never --force, never touches existing labels)
#   prune   git worktree prune -v; prints "result=done pruned=N"
#   remove-worktree <path> <ignored count>  remove one worktree that worktree-status.sh reports as merged now, with the ignored
#     count the user was shown: git worktree remove -- <path>, never --force, never deletes the branch
#     result=removed path=<p> branch_kept=<b>, or result=refused
#     reason=unsafe_path|missing_count|not_a_worktree|current|<state of the row, e.g. kept>|ignored_changed
#   ruleset [--admin-bypass] [--dry-run]  create or extend devkit's own ruleset ("devkit: protect default branch", source_type
#     Repository) for ~DEFAULT_BRANCH with pull_request (0 approvals) and non_fast_forward; ADMIN only. Never edits foreign or
#     organization rulesets. PUT bodies keep existing rules, parameters, and bypass actors, and only add what is missing; a GET
#     that is not the listed id, source_type Repository, and our name with rules/bypass_actors lists, a conditions object and a known
#     enforcement gives result=failed and no PUT. The list reads one page of 100 (failed at 100 or more). others= names are
#     percent-encoded (controls, space, DEL, =, ",", %), cut after whole names to 200 bytes with ",…". detail= is last and may contain spaces.
#     action=ruleset result=<r> rules_added=<csv>|- bypass=none|verified|unverified others=<names>|- [detail=<rest of the line>]
#     r = created|updated|unchanged|disabled|ambiguous|existed|conflict|bypass_rejected|failed, or would_create|would_update
#     with --dry-run (GETs only); result=refused reason=not_admin before any gh api call.
#     --admin-bypass adds the Admin role {"actor_id":5,"actor_type":"RepositoryRole","bypass_mode":"always"} when no actor_id 5
#     RepositoryRole entry exists. Admin role actor_id 5: unverified in GitHub docs (2026-10-20); the read-back decides
#     (bypass=verified when current_user_can_bypass is "always"). Without a write, bypass reports the existing ruleset's value
#     when the request is already satisfied, else unverified.
#     conflict = the rule types read back after a write differ from the ones sent (compared by type, since GitHub may add
#     default parameters); no retry. On a failed write, detail comes from the error body gh prints on stdout (message and
#     errors[] as message or "field: code"; seen live on a 404 GET with gh 2.102, not yet on a 422), else from stderr. bypass_rejected =
#     HTTP 422 after this run added the Admin actor, with "bypass" or "actor" in the raw body or stderr; any other 422 is failed.
# Output: lines starting "action=<a> result=<r>"; labels adds one "label=<name> result=created|failed [detail=<one line>]" line per label.
#   labels: result=started before the label lines; result=none_missing when nothing is missing; result=failed detail=... when the missing list cannot be read.
# Exit: 0 for every reported outcome, 1 when git or python3 is missing (gh too for labels and ruleset), the action is unknown,
#   or the arguments are unknown.

need() { local c; for c in "$@"; do command -v "$c" >/dev/null 2>&1 || { echo "team-fix: $c required" >&2; exit 1; }; done; }
need python3 git
# Plain output only: no colour or forced-TTY formatting.
ghq() { ( unset CLICOLOR_FORCE GH_FORCE_TTY; NO_COLOR=1 gh "$@" ); }
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# The first line of $1, without control characters, at most 200 chars.
oneline() { printf '%s\n' "$1" | head -n 1 | tr -d '\n' | tr '\r\t' '  ' | tr -d '\000-\010\013\014\016-\037\177' | head -c 200; }

do_labels() {
  local rows rc name color desc err detail t; t="$(printf '\t')"
  err="$(mktemp 2>/dev/null)" || { echo "action=labels result=failed detail=mktemp failed"; return 0; }
  rows="$(bash "$here/team-status.sh" --missing-labels 2>"$err")"; rc=$?; detail="$(oneline "$(cat "$err")")"; rm -f "$err"
  if [ "$rc" -ne 0 ]; then echo "action=labels result=failed detail=$detail"; return 0; fi
  if [ -z "$rows" ]; then echo "action=labels result=none_missing"; return 0; fi
  echo "action=labels result=started"
  while IFS="$t" read -r name color desc; do
    [ -n "$name" ] || continue
    case "$color" in [0-9a-fA-F][0-9a-fA-F][0-9a-fA-F][0-9a-fA-F][0-9a-fA-F][0-9a-fA-F]) ;; *) desc="" ;; esac
    case "$desc" in ""|*"$t"*) echo "label=$name result=failed detail=bad row"; continue ;; esac
    if err="$(ghq label create "$name" --color "$color" --description "$desc" 2>&1 >/dev/null)"; then
      echo "label=$name result=created"
    else
      echo "label=$name result=failed detail=$(oneline "$err")"
    fi
  done <<EOT
$rows
EOT
  return 0
}

do_prune() {
  local out n; out="$(LC_ALL=C git worktree prune -v 2>&1)" || { echo "action=prune result=failed detail=$(oneline "$out")"; return 0; }
  n="$(printf '%s\n' "$out" | awk '/^Removing/ { n++ } END { print n + 0 }')"
  echo "action=prune result=done pruned=$n"
}

do_remove() {
  local p="${1:-}" want="${2:-}" row st br cnt t; t="$(printf '\t')"
  case "$p" in ""|*[[:cntrl:]]*) echo "action=remove-worktree result=refused reason=unsafe_path"; return 0 ;; esac
  case "$want" in ""|*[!0-9]*|???????*) echo "action=remove-worktree result=refused reason=missing_count"; return 0 ;; esac
  p="$(python3 -I -c 'import os,sys; print(os.path.realpath(sys.argv[1]))' "$p")"
  row="$(bash "$here/worktree-status.sh" 2>/dev/null | P="$p" awk -F "$t" '$5 == ENVIRON["P"] && $1 != "prune_preview" { print $1 "\t" $2 "\t" $3; exit }')"
  [ -n "$row" ] || { echo "action=remove-worktree result=refused reason=not_a_worktree"; return 0; }
  [ "$p" != "$(python3 -I -c 'import os,sys; print(os.path.realpath(sys.argv[1]))' "$(git rev-parse --show-toplevel 2>/dev/null)")" ] \
    || { echo "action=remove-worktree result=refused reason=current"; return 0; }
  st="${row%%"$t"*}"; br="${row#*"$t"}"; cnt="${br#*"$t"}"; br="${br%%"$t"*}"
  [ "$st" = merged ] || { echo "action=remove-worktree result=refused reason=$st"; return 0; }
  want="${want#"${want%%[!0]*}"}"; [ "$cnt" = "${want:-0}" ] || { echo "action=remove-worktree result=refused reason=ignored_changed"; return 0; }
  if out="$(git worktree remove -- "$p" 2>&1)"; then echo "action=remove-worktree result=removed path=$p branch_kept=$br"
  else echo "action=remove-worktree result=failed detail=$(oneline "$out")"; fi
}

# Ruleset JSON helper; any bad JSON exits 1 with a short reason on stderr. Modes: list (stdin list -> "<own ids csv|->\t<other
# names, percent-encoded, |->"), merge <new|existing> <listed id|-> <bypass 0|1> <body file> (stdin detail; new ignores it ->
# "<disabled|unchanged|change>\t<added csv|->\t<current_user_can_bypass>\t<added_actor 0|1>"), id (stdin -> id), check <sent body> (stdin read-back
# -> "<ok|conflict>\t<current_user_can_bypass>"), err (stdin error body -> "<message>: <errors>", whitespace collapsed).
RSPY='import json,sys; sys.stdout.reconfigure(encoding="utf-8")
N="devkit: protect default branch"; enc=lambda s: "".join("%%%02X"%ord(c) if c<=" " or c in "=,%\x7f" else c for c in s)
w=lambda x: " ".join(str(x).split())
def main(m, a):
    d=json.load(sys.stdin)
    if m=="err":
        es=[e if not isinstance(e,dict) else e.get("message") or ": ".join(str(e[k]) for k in ("field","code") if e.get(k)) for e in d.get("errors") or []]
        print(": ".join(x for x in (w(d.get("message") or ""), "; ".join(w(e) for e in es if e)) if x)); return
    if m=="list":
        if not isinstance(d,list) or not all(isinstance(r,dict) for r in d): sys.exit("ruleset list is not a list")
        if len(d)>=100: sys.exit("100 or more rulesets; only one page is read")
        own=lambda r: r.get("source_type")=="Repository" and r.get("name")==N
        o=[enc(str(r.get("name"))) for r in d if not own(r)]; k=len(o)
        while k and len(",".join(o[:k]+(["…"] if k<len(o) else [])).encode())>200: k-=1
        print(",".join(str(int(r["id"])) for r in d if own(r)) or "-", ",".join(o[:k]+(["…"] if k<len(o) else [])) or "-", sep="\t"); return
    if m=="id": print(int(d["id"])); return
    if m=="check":
        if not isinstance(d.get("rules"),list): sys.exit("read-back has no rules list")
        t=lambda x: sorted(str(r.get("type")) for r in x.get("rules") or [])
        print("ok" if t(d)==t(json.load(open(a[0]))) else "conflict", d.get("current_user_can_bypass") or "-", sep="\t"); return
    if a[0]=="new": d={}
    elif not (isinstance(d.get("id"),int) and str(d["id"])==a[1] and d.get("source_type")=="Repository" and d.get("name")==N
              and isinstance(d.get("rules"),list) and isinstance(d.get("bypass_actors"),list) and isinstance(d.get("conditions"),dict)
              and d.get("enforcement") in ("active","disabled","evaluate")):
        sys.exit("ruleset read is not devkit'"'"'s own or lacks rules, bypass_actors, conditions or enforcement")
    if d.get("enforcement") in ("disabled","evaluate"): print("disabled", "-", "-", 0, sep="\t"); return
    b={"name":N,"target":"branch","enforcement":"active","bypass_actors":[],"conditions":{"ref_name":{"include":["~DEFAULT_BRANCH"],"exclude":[]}},"rules":[]}
    b.update((k,d[k]) for k in b if d.get(k) is not None)
    pr={k:False for k in ("dismiss_stale_reviews_on_push","require_code_owner_review","require_last_push_approval","required_review_thread_resolution")}
    pr["required_approving_review_count"]=0
    add=[r for r in ({"type":"pull_request","parameters":pr},{"type":"non_fast_forward"}) if r["type"] not in {x.get("type") for x in b["rules"]}]
    adm=a[2]=="1" and not any(x.get("actor_id")==5 and x.get("actor_type")=="RepositoryRole" for x in b["bypass_actors"])
    b["rules"]=b["rules"]+add; b["bypass_actors"]=b["bypass_actors"]+([{"actor_id":5,"actor_type":"RepositoryRole","bypass_mode":"always"}] if adm else [])
    json.dump(b, open(a[3], "w"))
    print("change" if add or adm else "unchanged", ",".join(r["type"] for r in add) or "-", d.get("current_user_can_bypass") or "-", int(adm), sep="\t")
try: main(sys.argv[1], sys.argv[2:])
except Exception as x: sys.exit("bad ruleset JSON (%s)" % type(x).__name__)'
rspy() { python3 -I -c "$RSPY" "$@"; }

do_ruleset() {
  local by=0 dry=0 a tmp rc; for a in "$@"; do case "$a" in --admin-bypass) by=1 ;; --dry-run) dry=1 ;; *) echo "team-fix: usage: team-fix.sh ruleset [--admin-bypass] [--dry-run]" >&2; return 1 ;; esac; done
  tmp="$(mktemp -d 2>/dev/null)" || { echo "action=ruleset result=failed detail=mktemp failed"; return 0; }
  rs_run; rc=$?; rm -rf "$tmp"; return "$rc"
}

rs_run() {
  local L='repos/{owner}/{repo}/rulesets?includes_parents=true&targets=branch&per_page=100' R='repos/{owner}/{repo}/rulesets'
  local out ids others st added can adm id m p e rej mode=new bp=none t; t="$(printf '\t')"; [ "$by" = 1 ] && bp=unverified
  say() { echo "action=ruleset result=$1 rules_added=${added:--} bypass=$bp others=$others${2:+ detail=$2}"; }
  fail() { echo "action=ruleset result=failed detail=$(oneline "$(cat "$tmp/err")")"; }
  out="$(ghq repo view --json viewerPermission 2>"$tmp/err")" || { fail; return 0; }
  [ "$(printf '%s' "$out" | python3 -I -c 'import json,sys; print(json.load(sys.stdin).get("viewerPermission"))' 2>/dev/null)" = ADMIN ] \
    || { echo "action=ruleset result=refused reason=not_admin"; return 0; }
  out="$(ghq api "$L" 2>"$tmp/err")" || { fail; return 0; }
  out="$(printf '%s' "$out" | rspy list 2>"$tmp/err")" || { fail; return 0; }
  ids="${out%%"$t"*}"; others="${out#*"$t"}"
  case "$ids" in *,*) say ambiguous; return 0 ;; -) out='{}'; m=POST; p="$R" ;;
    *) out="$(ghq api "$R/$ids" 2>"$tmp/err")" || { fail; return 0; }; m=PUT; p="$R/$ids"; mode=existing ;; esac
  out="$(printf '%s' "$out" | rspy merge "$mode" "$ids" "$by" "$tmp/body.json" 2>"$tmp/err")" || { fail; return 0; }
  IFS="$t" read -r st added can adm <<EOT
$out
EOT
  [ "$st" = disabled ] && { say disabled; return 0; }
  [ "$st" = unchanged ] && { [ "$by" = 1 ] && [ "$can" = always ] && bp=verified; say unchanged; return 0; }
  [ "$dry" = 1 ] && { if [ "$m" = POST ]; then say would_create; else say would_update; fi; return 0; }
  if ! out="$(ghq api -X "$m" "$p" --input "$tmp/body.json" 2>"$tmp/err")"; then
    e="$(printf '%s' "$out" | rspy err 2>/dev/null)"; e="$(oneline "${e:-$(cat "$tmp/err")}")"; rej=0
    [ "$adm" = 1 ] && { printf '%s' "$out"; cat "$tmp/err"; } | grep -qiE 'bypass|actor' && rej=1
    grep -q 'HTTP 422' "$tmp/err" || { say failed "$e"; return 0; }
    if [ "$m" = POST ]; then
      out="$(ghq api "$L" 2>/dev/null | rspy list 2>/dev/null)"; [ "${out%%"$t"*}" != - ] && [ -n "$out" ] && { say existed; return 0; }
    fi
    if [ "$rej" = 1 ]; then say bypass_rejected "$e"; else say failed "$e"; fi; return 0
  fi
  if [ "$m" = POST ]; then id="$(printf '%s' "$out" | rspy id 2>/dev/null)"; else id="$ids"; fi; st=created; [ "$m" = PUT ] && st=updated
  case "$id" in ""|*[!0-9]*) say "$st" "no ruleset id to read back"; return 0 ;; esac
  out="$(ghq api "$R/$id" 2>"$tmp/err")" && out="$(printf '%s' "$out" | rspy check "$tmp/body.json" 2>"$tmp/err")" \
    || { say "$st" "read-back failed: $(oneline "$(cat "$tmp/err")")"; return 0; }
  [ "$by" = 1 ] && { bp=unverified; [ "${out#*"$t"}" = always ] && bp=verified; }
  [ "${out%%"$t"*}" = conflict ] && st=conflict; say "$st"
}

action="${1:-}"
case "$action" in
  labels) need gh; do_labels ;;
  prune) do_prune ;;
  remove-worktree) do_remove "${2:-}" "${3:-}" ;;
  ruleset) need gh; shift; do_ruleset "$@" || exit 1 ;;
  *) echo "team-fix: usage: team-fix.sh <labels|prune|remove-worktree|ruleset>" >&2; exit 1 ;;
esac
