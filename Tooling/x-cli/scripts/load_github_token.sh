#!/usr/bin/env bash
set -euo pipefail

here="$(cd "$(dirname "$0")" && pwd)"
root="$(cd "$here/.." && pwd)"

candidates=(
  "$root/github_token.txt"
  "$root/.secrets/github_token.txt"
  "$(cd "$root/.." && pwd)/github_token.txt"
)

for p in "${candidates[@]}"; do
  if [[ -f "$p" ]]; then
    tok="$(tr -d '\r\n' < "$p")"
    if [[ -n "$tok" ]]; then
      export GITHUB_TOKEN="$tok"
      export GH_TOKEN="$tok"
      break
    fi
  fi
done

# Also load a user OAuth token (device-flow) if present
user_tok_file="$root/.secrets/github_user_token.txt"
if [[ -f "$user_tok_file" ]]; then
  u_tok="$(tr -d '\r\n' < "$user_tok_file")"
  if [[ -n "$u_tok" ]]; then
    export GITHUB_USER_TOKEN="$u_tok"
  fi
fi
