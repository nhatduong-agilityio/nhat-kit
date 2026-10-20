#!/usr/bin/env bash
# Test the plugin hooks with sample JSON. Exits 0 when every case matches.
# Columns: RESULT (ok/FAIL), HOOK, CASE, EXP exit, GOT exit, MS elapsed, STDERR (first line, FAIL only).
set -u
root="$(cd "$(dirname "$0")/.." && pwd)"
guard="$root/plugins/devkit/scripts/protect-files.sh"
notify="$root/plugins/devkit/scripts/notify.sh"
scan="$root/plugins/devkit/scripts/scan-secrets.sh"
push="$root/plugins/devkit/scripts/block-force-push.sh"
fail=0

err="$(mktemp)"; tf="$(mktemp)"
trap 'rm -f "$err" "$tf"' EXIT
total=0; cases=0; nfail=0
printf '%-6s %-16s %-48s %3s %3s %6s %s\n' RESULT HOOK CASE EXP GOT MS STDERR

expect() { # expect <script> <expected exit> <name> <json>
  local got ms res hook name msg
  TIMEFORMAT=%3R
  { time printf '%s' "$4" | "$1" >/dev/null 2>"$err"; } 2>"$tf"
  got=$?
  ms="$(tr -cd '0-9' <"$tf")"; ms=$((10#${ms:-0}))
  hook="$(basename "$1" .sh)"
  name="${3//$'\r'/ / }"; name="${name//$'\n'/ / }"; name="${name//$'\t'/ / }"
  name="$(printf '%s' "$name" | LC_ALL=C tr -c ' -~' '?')"; name="${name:0:48}"
  res=ok; msg=""
  if [ "$got" -ne "$2" ]; then
    res=FAIL; fail=1; nfail=$((nfail + 1))
    msg="$(head -n 1 "$err" | LC_ALL=C tr -c ' -~' '?')"; msg="${msg:0:80}"
  fi
  cases=$((cases + 1)); total=$((total + ms))
  printf '%-6s %-16s %-48s %3s %3s %6s %s\n' "$res" "$hook" "$name" "$2" "$got" "$ms" "$msg"
}

bash_cmd() { # bash_cmd <expected exit> <command>: run block-force-push on a Bash tool call
  local json
  json="$(python3 -c 'import json,sys; print(json.dumps({"tool_input":{"command":sys.argv[1]}}))' "$2")"
  expect "$push" "$1" "push: $2" "$json"
}

expect "$guard" 2 ".env blocked"            '{"tool_input":{"file_path":"/r/.env"}}'
expect "$guard" 2 ".env.local blocked"      '{"tool_input":{"file_path":"/r/.env.local"}}'
expect "$guard" 0 ".env.example allowed"   '{"tool_input":{"file_path":"/r/.env.example"}}'
expect "$guard" 2 "pnpm-lock blocked"       '{"tool_input":{"file_path":"/r/pnpm-lock.yaml"}}'
expect "$guard" 2 "package-lock blocked"    '{"tool_input":{"file_path":"/r/package-lock.json"}}'
expect "$guard" 2 ".git/ blocked"           '{"tool_input":{"file_path":"/r/.git/config"}}'
expect "$guard" 2 "node_modules blocked"    '{"tool_input":{"file_path":"/r/node_modules/x/index.js"}}'
expect "$guard" 2 "key file blocked"       '{"tool_input":{"file_path":"/r/certs/server.pem"}}'
expect "$guard" 0 "source allowed"         '{"tool_input":{"file_path":"/r/src/App.tsx"}}'
expect "$guard" 0 "notebook allowed"       '{"tool_input":{"notebook_path":"/r/a.ipynb"}}'
expect "$guard" 0 "empty input allowed"     '{}'
expect "$guard" 0 "malformed JSON allowed"      'not json'

bash_cmd 2 'git push --force'
bash_cmd 2 'git push -f origin main'
bash_cmd 2 'git push -uf origin feat'
bash_cmd 2 'git push --force-with-lease'
bash_cmd 2 'git push --force-with-lease=main:abc123'
bash_cmd 2 'git push --force-if-includes origin feat'
bash_cmd 2 'git push origin +main'
bash_cmd 2 'git -C repo push -f'
bash_cmd 2 'git fetch && git push -f'
bash_cmd 2 'FOO=1 git push --force'
bash_cmd 2 '(cd repo && git push -f)'
bash_cmd 2 'git status
git push --force'
bash_cmd 2 $'git push --force\r'
bash_cmd 2 'git push --mirror'
bash_cmd 2 'git push --force-w'
bash_cmd 2 'git push "--force"'
bash_cmd 2 "git push origin '+main'"
bash_cmd 2 'env FOO=1 git push -f'
bash_cmd 2 'timeout 60 git push -f'
bash_cmd 2 'sudo -u bob git push -f'
bash_cmd 2 'if git push -f; then echo ok; fi'
bash_cmd 2 'git --git-dir /r/.git push -f'
bash_cmd 2 'git -C "my repo" push -f'
bash_cmd 2 'echo `git push -f`'
bash_cmd 2 'echo $(git push -f)'
bash_cmd 2 'git push -vf origin feat 2>&1 | tail -3'
bash_cmd 2 'cat <<EOF
text
EOF
git push -f'
bash_cmd 2 'git push origin \
  -f'
bash_cmd 2 'cat <<< "x"
git push -f'
bash_cmd 2 'grep a <<<"$out"
git push -f origin main'
bash_cmd 2 'gh pr create --title "x" --body "$(cat <<'"'"'EOF'"'"'
Handle 5" displays
EOF
)" && git push -f'
bash_cmd 2 'git commit -m "$(echo x)" && git push --force'
bash_cmd 2 'echo $'"'"'it\'"'"'s'"'"' && git push -f'
bash_cmd 2 'echo $((1 << 2))
git push -f'
bash_cmd 2 'git push --mirr'
bash_cmd 2 'time -p git push -f'
bash_cmd 2 'x=$(git push -f 2>&1)'
bash_cmd 2 '(cd repo; (git push -f))'
bash_cmd 0 'git push'
bash_cmd 0 'git commit -m "$(cat <<'"'"'EOF'"'"'
docs: support 12" screens

git push --force is blocked now
EOF
)"'
bash_cmd 0 'git commit -m "$(cat <<'"'"'EOF'"'"'
fix: don'"'"'t hide errors

