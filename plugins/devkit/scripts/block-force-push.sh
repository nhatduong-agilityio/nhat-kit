#!/usr/bin/env bash
# PreToolUse (Bash): block git pushes that rewrite remote history.
# exit 2 + stderr = block and tell Claude why. exit 0 = no objection.
# A guardrail, not a sandbox. Not inspected: quoted command strings (bash -c "...",
# eval), git aliases, scripts, and pushes started by other programs.
here="$(cd "$(dirname "$0")" && pwd)"
input="$(cat)"
cmd="$(printf '%s' "$input" | "$here/json-field.sh" tool_input.command)"

# Fast path: most Bash calls are not pushes.
case "$cmd" in
  *git*push*) ;;
  *) exit 0 ;;
esac
cmd="${cmd//$'\r'/}"
export LC_ALL=C   # byte-wise indexing: much faster on long lines

block() {
  echo "Blocked by devkit: '$1' rewrites remote history (force push or --mirror). If the user really wants it, they can run it themselves with: ! $1" >&2
  exit 2
}

# check_segment <word>...: block if the words of one simple command form a force push.
check_segment() {
  local -a w=("$@")
  local n=$# i=0 start t s
  # Skip env assignments, shell keywords, and wrapper commands with their options.
  while [ "$i" -lt "$n" ]; do
    case "${w[$i]}" in
      *=*|'{'|'!'|command|exec|nohup|then|do|else|if|elif|while|until) i=$((i + 1)) ;;
      env|nice|sudo|xargs|timeout|time)
        t="${w[$i]}"
        i=$((i + 1))
        while [ "$i" -lt "$n" ]; do
          case "${w[$i]}" in
            -u|-g|-n|-I|-L|-P|-k|-s) i=$((i + 2)) ;;   # options that take a value
            -*|*=*) i=$((i + 1)) ;;
            *) break ;;
          esac
        done
        if [ "$t" = timeout ]; then
          case "${w[$i]:-}" in [0-9]*) i=$((i + 1)) ;; esac
        fi
        ;;
      *) break ;;
    esac
  done
  [ "$i" -lt "$n" ] || return 0
  [ "${w[$i]##*/}" = git ] || return 0
  start=$i
  i=$((i + 1))

  # Skip git's global options (-C <dir>, -c <k=v>, --git-dir <dir>, --no-pager, ...).
  while [ "$i" -lt "$n" ]; do
    case "${w[$i]}" in
      -C|-c|--git-dir|--work-tree|--namespace|--config-env|--super-prefix) i=$((i + 2)) ;;
      -*) i=$((i + 1)) ;;
      *) break ;;
    esac
  done
  [ "${w[$i]:-}" = push ] || return 0
  i=$((i + 1))

  while [ "$i" -lt "$n" ]; do
    t="${w[$i]}"
    case "$t" in
      -o|--push-option|--repo|--receive-pack|--exec) i=$((i + 1)) ;;   # value follows
      --force*|--m|--mi*) block "${w[*]:$start}" ;;  # --force, -with-lease, -if-includes, --mirror, abbreviations
      --*) ;;
      -o*) ;;                                         # -o<value>
      -*)                                             # short-flag cluster; an o starts its value
        s="${t#-}"
        s="${s%%o*}"
        case "$s" in *f*) block "${w[*]:$start}" ;; esac
        ;;
      +*) block "${w[*]:$start}" ;;                   # forced refspec such as +main
    esac
    i=$((i + 1))
  done
  return 0
}

# Split the command into simple commands the way the shell would, at a coarse level.
# Quoted text and heredoc bodies are words, never commands, but command substitutions
# $( ) are parsed as commands even inside "...". A stack tracks open contexts:
#   D = "...", S = $( ), P = ( ) subshell, A = (( )) / $(( )) arithmetic.
words=()
word=''
inword=0
sq=''            # "'" inside '...', "\$" inside $'...' (neither nests anything)
ctx=''           # context stack, innermost last
saved_words=()   # outer command's words while inside the outermost $( )
saved_word=''
heredoc=''       # delimiter whose body we are skipping
heredoc_tabs=0
pending=''       # delimiter seen on the current line; its body starts on the next line
pending_tabs=0
cont=0           # 1 when the previous line ended with a backslash
drop_next=0      # 1 after a redirect operator: the next word is its target, not an argument

flush_word() {
  if [ "$inword" = 1 ]; then
    if [ "$drop_next" = 1 ]; then drop_next=0; else words+=("$word"); fi
  fi
  word=''
  inword=0
}
end_segment() {
  flush_word
  drop_next=0
  [ "${#words[@]}" -gt 0 ] && check_segment "${words[@]}"
  words=()
}
start_redirect() {   # drop an fd number written right before the operator (2>), then the target
  case "$word" in
    *[!0-9]*|'') flush_word ;;
    *) word=''; inword=0 ;;
  esac
  drop_next=1
}
enter_sub() {        # at $(: the substitution's commands form their own segments
  case "$ctx" in
    *S*) end_segment ;;
    *)
      saved_words=("${words[@]}")
      saved_word="$word"
      words=()
      word=''
      inword=0
      drop_next=0
      ;;
  esac
  ctx="${ctx}S"
}
leave_sub() {        # at the ) closing $(: its output becomes part of the outer word
  end_segment
  ctx="${ctx%?}"
  case "$ctx" in
    *S*) ;;
    *)
      words=("${saved_words[@]}")
      word="$saved_word"
      inword=1
      ;;
  esac
}

