#!/usr/bin/env bash
set -euo pipefail
ROOT="$(git rev-parse --show-toplevel)"
markers=$(rg --no-heading --line-number --glob '!*check-tech-debt.sh' --glob '!docs/**' --glob '!*.md' "TECH-DEBT:" "$ROOT" || true)
if [[ -n "$markers" ]]; then
  echo "Detected unresolved technical debt markers:" >&2
  echo "$markers" >&2
  echo >&2
  echo "Resolve these items or remove the markers before retrying." >&2
  exit 1
fi
