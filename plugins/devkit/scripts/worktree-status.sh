#!/usr/bin/env bash
# Read-only: lists the extra git worktrees and whether each one is safe to remove. Never fetches, never writes.
# Usage: worktree-status.sh   (run inside the repository)
# Output: "worktrees=N prunable=N merged=N kept=N gh=ok|unavailable", then one row per extra worktree:
#   <prunable|merged|kept> TAB <branch|-> TAB <ignored count> TAB <up to 5 ignored names csv|-> TAB <path>
#   then "prune_preview TAB <line>" per line of `git worktree prune -n -v`.
#   merged = a merged PR's headRefOid equals the local tip, clean tree (untracked files counted whatever status.showUntrackedFiles
#   says; no skip-worktree or assume-unchanged entries), not locked, not detached, not the current worktree.
#   A nested git repository anywhere under an ignored path keeps the row kept: removal would delete its history.
# Exit: 0 for every report; 1 when git or python3 is missing or not in a git repository.

for c in python3 git; do command -v "$c" >/dev/null 2>&1 || { echo "worktree-status: $c required" >&2; exit 1; }; done
git rev-parse --git-dir >/dev/null 2>&1 || { echo "worktree-status: not a git repository" >&2; exit 1; }
ghq() { ( unset CLICOLOR_FORCE GH_FORCE_TTY; NO_COLOR=1 gh "$@" ); }
rp() { python3 -I -c 'import os,sys; print(os.path.realpath(sys.argv[1]))' "$1"; }
clean() { local s="${1//[[:cntrl:]]/ }"; printf '%s' "$s"; }
# Clean = git commands succeed, nothing in status (untracked shown whatever the user's config), no skip-worktree or
# assume-unchanged entry (ls-files -v tag S or lower case).
tree_clean() {
  local s
  s="$(git -C "$1" -c status.showUntrackedFiles=all status --porcelain --untracked-files=all --ignore-submodules=none 2>/dev/null)" \
    && [ -z "$s" ] || return 1
  s="$(git -C "$1" ls-files -v 2>/dev/null)" || return 1
  case "$s" in [[:lower:]S]*|*$'\n'[[:lower:]S]*) return 1 ;; esac
}

cur="$(rp "$(git rev-parse --show-toplevel 2>/dev/null || pwd)")"
gh=ok; command -v gh >/dev/null 2>&1 || gh=unavailable
n=0; np=0; nm=0; nk=0; rows=""; first=1; wt=""; head=""; br="-"; lock=""; prun=""

emit() { # one finished record in $wt $head $br $lock $prun
  [ -n "$wt" ] || return 0
  if [ "$first" = 1 ]; then first=0; return 0; fi # the first record is the main worktree
  local st=kept p="$wt" ctl cnt=0 names="-" ign line j nest=0 st2
  n=$((n + 1))
  ctl=0; case "$wt" in *[[:cntrl:]]*) ctl=1; p="$(clean "$wt")" ;; *) p="$(rp "$wt")" ;; esac
  if [ -n "$prun" ]; then st=prunable
  else
    ign="$(git -C "$wt" -c core.quotePath=false ls-files -o -i --exclude-standard --directory 2>/dev/null)"
    if [ -n "$ign" ]; then
      names=""
      while IFS= read -r line; do
        cnt=$((cnt + 1)); [ "$cnt" -le 5 ] && names="${names:+$names,}$(clean "$line")"
      done <<EOT
$ign
EOT
      # Without --directory git lists each nested repository as one entry ending in "/"; stop at the first one.
      # grep exit 1 (no "/" entry) with git succeeding is the only "no nested repo" answer; any failure keeps the row kept.
      nest=1
      git -C "$wt" -c core.quotePath=false ls-files -z -o -i --exclude-standard 2>/dev/null | LC_ALL=C grep -zqm1 '/$'
      st2=("${PIPESTATUS[@]}"); [ "${st2[0]}" = 0 ] && [ "${st2[1]}" = 1 ] && nest=0
    fi
    if [ "$nest" = 0 ] && [ "$gh" = ok ] && [ "$br" != "-" ] && [ -z "$lock" ] && [ "$p" != "$cur" ] && [ "$ctl" = 0 ] \
       && tree_clean "$wt"; then
      if j="$(ghq pr list --state merged --head "$br" --json headRefOid --limit 1 2>/dev/null)"; then
        j="${j// /}"; case "$j" in *'"headRefOid":"'"$head"'"'*) st=merged ;; esac
      else gh=unavailable; fi
    fi
  fi
  case "$st" in prunable) np=$((np + 1)) ;; merged) nm=$((nm + 1)) ;; *) nk=$((nk + 1)) ;; esac
  rows="$rows$st	$br	$cnt	$names	$p
"
}

while IFS= read -r -d '' f; do
  case "$f" in
    "worktree "*) wt="${f#worktree }"; head=""; br="-"; lock=""; prun="" ;;
    "HEAD "*) head="${f#HEAD }" ;;
    "branch refs/heads/"*) br="${f#branch refs/heads/}" ;;
    locked*) lock=1 ;;
    prunable*) prun=1 ;;
    "") emit; wt="" ;;
  esac
done < <(git worktree list --porcelain -z 2>/dev/null; printf '\0\0')

echo "worktrees=$n prunable=$np merged=$nm kept=$nk gh=$gh"
printf '%s' "$rows"
LC_ALL=C git worktree prune -n -v 2>&1 | while IFS= read -r line; do printf 'prune_preview\t%s\n' "$(clean "$line")"; done
exit 0