while IFS= read -r line || [ -n "$line" ]; do
  if [ -n "$heredoc" ]; then
    l="$line"
    [ "$heredoc_tabs" = 1 ] && l="${l#"${l%%[!	]*}"}"
    [ "$l" = "$heredoc" ] && heredoc=''
    continue
  fi

  # Fast path for lines that cannot matter: no git, nothing that changes parsing state.
  if [ -z "$sq" ] && [ -z "$ctx" ] && [ "$cont" = 0 ]; then
    case "$line" in
      *git*|*\'*|*\"*|*\\*|*\<*|*\(*|*\)*) ;;
      *) end_segment; continue ;;
    esac
    # Scanning is quadratic in line length; lines over 16 KB are not inspected.
    if [ "${#line}" -gt 16384 ]; then end_segment; continue; fi
  fi

  len=${#line}
  i=0
  cont=0
  while [ "$i" -lt "$len" ]; do
    c="${line:$i:1}"
    top="${ctx:${#ctx}-1}"
    if [ -n "$sq" ]; then
      if [ "$sq" = '$' ] && [ "$c" = '\' ]; then
        i=$((i + 1)); word+="${line:$i:1}"
      elif [ "$c" = "'" ]; then
        sq=''
      else
        word+="$c"
      fi
    elif [ "$top" = A ]; then
      case "$c" in
        '(') ctx="${ctx}A" ;;
        ')') ctx="${ctx%?}" ;;
      esac
    elif [ "$top" = D ]; then
      case "$c" in
        '"') ctx="${ctx%?}" ;;
        '\') i=$((i + 1)); word+="${line:$i:1}" ;;
        '$')
          if [ "${line:$((i + 1)):2}" = '((' ]; then ctx="${ctx}AA"; i=$((i + 2))
          elif [ "${line:$((i + 1)):1}" = '(' ]; then enter_sub; i=$((i + 1))
          else word+="$c"; fi
          ;;
        *) word+="$c" ;;
      esac
    else
      case "$c" in
        "'") sq="'"; inword=1 ;;
        '"') ctx="${ctx}D"; inword=1 ;;
        '$')
          if [ "${line:$((i + 1)):2}" = '((' ]; then ctx="${ctx}AA"; i=$((i + 2)); inword=1
          elif [ "${line:$((i + 1)):1}" = '(' ]; then enter_sub; i=$((i + 1))
          elif [ "${line:$((i + 1)):1}" = "'" ]; then sq='$'; i=$((i + 1)); inword=1
          else word+="$c"; inword=1; fi
          ;;
        '\')
          i=$((i + 1))
          if [ "$i" -ge "$len" ]; then cont=1; else word+="${line:$i:1}"; inword=1; fi
          ;;
        ' '|'	') flush_word ;;
        '(')
          end_segment
          if [ "${line:$((i + 1)):1}" = '(' ]; then ctx="${ctx}AA"; i=$((i + 1)); else ctx="${ctx}P"; fi
          ;;
        ')')
          if [ "$top" = S ]; then leave_sub
          else end_segment; [ "$top" = P ] && ctx="${ctx%?}"; fi
          ;;
        ';'|'&'|'|'|'`') end_segment ;;
        '#')
          if [ "$inword" = 0 ]; then break; fi          # comment runs to end of line
          word+="$c"
          ;;
        '>')
          start_redirect
          [ "${line:$((i + 1)):1}" = '&' ] && i=$((i + 1))   # 2>&1 is a redirect, not &
          ;;
        '<')
          start_redirect
          if [ "${line:$i:3}" = '<<<' ]; then
            i=$((i + 2))                                     # here-string: next word is its text
          elif [ "${line:$i:2}" = '<<' ]; then
            drop_next=0                                      # the delimiter is parsed here
            i=$((i + 2))
            pending_tabs=0
            if [ "${line:$i:1}" = '-' ]; then pending_tabs=1; i=$((i + 1)); fi
            while [ "${line:$i:1}" = ' ' ] || [ "${line:$i:1}" = '	' ]; do i=$((i + 1)); done
            pending=''
            while [ "$i" -lt "$len" ]; do
              c="${line:$i:1}"
              case "$c" in
                "'"|'"'|'\') ;;
                ' '|'	'|';'|'&'|'|'|'('|')'|'<'|'>') break ;;
                *) pending+="$c" ;;
              esac
              i=$((i + 1))
            done
            continue
          fi
          ;;
        *) word+="$c"; inword=1 ;;
      esac
    fi
    i=$((i + 1))
  done

  if [ -n "$pending" ]; then
    heredoc="$pending"
    heredoc_tabs=$pending_tabs
    pending=''
  fi
  top="${ctx:${#ctx}-1}"
  if [ -n "$sq" ] || [ "$top" = D ]; then
    word+=$'\n'                                          # quoted text spans lines
    continue
  fi
  [ "$cont" = 1 ] && continue                            # backslash-newline joins lines
  [ "$top" = A ] && continue
  end_segment
done <<< "$cmd"
end_segment

exit 0
