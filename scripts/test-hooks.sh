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
# --excluded-index: the same matcher over a NUL-separated path list (used by metrics.sh)
pxi() { # pxi <name> <dir> <list file> <exp exit> <exp output, lines joined by "|">
  local got
  (cd "$2" && "$ps" --excluded-index "$3" >"$out" 2>/dev/null); got=$?
  row pr-size "$1" "$4" "$got" 0 "exit code differs"
  [ "$got" = 0 ] || return 0
  [ "$(paste -sd'|' "$out")" = "$5" ]; row pr-size "$1: output" 0 $? 0 "got: $(paste -sd'|' "$out")"
}
mkrepo xi; xl="$psd/xi.list"
printf '%s\0' a.lock src/x.js pkg/__snapshots__/s dist/m.js sub/yarn.lock >"$xl"
pxi "excluded-index: default globs" "$r" "$xl" 0 "max_lines=300 max_files=10|0|2|3|4"
printf '%s\0' keep.txt >"$xl"; printf 'x.min.js' >>"$xl"
pxi "excluded-index: last path without a trailing NUL" "$r" "$xl" 0 "max_lines=300 max_files=10|1"
: >"$xl"
pxi "excluded-index: empty list prints the limits only" "$r" "$xl" 0 "max_lines=300 max_files=10"
mkrepo xicfg $'- pr_max_lines: 1000\n- pr_size_exclude: gen/**, *.out'
printf '%s\0' a.out gen/x.txt keep.txt sub/b.out >"$xl"
pxi "excluded-index: docs/devkit.md limits and globs" "$r" "$xl" 0 "max_lines=1000 max_files=10|0|1|3"
xie() { # xie <name> <expected stderr regex> <args...>: expects exit 1 and that message
  local n="$1" m="$2" got; shift 2
  (cd "$r" && "$ps" "$@" >/dev/null 2>"$out"); got=$?
  row pr-size "$n" 1 "$got" 0 "expected exit 1"
  grep -q "$m" "$out"; row pr-size "$n: message" 0 $? 0 "missing: $m"
}
xie "excluded-index: missing list file" "cannot read" --excluded-index "$psd/no-such.list"
xie "excluded-index: a directory as the list" "cannot read" --excluded-index "$psd"
xie "excluded-index without a file" "^usage:" --excluded-index
xie "excluded-index with an empty file name" "^usage:" --excluded-index ""
xie "excluded-index with two files" "^usage:" --excluded-index a b
mkdir -p "$r/sub"; printf '%s\0' a.out keep.txt >"$r/sub/rel.list"
pxi "excluded-index: relative list path from a subdirectory" "$r/sub" rel.list 0 "max_lines=1000 max_files=10|0"
# Parity: on one repo, the normal run's excluded paths are exactly the ones --excluded-index flags.
mkrepo xipar; mkdir -p "$r/pkg/__snapshots__" "$r/dist" "$r/lib"
gen 3 >"$r/sub.lock"; gen 3 >"$r/pkg/__snapshots__/a.txt"; gen 3 >"$r/dist/m.js"; gen 3 >"$r/lib/app.min.css"
gen 2 >"$r/lock.txt"; gen 2 >"$r/distx.js"; gen 2 >"$r/lib/app.css"; commit_all
psck "parity repo: normal run" "$r" 0 "lines=6 files=3 max_lines=300 max_files=10 excluded=4"
git -C "$r" diff --name-only -z main >"$xl"
(cd "$r" && "$ps" --excluded-index "$xl" >"$out" 2>/dev/null)
got="$(python3 -c 'import sys; p=open(sys.argv[1],"rb").read().split(b"\0"); ix=[int(l) for l in open(sys.argv[2]).read().split()[2:]]; print(",".join(sorted(p[i].decode() for i in ix)))' "$xl" "$out")"
[ "$got" = "dist/m.js,lib/app.min.css,pkg/__snapshots__/a.txt,sub.lock" ]
row pr-size "parity: --excluded-index flags the same 4 paths" 0 $? 0 "got: $got"

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

# --- branch-protection: stub gh on PATH, scenario chosen by BP_CASE ---
# Stub contract (the script under test must match it):
#   gh repo view --json defaultBranchRef [--jq .defaultBranchRef.name]  -> with --jq prints "main"; else {"defaultBranchRef":{"name":"main"}}
#   gh api repos/<o>/<r>/branches/<b>             -> JSON with protected, protection.enabled
#   gh api repos/<o>/<r>/rules/branches/<b>       -> JSON array of {"type": ...}
#   gh api repos/<o>/<r>/branches/<b>/protection  -> classic JSON, or stderr "gh: HTTP 403/404" + exit 1 (BP_CASE ending in 403)
# `gh api` calls must NOT pass --jq/-q: the stub exits 64 on it. The script parses raw JSON itself (python3 -I).
# The rules call carries "?per_page=100" (still matched by */rules/branches/*). The script rejects names that
# fail `git check-ref-format --branch`. BP_CASE=apifail makes branches/<b> fail (exit 1); rulesfail makes the rules call fail.
bp="$root/plugins/devkit/scripts/branch-protection.sh"
mkdir -p "$psd/bpbin"
cat >"$psd/bpbin/gh" <<'STUB'
#!/bin/sh
case "$1 $2" in
  "repo view")
    [ "${BP_CASE:-}" = viewfail ] && { echo "gh: not a repo" >&2; exit 1; }
    for a in "$@"; do
      if [ "$a" = "--jq" ] || [ "$a" = "-q" ]; then echo main; exit 0; fi
    done
    echo '{"defaultBranchRef":{"name":"main"}}'; exit 0 ;;
  "api "*) ;;
  *) exit 1 ;;