Never run git push -f here.
EOF
)" && git push -u origin feat'
bash_cmd 0 "cat <<	EOF
git push -f
EOF"
bash_cmd 0 'n=$((1 << 2)); git push origin main'
bash_cmd 0 'git push "$(git remote | head -1)" "$(git branch --show-current)"'
bash_cmd 0 'git push origin \
  main'
bash_cmd 0 'git commit -m "feat: guard; git push --force is now blocked"'
bash_cmd 0 "git commit -F - <<'EOF'
feat: x

git push --force is now blocked
EOF"
bash_cmd 0 'gh pr create --body "$(cat <<'"'"'EOF'"'"'
  git push -f origin main
EOF
)"'
bash_cmd 0 'cat <<-EOF
	git push -f
	EOF
git status'
bash_cmd 0 'echo "done && git push -f"'
bash_cmd 0 'git push -otopic=feature origin feat'
bash_cmd 0 'git push -o ci.skip origin feat'
bash_cmd 0 'git push origin main # never use -f here'
bash_cmd 0 'git push origin main 2>&1 | tail -3'
bash_cmd 0 'git push origin main > push.log 2>&1'
bash_cmd 0 'git push origin main 2> /tmp/f.log'
bash_cmd 0 'cat <<< "git push -f"'
bash_cmd 0 'git push -u origin feat'
bash_cmd 0 'git push --follow-tags'
bash_cmd 0 'git push origin main'
bash_cmd 0 'git push --no-force-with-lease'
bash_cmd 0 'git commit -m "push -f later"'
bash_cmd 0 'echo git push -f'
bash_cmd 0 'git log --format=%f && git push'
bash_cmd 0 'ls -f'
bash_cmd 0 'npm run build'
bash_cmd 2 'gh pr merge --admin'
bash_cmd 2 'gh pr merge 13 --squash --admin'
bash_cmd 2 'gh -R o/r pr merge --admin'
bash_cmd 2 'gh pr merge --admin=true'
bash_cmd 2 'git status && gh pr merge --admin'
bash_cmd 2 'sudo gh pr merge --admin'
bash_cmd 2 'gh pr review --approve'
bash_cmd 2 'gh pr review 5 -a'
bash_cmd 2 'gh pr review -ab "lgtm"'
bash_cmd 2 'gh pr review --approve=true -b ok'
bash_cmd 2 '/usr/local/bin/gh pr review --approve'
bash_cmd 2 'x=$(gh pr merge --admin)'
bash_cmd 0 'gh pr merge 13 --squash'
bash_cmd 0 'gh pr review 5 -Rorg/app -c -b x'
bash_cmd 0 'gh pr merge -sb "--admin" 13'
bash_cmd 0 'gh pr merge --admin=False'
bash_cmd 0 'gh pr review --approve=0 -b x'
bash_cmd 2 'gh pr merge --admin -- 13'
bash_cmd 2 'gh pr merge -tb --admin'
bash_cmd 2 'gh pr review -bF --approve'
bash_cmd 0 'gh pr merge --admin=false'
bash_cmd 0 'gh pr review --comment -b "approve after CI"'
bash_cmd 0 'gh pr review -ba'
bash_cmd 0 'gh pr review -r -b "needs --admin? no"'
bash_cmd 0 'gh pr create --body "never use --admin"'
bash_cmd 0 'echo "gh pr merge --admin"'
bash_cmd 0 'gh pr view 13'
bash_cmd 0 'gh issue create --title approve'
bash_cmd 0 'gh pr merge --body "--admin" 13'
bash_cmd 0 'cat <<'"'"'EOF'"'"'
gh pr merge --admin
EOF'
expect "$push" 0 "push: empty input allowed"     '{}'
expect "$push" 0 "push: no command allowed"      '{"tool_input":{"file_path":"/r/a"}}'
expect "$push" 0 "push: malformed JSON allowed"  'not json'

