#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

VERSION="${1:-}"
if [[ -z "$VERSION" ]]; then
  if git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    VERSION="dev-$(git rev-parse --short HEAD)"
  else
    VERSION="0.0.0"
  fi
fi

mkdir -p package
dotnet pack src/XCli/XCli.csproj -c Release -o package -p:PackageVersion="$VERSION"
echo "Packed XCli version $VERSION to ./package"