esac
for a in "$@"; do case "$a" in --jq|-q) echo "stub: gh api must not use --jq" >&2; exit 64 ;; esac; done
c="${BP_CASE:-}"
case "$2" in
  */branches/*/protection)
    case "$c" in
      classic_on) echo '{"required_pull_request_reviews":{"required_approving_review_count":1},"allow_force_pushes":{"enabled":false}}' ;;
      classic_open) echo '{"allow_force_pushes":{"enabled":true}}' ;;
      both) echo '{"required_pull_request_reviews":{"required_approving_review_count":1},"allow_force_pushes":{"enabled":true}}' ;;
      *403) echo "gh: HTTP 403: Upgrade to GitHub Pro or make this repository public (repos/o/r/branches/main/protection)" >&2; exit 1 ;;
      *) echo "gh: Not Found (HTTP 404)" >&2; exit 1 ;;
    esac ;;
  */rules/branches/*)
    case "$c" in
      ruleset) echo '[{"type":"pull_request"},{"type":"non_fast_forward"}]' ;;
      thisrepo) echo '[{"type":"deletion"},{"type":"non_fast_forward"}]' ;;
      both) echo '[{"type":"non_fast_forward"}]' ;;
      classic403_rules) echo '[{"type":"non_fast_forward"}]' ;;
      rulesfail) echo "gh: HTTP 500" >&2; exit 1 ;;
      *) echo '[]' ;;
    esac ;;
  */branches/*)
    case "$c" in
      apifail) echo "gh: HTTP 500" >&2; exit 1 ;;
      ruleset|thisrepo|rulesfail) echo '{"protected":true,"protection":{"enabled":false}}' ;;
      classic_on|classic_open|both|classic403|classic404|classic403_rules) echo '{"protected":true,"protection":{"enabled":true}}' ;;
      nonadmin) echo '{"protected":true}' ;;
      *) echo '{"protected":false,"protection":{"enabled":false}}' ;;
    esac ;;
  *) exit 1 ;;
esac
STUB
chmod +x "$psd/bpbin/gh"
bpck() { # bpck <name> <BP_CASE> <exp exit> <expected substring>... (script args via BP_ARGS)
  local name="$1" cs="$2" ex="$3" got; shift 3
  (cd "$root" && PATH="$psd/bpbin:$PATH" BP_CASE="$cs" "$bp" ${BP_ARGS:-} >"$out" 2>/dev/null); got=$?
  row branch-protection "$name" "$ex" "$got" 0 "exit code differs"
  local s; for s in "$@"; do grep -qF -- "$s" "$out"; row branch-protection "$name: $s" 0 $? 0 "missing: $s"; done
}
bpck "ruleset with PR and non_fast_forward" ruleset 0 "branch=main" "protected=true" "pr_required=true" "force_push_blocked=true" "source=rules"
bpck "this repo shape: deletion + non_fast_forward" thisrepo 0 "branch=main protected=true pr_required=false force_push_blocked=true" "source=rules"
bpck "classic on and readable, strict values" classic_on 0 "pr_required=true force_push_blocked=true" "source=classic"
bpck "classic on, no reviews, force push allowed" classic_open 0 "pr_required=false force_push_blocked=false" "source=classic"
bpck "classic on and 403 with no rules" classic403 0 "protected=true pr_required=unknown force_push_blocked=unknown"
bpck "classic on and 404 with no rules" classic404 0 "pr_required=unknown force_push_blocked=unknown"
bpck "classic 403 keeps what rules prove" classic403_rules 0 "force_push_blocked=true"
bpck "non-admin JSON without protection key" nonadmin 0 "protected=true" "pr_required=unknown" "force_push_blocked=unknown"
bpck "classic and rules both" both 0 "pr_required=true force_push_blocked=true" "source=both"
bpck "unprotected branch" unprotected 0 "protected=false pr_required=false force_push_blocked=false source=none"
BP_ARGS=develop bpck "explicit branch argument is used" ruleset 0 "branch=develop"
BP_ARGS=develop bpck "explicit branch is not the default" ruleset 0 "source=rules"
grep -qF "branch=develop" "$out" && ! grep -qF "branch=main" "$out"; row branch-protection "explicit branch: default not reported" 0 $? 0 "branch=main leaked"
bpck "api failure on branches/<b> is exit 1" apifail 1
bpck "rules call fails: unknown, not false" rulesfail 0 "protected=true pr_required=unknown force_push_blocked=unknown"
BP_ARGS='main?x=1' bpck "invalid branch name is exit 1" ruleset 1
bpck "gh repo view failure is exit 1" viewfail 1
bpck "output is a single line" ruleset 0
[ "$(wc -l <"$out" | tr -d ' ')" = 1 ]; row branch-protection "summary is exactly one line" 0 $? 0 "expected 1 line"
mkdir -p "$psd/bpnogh"; ln -sf "$(command -v python3)" "$psd/bpnogh/python3"
(cd "$root" && PATH="$psd/bpnogh" /bin/bash "$bp" >/dev/null 2>&1); got=$?
row branch-protection "gh missing from PATH is exit 1" 1 "$got" 0 "expected exit 1"

# --- team-status / team-fix labels: stub gh on PATH, scenario chosen by TS_CASE ---
# Stub contract (the scripts under test must make no other gh call; any other call exits 1):
#   gh auth status --json hosts
#       -> {"hosts":{"<host>":[{"active":bool,"host":..,"login":..,"scopes":"repo, read:org"}]}} (scopes is ONE comma+space string)
#          TS_CASE=loggedout prints {"hosts":{}} and exits 1; loggedout0 prints the same and exits 0 (both mean auth=none).
#          empty prints nothing, nohosts prints {}, autherror sets "state":"failure"; norepo makes repo view fail.
#          The active entry for github.com, or for $GH_HOST when set, decides login and scopes.
#   gh repo view --json nameWithOwner,visibility,viewerPermission
#       -> {"nameWithOwner":"octo/demo","visibility":"PRIVATE","viewerPermission":"ADMIN"} (TS_CASE=write gives WRITE)
#   gh label list --json name --limit 500
#       -> JSON array of {"name":..} for the names in TS_LABELS (comma list; default "bug,enhancement" = no queue label);
#          TS_LABELS=fail exits 1 with stderr.
#   gh label create <name> --color <hex> --description <text>
#       -> exit 0 and prints a URL; when <name> equals TS_CREATE_FAIL it prints
#          `label with name "<name>" already exists` on stderr and exits 1 (no HTTP code, as gh does).
# Every call is logged as one line "$*" to $TS_LOG. `--jq`/`-q` and `--force` are never passed: the stub exits 64.
# The scripts parse raw JSON themselves (python3 -I). GH_HOST is unset by tsck unless TS_HOST is given.
ts="$root/plugins/devkit/scripts/team-status.sh"
tf_="$root/plugins/devkit/scripts/team-fix.sh"
mkdir -p "$psd/tsbin"
cat >"$psd/tsbin/gh" <<'STUB'
#!/bin/sh
[ -n "${TS_LOG:-}" ] && echo "$*" >>"$TS_LOG"
for a in "$@"; do case "$a" in --jq|-q|--force|-f) echo "stub: forbidden flag $a" >&2; exit 64 ;; esac; done
c="${TS_CASE:-ok}"
case "$1 $2" in
  "auth status")
    [ "$3 $4" = "--json hosts" ] || exit 64
    case "$c" in
      loggedout) echo '{"hosts":{}}'; exit 1 ;;
      loggedout0) echo '{"hosts":{}}'; exit 0 ;;
      empty) exit 0 ;;
      nohosts) echo '{}'; exit 0 ;;
      autherror) s="repo"; st=failure ;;
      noscope) s="read:org, gist" ;;
      publicrepo) s="public_repo, gist" ;;
      emptyscopes) s="" ;;
      *) s="repo, read:org, gist" ;;
    esac
    if [ "$c" = twohosts ]; then
      echo '{"hosts":{"github.com":[{"active":true,"host":"github.com","login":"gh-user","scopes":"repo, gist"}],"ghe.example.com":[{"active":false,"host":"ghe.example.com","login":"old-user","scopes":"repo"},{"active":true,"host":"ghe.example.com","login":"ghe-user","scopes":"gist"}]}}'
    else
      printf '{"hosts":{"github.com":[{"state":"%s","active":true,"host":"github.com","login":"octo","scopes":"%s"}]}}\n' "${st:-success}" "$s"
    fi ;;
  "repo view")
    [ "$3" = "--json" ] && [ "$c" != norepo ] || exit 64
    p=ADMIN; [ "$c" = write ] && p=WRITE
    printf '{"nameWithOwner":"octo/demo","visibility":"PRIVATE","viewerPermission":"%s"}\n' "$p" ;;
  "label list")
    [ "${TS_LABELS:-}" = fail ] && { echo "gh: HTTP 500" >&2; exit 1; }
    printf '['; sep=""
    for n in $(echo "${TS_LABELS:-bug,enhancement}" | tr ',' ' '); do printf '%s{"name":"%s"}' "$sep" "$n"; sep=","; done
    echo ']' ;;
  "label create")
    if [ "$3" = "${TS_CREATE_FAIL:-}" ]; then echo "label with name \"$3\" already exists" >&2; exit 1; fi
    echo "https://github.com/octo/demo/labels/$3" ;;
  *) exit 1 ;;
esac
STUB
chmod +x "$psd/tsbin/gh"
all6="ai,severity:critical,severity:high,severity:medium,severity:low,in-progress"
tsck() { # tsck <name> <TS_CASE> <exp exit> <expected substring>... (script TS_SCRIPT default status; args via TS_ARGS; TS_LOG recorded)
  local name="$1" cs="$2" ex="$3" got script="${TS_SCRIPT:-$ts}"; shift 3
  : >"$psd/ts.log"
  (cd "$root" && env -u GH_HOST ${TS_HOST:+GH_HOST=$TS_HOST} PATH="$psd/tsbin:$PATH" TS_CASE="$cs" TS_LOG="$psd/ts.log" "$script" ${TS_ARGS:-} >"$out" 2>/dev/null); got=$?
  row team-status "$name" "$ex" "$got" 0 "exit code differs (script missing?)"
  local s; for s in "$@"; do grep -qF -- "$s" "$out"; row team-status "$name: $s" 0 $? 0 "missing: $s"; done
}
tsline() { # tsline <name> <exact line>: the last tsck output has this line exactly
  grep -qxF -- "$2" "$out"; row team-status "$1" 0 $? 0 "no exact line: $2"
}
tslog() { # tslog <name> <fixed string> <expected count in the gh log>
  local n; n="$(grep -cF -- "$2" "$psd/ts.log")"; [ -s "$psd/ts.log" ] && [ "$n" = "$3" ]; row team-status "$1" 0 $? 0 "log count $n, expected $3 for: $2"
}

# team-status: login and scopes
tsck "logged in with repo scope" ok 0 "auth=ok login=octo" "missing_scopes=-"
tsck "scopes without repo" noscope 0 "auth=ok" "missing_scopes=repo"
tsck "public_repo is not repo" publicrepo 0 "missing_scopes=repo"
tsck "empty scopes are unknown, not missing" emptyscopes 0 "scopes=unknown missing_scopes=unknown"
tsck "two hosts: github.com by default" twohosts 0 "login=gh-user" "missing_scopes=-"
[ -s "$out" ] && ! grep -qF "ghe-user" "$out"; row team-status "default host does not leak ghe login" 0 $? 0 "ghe-user leaked"
TS_HOST=ghe.example.com tsck "two hosts: GH_HOST picks the active entry" twohosts 0 "login=ghe-user" "missing_scopes=repo"
[ -s "$out" ] && ! grep -qE "old-user|gh-user" "$out"; row team-status "GH_HOST: other logins do not leak" 0 $? 0 "wrong login leaked"
tsck "logged out (exit 1) is auth=none" loggedout 0 "auth=none" "permission=unknown" "labels_missing=unknown"
tsck "logged out (exit 0) is auth=none" loggedout0 0 "auth=none" "permission=unknown" "labels_missing=unknown"
tsck "token state failure is auth=error" autherror 0 "auth=error login=octo scopes=- missing_scopes=-" "permission=unknown" "labels_missing=unknown"
tsck "empty auth output is exit 1" empty 1
tsck "auth JSON without hosts is exit 1" nohosts 1
tsck "repo view fails: unknown fields" norepo 0 "repo=unknown visibility=unknown permission=unknown"
tsck "exactly three lines" ok 0 "repo=octo/demo"
[ "$(wc -l <"$out" | tr -d ' ')" = 3 ]; row team-status "output is exactly three lines" 0 $? 0 "expected 3 lines"
# team-status: repo permission and labels
tsck "permission ADMIN and visibility" ok 0 "repo=octo/demo" "visibility=PRIVATE" "permission=ADMIN"
tsck "permission WRITE" write 0 "permission=WRITE"
TS_LABELS="$all6,bug" tsck "all queue labels present" ok 0
tsline "all present: labels_missing=-" "labels_missing=-"
TS_LABELS="ai,severity:high,bug" tsck "some labels present" ok 0
tsline "exact missing list, table order" "labels_missing=severity:critical,severity:medium,severity:low,in-progress"
tsck "no queue label present: all six missing" ok 0
tsline "all six missing, table order" "labels_missing=$all6"
TS_LABELS=fail tsck "label list fails: unknown" ok 0
tsline "label list failure is labels_missing=unknown" "labels_missing=unknown"
# team-status --missing-labels
TS_ARGS=--missing-labels tsck "missing-labels: all six rows" ok 0
for r in "ai${T}5319e7${T}" "severity:critical${T}b60205${T}" "severity:high${T}d93f0b${T}" "severity:medium${T}fbca04${T}" "severity:low${T}c2e0c6${T}" "in-progress${T}1d76db${T}"; do
  grep -q "^${r}[^${T}][^${T}]*$" "$out"; row team-status "missing-labels row: ${r%%$T*}" 0 $? 0 "no name/color/description row"
done
[ "$(wc -l <"$out" | tr -d ' ')" = 6 ]; row team-status "missing-labels: only the six rows" 0 $? 0 "expected 6 lines"
TS_LABELS="ai,severity:critical,severity:high,severity:medium,bug" TS_ARGS=--missing-labels tsck "missing-labels: only absent ones" ok 0
[ "$(wc -l <"$out" | tr -d ' ')" = 2 ] && grep -q "^severity:low${T}c2e0c6${T}" "$out" && grep -q "^in-progress${T}1d76db${T}" "$out"; row team-status "missing-labels lists exactly low, in-progress" 0 $? 0 "wrong rows"
TS_LABELS="$all6" TS_ARGS=--missing-labels tsck "missing-labels: none missing prints nothing" ok 0
[ -s "$psd/ts.log" ] && [ ! -s "$out" ]; row team-status "missing-labels: empty output when complete" 0 $? 0 "expected no output"
# team-fix labels
TS_SCRIPT="$tf_" TS_ARGS=labels TS_LABELS="ai,severity:high,bug" tsck "fix labels: creates only the missing four" ok 0 "action=labels" "label=severity:critical result=created" "label=severity:medium result=created" "label=severity:low result=created" "label=in-progress result=created"
tslog "fix labels: one create per missing label" "label create " 4
tslog "fix labels: critical color and description flag" "label create severity:critical --color b60205 --description" 1
tslog "fix labels: existing ai is not created" "label create ai " 0
tslog "fix labels: existing severity:high is not created" "label create severity:high " 0
[ -s "$psd/ts.log" ] && ! grep -qF -- "--force" "$psd/ts.log"; row team-status "fix labels: never --force" 0 $? 0 "--force in log"
grep -qF "result=created" "$out" && ! grep -qF "label=ai " "$out"; row team-status "fix labels: no output line for ai" 0 $? 0 "ai reported"
TS_SCRIPT="$tf_" TS_ARGS=labels TS_CREATE_FAIL=severity:medium TS_LABELS=bug tsck "fix labels: one create fails, exit 0" ok 0 "label=severity:medium result=failed detail=" "already exists" "label=ai result=created" "label=severity:critical result=created" "label=severity:high result=created" "label=severity:low result=created" "label=in-progress result=created"
tslog "fix labels: failure does not stop the rest" "label create " 6
TS_SCRIPT="$tf_" TS_ARGS=labels TS_LABELS="$all6" tsck "fix labels: nothing missing" ok 0 "result=none_missing"
tslog "fix labels: no create when nothing missing" "label create" 0
TS_SCRIPT="$tf_" TS_ARGS=labels TS_LABELS=fail tsck "fix labels: list fails" ok 0 "action=labels result=failed detail=team-status: cannot list labels"
tslog "fix labels: no create when the list fails" "label create" 0
TS_SCRIPT="$tf_" TS_ARGS=bogus tsck "team-fix: unknown action is exit 1" ok 1
TS_SCRIPT="$tf_" TS_ARGS=bogus2 tsck "team-fix: second unknown action is exit 1" ok 1
mkdir -p "$psd/tfbad"; cp "$tf_" "$psd/tfbad/"; printf '#!/bin/sh\necho "warn\tffffff\tnoise" >&2\nprintf "ai\\tzz\\tx\\nbad\\t5319e7\\n"\n' >"$psd/tfbad/team-status.sh"
TS_SCRIPT="$psd/tfbad/team-fix.sh" TS_ARGS=labels tsck "fix labels: bad rows skipped" ok 0 "label=ai result=failed detail=bad row" "label=bad result=failed detail=bad row"
! grep -qF "label=warn" "$out" && ! grep -qF "label create" "$psd/ts.log"; row team-status "fix labels: stderr is not a row; no create" 0 $? 0 "stderr row or create"
# gh missing from PATH: both scripts exit 1
mkdir -p "$psd/tsnogh"; ln -sf "$(command -v python3)" "$psd/tsnogh/python3"; ln -sf "$(command -v git)" "$psd/tsnogh/git"
(cd "$root" && PATH="$psd/tsnogh" /bin/bash "$ts" >/dev/null 2>&1); got=$?
row team-status "team-status: gh missing is exit 1" 1 "$got" 0 "expected exit 1"
(cd "$root" && PATH="$psd/tsnogh" /bin/bash "$tf_" labels >/dev/null 2>&1); got=$?
row team-status "team-fix labels: gh missing is exit 1" 1 "$got" 0 "expected exit 1"

# --- worktree-status / team-fix prune + remove-worktree: temp repos, stub gh chosen by WT_CASE ---
# Stub contract (the scripts under test must make no other gh call; anything else exits 64):
#   gh pr list --state merged --head <branch> --json headRefOid --limit 1
#       -> [{"headRefOid":"<sha>"}] when "<branch> <sha>" is a line of $WT_PRS, else []; WT_CASE=fail exits 1.
# A wrapper git first on PATH logs each call's argv ("$*") to $WT_GITLOG, then execs the real git.
# Output asserted (worktree-status): header "worktrees=N prunable=N merged=N kept=N gh=ok|unavailable"; one row per extra
#   worktree "<state>\t<branch|->\t<ignored_count>\t<ignored names csv|->\t<path>"; "prune_preview\t<line>" rows.
# Output asserted (team-fix, exit 0 for every outcome): "action=prune result=done pruned=N";
#   "action=remove-worktree result=removed path=<p> branch_kept=<b>" or "... result=refused reason=<state|not_a_worktree|unsafe_path|
#   missing_count|current|ignored_changed>". remove-worktree takes <path> <ignored count shown to the user>.
wts="$root/plugins/devkit/scripts/worktree-status.sh"; wtw="$psd/wtw"; mkdir -p "$psd/wtbin" "$wtw"
printf '#!/bin/sh\n[ "$*" = "pr list --state merged --head $6 --json headRefOid --limit 1" ] || exit 64\n' >"$psd/wtbin/gh"
cat >>"$psd/wtbin/gh" <<'STUB'
[ "${WT_CASE:-}" = fail ] && { echo "gh: HTTP 500" >&2; exit 1; }
s="$(awk -v b="$6" '$1 == b { print $2 }' "$WT_PRS")"
if [ -n "$s" ]; then echo "[{\"headRefOid\":\"$s\"}]"; else echo '[]'; fi
STUB
printf '#!/bin/sh\necho "$*" >>"$WT_GITLOG"\nexec %s "$@"\n' "$(command -v git)" >"$psd/wtbin/git"; chmod +x "$psd/wtbin/gh" "$psd/wtbin/git"
: >"$psd/wt.prs"
wtadd() { # wtadd <branch> <path> [nopr]: worktree with one commit; a merged PR at the tip unless nopr
  git -C "$r" worktree add -q -b "$1" "$2"; echo c >"$2/$1.txt"; git -C "$2" add -A; pgit "$2" commit -q -m c
  [ "${3:-}" = nopr ] || echo "$1 $(git -C "$2" rev-parse HEAD)" >>"$psd/wt.prs"
}
wtrun() { # wtrun <name> <exp exit> <cwd> <WT_CASE> <script> [args]: output to $out; WT_KEEP=1 keeps the git log
  [ -n "${WT_KEEP:-}" ] || : >"$psd/wt.gitlog"; local got
  (cd "$3" && PATH="$psd/wtbin:$PATH" WT_CASE="$4" WT_PRS="$psd/wt.prs" WT_GITLOG="$psd/wt.gitlog" "$5" "${@:6}" >"$out" 2>/dev/null); got=$?
  row worktree-status "$1" "$2" "$got" 0 "exit code differs (script missing or not implemented?)"
}
wtis() { grep -qE -- "$2" "$out"; row worktree-status "$1" 0 $? 0 "no match: $2"; }   # wtis <name> <ERE>
wtno() { ! grep -qE -- "$2" "$out"; row worktree-status "$1" 0 $? 0 "unexpected: $2"; } # wtno <name> <ERE>
wtlog() { grep -qE -- "$2" "$psd/wt.gitlog"; [ "$?" = "$3" ]; row worktree-status "$1" 0 $? 0 "git log check ($3) failed: $2"; } # wtlog <name> <ERE> <grep rc>
mkrepo wt0; wtrun "no extra worktrees" 0 "$r" ok "$wts"; wtis "no extra: header all zero" "^worktrees=0 prunable=0 merged=0 kept=0 gh=ok$"
mkrepo wt; wr="$r"; printf '.env.local\nnode_modules/\n' >>"$wr/.git/info/exclude"; git -C "$wr" branch -q b-newbase
wtadd b-merged "$wtw/mrg"; mkdir -p "$wr/.claude/worktrees"; wtadd b-claude "$wr/.claude/worktrees/cw"
wtadd b-ign "$wtw/ign"; echo s >"$wtw/ign/.env.local"; mkdir -p "$wtw/ign/node_modules/p"; echo s >"$wtw/ign/node_modules/p/i.js"
git -C "$wr" worktree add -q -b b-new "$wtw/newb"
wtadd b-stale "$wtw/stale"; echo m >"$wtw/stale/more.txt"; git -C "$wtw/stale" add -A; pgit "$wtw/stale" commit -q -m after
wtadd b-untr "$wtw/untr"; echo u >"$wtw/untr/u.txt"; wtadd b-trk "$wtw/trk"; echo x >>"$wtw/trk/b-trk.txt"
wtadd b-lock "$wtw/lock"; git -C "$wr" worktree lock "$wtw/lock"; wtadd b-det "$wtw/det"; git -C "$wtw/det" checkout -q --detach
wtadd b-gone "$wtw/gone" nopr; rm -rf "$wtw/gone"
wtrun "status: header counts" 0 "$wr" ok "$wts"; wtis "header: 3 merged 6 kept 1 prunable" "^worktrees=10 prunable=1 merged=3 kept=6 gh=ok$"
wtis "merged: clean tree, PR at the tip" "^merged${T}b-merged${T}0${T}-${T}.*/mrg$"
wtis "merged: under .claude/worktrees" "^merged${T}b-claude${T}0${T}-${T}.*/\.claude/worktrees/cw$"
wtis "prunable: directory deleted" "^prunable${T}b-gone${T}"; wtis "prune_preview row for the deleted one" "^prune_preview${T}.*gone"
wtis "no commits, no PR: kept" "^kept${T}b-new${T}"; wtis "tip differs from merged PR: kept" "^kept${T}b-stale${T}"
wtis "untracked file: kept" "^kept${T}b-untr${T}"; wtis "tracked change: kept" "^kept${T}b-trk${T}"
wtis "locked: kept" "^kept${T}b-lock${T}"; wtis "detached: kept, branch -" "^kept${T}-${T}"
wtis "ignored: count 2" "^merged${T}b-ign${T}2${T}"; wtis "ignored: .env.local named" "^merged${T}b-ign${T}2${T}.*\.env\.local"; wtis "ignored: node_modules named" "^merged${T}b-ign${T}2${T}.*node_modules"
wtrun "status from inside a merged worktree" 0 "$wtw/mrg" ok "$wts"; wtis "current worktree is kept" "^kept${T}b-merged${T}"
wtrun "gh failing" 0 "$wr" fail "$wts"; wtis "gh fails: unavailable, only prunable stays" "^worktrees=10 prunable=1 merged=0 kept=9 gh=unavailable$"; wtno "gh fails: no merged row" "^merged${T}"
mkdir -p "$psd/wtnogh"; for c in git python3 awk dirname; do ln -sf "$(command -v $c)" "$psd/wtnogh/$c"; done
(cd "$wr" && PATH="$psd/wtnogh" /bin/bash "$wts" >"$out" 2>/dev/null); got=$?; row worktree-status "gh missing is exit 0" 0 "$got" 0 "exit code differs"
wtis "gh missing: unavailable, none merged" "^worktrees=10 prunable=1 merged=0 kept=9 gh=unavailable$"
# team-fix remove-worktree refusals, then removal, then prune (order matters: they mutate $wr)
tfw() { WT_KEEP=1 wtrun "$1" 0 "${4:-$wr}" ok "$tf_" remove-worktree "$2" "$3"; }; : >"$psd/wt.gitlog" # tfw <name> <path> <count> [cwd]
tfw "remove: kept worktree refused" "$wtw/trk" 0; wtis "remove: kept reason" "^action=remove-worktree result=refused reason=kept$"
tfw "remove: main worktree refused" "$wr" 0; wtis "remove: main is not_a_worktree" "reason=not_a_worktree"
tfw "remove: non-worktree path refused" "$psd" 0; wtis "remove: plain dir is not_a_worktree" "reason=not_a_worktree"
tfw "remove: current worktree refused" "$wtw/mrg" 0 "$wtw/mrg"; wtis "remove: current is refused" "^action=remove-worktree result=refused reason=current$"
tfw "remove: newline in path refused" "$wtw/a"$'\n'"b" 0; wtis "remove: newline reason" "reason=unsafe_path"
tfw "remove: ignored count changed refused" "$wtw/ign" 1; wtis "remove: ignored_changed reason" "^action=remove-worktree result=refused reason=ignored_changed$"
tfw "remove: missing count refused" "$wtw/mrg" ""; wtis "remove: missing_count reason" "^action=remove-worktree result=refused reason=missing_count$"
tfw "remove: non-numeric count refused" "$wtw/mrg" x1; wtis "remove: non-numeric is missing_count" "^action=remove-worktree result=refused reason=missing_count$"
tfw "remove: 2^64 count refused" "$wtw/mrg" 18446744073709551616; wtis "remove: overlong count is missing_count" "^action=remove-worktree result=refused reason=missing_count$"
wtlog "refusals never ran worktree remove" "worktree remove" 1; [ -d "$wtw/trk" ] && [ -d "$wtw/mrg" ] && [ -d "$wtw/ign" ]; row worktree-status "refused worktrees still on disk" 0 $? 0 "directory removed"
tfw "remove: merged worktree removed" "$wtw/mrg" 0; wtis "remove: removed line" "^action=remove-worktree result=removed path=.*/mrg branch_kept=b-merged$"
[ ! -d "$wtw/mrg" ] && git -C "$wr" rev-parse -q --verify refs/heads/b-merged >/dev/null; row worktree-status "removed: dir gone, branch kept" 0 $? 0 "dir or branch wrong"
wtlog "removal ran git worktree remove --" "worktree remove -- " 0; wtlog "removal never used --force" "(--force| -f( |$))" 1
wtrun "prune removes the prunable entry" 0 "$wr" ok "$tf_" prune; wtis "prune: done, one pruned" "^action=prune result=done pruned=1$"
git -C "$wr" worktree list --porcelain | grep -qF "/gone"; [ "$?" = 1 ]; row worktree-status "prune: gone entry dropped from git" 0 $? 0 "still listed"
wtlog "prune never used --force" "--force" 1
mkrepo wtpr; wtadd p-gone "$psd/wtpr-gone" nopr; rm -rf "$psd/wtpr-gone"
(cd "$r" && PATH="$psd/wtnogh" /bin/bash "$tf_" prune >"$out" 2>/dev/null); got=$?; row worktree-status "prune: gh missing is exit 0" 0 "$got" 0 "exit code differs"
wtis "prune: gh missing still prunes" "^action=prune result=done pruned=1$"
# not a git repository: exit 1
mkdir -p "$psd/wtnogit"; wtrun "status outside a git repo is exit 1" 1 "$psd/wtnogit" ok "$wts"
# clean check ignores the user's untracked-files config and catches skip-worktree / assume-unchanged edits
mkrepo wtc; git -C "$r" config status.showUntrackedFiles no; wtadd c-ok "$wtw/c-ok"; wtadd c-untr "$wtw/c-untr"; echo u >"$wtw/c-untr/u.txt"
wtadd c-skip "$wtw/c-skip"; git -C "$wtw/c-skip" update-index --skip-worktree c-skip.txt; echo e >>"$wtw/c-skip/c-skip.txt"
wtadd c-asm "$wtw/c-asm"; git -C "$wtw/c-asm" update-index --assume-unchanged c-asm.txt; echo e >>"$wtw/c-asm/c-asm.txt"
wtrun "clean check: status" 0 "$r" ok "$wts"; wtis "clean check: 1 merged 3 kept" "^worktrees=4 prunable=0 merged=1 kept=3 gh=ok$"
wtis "showUntrackedFiles=no + untracked file: kept" "^kept${T}c-untr${T}"; wtis "skip-worktree edit: kept" "^kept${T}c-skip${T}"
wtis "assume-unchanged edit: kept" "^kept${T}c-asm${T}"; wtis "control: clean worktree merged" "^merged${T}c-ok${T}"
WT_KEEP=1 wtrun "remove: hidden untracked refused" 0 "$r" ok "$tf_" remove-worktree "$wtw/c-untr" 0
wtis "remove: hidden untracked is kept" "reason=kept$"; [ -f "$wtw/c-untr/u.txt" ]; row worktree-status "hidden untracked file still on disk" 0 $? 0 "file removed"
# ignored nested git repository: removal would delete its history, so the row is kept
mkrepo wtn; echo 'nested/' >>"$r/.git/info/exclude"; wtadd n-nest "$wtw/n-nest"; git init -q "$wtw/n-nest/nested"
echo n >"$wtw/n-nest/nested/n.txt"; git -C "$wtw/n-nest/nested" add -A; pgit "$wtw/n-nest/nested" commit -q -m n
wtrun "nested repo: status" 0 "$r" ok "$wts"; wtis "ignored nested repo: kept" "^kept${T}n-nest${T}1${T}nested/${T}"
WT_KEEP=1 wtrun "remove: nested repo refused" 0 "$r" ok "$tf_" remove-worktree "$wtw/n-nest" 1
wtis "remove: nested repo is kept" "reason=kept$"; [ -e "$wtw/n-nest/nested/.git" ]; row worktree-status "nested .git still on disk" 0 $? 0 "nested repo removed"
# nested repo below an ignored dir (listing collapses to build/) and one with a name git quotes (né/)
mkrepo wtn2; printf 'build/\nn\303\251/\n' >>"$r/.git/info/exclude"; wtadd n-deep "$wtw/n-deep"; wtadd n-utf "$wtw/n-utf"
for d in "$wtw/n-deep/build/sub" "$wtw/n-utf/né"; do git init -q "$d"; echo n >"$d/n.txt"; git -C "$d" add -A; pgit "$d" commit -q -m n; done
echo b >"$wtw/n-deep/build/out.txt"
wtrun "deep/quoted nested repo: status" 0 "$r" ok "$wts"; wtis "nested repo below ignored dir: kept" "^kept${T}n-deep${T}1${T}build/${T}"
wtis "non-ASCII nested repo: kept, name unescaped" "^kept${T}n-utf${T}1${T}né/${T}"
WT_KEEP=1 wtrun "remove: deep nested repo refused" 0 "$r" ok "$tf_" remove-worktree "$wtw/n-deep" 1
wtis "remove: deep nested repo is kept" "reason=kept$"; [ -e "$wtw/n-deep/build/sub/.git" ]; row worktree-status "deep nested .git still on disk" 0 $? 0 "nested repo removed"
WT_KEEP=1 wtrun "remove: non-ASCII nested repo refused" 0 "$r" ok "$tf_" remove-worktree "$wtw/n-utf" 1
wtis "remove: non-ASCII nested repo is kept" "reason=kept$"; [ -e "$wtw/n-utf/né/.git" ]; row worktree-status "non-ASCII nested .git still on disk" 0 $? 0 "nested repo removed"
# symlinked temp dir: realpath comparison
mkrepo wsym; ln -s "$r" "$psd/wsymrepo"; wtadd s-a "$psd/wsym-a"; wtadd s-b "$psd/wsym-b"; ln -s "$psd/wsym-a" "$psd/wsymlink-a"
wtrun "status via symlinked repo path" 0 "$psd/wsymrepo" ok "$wts"; wtis "symlinked repo: merged" "^merged${T}s-a${T}"
wtrun "remove via symlinked worktree path" 0 "$psd/wsymrepo" ok "$tf_" remove-worktree "$psd/wsymlink-a" 0; wtis "symlink path removed" "result=removed .*branch_kept=s-a$"
wtrun "remove via realpath form" 0 "$psd/wsymrepo" ok "$tf_" remove-worktree "$(python3 -c 'import os,sys; print(os.path.realpath(sys.argv[1]))' "$psd/wsym-b")" 0; wtis "realpath form removed" "result=removed .*branch_kept=s-b$"