# --- scan-secrets: fixture repo with runtime-built values (no literal tokens in this file) ---
row() { # row <hook> <name> <exp> <got> <ms> <stderr msg on FAIL>
  local res=ok msg=""
  if [ "$3" -ne "$4" ]; then res=FAIL; fail=1; nfail=$((nfail + 1)); msg="$6"; fi
  cases=$((cases + 1)); total=$((total + $5))
  printf '%-6s %-16s %-48s %3s %3s %6s %s\n' "$res" "$1" "${2:0:48}" "$3" "$4" "$5" "$msg"
}
rnd() { LC_ALL=C tr -dc "$1" </dev/urandom | head -c "$2"; } # rnd <charset> <length>
fx="$(mktemp -d)"; out="$(mktemp)"; out2="$(mktemp)"
trap 'rm -rf "$err" "$tf" "$fx" "$out" "$out2"' EXIT
T=$'\t'
m_aws="AK""IA****"; m_gh="gh""p_****"
v_aws="AK""IA$(rnd 'A-Z0-9' 16)"; v_aws2="AK""IA$(rnd 'A-Z0-9' 16)"
v_gh="gh""p_$(rnd 'A-Za-z0-9' 36)"; v_env="$(rnd 'A-Za-z0-9' 20)"
v_aws3="AK""IA$(rnd 'A-Z0-9' 16)"; v_aws4="AK""IA$(rnd 'A-Z0-9' 16)"; v_aws5="AK""IA$(rnd 'A-Z0-9' 16)"
mkdir -p "$fx/src" "$fx/test" "$fx/café" "$fx/my certs"
printf 'const k = "%s";\n' "$v_aws" >"$fx/src/config.js"
printf 'const t = "%s";\n' "$v_gh" >"$fx/test/fixture.js"
printf 'const k = "%s";\n' "$v_aws2" >"$fx/src/a:b.js"
printf '%s\n' "-----BEG""IN RSA PRIVATE KEY-----" >"$fx/src/pk.txt"
printf 'const apiKey = load();\n' >"$fx/src/app.js"
printf 'const x = 1;\n' >"$fx/src/clean.js"
printf 'DB_PASS=%s\n' "$v_env" >"$fx/.env"
printf 'DB_PASS=changeme\n' >"$fx/.env.example"
printf 'const k = "%s";\n' "$v_aws3" >"$fx/:lit.js"
printf 'x\n' >"$fx/café/id_rsa"
printf 'x\n' >"$fx/my certs/server file.pem"
printf 'run(eval(input));\n' >"$fx/src/sink.js"
printf 'eval(x); const k = "%s";\n' "$v_aws4" >"$fx/src/mixed.js"
nlf="$fx/nl"$'\n'"file.js"
printf 'const k = "%s";\n' "$v_aws5" >"$nlf"
git -C "$fx" init -q && git -C "$fx" add -A &&
  git -C "$fx" -c user.name=t -c user.email=t@t -c commit.gpgsign=false -c core.hooksPath=/dev/null commit -q -m fx
