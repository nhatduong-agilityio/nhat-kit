#!/usr/bin/env bash
IFS= read -r -d '' PROTECTED <<'__DEVKIT_PROTECTED_EOF__'
{{PROTECTED_BRANCHES}}
__DEVKIT_PROTECTED_EOF__
PROTECTED="${PROTECTED%$'\n'}"
# PreToolUse (Bash): block `git push` to a protected branch; exit 2 blocks, anything else exits 0.
# Placeholder: branch names separated by spaces or commas; bash `case` globs work (`main release/*`).
#   Unfilled, empty, or multi-line values disable the hook.
# Exit codes: 0 allow (including every error or unknown shape), 2 block with a reason on stderr.
# Checks: the push command in each segment split on ; & | newline (env/sudo prefixes, `git -C dir`,
#   `-c k=v`, redirections), `--all`/`--mirror`, each refspec destination, and for a bare push the
#   current branch and its upstream branch name (`branch.<name>.merge`, no fetch needed). Runs in the
#   tool call's `cwd` (else $CLAUDE_PROJECT_DIR); a `cd <dir>` segment moves later segments there.
# Does not inspect: quoted or escaped words, aliases, scripts that push (`npm run release`), or
#   push.default and remote mapping beyond the upstream branch name, wrapper options that take a value
#   (`sudo -u me`, `nice -n 5`), a `(` or `{` glued to a word (`(git push ...)`), or a redirect glued to a
#   refspec (`main>/dev/null`). Quoted multi-line arguments that contain a push line may be blocked. A guardrail, not a sandbox. The user can still
#   run `! git push ...` themselves.
case "$PROTECTED" in ""|"{{"*|*$'\n'*) exit 0 ;; esac
input="$(cat)"
case "$input" in *push*) ;; *) exit 0 ;; esac
# Two NUL-terminated fields: cwd, then command (the command may contain newlines).
{ IFS= read -r -d '' cwd; IFS= read -r -d '' cmd; } < <(printf '%s' "$input" | python3 -c '
import json,sys; d=json.load(sys.stdin); sys.stdout.write("%s\0%s\0" % (d.get("cwd") or "", d.get("tool_input",{}).get("command") or ""))' 2>/dev/null \
  || printf '%s' "$input" | node -e 'let s="";process.stdin.on("data",d=>s+=d).on("end",()=>{try{const j=JSON.parse(s);process.stdout.write((j.cwd||"")+"\0"+((j.tool_input||{}).command||"")+"\0")}catch{}})' 2>/dev/null)
case "$cmd" in *push*) ;; *) exit 0 ;; esac
{ [ -n "$cwd" ] && cd "$cwd" 2>/dev/null; } || cd "${CLAUDE_PROJECT_DIR:-$PWD}" 2>/dev/null || exit 0
wd="$PWD"

set -f
read -r -a pats <<<"${PROTECTED//,/ }"
[ "${#pats[@]}" -gt 0 ] || exit 0
deny() { # deny <what>: block with the reason on stderr
  echo "Blocked by devkit: $1 is protected (CLAUDE.md \"Remotes & never-push rules\"). Push a feature branch and open a PR; if the user wants this push, they run it themselves with ! git push …" >&2
  exit 2
}
block() { # block <branch>: deny when it matches a protected pattern
  local b="$1" p
  [ -n "$b" ] || return 0
  for p in "${pats[@]}"; do
    case "$b" in $p) deny "$b" ;; esac
  done
}
redir='^[0-9]*[<>]'; redir_alone='^[0-9]*(>>?|<)$'
check_segment() {
  local -a v w; local i=0 k=0 n dir=. cur dest r rd remote="" tags=0 refs=0 up t
  read -r -a v <<<"$1"
  while [ "$k" -lt "${#v[@]}" ]; do # drop redirections; a lone operator also takes the next word
    if [[ ${v[k]} =~ $redir ]]; then [[ ${v[k]} =~ $redir_alone ]] && k=$((k + 1))
    else w[${#w[@]}]="${v[k]}"; fi
    k=$((k + 1))
  done
  n=${#w[@]}
  if [ "${w[0]:-}" = cd ]; then # `cd <dir>` moves later segments; a missing dir keeps the current one
    t="${w[1]:-}"; t="${t/#\~/$HOME}"; [ -n "$t" ] || return 0
    case "$t" in /*) ;; *) t="$wd/$t" ;; esac
    [ -d "$t" ] && t="$(cd "$t" 2>/dev/null && pwd)" && wd="$t"
    return 0
  fi
  while [ "$i" -lt "$n" ]; do
    case "${w[i]}" in env|sudo|time|command|nice|nohup|-*|[A-Za-z_]*=*|'('|'{') i=$((i + 1)) ;; *) break ;; esac
  done
  case "${w[i]:-}" in git|*/git) i=$((i + 1)) ;; *) return 0 ;; esac
  while [ "$i" -lt "$n" ]; do
    case "${w[i]}" in
      -C) dir="${w[i+1]:-.}"; i=$((i + 2)) ;;
      -c|--git-dir|--work-tree|--namespace) i=$((i + 2)) ;;
      -*) i=$((i + 1)) ;;
      *) break ;;
    esac
  done
  [ "${w[i]:-}" = push ] || return 0
  cur="$(git -C "$wd" -C "$dir" rev-parse --abbrev-ref HEAD 2>/dev/null)"
  for ((i = i + 1; i < n; i++)); do
    case "${w[i]}" in
      --all|--mirror) deny "${pats[*]}" ;;
      --tags) tags=1 ;;
      --repo|-o|--push-option|--receive-pack|--exec) i=$((i + 1)) ;;
      -*) ;;
      *)
        if [ -z "$remote" ]; then remote="${w[i]}"; continue; fi
        refs=1; r="${w[i]#+}"; rd="${r##*:}"
        case "$rd" in refs/tags/*) continue ;; esac
        dest="${rd#refs/heads/}"
        case "$dest" in HEAD|@) dest="$cur" ;; esac
        block "$dest" ;;
    esac
  done
  if [ "$refs" -eq 0 ] && [ "$tags" -eq 0 ]; then
    [ "$cur" = HEAD ] || block "$cur"
    up="$(git -C "$wd" -C "$dir" config "branch.$cur.merge" 2>/dev/null)" && block "${up#refs/heads/}"
  fi
}
while IFS= read -r seg; do
  check_segment "$seg"
done < <(printf '%s\n' "$cmd" | tr -d '\r' | sed -E -e 's/[0-9]*>&([0-9]+|-)/ /g' -e 's/>&/>/g' -e 's/&>/>/g' | tr ';&|' '\n\n\n')
exit 0