# --- team-fix ruleset: stub gh on PATH, scenario chosen by TF_CASE, data by TF_LIST/TF_LIST2/TF_GET/TF_GET2/TF_CAN ---
# Stub contract (the script under test may make no other gh call; anything else exits 64):
#   gh repo view --json ...  -> {"nameWithOwner","visibility","viewerPermission":"ADMIN"} (TF_CASE=write gives WRITE); auth status / label list
#       answer too, in case the script reuses team-status.sh. gh api is never used for the permission.
#   TF_CASE=viewfail: repo view fails (stderr "gh: repo view failed")
#   gh api 'repos/{owner}/{repo}/rulesets?includes_parents=true&targets=branch&per_page=100'  (query in the PATH, never via -f) -> $TF_LIST,
#       the second and later calls -> $TF_LIST2 when set
#   gh api repos/{owner}/{repo}/rulesets/<id>  -> $TF_GET; after a successful write -> $TF_GET2, else the last body sent plus id and
#       current_user_can_bypass=$TF_CAN (default never); TF_CASE=rbfail: that GET prints {"message":"Not Found"}, stderr HTTP 404, exit 1
#   gh api -X POST repos/{owner}/{repo}/rulesets --input <file>  -> {"id":77} ({} with TF_CASE=noid);  gh api -X PUT .../rulesets/<id> --input <file>
#   TF_CASE=w422 / w422b / w422f / w403: every write fails with stderr "gh: Validation Failed (HTTP 422)" (+ a second line) and, like gh api for
#   non-2xx, the error body on stdout: generic (w422), naming bypass actors (w422b), or field bypass_actors code invalid, no message (w422f) / stderr "gh: Must have admin rights (HTTP 403)" (+ a second line), no body
# Every call is logged as "$*" to $TF_LOG; each --input file is copied to $TF_LOG.<n>.json (n = 1, 2, ...). A call with --input, -f, -F,
# --field or --raw-field and no explicit -X POST|PUT is an implicit gh write: the stub exits 99 and creates $TF_LOG.illegal.
mkdir -p "$psd/tfbin"
cat >"$psd/tfbin/gh" <<'STUB'
#!/bin/sh
echo "$*" >>"$TF_LOG"
c="${TF_CASE:-ok}"; m=GET; w=0; prev=""; path=""; inp=""
for a in "$@"; do
  case "$prev" in -X) m="$a" ;; --input) inp="$a" ;; esac
  case "$a" in --input|-f|-F|--field|--raw-field) w=1 ;; repos/*) path="$a" ;; esac
  prev="$a"
done
case "$1 $2" in
  "auth status") echo '{"hosts":{"github.com":[{"state":"success","active":true,"host":"github.com","login":"octo","scopes":"repo"}]}}'; exit 0 ;;
  "label list") echo '[]'; exit 0 ;;
  "repo view") p=ADMIN; [ "$c" = write ] && p=WRITE; [ "$c" = viewfail ] && { echo "gh: repo view failed" >&2; exit 1; }
    printf '{"nameWithOwner":"octo/demo","visibility":"PRIVATE","viewerPermission":"%s"}\n' "$p"; exit 0 ;;
esac
[ "$1" = api ] || exit 64
if [ "$w" = 1 ]; then case "$m" in POST|PUT) ;; *) : >"$TF_LOG.illegal"; echo "stub: implicit write" >&2; exit 99 ;; esac; fi
case "$m $path" in
  "GET repos/"*"/rulesets?includes_parents=true&targets=branch&per_page=100")
    echo x >>"$TF_LOG.l"
    if [ "$(wc -l <"$TF_LOG.l")" -gt 1 ] && [ -n "${TF_LIST2:-}" ]; then printf '%s\n' "$TF_LIST2"; else printf '%s\n' "${TF_LIST:-[]}"; fi ;;
  "GET repos/"*"/rulesets/"[0-9]*)
    if [ ! -e "$TF_LOG.w" ]; then if [ -n "${TF_GET:-}" ]; then printf '%s\n' "$TF_GET"; else echo '{}'; fi
    elif [ "$c" = rbfail ]; then echo '{"message":"Not Found"}'; echo "gh: Not Found (HTTP 404)" >&2; exit 1
    elif [ -n "${TF_GET2:-}" ]; then printf '%s\n' "$TF_GET2"
    else python3 -I -c 'import json,sys; d=json.load(open(sys.argv[1])); d.update(id=int(sys.argv[3]),current_user_can_bypass=sys.argv[2],source_type="Repository"); print(json.dumps(d))' "$TF_LOG.last" "${TF_CAN:-never}" "${path##*/}"; fi ;;
  "POST repos/"*"/rulesets"|"PUT repos/"*"/rulesets/"[0-9]*)
    [ -f "$inp" ] || exit 64
    cp "$inp" "$TF_LOG.$(( $(ls "$TF_LOG".*.json 2>/dev/null | wc -l) + 1 )).json"; cp "$inp" "$TF_LOG.last"
    case "$c" in
      w422*) echo "gh: Validation Failed (HTTP 422)" >&2; echo "second line" >&2; e='{"resource":"Ruleset","code":"invalid","field":"rules"}'
        [ "$c" = w422b ] && e='"Invalid Bypass Actors: actor_id 5"'; [ "$c" = w422f ] && e='{"field":"bypass_actors","code":"invalid"}'; printf '{"message":"Validation Failed","errors":[%s]}\n' "$e"; exit 1 ;;
      w403) echo "gh: Must have admin rights (HTTP 403)" >&2; echo "second line" >&2; exit 1 ;;
    esac
    : >"$TF_LOG.w"; if [ "$c" = noid ]; then echo '{}'; elif [ "$m" = POST ]; then echo '{"id":77}'; else cat "$inp"; fi ;;
  *) exit 64 ;;
