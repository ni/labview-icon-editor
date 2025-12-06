#!/usr/bin/env bash
set -euo pipefail

source "$(dirname "$0")/common.sh"

if [ -d "$ROOT/.venv" ]; then
  # shellcheck disable=SC1090
  source "$ROOT/.venv/bin/activate"
fi

if ! command -v dotnet >/dev/null 2>&1; then
  "$ROOT/scripts/install-dotnet.sh"
fi

# Install test/runtime tooling only (avoid editable install to prevent console script warnings)
python -m pip install ruamel.yaml pytest pytest-timeout pytest-xdist pytest-cov coverage

PREINSTALLED="$ROOT/docs/preinstalled-tools.md"
if grep -q "^| pre-commit |" "$PREINSTALLED"; then
  if command -v pre-commit >/dev/null 2>&1; then
    echo "pre-commit is preinstalled; skipping."
  else
    echo "pre-commit listed as preinstalled but missing; installing."
    python -m pip install pre-commit
  fi
else
  python -m pip install pre-commit
fi
