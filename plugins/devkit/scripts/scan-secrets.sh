#!/usr/bin/env bash
# Usage: scan-secrets.sh <git root> [--check <rule> <path> | --sinks]
# Scan the tracked tree for secret patterns and sensitive files. Prints TSV rows:
#   severity<TAB>category<TAB>path:line<TAB>masked<TAB>rule
# --check prints only the number of matching lines of <rule> in tracked <path> (re-check a row).
#   Exit 0 = counted (0 means no match), 1 = bad usage, 2 = error or untracked path.
# --sinks prints path:line<TAB>sink-name for risky code sinks in paths the default scan does
#   not flag. It never prints line content.
# Never prints a matched value beyond its first 4 chars + ****. The scan and --sinks exit 0 (1 on bad usage).
# Rules are POSIX ERE (no \b, \s) with bracketed literals so this file holds no token prefixes.
set -u
root="${1:-}"
if [ -z "$root" ] || ! git -C "$root" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  echo "usage: scan-secrets.sh <git root> [--check <rule> <path> | --sinks]" >&2
  exit 1
fi
here="$(cd "$(dirname "$0")" && pwd)"
cd "$root" || exit 1
TAB=$'\t'
FS=$'\037'

fill() { # fill <char> <count>
  local s="" i=0
  while [ "$i" -lt "$2" ]; do s="$s$1"; i=$((i + 1)); done
  printf '%s' "$s"
}

# Sets name-specific globals: sev, fl (grep flags), re (pattern), pos (positive sample).
rule() {
  fl=""; sev=critical
  case "$1" in
    aws-key)        re='(AK[I]A|AS[I]A)[0-9A-Z]{16}'; pos="AK""IA$(fill A 16)" ;;
    github-token)   re='gh[pousr]_[A-Za-z0-9]{36,}'; pos="gh""p_$(fill a 36)" ;;
    private-key)    re='-----BEG[I]N ([A-Z]+ )*PRIVATE KEY-----'; pos="-----BEG""IN RSA PRIVATE KEY-----" ;;
    slack-token)    re='xo[x][abprs]-[A-Za-z0-9-]{10,}'; pos="xo""xb-1234567890" ;;
    stripe-live)    re='sk_li[v]e_[A-Za-z0-9]{20,}'; pos="sk_li""ve_$(fill a 20)" ;;
    google-api-key) re='AI[z]a[0-9A-Za-z_-]{35}'; pos="AI""za$(fill a 35)" ;;
    llm-key)        re='s[k]-[A-Za-z0-9_-]{32,}'; pos="s""k-$(fill a 32)" ;;
    generic)        re='(password|secret|api_?key|token)[[:space:]]*[:=]'; pos="PASS""WORD :"; fl="-i"; sev=medium ;;
  esac
}
rules="aws-key github-token private-key slack-token stripe-live google-api-key llm-key generic"


# Sets name-specific globals for sink rules: sre (pattern), spos (positive sample), sfl (grep flags).
sink() {
  sfl=""
  case "$1" in
    eval)            sre='(^|[^A-Za-z0-9_.])eval[[:space:]]*\('; spos='x = eval(y)' ;;
    exec)            sre='(^|[^A-Za-z0-9_.])exec[[:space:]]*\('; spos='exec(code)' ;;
    new-function)    sre='new[[:space:]]+Function[[:space:]]*\('; spos='new Function("a")' ;;
    sql-concat)      sre='(select[[:space:]].*[[:space:]]from|insert[[:space:]]+into|delete[[:space:]]+from|update[[:space:]].*[[:space:]]set)[[:space:]].*(\$\{|["'"'"'`][[:space:]]*\+)'
                     spos='q = "SELECT a FROM t WHERE id = " + id'; sfl="-i" ;;
    sql-interp)      sre='(select[[:space:]].*[[:space:]]from|insert[[:space:]]+into|delete[[:space:]]+from|update[[:space:]].*[[:space:]]set)[[:space:]].*\$\{'
                     spos='q = `SELECT a FROM t WHERE id = ${id}`'; sfl="-i" ;;
    dangerous-html)  sre='dangerouslySetInnerHTML'; spos='<div dangerouslySetInnerHTML={x} />' ;;
    inner-html)      sre='innerHTML[[:space:]]*=([^=]|$)'; spos='el.innerHTML = x' ;;
    shell-true)      sre='shell[[:space:]]*=[[:space:]]*True'; spos='run(c, shell=True)' ;;
    child-exec)      sre='(^|[^A-Za-z0-9_.]|child_process\.|cp\.)exec(Sync)?[[:space:]]*\([[:space:]]*[^"'"'"'[:space:])]'; spos='execSync(cmd)' ;;
    verify-false)    sre='verify[[:space:]]*=[[:space:]]*False'; spos='get(u, verify=False)' ;;
    tls-reject-off)  sre='rejectUnauthorized:[[:space:]]*false'; spos='{ rejectUnauthorized: false }' ;;
    tls-skip-verify) sre='InsecureSkipVerify:[[:space:]]*true'; spos='InsecureSkipVerify: true' ;;
  esac
}
sinks="eval exec new-function sql-concat sql-interp dangerous-html inner-html shell-true child-exec verify-false tls-reject-off tls-skip-verify"