esac
STUB
chmod +x "$psd/tfbin/gh"
OWN='devkit: protect default branch'
li() { printf '{"id":%s,"name":"%s","source_type":"%s","enforcement":"active"}' "$1" "$2" "${3:-Repository}"; } # li <id> <name> [source_type]
det() { printf '{"id":11,"name":"%s","target":"branch","source_type":"Repository","source":"octo/demo","node_id":"N","_links":{},"created_at":"t","updated_at":"t","current_user_can_bypass":"never","enforcement":"%s","bypass_actors":%s,"conditions":{"ref_name":{"include":["~DEFAULT_BRANCH"],"exclude":[]}},"rules":[%s]}' "$OWN" "$1" "${3:-[]}" "$2"; } # det <enforcement> <rules> [actors]
NFF='{"type":"non_fast_forward"}'; SC='{"type":"required_status_checks","parameters":{"required_status_checks":[{"context":"ci"}],"strict_required_status_checks_policy":true}}'
PR2='{"type":"pull_request","parameters":{"required_approving_review_count":2,"dismiss_stale_reviews_on_push":true,"require_code_owner_review":true,"require_last_push_approval":false,"required_review_thread_resolution":true}}'
ADM='{"actor_id":5,"actor_type":"RepositoryRole","bypass_mode":"always"}'; OLD='{"actor_id":1,"actor_type":"Team","bypass_mode":"pull_request"}'
BODY='(pr:=next(r for r in d["rules"] if r["type"]=="pull_request")) and sorted(pr["parameters"])==sorted(["dismiss_stale_reviews_on_push","require_code_owner_review","require_last_push_approval","required_approving_review_count","required_review_thread_resolution"]) and any(r["type"]=="non_fast_forward" for r in d["rules"]) and d["target"]=="branch" and d["enforcement"]=="active" and d["conditions"]["ref_name"]["include"]==["~DEFAULT_BRANCH"]'
SIX='sorted(d)==sorted(["name","target","enforcement","bypass_actors","conditions","rules"])'; C0='pr["parameters"]["required_approving_review_count"]==0'
tfck() { # tfck <name> <TF_CASE> <exp exit> <substring>... (TF_ARGS = action args; TF_RO=1 also asserts no write flag in the log)
  local name="$1" cs="$2" ex="$3" got s; shift 3
  rm -f "$psd"/tf.log*; : >"$psd/tf.log"
  (cd "$root" && env -u GH_HOST PATH="$psd/tfbin:$PATH" TF_CASE="$cs" TF_LOG="$psd/tf.log" "$tf_" ruleset ${TF_ARGS:-} >"$out" 2>/dev/null); got=$?
  row team-fix "$name" "$ex" "$got" 0 "exit code differs"
  [ ! -e "$psd/tf.log.illegal" ]; row team-fix "$name: no implicit gh write" 0 $? 0 "gh api write without -X"
  for s in "$@"; do grep -qF -- "$s" "$out"; row team-fix "$name: $s" 0 $? 0 "missing: $s"; done
  [ -z "${TF_RO:-}" ] || { ! grep -qE -e '(^| )-X (POST|PUT)( |$)' -e '(^| )(--input|-f|-F|--field|--raw-field)( |=|$)' "$psd/tf.log"; row team-fix "$name: read-only log" 0 $? 0 "write flag in log"; }
}
tfl() { local n; n="$(grep -cE -- "$2" "$psd/tf.log")"; [ -s "$psd/tf.log" ] && [ "$n" = "$3" ]; row team-fix "$1" 0 $? 0 "log count $n, expected $3 for: $2"; } # tfl <name> <ERE> <count>
tfj() { python3 -I -c 'import json,sys; d=json.load(open(sys.argv[1])); sys.exit(0 if eval(sys.argv[2]) else 1)' "$psd/tf.log.$2.json" "$3" 2>/dev/null; row team-fix "$1" 0 $? 0 "body check failed: ${3:0:60}"; } # tfj <name> <n> <python expr over d>
POST=' -X POST '; PUT=' -X PUT '
# permission, create, foreign and organization rulesets, ambiguous
tfck "ruleset: WRITE permission is refused" write 0 "action=ruleset result=refused reason=not_admin"
tfl "ruleset refused: no gh api call" '^api ' 0
TF_ARGS=--dry-run tfck "ruleset dry-run: WRITE is refused" write 0 "action=ruleset result=refused reason=not_admin"
tfl "ruleset dry-run refused: no gh api call" '^api ' 0
tfck "ruleset: no rulesets creates" ok 0 "action=ruleset result=created rules_added=pull_request,non_fast_forward bypass=none others=-"
tfl "create: one POST, no PUT" "$POST.*rulesets --input " 1; tfl "create: no PUT" "$PUT" 0
tfl "create: list query is in the path, no field flags" 'api repos/.*/rulesets\?includes_parents=true&targets=branch&per_page=100$' 1
tfj "create: body has both rules, 5 params, count 0" 1 "$BODY and $C0 and d['name']=='$OWN' and d['bypass_actors']==[]"
TF_LIST="[$(li 25369692 kit)]" tfck "ruleset: only foreign kit is not edited" ok 0 "result=created" "others=kit"
tfl "foreign kit: POST, no PUT" "$POST" 1; tfl "foreign kit: no write to its id" "25369692 --input" 0
TF_LIST="[$(li 900 "$OWN" Organization)]" tfck "ruleset: organization ruleset with our name" ok 0 "result=created" "others=devkit:%20protect%20default%20branch"
tfl "org ruleset ignored: POST, no PUT" "$POST" 1; tfl "org ruleset ignored: no PUT" "$PUT" 0
TF_RO=1 TF_LIST="[$(li 11 "$OWN"),$(li 12 "$OWN")]" tfck "ruleset: two own rulesets are ambiguous" ok 0 "action=ruleset result=ambiguous rules_added=- bypass=none others=-"
# update: PUT keeps existing parameters and bypass actors, adds only what is missing
TF_LIST="[$(li 11 "$OWN")]" TF_GET="$(det active "$SC,$NFF" "[$OLD]")" tfck "ruleset: own NFF-only is updated" ok 0 "action=ruleset result=updated rules_added=pull_request bypass=none others=-"
tfl "update: one PUT to the id, no POST" "$PUT.*rulesets/11 --input " 1; tfl "update: no POST" "$POST" 0
tfj "update: exactly the six editable keys" 1 "$SIX"; tfj "update: pull_request added with 5 params, count 0" 1 "$BODY and $C0"
tfj "update: status check parameters kept" 1 'any(r["type"]=="required_status_checks" and r["parameters"]["required_status_checks"][0]["context"]=="ci" and r["parameters"]["strict_required_status_checks_policy"] is True for r in d["rules"])'
tfj "update: existing bypass actor kept" 1 "d['bypass_actors']==[$OLD]"
TF_LIST="[$(li 11 "$OWN")]" TF_GET="$(det active "$PR2")" tfck "ruleset: own PR-only gets non_fast_forward" ok 0 "result=updated rules_added=non_fast_forward"
tfj "update: custom pull_request parameters kept" 1 "$SIX and $BODY and pr['parameters']['required_approving_review_count']==2 and pr['parameters']['require_code_owner_review'] is True"
TF_RO=1 TF_LIST="[$(li 11 "$OWN")]" TF_GET="$(det active "$NFF,$PR2")" tfck "ruleset: own with both rules is unchanged" ok 0 "result=unchanged rules_added=- bypass=none"
for e in disabled evaluate; do TF_RO=1 TF_LIST="[$(li 11 "$OWN")]" TF_GET="$(det $e "$NFF")" tfck "ruleset: own $e is left alone" ok 0 "result=disabled rules_added=-"; done
TF_LIST="[$(li 11 "$OWN")]" TF_GET="$(det active "$NFF")" TF_GET2="$(det active "$SC")" tfck "ruleset: PUT read-back lacks a rule" ok 0 "result=conflict"
tfl "conflict: one PUT, no retry" "$PUT" 1
# failures
TF_LIST='[]' TF_LIST2="[$(li 11 "$OWN")]" tfck "ruleset: POST 422 then own exists" w422 0 "result=existed"
tfl "existed: one POST, list read twice" "$POST" 1; tfl "existed: list called twice" 'includes_parents=true&targets=branch&per_page=100$' 2
TF_ARGS=--admin-bypass TF_LIST2='[]' tfck "ruleset: POST 422 naming bypass actors" w422b 0 "result=bypass_rejected" "detail=Validation Failed: Invalid Bypass Actors: actor_id 5"
[ "$(wc -l <"$out" | tr -d ' ')" = 1 ] && ! grep -qF "second line" "$out"; row team-fix "bypass_rejected: one-line detail" 0 $? 0 "multi-line output"
TF_LIST2='[]' tfck "ruleset: POST 422 without bypass fails" w422b 0 "result=failed" "detail=Validation Failed: Invalid Bypass Actors: actor_id 5"
[ "$(wc -l <"$out" | tr -d ' ')" = 1 ] && ! grep -qF "second line" "$out"; row team-fix "failed: one-line detail" 0 $? 0 "multi-line output"
tfck "ruleset: POST 403 fails, exit 0" w403 0 "result=failed" "detail=gh: Must have admin rights (HTTP 403)"
[ "$(wc -l <"$out" | tr -d ' ')" = 1 ] && ! grep -qF "second line" "$out"; row team-fix "403: one-line stderr detail" 0 $? 0 "multi-line output"
TF_ARGS=--admin-bypass TF_LIST="[$(li 11 "$OWN")]" TF_GET="$(det active "$NFF")" tfck "ruleset: PUT 422 naming bypass actors" w422b 0 "result=bypass_rejected" "detail=Validation Failed: Invalid Bypass Actors: actor_id 5"
TF_ARGS=--admin-bypass TF_LIST2='[]' tfck "ruleset: generic 422 with --admin-bypass fails" w422 0 "result=failed" "detail=Validation Failed: rules: invalid"
TF_LIST="[$(li 11 "$OWN")]" TF_GET="$(det active "$NFF")" tfck "ruleset: PUT 422 without bypass fails" w422 0 "result=failed" "detail=Validation Failed: rules: invalid"
TF_ARGS=--admin-bypass TF_LIST2='[]' tfck "ruleset: 422 bypass_actors code only" w422f 0 "result=bypass_rejected" "detail=Validation Failed: bypass_actors: invalid"
TF_ARGS=--admin-bypass TF_LIST="[$(li 11 "$OWN")]" TF_GET="$(det active "$NFF" "[$ADM,$OLD]")" tfck "ruleset: Admin actor not added by this run, 422 naming actor" w422b 0 "result=failed" "detail=Validation Failed: Invalid Bypass"
TF_LIST="[$(li 11 "$OWN")]" TF_GET="$(det bogus "$NFF")" tfck "ruleset: unknown enforcement" ok 0 "result=failed detail=ruleset read is not devkit"; tfl "unknown enforcement: no PUT" "$PUT" 0
TF_LIST="[$(for i in $(seq 100); do li "$i" "n$i"; echo; done | paste -sd, -)]" tfck "ruleset: 100 rulesets fail" ok 0 "result=failed detail=100 or more"; tfl "100 rulesets: no write" "$POST|$PUT" 0
TF_ARGS=--force tfck "ruleset: unknown flag is exit 1" ok 1; [ ! -s "$psd/tf.log" ]; row team-fix "unknown flag: no gh call" 0 $? 0 "gh called"
TF_RO=1 TF_ARGS=--dry-run TF_LIST="[$(li 5 'a\tb\u007f,c=d%')]" tfck "ruleset: others= encodes controls, DEL, comma, =, %" ok 0 "others=a%09b%7F%2Cc%3Dd%25"
TF_RO=1 TF_ARGS=--dry-run TF_LIST="[$(for i in $(seq 30); do li "$i" "n n n n $i"; echo; done | paste -sd, -)]" tfck "ruleset: long others= is cut after a whole name" ok 0 ",…"
o="$(sed 's/.*others=//' "$out")"; [ "$(printf '%s' "$o" | wc -c)" -le 200 ] && case "$o" in *%,…|*%?,…) false ;; *,…) true ;; *) false ;; esac; row team-fix "long others=: at most 200 bytes, no split %XX" 0 $? 0 "bad cut: $o"
TF_RO=1 TF_ARGS=--admin-bypass TF_LIST="[$(li 11 "$OWN")]" TF_GET="$(det active "$NFF,$PR2" "[$ADM]" | sed 's/"never"/"always"/')" tfck "ruleset: bypass already present, can bypass" ok 0 "result=unchanged rules_added=- bypass=verified"
# W1: a GET that is not devkit's own complete ruleset never turns into a PUT
TF_LIST="[$(li 11 "$OWN")]" tfck "ruleset: own listed, GET is {}" ok 0 "result=failed detail=ruleset read is not devkit"; tfl "GET {}: no PUT" "$PUT" 0
TF_LIST="[$(li 11 "$OWN")]" TF_GET='{"id":11,"name":"'"$OWN"'","source_type":"Repository","enforcement":"active","rules":null,"bypass_actors":[],"conditions":{}}' tfck "ruleset: GET with null rules" ok 0 "result=failed"
tfl "null rules: no PUT" "$PUT" 0
TF_LIST="[$(li 12 "$OWN")]" TF_GET="$(det active "$NFF")" tfck "ruleset: GET id differs from the listed id" ok 0 "result=failed"; tfl "id differs: no PUT" "$PUT" 0
TF_LIST='{"message":"x"}' tfck "ruleset: list response not a list" ok 0 "result=failed detail=ruleset list is not a list"; tfl "list not a list: no write" "$POST|$PUT" 0
tfck "ruleset: POST response without id" noid 0 "result=created rules_added=pull_request,non_fast_forward bypass=none others=- detail=no ruleset id to read back"
tfck "ruleset: read-back GET fails" rbfail 0 "result=created" "detail=read-back failed: gh: Not Found (HTTP 404)"
tfck "ruleset: repo view fails" viewfail 0 "action=ruleset result=failed detail=gh: repo view failed"; tfl "repo view fails: no gh api call" '^api ' 0
# --admin-bypass
TF_ARGS=--admin-bypass TF_CAN=always tfck "ruleset: bypass read back always" ok 0 "result=created rules_added=pull_request,non_fast_forward bypass=verified"
tfj "bypass: body carries the Admin role actor" 1 "{'actor_id':5,'actor_type':'RepositoryRole','bypass_mode':'always'} in d['bypass_actors'] and $BODY"
TF_ARGS=--admin-bypass TF_CAN=never tfck "ruleset: bypass read back never" ok 0 "result=created" "bypass=unverified"
TF_ARGS=--admin-bypass TF_CAN=always TF_LIST="[$(li 11 "$OWN")]" TF_GET="$(det active "$NFF,$PR2" "[$OLD]")" tfck "ruleset: bypass added to a complete ruleset" ok 0 "result=updated rules_added=- bypass=verified"
tfj "bypass PUT: old actor kept, Admin added" 1 "d['bypass_actors']==[$OLD,$ADM] and $SIX"
A5='{"actor_id":5,"actor_type":"RepositoryRole","bypass_mode":"pull_request"}'
TF_ARGS=--admin-bypass TF_LIST="[$(li 11 "$OWN")]" TF_GET="$(det active "$NFF" "[$A5]" | sed -e 's/~DEFAULT_BRANCH/refs\/heads\/dev/' -e 's/"target":"branch"/"target":"push"/')" tfck "ruleset: Admin actor exists, edited conditions" ok 0 "result=updated rules_added=pull_request"
tfj "bypass PUT: Admin not duplicated; own conditions and target kept" 1 "d['bypass_actors']==[$A5] and d['conditions']['ref_name']['include']==['refs/heads/dev'] and d['target']=='push'"
# --dry-run: only reads
TF_RO=1 TF_ARGS=--dry-run tfck "ruleset dry-run: nothing exists" ok 0 "action=ruleset result=would_create rules_added=pull_request,non_fast_forward bypass=none others=-"
TF_RO=1 TF_ARGS=--dry-run TF_LIST="[$(li 25369692 kit),$(li 11 "$OWN")]" TF_GET="$(det active "$NFF")" tfck "ruleset dry-run: own NFF-only" ok 0 "result=would_update rules_added=pull_request" "others=kit"
TF_RO=1 TF_ARGS=--dry-run TF_LIST="[$(li 11 "$OWN")]" TF_GET="$(det active "$NFF,$PR2")" tfck "ruleset dry-run: complete" ok 0 "result=unchanged rules_added=-"
TF_RO=1 TF_ARGS=--dry-run TF_LIST="[$(li 11 "$OWN")]" TF_GET="$(det disabled "$NFF")" tfck "ruleset dry-run: disabled" ok 0 "result=disabled"
TF_RO=1 TF_ARGS=--dry-run TF_LIST="[$(li 11 "$OWN"),$(li 12 "$OWN")]" tfck "ruleset dry-run: ambiguous" ok 0 "result=ambiguous"
(cd "$root" && PATH="$psd/tsnogh" /bin/bash "$tf_" ruleset >/dev/null 2>&1); got=$?
row team-fix "team-fix ruleset: gh missing is exit 1" 1 "$got" 0 "expected exit 1"

