#!/usr/bin/env bash
# Test the plugin hooks with sample JSON. Exits 0 when every case matches.
set -u
root="$(cd "$(dirname "$0")/.." && pwd)"
guard="$root/plugins/devkit/scripts/protect-files.sh"
notify="$root/plugins/devkit/scripts/notify.sh"
push="$root/plugins/devkit/scripts/block-force-push.sh"
fail=0

expect() { # expect <script> <expected exit> <name> <json>
  printf '%s' "$4" | "$1" >/dev/null 2>&1
  local got=$?
  if [ "$got" -eq "$2" ]; then echo "ok   $3"; else echo "FAIL $3 (expected $2, got $got)"; fail=1; fi
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

printf '%s' '{"message":"test"}' | "$notify" >/dev/null 2>&1
if [ $? -eq 0 ]; then echo "ok   notify always exits 0"; else echo "FAIL notify"; fail=1; fi

[ "$fail" -eq 0 ] && echo "All hooks passed." || echo "Some hooks failed."
exit "$fail"
