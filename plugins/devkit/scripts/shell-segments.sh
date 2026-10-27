#!/usr/bin/env bash
# Shared shell tokenizer for devkit hooks. Source it; do not execute it.
#
#   . "$here/shell-segments.sh"
#   scan_segments "$cmd"
#
# scan_segments splits <cmd> into simple commands the way the shell would, at a coarse
# level, and calls check_segment <word>... once per command. The hook defines:
#   check_segment <word>...  inspect one command; declare every variable `local`, and
#                            print why and `exit 2` to block
#   line_relevant <line>     return 0 when a line may matter to the hook. A line that
#                            returns 1 and has no quote, backslash, < or paren is
#                            skipped without parsing. Lines over 16 KB are skipped.
# Library state and helpers are prefixed _seg_; a hook must not use that prefix.
# The caller should strip \r and set LC_ALL=C (byte-wise indexing is much faster).
#
# A guardrail, not a sandbox. Not inspected: quoted command strings (bash -c "...",
# eval), aliases, functions, scripts, variable expansion ($CMD), process substitution <( ).

# Quoted text and heredoc bodies are words, never commands, but command substitutions
# $( ) are parsed as commands even inside "...". A stack tracks open contexts:
#   D = "...", S = $( ), P = ( ) subshell, A = (( )) / $(( )) arithmetic.
# The state variables are declared local in scan_segments and shared with the helpers
# through bash dynamic scope.

_seg_flush_word() {
  if [ "$_seg_inword" = 1 ]; then
    if [ "$_seg_drop_next" = 1 ]; then _seg_drop_next=0; else _seg_words+=("$_seg_word"); fi
  fi
  _seg_word=''
  _seg_inword=0
}
_seg_end_segment() {
  _seg_flush_word
  _seg_drop_next=0
  [ "${#_seg_words[@]}" -gt 0 ] && check_segment "${_seg_words[@]}"
  _seg_words=()
}
_seg_start_redirect() {   # drop an fd number written right before the operator (2>), then the target
  case "$_seg_word" in
    *[!0-9]*|'') _seg_flush_word ;;
    *) _seg_word=''; _seg_inword=0 ;;
  esac
  _seg_drop_next=1
}
_seg_enter_sub() {        # at $(: the substitution's commands form their own segments
  case "$_seg_ctx" in
    *S*) _seg_end_segment ;;
    *)
      _seg_saved_words=("${_seg_words[@]}")
      _seg_saved_word="$_seg_word"
      _seg_words=()
      _seg_word=''
      _seg_inword=0
      _seg_drop_next=0
      ;;
  esac
  _seg_ctx="${_seg_ctx}S"
}
_seg_leave_sub() {        # at the ) closing $(: its output becomes part of the outer word
  _seg_end_segment
  _seg_ctx="${_seg_ctx%?}"
  case "$_seg_ctx" in
    *S*) ;;
    *)
      _seg_words=("${_seg_saved_words[@]}")
      _seg_word="$_seg_saved_word"
      _seg_inword=1
      ;;
  esac
}

