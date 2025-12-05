#!/usr/bin/env bash
set -euo pipefail

# Linux/WSL helper to export Seed metadata, run Pester tests (when pwsh is available),
# and execute Analyze-VIP against the newest built .vip artifact.

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
COMPOSE_FILE="$ROOT/Tooling/docker/seed/docker-compose.yml"
VIPB_INPUT="/workspace/Tooling/deployment/seed.vipb"
METADATA_OUTPUT="/workspace/artifacts/seed/metadata.json"
export PSModulePath="/usr/local/share/powershell/Modules:${PSModulePath:-}"

echo "Building Seed image..."
docker compose -f "$COMPOSE_FILE" build seed

echo "Exporting VIPB metadata to $METADATA_OUTPUT ..."
docker compose -f "$COMPOSE_FILE" run --rm \
  -e INPUT_MODE=vipb2json \
  -e INPUT_INPUT="$VIPB_INPUT" \
  -e INPUT_OUTPUT="$METADATA_OUTPUT" \
  seed

if command -v pwsh >/dev/null 2>&1; then
  echo "Running Seed metadata tests (Pester)..."
  pwsh -NoProfile -Command "Import-Module Pester -ErrorAction Stop; Invoke-Pester -Path '$ROOT/Test/SeedMetadata.Tests.ps1' -CI"
else
  echo "pwsh not found; skipping Pester metadata tests. Install PowerShell to run them." >&2
fi

latest_vip=$(
  find "$ROOT/builds-isolated" -type f -name '*.vip' -printf '%T@ %p\n' 2>/dev/null \
    | sort -nr \
    | head -n1 \
    | cut -d' ' -f2- || true
)

if [[ -z "${latest_vip:-}" ]]; then
  echo "No .vip found under builds-isolated; skipping Analyze-VIP."
  exit 0
fi

if ! command -v pwsh >/dev/null 2>&1; then
  echo "pwsh not found; cannot run Analyze-VIP PowerShell tests. Install PowerShell to include this step." >&2
  exit 0
fi

echo "Running Analyze-VIP against: $latest_vip"
pwsh -NoProfile -File "$ROOT/scripts/analyze-vi-package/run-local.ps1" -VipArtifactPath "$latest_vip" -MinLabVIEW "23.0"