if [ "${2:-}" = "--check" ]; then
  case "${3:-}" in
    ""|*[[:space:]]*) echo "bad rule name: '${3:-}'" >&2; exit 1 ;;
  esac
  case " $rules " in *" $3 "*) ;; *) echo "unknown rule: $3" >&2; exit 1 ;; esac
  [ -n "${4:-}" ] || { echo "usage: scan-secrets.sh <git root> --check <rule> <path>" >&2; exit 1; }
  if ! git ls-files --error-unmatch -- ":(literal)$4" >/dev/null 2>&1; then
    echo "not a tracked path: $4" >&2; exit 2
  fi
  rule "$3"
  cout="$(git grep -c -IE $fl -e "$re" -- ":(literal)$4" 2>/dev/null)"; rc=$?
  if [ "$rc" -ge 2 ]; then echo "git grep failed (exit $rc)" >&2; exit 2; fi
  if [ "$rc" -eq 1 ]; then echo 0; exit 0; fi
  printf '%s\n' "$cout" | awk -F: '{ n += $NF } END { print n + 0 }'
  exit 0
fi

# Paths with control characters (newline, tab, ...) cannot be reported safely: skip them everywhere.
ex=(); skipped=""
while IFS= read -r -d '' p; do
  case "$p" in
    *$'\n'*) ex[${#ex[@]}]=":(exclude,literal)$p"
             skipped="${skipped}info${TAB}tool error${TAB}-${TAB}-${TAB}path with newline skipped
" ;;
    *[[:cntrl:]]*) ex[${#ex[@]}]=":(exclude,literal)$p"
             skipped="${skipped}info${TAB}tool error${TAB}-${TAB}-${TAB}path with control character skipped
" ;;
  esac
done < <(git ls-files -z)

selftest() { # sets ok, bad, good, infos for the secret rules
  ok=0; bad=0; good=""; infos=""
  for r in $rules; do
    rule "$r"
    if printf '%s' "$pos" | grep -qE $fl -e "$re"; then
      ok=$((ok + 1)); good="$good $r"
    else
      bad=$((bad + 1)); infos="${infos}info${TAB}tool error${TAB}-${TAB}-${TAB}rule $r missed its self-test
"
    fi
  done
}

# Secret and sensitive-file rows (no header). Used by the default scan and to find paths to skip for sinks.
scan_rows() {
  [ -n "$infos" ] && printf '%s' "$infos"
  [ -n "$skipped" ] && printf '%s' "$skipped"

  # Tracked-tree secret rules: git grep -z -o, NUL -> US for awk, then mask to 4 chars + ****.
  for r in $good; do
    rule "$r"
    git grep -z -nIoE $fl -e "$re" -- . ${ex[@]+"${ex[@]}"} 2>/dev/null | tr '\0' '\037' |
      awk -F"$FS" -v sev="$sev" -v rule="$r" -v tab="$TAB" '
        NF >= 3 {
          s = sev
          if ($1 ~ /(^|\/)(test|tests|fixtures)\// || tolower($1) ~ /example/ || $1 ~ /\.sample$/) s = "low"
          print s tab "secret" tab $1 ":" $2 tab substr($3, 1, 4) "****" tab rule
        }'
  done

  # Sensitive tracked files: the protect-files hook is the oracle (exit 2 = sensitive).
  local sens_re='(^|/)\.env|\.(pem|key|p12|keystore)$|(^|/)id_(rsa|ed25519)$' p esc msg kind
  while IFS= read -r -d '' p; do
    [[ "$p" =~ $sens_re ]] || continue
    case "$p" in *[[:cntrl:]]*) continue ;; esac
    esc="$(printf '%s' "$PWD/$p" | sed 's/\\/\\\\/g; s/"/\\"/g')"
    msg="$(printf '{"tool_input":{"file_path":"%s"}}' "$esc" | "$here/protect-files.sh" 2>&1 >/dev/null)"
    if [ "$?" -eq 2 ]; then
      case "$msg" in
        *"environment file"*) kind="(environment file)" ;;
        *"key/certificate"*)  kind="(key/certificate)" ;;
        *)                    kind="(sensitive file)" ;;
      esac
      printf 'high\tsensitive-file\t%s\t%s\tprotect-files\n' "$p" "$kind"
    fi
  done < <(git ls-files -z)

  # Tracked root .env that is not ignored (the untracked case is covered by the loop below).
  if git ls-files --error-unmatch -- .env >/dev/null 2>&1 && ! git check-ignore -q --no-index .env 2>/dev/null; then
    printf 'medium\tsensitive-file\t.env\t(not ignored)\tenv-not-ignored\n'
  fi
  # Untracked, not ignored .env files anywhere (samples excluded).
  local env_re='(^|/)\.env(\.[^/]*)?$' sample_re='\.(example|sample|template)$'
  while IFS= read -r -d '' p; do
    [[ "$p" =~ $env_re ]] || continue
    [[ "$p" =~ $sample_re ]] && continue
    case "$p" in *[[:cntrl:]]*) continue ;; esac
    printf 'medium\tsensitive-file\t%s\t(not ignored)\tenv-not-ignored\n' "$p"
  done < <(git ls-files -o --exclude-standard -z)
}

