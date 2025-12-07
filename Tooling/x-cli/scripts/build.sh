#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/common.sh"
PROJECT=$ROOT/src/XCli/XCli.csproj
OUT=$ROOT/dist
rm -rf "$OUT"

"$ROOT/scripts/stream-output.sh" dotnet publish "$PROJECT" -c Release -r linux-x64 -p:PublishSingleFile=true -p:SelfContained=true -o "$OUT/linux-x64"
mkdir -p "$OUT"
if [ -f "$OUT/linux-x64/XCli" ]; then
  cp "$OUT/linux-x64/XCli" "$OUT/x-cli-linux-x64"
elif [ -f "$OUT/linux-x64/XCli.dll" ]; then
  cp "$OUT/linux-x64/XCli.dll" "$OUT/x-cli-linux-x64"
fi
if [ ! -f "$OUT/x-cli-linux-x64" ]; then
  echo "ERROR: linux artifact not normalized to dist/x-cli-linux-x64" >&2
  exit 1
fi

"$ROOT/scripts/stream-output.sh" dotnet publish "$PROJECT" -c Release -r win-x64 -p:PublishSingleFile=true -p:SelfContained=true -o "$OUT/win-x64"
shopt -s nullglob
exes=("$OUT/win-x64"/*.exe)
if [ ${#exes[@]} -gt 0 ]; then
  cp "${exes[0]}" "$OUT/x-cli-win-x64"
fi
if [ ! -f "$OUT/x-cli-win-x64" ]; then
  echo "ERROR: win-x64 artifact not normalized to dist/x-cli-win-x64" >&2
  exit 1
fi