printf 'const k = "%s";\n' "$v_aws" >"$fx/untracked.js"
mkdir -p "$fx/apps/web"; printf 'A=1\n' >"$fx/apps/web/.env"; printf 'A=1\n' >"$fx/apps/web/.env.example"
has() { grep -qxF -- "$1" "$out"; }
lacks() { ! grep -qF -- "$1" "$out"; }
check() { # check <name> <command...>: expects exit 0
  local n="$1" got; shift
  "$@" >/dev/null 2>&1; got=$?
  row scan-secrets "$n" 0 "$got" 0 "assertion failed"
}
TIMEFORMAT=%3R
{ time "$scan" "$fx" >"$out" 2>/dev/null; } 2>"$tf"
got=$?
ms="$(tr -cd '0-9' <"$tf")"; ms=$((10#${ms:-0}))
row scan-secrets "fixture scan exits 0" 0 "$got" "$ms" "scan-secrets.sh failed or missing"
"$scan" >/dev/null 2>&1; got=$?
row scan-secrets "no args is a usage error" 1 "$got" 0 "expected exit 1"
check "self-test: all rules ok" grep -qxF "# scanned: 8 rules ok, 0 failed" "$out"
check "aws key in src is critical" has "critical${T}secret${T}src/config.js:1${T}${m_aws}${T}aws-key"
check "path with colon stays intact" has "critical${T}secret${T}src/a:b.js:1${T}${m_aws}${T}aws-key"
check "test path downgraded to low" has "low${T}secret${T}test/fixture.js:1${T}${m_gh}${T}github-token"
check "private key header critical" has "critical${T}secret${T}src/pk.txt:1${T}----****${T}private-key"
check "generic rule is medium" has "medium${T}secret${T}src/app.js:1${T}apiK****${T}generic"
check "tracked .env is high" has "high${T}sensitive-file${T}.env${T}(environment file)${T}protect-files"
check ".env not ignored is medium" has "medium${T}sensitive-file${T}.env${T}(not ignored)${T}env-not-ignored"
check ".env.example not flagged" lacks ".env.example"
check "clean file not flagged" lacks "clean.js"
check "--check counts a real row" test "$("$scan" "$fx" --check aws-key src/config.js 2>/dev/null)" = 1
check "--check is 0 on a clean file" test "$("$scan" "$fx" --check aws-key src/clean.js 2>/dev/null)" = 0
"$scan" "$fx" --check no-such-rule src/config.js >/dev/null 2>&1; got=$?
row scan-secrets "--check unknown rule is a usage error" 1 "$got" 0 "expected exit 1"
check "--check literal ':' tracked path" test "$("$scan" "$fx" --check aws-key ':lit.js' 2>/dev/null)" = 1
"$scan" "$fx" --check aws-key untracked.js >/dev/null 2>&1; got=$?
row scan-secrets "--check untracked path is exit 2" 2 "$got" 0 "expected exit 2"
"$scan" "$fx" --check "aws-key github-token" src/config.js >/dev/null 2>&1; got=$?
row scan-secrets "--check multi-word rule is exit 1" 1 "$got" 0 "expected exit 1"
check "non-ASCII id_rsa reported high" has "high${T}sensitive-file${T}café/id_rsa${T}(key/certificate)${T}protect-files"
check "spaced .pem reported high" has "high${T}sensitive-file${T}my certs/server file.pem${T}(key/certificate)${T}protect-files"
check "newline path gives info row" has "info${T}tool error${T}-${T}-${T}path with newline skipped"
check "newline path gives no secret row" lacks "file.js"
check "nested untracked .env is medium" has "medium${T}sensitive-file${T}apps/web/.env${T}(not ignored)${T}env-not-ignored"
check "nested .env.example not flagged" lacks "apps/web/.env.example"
mkdir -p "$fx/.env2"; printf 'x\n' >"$fx/.envrc"; printf 'y\n' >"$fx/.env2/f"
"$scan" "$fx" >"$out" 2>/dev/null
check ".envrc not flagged" lacks ".envrc"
check "files under .env2/ not flagged" lacks ".env2/f"
check "tracked root .env reported once" test "$(grep -c "${T}\.env${T}(not ignored)" "$out")" = 1
fx2="$fx/.untracked-env"; mkdir -p "$fx2"; git -C "$fx2" init -q; printf 'A=1\n' >"$fx2/.env"
check "untracked root .env reported once" test "$("$scan" "$fx2" 2>/dev/null | grep -c "${T}\.env${T}(not ignored)")" = 1
"$scan" "$fx" --sinks >"$out2" 2>/dev/null; got=$?
row scan-secrets "--sinks exits 0" 0 "$got" 0 "scan-secrets.sh --sinks failed"
check "sink in unflagged file listed" grep -qxF "src/sink.js:1${T}eval" "$out2"
check "sink in flagged file not listed" bash -c '! grep -qF "src/mixed.js" "$1"' _ "$out2"
check "sinks output has no secret value" bash -c '! grep -qF "$2" "$1"' _ "$out2" "$v_aws4"
check "sinks output has no line content" bash -c '! grep -qF "input" "$1"' _ "$out2"
for v in "$v_aws" "$v_aws2" "$v_gh" "$v_env" "$v_aws3" "$v_aws4" "$v_aws5"; do
  check "no full value in output" lacks "$v"
  check "no 12-char prefix in output" lacks "${v:0:12}"
done

# --- commit-gate: template copies with {{QUICK_CHECK_CMD}} substituted ---
tpl="$root/plugins/devkit/templates/hooks/check-before-commit.sh"
gd="$(mktemp -d)"
trap 'rm -rf "$err" "$tf" "$fx" "$out" "$out2" "$gd"' EXIT
gate() { # gate <check cmd|@unfilled> <exp> <name> <command> [stderr substring]
  local copy="$gd/check-before-commit.sh" json
  rm -f "$copy"
  if [ "$1" = "@unfilled" ]; then cp "$tpl" "$copy"
  else python3 -c 'import sys; t=open(sys.argv[1]).read(); open(sys.argv[2],"w").write(t.replace("{{QUICK_CHECK_CMD}}", sys.argv[3]))' "$tpl" "$copy" "$1"; fi
  chmod +x "$copy" 2>/dev/null
  case "$4" in "{"*|not*) json="$4" ;; *)
    json="$(python3 -c 'import json,sys; print(json.dumps({"tool_input":{"command":sys.argv[1]}}))' "$4")" ;; esac
  expect "$copy" "$2" "gate: $3" "$json"
  if [ -n "${5:-}" ]; then
    grep -qF -- "$5" "$err"; row check-before-commit "gate: stderr has $5" 0 $? 0 "stderr missing text"
  fi
}
gate true 0 "passing check allows commit" 'git commit -m x'
gate false 2 "failing check blocks commit" 'git commit -m x' 'Blocked by devkit'
gate 'sh -c "echo boom-line; exit 1"' 2 "failing output is shown" 'git commit -m x' 'boom-line'
gate "sh -c 'echo quoted; exit 1'" 2 "check with single quotes blocks" 'git commit -m x' 'quoted'
gate 'true && true' 0 "check with && passes" 'git commit -m x'
gate "true # project's check" 0 "apostrophe in a comment is safe" 'git status'
gate "false # project's check" 2 "apostrophe comment still runs the check" 'git commit -m x'
gate 'echo "unterminated' 0 "unbalanced quote in fill never blocks git status" 'git status'
gate false 2 "FOO=1 git commit blocked" 'FOO=1 git commit -m x'
gate false 2 "sudo git commit blocked" 'sudo git commit -m x'
gate false 2 "git --no-pager commit blocked" 'git --no-pager commit -m x'
gate false 2 "git -C quoted path commit blocked" 'git -C "a b" commit -m x'
gate false 2 "/usr/bin/git commit blocked" '/usr/bin/git commit -m x'
gate false 2 "git -c k=v commit blocked" 'git -c k=v commit -m x'
gate false 0 "git commit-tree is not a commit" 'git commit-tree HEAD^{tree}'
gate false 2 "git -c quoted value commit blocked" 'git -c user.name="a b" commit -m x'
gate false 2 "nohup git commit blocked" 'nohup git commit -m x'
gate false 0 "git status is not a commit" 'git status'
gate false 0 "git log --grep commit is not a commit" 'git log --grep commit'
gate false 2 "chained commit blocked" 'npm test && git commit -m x'
gate false 2 "git -C repo commit blocked" 'git -C repo commit -m x'
gate false 2 "env FOO=1 git commit blocked" 'env FOO=1 git commit'
gate false 2 "multi-line command blocked" $'git add -A\ngit commit -m x'
gate @unfilled 0 "unfilled placeholder allows" 'git commit -m x'
gate no-such-cmd-xyz 0 "missing check command allows" 'git commit -m x'
gate false 0 "malformed JSON allowed" 'not json'
gate false 0 "empty input allowed" '{}'

