#!/usr/bin/env bash
set -euo pipefail

source "$(dirname "$0")/common.sh"

python -m venv "$ROOT/.venv"
# shellcheck disable=SC1091
source "$ROOT/.venv/bin/activate"
python -m pip install -U pip
# Test/runtime utilities inline (no requirements.txt); avoid editable install
python -m pip install ruamel.yaml pytest pytest-timeout pytest-xdist pytest-cov coverage