# --- metrics: stub gh chosen by MX_CASE; the fixture JSON comes from MX_FIX ---
mx="$root/plugins/devkit/scripts/metrics.sh"
mkdir -p "$psd/mxbin"
cat >"$psd/mxbin/gh" <<'STUB'
#!/usr/bin/env bash
# Stub gh for metrics.sh. Allowed calls: "auth status" (fails when MX_CASE=noauth) and "pr list" (prints $MX_FIX, or
# garbage when MX_CASE=badjson, or fails when MX_CASE=prfail). Every call is logged to $MX_LOG; anything else exits 1.
echo "$*" >>"${MX_LOG:-/dev/null}"
case "$1 $2" in
  "auth status") [ "${MX_CASE:-}" != noauth ] || exit 1 ;;
  "pr list") case "${MX_CASE:-}" in badjson) echo 'not json' ;; prfail) exit 1 ;; *) cat "$MX_FIX" ;; esac ;;
  *) exit 1 ;;
esac
STUB
chmod +x "$psd/mxbin/gh"
mxfix() { # mxfix <python expr using pr(n, merged, files, cf=None, revs=0, title="t")>: write the fixture
  python3 -c '
import json, sys
def pr(n, m="2026-10-12T10:00:00Z", files=(), cf=None, revs=0, title="t"):
    fs = [{"path": p, "additions": a, "deletions": d} for p, a, d in files]
    return {"number": n, "title": title, "mergedAt": m, "changedFiles": len(fs) if cf is None else cf, "files": fs,
            "reviews": [{"state": "CHANGES_REQUESTED" if i < 2 else "APPROVED", "body": "secret"} for i in range(revs)]}
json.dump(eval(sys.argv[1]), open(sys.argv[2], "w"))' "$1" "$psd/mx.json"
}
mxck() { # mxck <name> <MX_CASE> <exp exit> <expected substring>... (dir MX_DIR, script MX_SCRIPT, args MX_ARGS; stderr in $out2)
  local name="$1" cs="$2" ex="$3" got s; shift 3; : >"$psd/mx.log"
  (cd "${MX_DIR:-$r}" && PATH="$psd/mxbin:$PATH" MX_CASE="$cs" MX_FIX="$psd/mx.json" MX_LOG="$psd/mx.log" \
    "${MX_SCRIPT:-$mx}" ${MX_ARGS---since 2026-10-10} >"$out" 2>"$out2"); got=$?
  row metrics "$name" "$ex" "$got" 0 "exit code differs (script missing?)"
  for s in "$@"; do grep -qF -- "$s" "$out" "$out2"; row metrics "$name: $s" 0 $? 0 "missing: $s"; done
}
mkrepo mxr; L1="[('a.js',10,5),('package-lock.json',500,0)]"
mxfix "[pr(1,files=$L1,title='one'),pr(2,files=[('b.js',20,0)],revs=3)]"
mxck "two PRs, lock file excluded" ok 0 "since=2026-10-10 until=" "prs_merged=2 prs_truncated=0" "size_n=2 size_missing=0 lines_median=15 lines_p90=20 files_median=1 files_p90=1 over_limit=0 max_lines=300 max_files=10" "capped_items=0" "#1${T}15${T}1${T}-${T}0${T}one" "#2${T}20${T}1${T}-${T}2${T}t"
[ "$(grep -n '^#2' "$out" | cut -d: -f1)" -lt "$(grep -n '^#1' "$out" | cut -d: -f1)" ]; row metrics "rows: highest PR number first" 0 $? 0 "order"
! grep -qF secret "$out" "$out2"; row metrics "review bodies are never printed" 0 $? 0 "body leaked"
mxfix "[pr(1,files=[('a.js',4,0)]),pr(2,files=[('package-lock.json',900,0),('b.js',6,0)]),pr(3,files=[('b.js',2,0),('package-lock.json',50,0)])]"
mxck "excluded index is global and paths are deduplicated" ok 0 "#1${T}4${T}1" "#2${T}6${T}1" "#3${T}2${T}1" "size_n=3"
mxfix "[pr(n,files=[('f',n,0)]) for n in range(1,11)]"
mxck "nearest rank on 10 PRs: median 5th, p90 9th" ok 0 "lines_median=5 lines_p90=9"
mxfix "[pr(n,files=[('f',n,0)]) for n in range(1,8)]"
mxck "nearest rank on 7 PRs: median 4th" ok 0 "lines_median=4 lines_p90=7"
mxfix "[pr(1,m='2026-10-10T00:00:00Z',files=[('a',1,0)])]"
mxck "PR merged exactly at since 00:00Z is included" ok 0 "prs_merged=1"
mxfix "[pr(1,files=[('a',1,0)]),{'number':2,'title':'x'}]"
mxck "malformed PR entry is exit 1" ok 1 "unexpected gh output"
for bad in "dict(pr(1),files=3)" "dict(pr(1),title=5)" "pr(1,files=[('a','5',0)])" "pr(1,files=[('a\\x00b',1,0)])" "pr(1,files=[('a\\ud800',1,0)])" "dict(pr(1),number=True)"; do
  mxfix "[$bad]"; mxck "wrongly typed gh field fails closed: $bad" ok 1 "metrics: unexpected gh output"
  ! grep -q Traceback "$out2"; row metrics "no traceback: $bad" 0 $? 0 "traceback printed"
