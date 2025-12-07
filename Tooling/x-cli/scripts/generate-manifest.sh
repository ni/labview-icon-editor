#!/usr/bin/env bash
set -euo pipefail

mkdir -p telemetry

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
WORKFLOW="${GITHUB_WORKFLOW:-ci.yml}"
RUN_ID="${GITHUB_RUN_ID:-local}"
COMMIT="${GITHUB_SHA:-$(git -C "$REPO_ROOT" rev-parse --short=8 HEAD)}"
TS="$(date -u +%Y-%m-%dT%H:%M:%SZ)"

sha_or_empty () {
  local p="$1"
  if [[ -f "$p" ]]; then sha256sum "$p" | awk '{print $1}'; else echo ""; fi
}

WIN="dist/x-cli-win-x64"
LIN="dist/x-cli-linux-x64"
SUM="telemetry/summary.json"
MAN="telemetry/manifest.json"

if [[ ! -f "$SUM" ]]; then
  echo "ERROR: missing telemetry summary at $SUM" >&2
  exit 1
fi

if [[ ! -f "$WIN" || ! -f "$LIN" ]]; then
  echo "ERROR: missing dist artifacts: expected $WIN and $LIN" >&2
  exit 1
fi

WIN_SHA="$(sha_or_empty "$WIN")"
LIN_SHA="$(sha_or_empty "$LIN")"
SUM_SHA="$(sha_or_empty "$SUM")"

cat > "$MAN" <<JSON
{
  "schema": "pipeline.manifest/v1",
  "run": { "workflow": "$WORKFLOW", "run_id": "$RUN_ID", "commit": "$COMMIT", "ts": "$TS" },
  "artifacts": {
    "win_x64":   { "path": "$WIN", "sha256": "$WIN_SHA" },
    "linux_x64": { "path": "$LIN", "sha256": "$LIN_SHA" }
  },
  "telemetry": {
    "summary": { "path": "$SUM", "sha256": "$SUM_SHA" }
  }
}
JSON

echo "Wrote $MAN"
