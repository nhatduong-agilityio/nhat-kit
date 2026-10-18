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

expect "$notify" 0 "always exits 0" '{"message":"test"}'

echo "$cases cases, $nfail failed, total $total ms"
[ "$fail" -eq 0 ] && echo "All hooks passed." || echo "Some hooks failed."
exit "$fail"