done
mxfix "[]"
mxck "no PRs in the window" ok 0 "prs_merged=0" "size_n=0 size_missing=0 lines_median=- lines_p90=- files_median=- files_p90=- over_limit=0"
mxfix "[pr(1,files=$L1),pr(2,files=[('b.js',20,0)],cf=3)]"
mxck "files shorter than changedFiles: size missing" ok 0 "size_n=1 size_missing=1 lines_median=15" "#2${T}-${T}-${T}-${T}0"
mxfix "[pr(1,files=[('big.js',400,0)]),pr(2,files=[('m.js',1,0)])]"
mxck "PR over the line limit" ok 0 "over_limit=1"
mkrepo mxcfg "- pr_max_lines: 1000"
mxck "docs/devkit.md raises the limit" ok 0 "over_limit=0 max_lines=1000"
mkrepo mxr2
mxfix "[pr(1,m='2026-10-09T23:00:00Z',files=[('a',1,1)]),pr(2,files=[('b',1,1)])]"
mxck "PR merged before since is dropped" ok 0 "prs_merged=1" "#2"
grep -qF -- "merged:>=2026-10-09" "$psd/mx.log"; row metrics "search uses since minus one day" 0 $? 0 "log: $(cat "$psd/mx.log")"
! grep -q '^#1' "$out"; row metrics "dropped PR has no row" 0 $? 0 "row #1 printed"
mxfix "[pr(n,files=[('a',1,1)]) for n in range(1,1001)]"
mxck "1000 PRs: truncated flag" ok 0 "prs_merged=1000 prs_truncated=1"
mxfix "[pr(1,files=[('a',1,1)],revs=100),pr(2,files=[('a',1,1)],revs=99)]"
mxck "exactly 100 reviews is capped" ok 0 "capped_items=1"
mxfix "[pr(1,files=[('a',1,1)],title='a\x01b\tc\u2028d\u202ee\x85f')]"
mxck "control, line-separator and bidi characters in a title are cleaned" ok 0 "a b c d e f"
MX_ARGS="--since 2026-1-5" mxck "bad --since format" ok 1 "usage:"
MX_ARGS="--since 2026-02-31" mxck "impossible date" ok 1 "invalid date"
MX_ARGS="--bogus" mxck "unknown argument" ok 1 "usage:"
MX_ARGS="" mxck "default since is 14 days ago" ok 0 "since=$(python3 -c 'import datetime as d; print((d.datetime.now(d.timezone.utc)-d.timedelta(days=14)).strftime("%Y-%m-%d"))')"
mxck "gh not logged in" noauth 1 "metrics: gh not logged in"
mxck "gh pr list fails" prfail 1 "metrics:"
mxck "invalid JSON from pr list" badjson 1 "unexpected gh output"
# pr-size.sh is found beside metrics.sh (no slash in $0), and a failing one never counts every path
mkrepo mxrun; mkdir "$r/s"; cp "$mx" "$ps" "$r/s/"
mxfix "[pr(1,files=[('a.js',3,0)])]"
MX_DIR="$r/s" MX_SCRIPT=/bin/bash MX_ARGS="metrics.sh --since 2026-10-10" mxck "bash metrics.sh finds pr-size.sh beside it" ok 0 "lines_median=3"
for bad in 5 -1; do
  printf '#!/bin/sh\necho max_lines=300 max_files=10\necho %s\n' "$bad" >"$r/s/pr-size.sh"
  MX_DIR="$r/s" MX_SCRIPT=/bin/bash MX_ARGS="metrics.sh --since 2026-10-10" mxck "pr-size index $bad out of range is exit 1" ok 1 "unexpected pr-size output"
done
printf '#!/bin/sh\nexit 1\n' >"$r/s/pr-size.sh"
MX_DIR="$r/s" MX_SCRIPT=/bin/bash MX_ARGS="metrics.sh --since 2026-10-10" mxck "pr-size.sh failure is exit 1" ok 1 "pr-size.sh failed"
mkdir -p "$psd/mxnogh"; ln -sf "$(command -v python3)" "$psd/mxnogh/python3"; ln -sf "$(command -v git)" "$psd/mxnogh/git"
(cd "$r" && PATH="$psd/mxnogh" /bin/bash "$mx" >/dev/null 2>"$out2"); got=$?
row metrics "gh missing is exit 1" 1 "$got" 0 "expected exit 1"
grep -qF "metrics: gh required" "$out2"; row metrics "gh missing: message" 0 $? 0 "got: $(cat "$out2")"

expect "$notify" 0 "always exits 0" '{"message":"test"}'

echo "$cases cases, $nfail failed, total $total ms"
[ "$fail" -eq 0 ] && echo "All hooks passed." || echo "Some hooks failed."
exit "$fail"
