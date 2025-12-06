#!/usr/bin/env bash
set -euo pipefail

manifest=${1:-telemetry/manifest.json}
repo_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)

if [[ ! -f telemetry/summary.json ]]; then
  echo "telemetry/summary.json missing; generate telemetry summary before manifest." >&2
  exit 1
fi

if ! "$repo_root/scripts/validate-manifest.sh" "$manifest"; then
  echo "Manifest validation failed. Ensure telemetry/manifest.json lists required artifacts and files exist." >&2
  exit 1
fi