# --- pr-size: temp repos with main plus a feature branch ---
ps="$root/plugins/devkit/scripts/pr-size.sh"
psd="$(mktemp -d)"
trap 'rm -rf "$err" "$tf" "$fx" "$out" "$out2" "$gd" "$psd"' EXIT
pgit() { local d="$1"; shift; git -C "$d" -c user.name=t -c user.email=t@t -c commit.gpgsign=false -c core.hooksPath=/dev/null "$@"; }
mkrepo() { # mkrepo <name> [docs/devkit.md content]: fresh repo in $r, on branch feat
  r="$psd/$1"; mkdir -p "$r"; git -C "$r" init -q; git -C "$r" symbolic-ref HEAD refs/heads/main
  if [ -n "${2:-}" ]; then mkdir -p "$r/docs"; printf '%s\n' "$2" >"$r/docs/devkit.md"; fi
  printf 'base\n' >"$r/README.md"; git -C "$r" add -A; pgit "$r" commit -q -m base
  git -C "$r" checkout -q -b feat
}
commit_all() { git -C "$r" add -A; pgit "$r" commit -q -m change; }
gen() { awk -v n="$1" 'BEGIN { for (i = 1; i <= n; i++) print "line " i }'; } # gen <lines>
psck() { # psck <name> <dir> <exp exit> <expected output substring>
  local got
  (cd "$2" && "$ps" main >"$out" 2>/dev/null); got=$?
  row pr-size "$1" "$3" "$got" 0 "exit code differs"
  if [ -n "$4" ]; then
    grep -qF -- "$4" "$out"; row pr-size "$1: output" 0 $? 0 "missing: $4"
  fi
}
mkrepo small; gen 5 >"$r/a.txt"; commit_all
psck "small change is ok" "$r" 0 "lines=5 files=1 max_lines=300 max_files=10 excluded=0 base=main status=ok"
mkrepo dashname; printf 'a\nb\n' >"$r/-dash.txt"
psck "untracked name starting with - counts its lines" "$r" 0 "lines=2 files=1"
mkrepo manyuntracked; mkdir -p "$r/u"; for i in $(seq 1 501); do printf 'x\n' >"$r/u/f$i"; done
psck "over 500 untracked files: lines not counted" "$r" 3 "files=501 max_lines=300 max_files=10 excluded=0 base=main status=over partial=untracked"
mkrepo distskip; mkdir -p "$r/dist"; for i in $(seq 1 50); do gen 100 >"$r/dist/d$i.js"; done
psck "excluded untracked files are skipped" "$r" 0 "lines=0 files=0 max_lines=300 max_files=10 excluded=50"
mkrepo big; gen 400 >"$r/big.txt"; commit_all
psck "400 added lines is over" "$r" 3 "lines=400 files=1 max_lines=300 max_files=10 excluded=0 base=main status=over"
mkrepo many; for i in 1 2 3 4 5 6 7 8 9 10 11; do echo x >"$r/f$i.txt"; done; commit_all
psck "11 one-line files is over on files" "$r" 3 "lines=11 files=11 max_lines=300 max_files=10 excluded=0 base=main status=over"
mkrepo lock; gen 5000 >"$r/package-lock.json"; commit_all
psck "5000-line package-lock is excluded" "$r" 0 "lines=0 files=0 max_lines=300 max_files=10 excluded=1 base=main status=ok"
mkrepo bin; printf '\000\001\002\003' >"$r/b.bin"; commit_all
psck "binary file counts as a file only" "$r" 0 "lines=0 files=1 max_lines=300"
mkrepo untr; gen 7 >"$r/new.txt"
psck "untracked file is counted" "$r" 0 "lines=7 files=1 max_lines=300"
mkrepo cfg "- pr_max_lines: 1000"; gen 400 >"$r/big.txt"; commit_all
psck "docs/devkit.md raises the line limit" "$r" 0 "lines=400 files=1 max_lines=1000 max_files=10 excluded=0 base=main status=ok"
mkrepo bad $'# devkit\n- pr_max_lines: lots\n- pr_max_files:\npr_max_lines: 5\n- pr_size_exclude: '; gen 400 >"$r/big.txt"; commit_all
psck "malformed docs/devkit.md uses defaults" "$r" 3 "lines=400 files=1 max_lines=300 max_files=10 excluded=0 base=main status=over"
mkrepo excl "- pr_size_exclude: gen/**, *.out"; gen 50 >"$r/a.out"; mkdir "$r/gen"; gen 50 >"$r/gen/x.txt"; gen 3 >"$r/keep.txt"; commit_all
psck "custom exclude globs apply" "$r" 0 "lines=3 files=1 max_lines=300 max_files=10 excluded=2 base=main status=ok"
mkrepo nest; mkdir -p "$r/pkg/__snapshots__" "$r/sub"; gen 20 >"$r/pkg/__snapshots__/a.snap.txt"; gen 20 >"$r/sub/yarn.lock"; gen 20 >"$r/__snapshots__x"; commit_all
psck "nested default excludes match" "$r" 0 "lines=20 files=1 max_lines=300 max_files=10 excluded=2"
mkrepo uni; mkdir -p "$r/my dir"; gen 4 >"$r/my dir/café ü.txt"; commit_all
psck "path with spaces and unicode works" "$r" 0 "my dir/café ü.txt"$'\t'"4"
mkrepo dirty; gen 6 >"$r/a.txt"; commit_all; gen 9 >"$r/a.txt"
psck "uncommitted tracked change is counted" "$r" 0 "lines=9 files=1 max_lines=300"
(cd "$r" && "$ps" no-such-ref >/dev/null 2>&1); got=$?
row pr-size "bad base ref is exit 1" 1 "$got" 0 "expected exit 1"
mkdir -p "$psd/norepo"
(cd "$psd/norepo" && "$ps" main >/dev/null 2>&1); got=$?
row pr-size "not a repo is exit 1" 1 "$got" 0 "expected exit 1"

