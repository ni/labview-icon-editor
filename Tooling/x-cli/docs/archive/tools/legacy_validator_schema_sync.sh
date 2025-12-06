#!/usr/bin/env bash
set -euo pipefail

# Legacy external validator schema sync helper (archived)

SCHEMA_DIR="schema"
SCHEMA_FILE="$SCHEMA_DIR/validation-result.schema.json"
mkdir -p "$SCHEMA_DIR"

# 1) Prefer installed dotnet tool (if available)
if command -v jarvis >/dev/null 2>&1; then
  echo "[schema-sync] Using dotnet tool: jarvis"
  jarvis schema print --name validation-result --pretty > "$SCHEMA_FILE"
  exit 0
fi

# 2) Fallback: use checked-out jarvis-cli source (from actions/checkout)
if [ -f "_jarvis/src/Jarvis/Jarvis.csproj" ]; then
  echo "[schema-sync] Using checked-out jarvis-cli at _jarvis/"
  pushd "_jarvis" >/dev/null
  dotnet restore
  dotnet build -c Release
  dotnet run --project src/Jarvis/Jarvis.csproj -- schema print --name validation-result --pretty > "../$SCHEMA_FILE"
  popd >/dev/null
else
  # 3) Last-resort clone with token (handles private repos)
  echo "[schema-sync] No local jarvis-cli; attempting authenticated clone..."
  WORK="_jarvis"
  rm -rf "$WORK"
  if [ -n "${GITHUB_TOKEN:-}" ]; then
    git clone "https://x-access-token:${GITHUB_TOKEN}@github.com/LabVIEW-Community-CI-CD/jarvis-cli.git" "$WORK"
  else
    git clone "https://github.com/LabVIEW-Community-CI-CD/jarvis-cli.git" "$WORK"
  fi
  pushd "$WORK" >/dev/null
  dotnet restore
  dotnet build -c Release
  dotnet run --project src/Jarvis/Jarvis.csproj -- schema print --name validation-result --pretty > "../$SCHEMA_FILE"
  popd >/dev/null
  rm -rf "$WORK"
fi

# Normalize schema order if jq is present
if command -v jq >/dev/null 2>&1; then
  tmp="$SCHEMA_FILE.tmp"
  jq -S . "$SCHEMA_FILE" > "$tmp" && mv "$tmp" "$SCHEMA_FILE"
fi

echo "[schema-sync] Synced schema to: $SCHEMA_FILE"