selftest

if [ "${2:-}" = "--sinks" ]; then
  flagged="$(mktemp)"; trap 'rm -f "$flagged"' EXIT
  scan_rows | awk -F"$TAB" '$2 == "secret" { sub(/:[0-9]+$/, "", $3); print $3 } $2 == "sensitive-file" { print $3 }' >"$flagged"
  sok=0; sbad=0; sgood=""; sinfos=""
  for r in $sinks; do
    sink "$r"
    if printf '%s' "$spos" | grep -qE $sfl -e "$sre"; then
      sok=$((sok + 1)); sgood="$sgood $r"
    else
      sbad=$((sbad + 1)); sinfos="${sinfos}info${TAB}tool error${TAB}-${TAB}-${TAB}sink rule $r missed its self-test
"
    fi
  done
  echo "# sinks: $sok rules ok, $sbad failed"
  [ -n "$sinfos" ] && printf '%s' "$sinfos"
  nskip=0
  while IFS= read -r f; do git ls-files --error-unmatch -- ":(literal)$f" >/dev/null 2>&1 && nskip=$((nskip + 1)); done < <(sort -u "$flagged")
  [ "$nskip" -gt 0 ] && printf 'info\tsink scan\t-\t-\t%s flagged file(s) not searched for sinks\n' "$nskip"
  for r in $sgood; do
    sink "$r"
    git grep -z -nIE $sfl -e "$sre" -- . ${ex[@]+"${ex[@]}"} 2>/dev/null | tr '\0' '\037' |
      awk -F"$FS" -v name="$r" -v tab="$TAB" -v ff="$flagged" '
        BEGIN { while ((getline line < ff) > 0) skip[line] = 1 }
        NF >= 3 && !($1 in skip) { print $1 ":" $2 tab name }'
  done
  exit 0
fi

echo "# scanned: $ok rules ok, $bad failed"
scan_rows
exit 0