# --- block-protected-push: template copy with {{PROTECTED_BRANCHES}} substituted, run in a temp repo ---
# Placed after the pr-size repo helpers because it reuses mkrepo.
ptpl="$root/plugins/devkit/templates/hooks/block-protected-push.sh"
pgn=0
pushgate() { # pushgate <list|@unfilled> <branch> <upstream: none|origin/main> <exp> <name> <command> [stderr substring]
  local copy="$gd/block-protected-push.sh" json cmd
  pgn=$((pgn + 1)); mkrepo "pg$pgn"
  [ "$2" = main ] && git -C "$r" checkout -q main
  [ "$2" = detached ] && git -C "$r" checkout -q --detach
  if [ "$3" != none ]; then
    git -C "$r" remote add origin "$r/.git"
    git -C "$r" config "branch.$2.remote" origin
    git -C "$r" config "branch.$2.merge" "refs/heads/${3#origin/}"
  fi
  rm -f "$copy"
  if [ "$1" = "@unfilled" ]; then cp "$ptpl" "$copy" 2>/dev/null
  else python3 -c 'import sys; t=open(sys.argv[1]).read(); open(sys.argv[2],"w").write(t.replace("{{PROTECTED_BRANCHES}}", sys.argv[3]))' "$ptpl" "$copy" "$1" 2>/dev/null; fi
  chmod +x "$copy" 2>/dev/null
  cmd="${6//@REPO/$r}"
  case "$cmd" in "{"*|not*) json="$cmd" ;; *)
    json="$(python3 -c 'import json,sys; print(json.dumps({"tool_input":{"command":sys.argv[1]}}))' "$cmd")" ;; esac
  CLAUDE_PROJECT_DIR="$r" expect "$copy" "$4" "pushgate: $5" "$json"
  if [ -n "${7:-}" ]; then
    grep -qF -- "$7" "$err"; row block-protected-push "pushgate: stderr has $7" 0 $? 0 "stderr missing text"
    grep -qF -- "main" "$err"; row block-protected-push "pushgate: stderr has branch name" 0 $? 0 "branch name missing"
  fi
}
PL='main release/*'
pushgate "$PL" feat none 2 "push origin main" 'git push origin main'
pushgate "$PL" feat none 2 "push -u origin main" 'git push -u origin main'
pushgate "$PL" feat none 2 "push origin HEAD:main" 'git push origin HEAD:main'
pushgate "$PL" feat none 2 "push origin feat:refs/heads/main" 'git push origin feat:refs/heads/main'
pushgate "$PL" feat none 2 "push origin +feat:main" 'git push origin +feat:main'
pushgate "$PL" feat none 2 "push origin :main (delete)" 'git push origin :main'
pushgate "$PL" feat none 2 "push --delete origin main" 'git push --delete origin main'
pushgate "$PL" feat none 2 "push origin release/1.2 (glob)" 'git push origin release/1.2'
pushgate "$PL" feat none 2 "push --all origin" 'git push --all origin'
pushgate "$PL" feat none 2 "push --mirror" 'git push --mirror'
pushgate "$PL" main none 2 "git -C repo push on main" 'git -C @REPO push'
pushgate "$PL" main none 2 "bare push on main" 'git push'
pushgate "$PL" feat origin/main 2 "bare push on feat with upstream main" 'git push'
pushgate "$PL" feat none 2 "cd x && git push origin main" 'cd x && git push origin main'
pushgate "$PL" feat none 2 "FOO=1 git push origin main" 'FOO=1 git push origin main'
pushgate "$PL" feat none 2 "git --git-dir .git push origin main" 'git --git-dir .git push origin main'
pushgate "$PL" feat none 2 "block message" 'git push origin main' 'Blocked by devkit'
pushgate "$PL" feat none 0 "push origin feat" 'git push origin feat'
pushgate "$PL" feat none 0 "bare push on feat, no upstream" 'git push'
pushgate "$PL" feat none 0 "push --tags" 'git push --tags'
pushgate "$PL" feat none 0 "push origin refs/tags/v1.0" 'git push origin refs/tags/v1.0'
pushgate "$PL" feat none 0 "push origin v1.0" 'git push origin v1.0'
pushgate "$PL" feat none 0 "git status is not a push" 'git status'
pushgate "$PL" feat none 0 "git log --grep push is not a push" 'git log --grep push'
pushgate "main,release/*" feat none 2 "comma list: push origin main" 'git push origin main'
pushgate "main,release/*" feat none 2 "comma list: push origin release/2" 'git push origin release/2'
pushgate "main,release/*" feat none 0 "comma list: push origin feat" 'git push origin feat'
pushgate "$PL" feat none 2 "push -d origin main (short delete flag)" 'git push -d origin main'
pushgate "$PL" main none 2 "push origin HEAD on main" 'git push origin HEAD'
pushgate "$PL" feat none 0 "push origin HEAD on feat" 'git push origin HEAD'
pushgate "$PL" feat none 2 "push -o value skipped, then main" 'git push -o ci.skip origin main'
pushgate "$PL" feat none 0 "push -o main value is not a refspec" 'git push -o main origin feat'
pushgate "$PL" feat none 2 "push --repo=x origin main" 'git push --repo=x origin main'
pushgate "$PL" feat none 2 "sudo git push origin main" 'sudo git push origin main'
pushgate "$PL" feat none 2 "/usr/bin/git push origin main" '/usr/bin/git push origin main'
pushgate "$PL" detached none 0 "bare push on detached HEAD" 'git push'
pushgate "$PL" feat none 0 "push origin mainline (glob does not over-match)" 'git push origin mainline'
pushgate "$PL" feat none 2 "second segment pushes main (&&)" 'git push origin feat && git push origin main'
pushgate "$PL" feat none 0 "main only in a later non-push segment" 'git push origin feat; echo main'
pushgate @unfilled feat none 0 "unfilled placeholder allows" 'git push origin main'
pushgate "" feat none 0 "empty list allows" 'git push origin main'
pushgate "$PL" feat none 0 "malformed JSON allowed" 'not json'
pushgate "$PL" feat none 0 "empty input allowed" '{}'
pushgate "$PL" main none 2 "push origin 2>&1 on main" 'git push origin 2>&1'
pushgate "$PL" main none 2 "push origin >&/dev/null on main" 'git push origin >&/dev/null'
pushgate "$PL" main none 2 "push >& /dev/null on main" 'git push >& /dev/null'
pushgate "$PL" main none 2 "push -u origin 2>&1 on main" 'git push -u origin 2>&1'
pushgate "$PL" main none 2 "push origin 2>&1 | tail -3 on main" 'git push origin 2>&1 | tail -3'
pushgate "$PL" main none 2 "push origin > /tmp/log on main" 'git push origin > /tmp/log'
pushgate "$PL" main none 2 "push >/dev/null 2>&1 on main" 'git push >/dev/null 2>&1'
pushgate "$PL" main none 0 "push origin feat 2>&1 on main" 'git push origin feat 2>&1'
pushgate "$PL" feat none 2 "push origin refs/tags/v1:refs/heads/main" 'git push origin refs/tags/v1:refs/heads/main'
pushgate "$PL" main none 2 "push origin @ on main" 'git push origin @'
pushgate "$PL" feat none 2 "sudo -E git push origin main" 'sudo -E git push origin main'
pushgate " , " feat none 0 "list of only separators allows --all" 'git push --all origin'
# Worktrees: the hook runs in the JSON cwd (else CLAUDE_PROJECT_DIR) and follows `cd <dir>` segments.
mkdir -p "$gd/wt"
python3 -c 'import sys; t=open(sys.argv[1]).read(); open(sys.argv[2],"w").write(t.replace("{{PROTECTED_BRANCHES}}", sys.argv[3]))' "$ptpl" "$gd/wt/block-protected-push.sh" "$PL"
chmod +x "$gd/wt/block-protected-push.sh"
pgwt() { # pgwt <exp> <name> <project dir> <json cwd or ""> <command>
  local json
  json="$(python3 -c 'import json,sys; d={"tool_input":{"command":sys.argv[1]}}; d.update({"cwd":sys.argv[2]} if sys.argv[2] else {}); print(json.dumps(d))' "$5" "$4")"
  CLAUDE_PROJECT_DIR="$3" expect "$gd/wt/block-protected-push.sh" "$1" "pushgate: $2" "$json"
}
mkrepo pgwtmain; git -C "$r" checkout -q main; git -C "$r" worktree add -q "$psd/pgwtmain-feat" feat
pgwt 0 "cd <worktree on feat> && push -u origin HEAD" "$r" "" "cd $psd/pgwtmain-feat && git push -u origin HEAD"
pgwt 0 "bare push with JSON cwd = worktree on feat" "$r" "$psd/pgwtmain-feat" 'git push'
pgwt 2 "bare push, no cwd, project dir on main" "$r" "" 'git push'
mkrepo pgwtfeat; git -C "$r" worktree add -q "$psd/pgwtfeat-main" main
pgwt 2 "bare push with JSON cwd = worktree on main" "$r" "$psd/pgwtfeat-main" 'git push'
pgwt 0 "cd to a missing dir keeps the current one" "$r" "" 'cd /nonexistent-devkit && git push'

