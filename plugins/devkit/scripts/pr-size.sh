#!/usr/bin/env bash
# Measure the size of the current change against a base: lines added + deleted and files changed.
# Usage: pr-size.sh [base]        (base defaults to origin/HEAD, else main)
# Limits and exclude globs come from docs/devkit.md at the repo root; defaults apply when missing.
# Output: one summary line, then up to 5 "path<TAB>lines" rows. Never prints file contents.
# Exit: 0 ok, 3 over a limit, 1 usage / not a repo / bad base.
d_lines=300; d_files=10
d_excl='*.lock, package-lock.json, pnpm-lock.yaml, yarn.lock, go.sum, Cargo.lock, **/__snapshots__/**, *.snap, dist/**, build/**, *.min.*'
tab=$'\t'

[ "$#" -le 1 ] || { echo "usage: pr-size.sh [base]" >&2; exit 1; }
top="$(git rev-parse --show-toplevel 2>/dev/null)" || { echo "pr-size: not a git repository" >&2; exit 1; }
cd "$top" || exit 1
git rev-parse --verify -q 'HEAD^{commit}' >/dev/null 2>&1 || { echo "pr-size: no commits yet" >&2; exit 1; }

base="${1:-}"
if [ -z "$base" ]; then
  if git rev-parse --verify -q 'origin/HEAD^{commit}' >/dev/null 2>&1; then base=origin/HEAD; else base=main; fi
fi
git rev-parse --verify -q "$base^{commit}" >/dev/null 2>&1 || { echo "pr-size: unknown base '$base'" >&2; exit 1; }
mb="$(git merge-base "$base" HEAD 2>/dev/null)" || { echo "pr-size: no merge base with '$base'" >&2; exit 1; }

cfg="$top/docs/devkit.md"
cfg_get() { # cfg_get <key>: value of the first "- key: value" line, trimmed; empty when missing
  [ -f "$cfg" ] || return 0
  sed -n "s/^[[:space:]]*-[[:space:]]*$1:[[:space:]]*//p" "$cfg" | head -n 1 | tr -d '\r' | sed 's/[[:space:]]*$//'
}
cfg_int() { # cfg_int <key> <default>: a positive integer from the doc, else the default
  local v; v="$(cfg_get "$1")"
  case "$v" in ''|*[!0-9]*) echo "$2"; return ;; esac
  [ "${#v}" -le 9 ] && [ "$((10#$v))" -gt 0 ] && echo "$((10#$v))" || echo "$2"
}
max_lines="$(cfg_int pr_max_lines "$d_lines")"
max_files="$(cfg_int pr_max_files "$d_files")"
excl="$(cfg_get pr_size_exclude)"; [ -n "$excl" ] || excl="$d_excl"

pats=()
while IFS= read -r p; do
  p="${p#"${p%%[![:space:]]*}"}"; p="${p%"${p##*[![:space:]]}"}"
  [ -n "$p" ] && pats+=("$p")
done < <(printf '%s\n' "$excl" | tr ',' '\n')

# Matching rule: bash case patterns where * also matches "/". A pattern without "/" is also tried
# against the file name alone. A leading "**/" also matches zero directories.
excluded() { # excluded <path>
  local path="$1" name="${1##*/}" p q
  for p in ${pats[@]+"${pats[@]}"}; do
    case "$path" in $p) return 0 ;; esac
    case "$p" in
      */*) ;;
      *) case "$name" in $p) return 0 ;; esac ;;
    esac
    case "$p" in
      '**/'*) q="${p#\*\*/}"; case "$path" in $q) return 0 ;; esac ;;
    esac
  done
  return 1
}

lines=0; files=0; skipped=0; rows=""; partial=""
row() { # row <lines> <path>: one display row; control characters in the name become "?"
  local shown
  shown="$(printf '%s' "$2" | LC_ALL=C tr '[:cntrl:]' '?')"
  [ "$1" -gt 0 ] && rows="$rows$1$tab$shown"$'\n'
}
add() { # add <lines> <path>
  if excluded "$2"; then skipped=$((skipped + 1)); return; fi
  files=$((files + 1)); lines=$((lines + $1))
  row "$1" "$2"
}

tmp="$(mktemp)" || exit 1
trap 'rm -f "$tmp"' EXIT
git diff --numstat -z --no-renames "$mb" >"$tmp" 2>/dev/null || { echo "pr-size: git diff failed" >&2; exit 1; }
while IFS= read -r -d '' rec; do
  a="${rec%%$'\t'*}"; rest="${rec#*$'\t'}"; dl="${rest%%$'\t'*}"; path="${rest#*$'\t'}"
  case "$a$dl" in *-*) n=0 ;; *) n=$((a + dl)) ;; esac
  add "$n" "$path"
done <"$tmp"

# Untracked, not ignored files: drop excluded ones before reading anything, then count lines in
# one batch (grep -I gives binary files no output, so they count as files only). Above 500 files
# lines are not counted (status is already over on files); "partial=untracked" says so.
utrk=()
while IFS= read -r -d '' path; do
  [ -f "$path" ] || continue
  if excluded "$path"; then skipped=$((skipped + 1)); continue; fi
  utrk[${#utrk[@]}]="$path"
done < <(git ls-files -o --exclude-standard -z 2>/dev/null)
files=$((files + ${#utrk[@]}))
if [ "${#utrk[@]}" -gt 500 ]; then
  partial=" partial=untracked"
elif [ "${#utrk[@]}" -gt 0 ]; then
  : >"$tmp"
  for path in "${utrk[@]}"; do
    case "$path" in *$'\n'*) ;; *) printf '%s\0' "$path" >>"$tmp" ;; esac   # newline names: file only
  done
  while IFS= read -r l; do
    n="${l##*:}"; path="${l%:*}"
    case "$n" in ''|*[!0-9]*) continue ;; esac
    lines=$((lines + n)); row "$n" "$path"
  done < <(xargs -0 grep -cIH -- '' <"$tmp" 2>/dev/null)
fi

status=ok
{ [ "$lines" -gt "$max_lines" ] || [ "$files" -gt "$max_files" ]; } && status=over
echo "lines=$lines files=$files max_lines=$max_lines max_files=$max_files excluded=$skipped base=$base status=$status$partial"
if [ -n "$rows" ]; then
  printf '%s' "$rows" | sort -t "$tab" -k1,1nr | head -n 5 | sed "s/^\([0-9]*\)$tab\(.*\)$/\2$tab\1/"
fi
[ "$status" = ok ] && exit 0
exit 3
