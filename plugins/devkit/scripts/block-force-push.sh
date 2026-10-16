#!/usr/bin/env bash
# PreToolUse (Bash): block git pushes that rewrite remote history.
# exit 2 + stderr = block and tell Claude why. exit 0 = no objection.
# A guardrail, not a sandbox. Not inspected: commands inside quotes (bash -c "...",
# "$(...)"), git aliases, scripts, and pushes started by other programs.
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
      *=*|'{'|'!'|time|command|exec|nohup|then|do|else|if|elif|while|until) i=$((i + 1)) ;;
      env|nice|sudo|xargs|timeout)
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
      --force*|--mirror) block "${w[*]:$start}" ;;   # --force, abbreviations, -with-lease, -if-includes
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

# Split the command into simple commands the way the shell would, at a coarse level:
# quotes and backslashes group text into one word, quoted text and heredoc bodies are
# never treated as commands, # starts a comment, and ; & | ( ) ` and newlines separate.
words=()
word=''
inword=0
quote=''
heredoc=''       # delimiter whose body we are skipping
heredoc_tabs=0
pending=''       # delimiter seen on the current line; its body starts on the next line
pending_tabs=0
cont=0          # 1 when the previous line ended with a backslash
drop_next=0     # 1 after a redirect operator: the next word is its target, not an argument

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

while IFS= read -r line || [ -n "$line" ]; do
  if [ -n "$heredoc" ]; then
    l="$line"
    [ "$heredoc_tabs" = 1 ] && l="${l#"${l%%[!	]*}"}"
    [ "$l" = "$heredoc" ] && heredoc=''
    continue
  fi

  # Fast path for lines that cannot matter: no git, nothing that changes quoting state.
  if [ -z "$quote" ] && [ "$cont" = 0 ]; then
    case "$line" in
      *git*|*\'*|*\"*|*\\*|*\<\<*) ;;
      *) end_segment; continue ;;
    esac
  fi

  len=${#line}
  i=0
  cont=0
  while [ "$i" -lt "$len" ]; do
    c="${line:$i:1}"
    if [ "$quote" = "'" ]; then
      if [ "$c" = "'" ]; then quote=''; else word+="$c"; fi
    elif [ "$quote" = '"' ]; then
      case "$c" in
        '"') quote='' ;;
        '\') i=$((i + 1)); word+="${line:$i:1}" ;;
        *) word+="$c" ;;
      esac
    else
      case "$c" in
        "'"|'"') quote="$c"; inword=1 ;;
        '\')
          i=$((i + 1))
          if [ "$i" -ge "$len" ]; then cont=1; else word+="${line:$i:1}"; inword=1; fi
          ;;
        ' '|'	') flush_word ;;
        ';'|'&'|'|'|'('|')'|'`') end_segment ;;
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
          if [ "${line:$i:2}" = '<<' ] && [ "${line:$i:3}" != '<<<' ]; then
            drop_next=0                                      # the delimiter is parsed below
            i=$((i + 2))
            pending_tabs=0
            if [ "${line:$i:1}" = '-' ]; then pending_tabs=1; i=$((i + 1)); fi
            while [ "${line:$i:1}" = ' ' ]; do i=$((i + 1)); done
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

  if [ -n "$quote" ]; then
    word+=$'\n'                                          # quoted text spans lines
    continue
  fi
  [ "$cont" = 1 ] && continue                            # backslash-newline joins lines
  end_segment
  if [ -n "$pending" ]; then
    heredoc="$pending"
    heredoc_tabs=$pending_tabs
    pending=''
  fi
done <<< "$cmd"
end_segment

exit 0
