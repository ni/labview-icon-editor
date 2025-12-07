#!/usr/bin/env bash
set -euo pipefail

source "$(dirname "$0")/common.sh"

cd "$ROOT"
PREINSTALLED="$ROOT/docs/preinstalled-tools.md"
if ! command -v pre-commit >/dev/null 2>&1; then
  if grep -q "^| pre-commit |" "$PREINSTALLED"; then
    echo "pre-commit is expected to be preinstalled. Run scripts/install_dependencies.sh." >&2
    exit 1
  else
    python -m pip install pre-commit
  fi
fi

pre-commit install
pre-commit install --hook-type commit-msg
git config commit.template scripts/commit-template.txt
