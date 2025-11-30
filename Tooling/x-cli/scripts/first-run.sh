#!/usr/bin/env bash
set -euo pipefail

here="$(cd "$(dirname "$0")" && pwd)"
root="$(cd "$here/.." && pwd)"
secrets="$root/.secrets"
token="$secrets/github_token.txt"

mkdir -p "$secrets"
if [[ ! -f "$token" ]]; then
  : > "$token"
  echo "Created placeholder token file: $token"
  echo "Paste your GitHub PAT (single line), then re-run 'make first-run' or this script."
  exit 0
fi

# 1) Load token and login
bash "$root/scripts/ghops/tools/use-local-github-token.sh" --validate --login || true

# 2) Persist PATH bootstrap with optional echo-once notice
bash "$root/scripts/ghops/tools/bootstrap-path.sh" --echo-once

# 3) Show status
if command -v gh >/dev/null 2>&1; then
  gh --version || true
  gh auth status || true
else
  echo "Note: gh CLI not found. Install https://cli.github.com/ or place a portable binary at .tools/bin/gh"
fi
echo "First-run complete. Open a new terminal to get the PATH bootstrap and notice."

