#!/usr/bin/env bash
# PreToolUse (Edit|Write|NotebookEdit): block edits to sensitive files.
# exit 2 + stderr = block and tell Claude why. exit 0 = no objection.
here="$(cd "$(dirname "$0")" && pwd)"
input="$(cat)"
file="$(printf '%s' "$input" | "$here/json-field.sh" tool_input.file_path)"
[ -z "$file" ] && file="$(printf '%s' "$input" | "$here/json-field.sh" tool_input.notebook_path)"
[ -z "$file" ] && exit 0

# Normalize Windows path separators
file="${file//\\//}"
base="$(basename "$file")"

block() {
  echo "Blocked by devkit: $file — $1" >&2
  exit 2
}

case "$base" in
  .env.example|.env.sample|.env.template) ;;           # sample files: allowed
  .env|.env.*) block "environment file holding secrets; edit it by hand or edit .env.example instead" ;;
  package-lock.json|pnpm-lock.yaml|yarn.lock|bun.lockb|bun.lock|poetry.lock|Cargo.lock|composer.lock)
    block "lockfiles may only change through the package manager (install/add/remove)" ;;
  *.pem|*.key|*.p12|*.keystore|id_rsa|id_ed25519)
    block "key/certificate file" ;;
esac

case "/$file" in
  */.git/*) block "git internals" ;;
  */node_modules/*) block "installed dependency; change it via the package manager or patch-package" ;;
esac

exit 0