# --- queue-status: stub gh on PATH returns canned JSON per subcommand ---
qs="$root/plugins/devkit/scripts/queue-status.sh"
mkdir -p "$psd/qsbin"
cat >"$psd/qsbin/gh" <<'STUB'
#!/bin/sh
[ -z "${QS_FAIL:-}" ] || { echo "gh: boom" >&2; exit 1; }
case "$1 $2" in
  "pr list") f="$QS_PRS" ;;
  "issue list") f="$QS_ISSUES" ;;
  *) exit 1 ;;
esac
if [ -n "${QS_PRETTY:-}" ]; then python3 -c 'import json,sys; print(json.dumps(json.load(sys.stdin), indent=2))' <"$f"; else cat "$f"; fi
STUB
chmod +x "$psd/qsbin/gh"
qs_ago() { python3 -c 'import sys,datetime as d; print((d.datetime.now(d.timezone.utc)-d.timedelta(minutes=int(sys.argv[1]))).strftime("%Y-%m-%dT%H:%M:%SZ"))' "$1"; } # qs_ago <minutes>
qs_prs() { # qs_prs <open non-draft count> <draft count> [body of first PR]
  python3 -c 'import sys,json
n,dr=int(sys.argv[1]),int(sys.argv[2]); b=sys.argv[3] if len(sys.argv)>3 else ""
print(json.dumps([{"number":100+i,"isDraft":i>=n,"body":(b if i==0 else ""),"headRefName":"b%d"%i} for i in range(n+dr)]))' "$@" >"$psd/prs.json"
}
qs_issue() { # qs_issue <claim minutes ago> [release minutes ago] [claim time override]: one issue #7
  python3 -c 'import sys,json,datetime as d
def t(m): return (d.datetime.now(d.timezone.utc)-d.timedelta(minutes=int(m))).strftime("%Y-%m-%dT%H:%M:%SZ")
c=sys.argv[1]; r=sys.argv[2] if len(sys.argv)>2 else ""; o=sys.argv[3] if len(sys.argv)>3 else ""
cm=[{"author":{"login":"u"},"body":"hello","createdAt":t(500)},
    {"author":{"login":"u"},"body":"\U0001F512 devkit claim · host: box1 · task: T-1 · "+t(c),"createdAt":o or t(c)}]
if r: cm.append({"author":{"login":"u"},"body":"\U0001F513 devkit release · host: box1 · reason: x · done so far: nothing","createdAt":t(r)})
print(json.dumps([{"number":7,"title":"Fix the thing","comments":cm}]))' "$@" >"$psd/issues.json"
}
qs_multi() { # qs_multi <kind:host:minutes-ago>...: issue #7 with these claim (c) / release (r) comments
  python3 -c 'import sys,json,datetime as d
def t(m): return (d.datetime.now(d.timezone.utc)-d.timedelta(minutes=int(m))).strftime("%Y-%m-%dT%H:%M:%SZ")
cm=[]
for a in sys.argv[1:]:
    k,h,m=a.split(":")
    b=("\U0001F512 devkit claim · host: %s · task: T-1 · " if k=="c" else "\U0001F513 devkit release · host: %s · reason: x · done so far: nothing") % h
    cm.append({"body":b,"createdAt":t(m)})
print(json.dumps([{"number":7,"title":"Fix the thing","comments":cm}]))' "$@" >"$psd/issues.json"
}
qsck() { # qsck <name> <dir> <exp exit> <expected output substring> [unexpected substring]
  local got
  (cd "$2" && PATH="$psd/qsbin:$PATH" QS_PRS="$psd/prs.json" QS_ISSUES="$psd/issues.json" "$qs" >"$out" 2>/dev/null); got=$?
  row queue-status "$1" "$3" "$got" 0 "exit code differs"
  if [ -n "$4" ]; then grep -qF -- "$4" "$out"; row queue-status "$1: output" 0 $? 0 "missing: $4"; fi
  if [ -n "${5:-}" ]; then ! grep -qF -- "$5" "$out"; row queue-status "$1: absent" 0 $? 0 "unexpected: $5"; fi
}
echo '[]' >"$psd/issues.json"
mkrepo qsa; qs_prs 1 1
qsck "2 PRs (1 draft), limit 5 is ok" "$r" 0 "open_prs=1 max_open_prs=5 pressure=ok ttl_minutes=120 stale=0"
qs_prs 5 0
qsck "5 non-draft PRs is over" "$r" 0 "open_prs=5 max_open_prs=5 pressure=over"
mkrepo qsoff "- max_open_prs: 0"; qs_prs 9 0
qsck "max_open_prs 0 turns it off" "$r" 0 "pressure=off"
mkrepo qsb; qs_prs 0 0; qs_issue 180
qsck "3-hour claim without release or PR is stale" "$r" 0 "stale=1"
grep -qE $'^#7\tbox1\t(18[0-9]|19[0-9])\tFix the thing$' "$out"; row queue-status "stale row has host, age, title" 0 $? 0 "row format"
qs_issue 180 60
qsck "later release means not stale" "$r" 0 "stale=0"
qs_prs 1 0 "Closes #7"; qs_issue 180
qsck "open PR with Closes #N means not stale" "$r" 0 "stale=0"
qs_prs 0 0; qs_issue 10
qsck "10-minute claim is not stale" "$r" 0 "stale=0"
mkrepo qsttl "- claim_ttl_minutes: 30"; qs_issue 45
qsck "ttl 30 with a 45-minute claim is stale" "$r" 0 "ttl_minutes=30 stale=1"
mkrepo qsc; qs_issue 180 "" "not-a-time"
qsck "malformed comment time is skipped" "$r" 0 "stale=0"
qs_prs 0 0; qs_multi c:A:300 c:B:200 r:B:190
qsck "released second host: stale on the winner A" "$r" 0 "stale=1"
grep -qE $'^#7\tA\t' "$out"; row queue-status "winner host is reported" 0 $? 0 "host A expected"
qs_multi c:A:400 c:B:300
qsck "takeover without release: stale on the latest claim" "$r" 0 "stale=1"
grep -qE $'^#7\tB\t30[0-9]\t' "$out"; row queue-status "takeover row names the latest claimer B" 0 $? 0 "host B expected"
qs_multi c:A:300 c:B:10
qsck "old claim plus recent active claim is not stale" "$r" 0 "stale=0"
qs_multi c:A:300 r:A:200
qsck "all released but labelled is stale" "$r" 0 "stale=1"
grep -qE $'^#7\t-\t(19[0-9]|200)\t' "$out"; row queue-status "all-released row has host - and age since release" 0 $? 0 "row format"
qs_multi c:A:200 r:A:200
qsck "release in the same second as a claim counts as after it" "$r" 0 "stale=1"
qs_prs 0 0; qs_issue 180
(cd "$r" && PATH="$psd/qsbin:$PATH" QS_PRETTY=1 CLICOLOR_FORCE=1 GH_FORCE_TTY=1 QS_PRS="$psd/prs.json" QS_ISSUES="$psd/issues.json" "$qs" >"$out" 2>/dev/null); got=$?
row queue-status "pretty-printed multi-line gh JSON works" 0 "$got" 0 "exit code differs"
grep -qF "stale=1" "$out"; row queue-status "pretty-printed output parsed" 0 $? 0 "stale=1 missing"
qs_prs 5 2
qsck "review lists the 3 oldest non-draft PRs" "$r" 0 " review=#100,#101,#102"
qs_prs 0 2
qsck "no non-draft PR gives review=-" "$r" 0 " review=-"
qs_prs 1 0 "fix #7"; qs_issue 180
qsck "fix #N counts as a reference" "$r" 0 "stale=0"
qs_prs 1 0 "Closes: #7"
qsck "Closes: #N counts as a reference" "$r" 0 "stale=0"
qs_prs 1 0 "see owner/repo#7"
qsck "owner/repo#N is not a reference" "$r" 0 "stale=1"
qs_prs 0 0; python3 -c 'import json,datetime as d
t=(d.datetime.now(d.timezone.utc)-d.timedelta(minutes=180)).strftime("%Y-%m-%dT%H:%M:%SZ")
print(json.dumps([{"number":7,"title":"T","comments":[{"body":"\U0001F512 devkit claim · host: bo\x1bx · task: T-1","createdAt":t}]}]))' >"$psd/issues.json"
qsck "control chars are stripped from the host" "$r" 0 "stale=1"
! grep -q $'\x1b' "$out"; row queue-status "no escape char in output" 0 $? 0 "escape leaked"
(cd "$r" && PATH="$psd/qsbin:$PATH" QS_FAIL=1 QS_PRS="$psd/prs.json" QS_ISSUES="$psd/issues.json" "$qs" >/dev/null 2>&1); got=$?
row queue-status "failing gh is exit 1" 1 "$got" 0 "expected exit 1"

expect "$notify" 0 "always exits 0" '{"message":"test"}'

echo "$cases cases, $nfail failed, total $total ms"
[ "$fail" -eq 0 ] && echo "All hooks passed." || echo "Some hooks failed."
exit "$fail"
