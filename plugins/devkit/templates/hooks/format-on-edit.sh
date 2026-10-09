#!/usr/bin/env bash
# PostToolUse (Edit|Write): format the file Claude just edited with the project's formatter.
# Never blocks; formatter errors are ignored. Always exits 0.
input="$(cat)"
file="$(printf '%s' "$input" | python3 -c 'import json,sys; print(json.load(sys.stdin).get("tool_input",{}).get("file_path",""))' 2>/dev/null \
  || printf '%s' "$input" | node -e 'let s="";process.stdin.on("data",d=>s+=d).on("end",()=>{try{process.stdout.write(JSON.parse(s).tool_input.file_path||"")}catch{}})' 2>/dev/null)"
[ -z "$file" ] || [ ! -f "$file" ] && exit 0

root="${CLAUDE_PROJECT_DIR:-$PWD}"
cd "$root" || exit 0

case "$file" in
  *.ts|*.tsx|*.js|*.jsx|*.mjs|*.cjs|*.json|*.css|*.scss|*.md|*.mdx|*.html|*.vue|*.svelte|*.yml|*.yaml)
    if [ -f biome.json ] || [ -f biome.jsonc ]; then
      npx --no-install biome format --write "$file" >/dev/null 2>&1 || true
    elif ls .prettierrc* prettier.config.* >/dev/null 2>&1 || grep -q '"prettier"' package.json 2>/dev/null; then
      npx --no-install prettier --write --log-level warn "$file" >/dev/null 2>&1 || true
    fi
    ;;
  *.py)
    if command -v ruff >/dev/null 2>&1; then ruff format "$file" >/dev/null 2>&1 || true
    elif command -v black >/dev/null 2>&1; then black -q "$file" || true; fi
    ;;
  *.go)
    command -v gofmt >/dev/null 2>&1 && gofmt -w "$file" || true
    ;;
esac
exit 0
