#!/usr/bin/env bash
set -euo pipefail

# Uploads telemetry history to the gh-pages branch.
# Requires GITHUB_TOKEN with "contents: write" scope.
# Usage: upload-telemetry-history.sh [history_dir] [branch]

HISTORY_DIR="${1:-telemetry/history}"
BRANCH="${2:-gh-pages}"
REPO_URL="${GITHUB_SERVER_URL:-https://github.com}/${GITHUB_REPOSITORY}"

if [[ -z "${GITHUB_TOKEN:-}" ]]; then
  echo "GITHUB_TOKEN is required" >&2
  exit 1
fi

if [[ ! -d "$HISTORY_DIR" ]]; then
  echo "History directory not found: $HISTORY_DIR" >&2
  exit 1
fi

TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

git clone --depth 1 --branch "$BRANCH" "https://${GITHUB_TOKEN}@${REPO_URL#https://}" "$TMP_DIR"
mkdir -p "$TMP_DIR/history"

# Prune entries older than 90 days before upload
find "$HISTORY_DIR" -type f -name '*.json' -mtime +90 -delete

cp -a "$HISTORY_DIR"/. "$TMP_DIR/history/"

cd "$TMP_DIR"
if git diff --quiet --exit-code; then
  echo "No telemetry history changes; skipping commit." >&2
  exit 0
fi

git config user.name "github-actions[bot]"
git config user.email "41898282+github-actions[bot]@users.noreply.github.com"
TS="$(date -u +%Y%m%dT%H%M%SZ)"

git add history
if git commit -m "Update telemetry history $TS"; then
  git push origin "$BRANCH"
else
  echo "Nothing to commit" >&2
fi