scan_segments() { # scan_segments <command string>
  local _seg_words _seg_saved_words _seg_word='' _seg_saved_word='' _seg_inword=0
  local _seg_sq=''            # "'" inside '...', "\$" inside $'...' (neither nests anything)
  local _seg_ctx=''           # context stack, innermost last
  local _seg_heredoc=''       # delimiter whose body we are skipping
  local _seg_heredoc_tabs=0 _seg_pending='' _seg_pending_tabs=0
  local _seg_cont=0           # 1 when the previous line ended with a backslash
  local _seg_drop_next=0      # 1 after a redirect operator: the next word is its target
  local _seg_line _seg_l _seg_len _seg_i _seg_c _seg_top
  _seg_words=()
  _seg_saved_words=()

  while IFS= read -r _seg_line || [ -n "$_seg_line" ]; do
    if [ -n "$_seg_heredoc" ]; then
      _seg_l="$_seg_line"
      [ "$_seg_heredoc_tabs" = 1 ] && _seg_l="${_seg_l#"${_seg_l%%[!	]*}"}"
      [ "$_seg_l" = "$_seg_heredoc" ] && _seg_heredoc=''
      continue
    fi

    # Fast path for lines that cannot matter: not relevant to the hook, and nothing that
    # changes parsing state.
    if [ -z "$_seg_sq" ] && [ -z "$_seg_ctx" ] && [ "$_seg_cont" = 0 ]; then
      if ! line_relevant "$_seg_line"; then
        case "$_seg_line" in
          *\'*|*\"*|*\\*|*\<*|*\(*|*\)*) ;;
          *) _seg_end_segment; continue ;;
        esac
      fi
      # Scanning is quadratic in line length; lines over 16 KB are not inspected.
      if [ "${#_seg_line}" -gt 16384 ]; then _seg_end_segment; continue; fi
    fi

    _seg_len=${#_seg_line}
    _seg_i=0
    _seg_cont=0
    while [ "$_seg_i" -lt "$_seg_len" ]; do
      _seg_c="${_seg_line:$_seg_i:1}"
      _seg_top="${_seg_ctx:${#_seg_ctx}-1}"
      if [ -n "$_seg_sq" ]; then
        if [ "$_seg_sq" = '$' ] && [ "$_seg_c" = '\' ]; then
          _seg_i=$((_seg_i + 1)); _seg_word+="${_seg_line:$_seg_i:1}"
        elif [ "$_seg_c" = "'" ]; then
          _seg_sq=''
        else
          _seg_word+="$_seg_c"
        fi
      elif [ "$_seg_top" = A ]; then
        case "$_seg_c" in
          '(') _seg_ctx="${_seg_ctx}A" ;;
          ')') _seg_ctx="${_seg_ctx%?}" ;;
        esac
      elif [ "$_seg_top" = D ]; then
        case "$_seg_c" in
          '"') _seg_ctx="${_seg_ctx%?}" ;;
          '\') _seg_i=$((_seg_i + 1)); _seg_word+="${_seg_line:$_seg_i:1}" ;;
          '$')
            if [ "${_seg_line:$((_seg_i + 1)):2}" = '((' ]; then _seg_ctx="${_seg_ctx}AA"; _seg_i=$((_seg_i + 2))
            elif [ "${_seg_line:$((_seg_i + 1)):1}" = '(' ]; then _seg_enter_sub; _seg_i=$((_seg_i + 1))
            else _seg_word+="$_seg_c"; fi
            ;;
          *) _seg_word+="$_seg_c" ;;
        esac
      else
        case "$_seg_c" in
          "'") _seg_sq="'"; _seg_inword=1 ;;
          '"') _seg_ctx="${_seg_ctx}D"; _seg_inword=1 ;;
          '$')
            if [ "${_seg_line:$((_seg_i + 1)):2}" = '((' ]; then _seg_ctx="${_seg_ctx}AA"; _seg_i=$((_seg_i + 2)); _seg_inword=1
            elif [ "${_seg_line:$((_seg_i + 1)):1}" = '(' ]; then _seg_enter_sub; _seg_i=$((_seg_i + 1))
            elif [ "${_seg_line:$((_seg_i + 1)):1}" = "'" ]; then _seg_sq='$'; _seg_i=$((_seg_i + 1)); _seg_inword=1
            else _seg_word+="$_seg_c"; _seg_inword=1; fi
            ;;
          '\')
            _seg_i=$((_seg_i + 1))
            if [ "$_seg_i" -ge "$_seg_len" ]; then _seg_cont=1; else _seg_word+="${_seg_line:$_seg_i:1}"; _seg_inword=1; fi
            ;;
          ' '|'	') _seg_flush_word ;;
          '(')
            _seg_end_segment
            if [ "${_seg_line:$((_seg_i + 1)):1}" = '(' ]; then _seg_ctx="${_seg_ctx}AA"; _seg_i=$((_seg_i + 1)); else _seg_ctx="${_seg_ctx}P"; fi
            ;;
          ')')
            if [ "$_seg_top" = S ]; then _seg_leave_sub
            else _seg_end_segment; [ "$_seg_top" = P ] && _seg_ctx="${_seg_ctx%?}"; fi
            ;;
          ';'|'&'|'|'|'`') _seg_end_segment ;;
          '#')
            if [ "$_seg_inword" = 0 ]; then break; fi          # comment runs to end of line
            _seg_word+="$_seg_c"
            ;;
          '>')
            _seg_start_redirect
            [ "${_seg_line:$((_seg_i + 1)):1}" = '&' ] && _seg_i=$((_seg_i + 1))   # 2>&1 is a redirect, not &
            ;;
          '<')
            _seg_start_redirect
            if [ "${_seg_line:$_seg_i:3}" = '<<<' ]; then
              _seg_i=$((_seg_i + 2))                                     # here-string: next word is its text
            elif [ "${_seg_line:$_seg_i:2}" = '<<' ]; then
              _seg_drop_next=0                                      # the delimiter is parsed here
              _seg_i=$((_seg_i + 2))
              _seg_pending_tabs=0
              if [ "${_seg_line:$_seg_i:1}" = '-' ]; then _seg_pending_tabs=1; _seg_i=$((_seg_i + 1)); fi
              while [ "${_seg_line:$_seg_i:1}" = ' ' ] || [ "${_seg_line:$_seg_i:1}" = '	' ]; do _seg_i=$((_seg_i + 1)); done
              _seg_pending=''
              while [ "$_seg_i" -lt "$_seg_len" ]; do
                _seg_c="${_seg_line:$_seg_i:1}"
                case "$_seg_c" in
                  "'"|'"'|'\') ;;
                  ' '|'	'|';'|'&'|'|'|'('|')'|'<'|'>') break ;;
                  *) _seg_pending+="$_seg_c" ;;
                esac
                _seg_i=$((_seg_i + 1))
              done
              continue
            fi
            ;;
          *) _seg_word+="$_seg_c"; _seg_inword=1 ;;
        esac
      fi
      _seg_i=$((_seg_i + 1))
    done

    if [ -n "$_seg_pending" ]; then
      _seg_heredoc="$_seg_pending"
      _seg_heredoc_tabs=$_seg_pending_tabs
      _seg_pending=''
    fi
    _seg_top="${_seg_ctx:${#_seg_ctx}-1}"
    if [ -n "$_seg_sq" ] || [ "$_seg_top" = D ]; then
      _seg_word+=$'\n'                                          # quoted text spans lines
      continue
    fi
    [ "$_seg_cont" = 1 ] && continue                            # backslash-newline joins lines
    [ "$_seg_top" = A ] && continue
    _seg_end_segment
  done <<< "$1"
  _seg_end_segment
}
