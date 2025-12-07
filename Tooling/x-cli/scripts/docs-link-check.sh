#!/usr/bin/env bash
# Run Markdown link + anchor checks using lychee.
# Prefers a native `lychee` binary if present, otherwise uses Docker.
# Usage:
#   ./scripts/docs-link-check.sh [path]
# Env:
#   CONFIG=.lychee.toml (override with absolute or repo-relative path)

set -euo pipefail

CONFIG=${CONFIG:-.lychee.toml}
TARGET=${1:-.}

if command -v lychee >/dev/null 2>&1; then
  lychee --config "$CONFIG" --no-progress --offline --include-fragments "$TARGET"
else
  docker run --rm -v "$PWD:/data" -w /data lycheeverse/lychee:latest \
    --config "$CONFIG" --no-progress --offline --include-fragments "$TARGET"
fi

