#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

TAG="${1:-x-cli:dev}"
VERSION="${2:-}"
TARGET="${3:-package-image}"

if [[ -z "$VERSION" ]]; then
  if git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    VERSION="dev-$(git rev-parse --short HEAD)"
  else
    VERSION="0.0.0"
  fi
fi

./scripts/pack-cli.sh "$VERSION"

echo "Building image $TAG (target=$TARGET, XCLI_VERSION=$VERSION)"
docker build --target "$TARGET" --build-arg XCLI_VERSION="$VERSION" -t "$TAG" .
echo "Built $TAG"

