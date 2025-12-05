#!/usr/bin/env bash
set -euo pipefail

# Local reproduction of the seed-image GitHub workflow's build + smoke test.
# Builds the Seed image from the repo root and runs vipb2json against the vendored
# seed.vipb, mirroring the workflow's smoke test job.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../../.." && pwd)"
DOCKER_BIN="${DOCKER_BIN:-docker}"
IMAGE_NAME="${IMAGE_NAME:-seed-local}"
TAG_SUFFIX="${TAG_SUFFIX:-local-smoke}"
ARTIFACT_DIR="${REPO_ROOT}/artifacts/seed-image-smoke"
SEED_VIPB="${REPO_ROOT}/Tooling/deployment/seed.vipb"
OUTPUT_JSON="${ARTIFACT_DIR}/seed.json"

if ! command -v "${DOCKER_BIN}" >/dev/null 2>&1; then
  echo "Docker CLI not found (looked for ${DOCKER_BIN}). Install Docker/Podman and set DOCKER_BIN if needed." >&2
  exit 1
fi

if ! "${DOCKER_BIN}" info >/dev/null 2>&1; then
  echo "Docker daemon is not reachable. Start Docker or point DOCKER_HOST/DOCKER_BIN at a running engine." >&2
  exit 1
fi

if [ ! -f "${SEED_VIPB}" ]; then
  echo "Seed template missing: ${SEED_VIPB}" >&2
  exit 1
fi

IMAGE_REF="${IMAGE_NAME}:${TAG_SUFFIX}"

echo "[seed-image-smoke] Building ${IMAGE_REF} from ${REPO_ROOT}" >&2
"${DOCKER_BIN}" build \
  -f "${REPO_ROOT}/Tooling/seed/Dockerfile" \
  -t "${IMAGE_REF}" \
  "${REPO_ROOT}"

echo "[seed-image-smoke] Running vipb2json smoke test into ${OUTPUT_JSON}" >&2
mkdir -p "${ARTIFACT_DIR}"
"${DOCKER_BIN}" run --rm \
  -v "${REPO_ROOT}:/workspace" \
  -w /workspace \
  "${IMAGE_REF}" \
  vipb2json --input /workspace/Tooling/deployment/seed.vipb --output /workspace/artifacts/seed-image-smoke/seed.json

if [ ! -s "${OUTPUT_JSON}" ]; then
  echo "Smoke test output missing or empty: ${OUTPUT_JSON}" >&2
  exit 1
fi

echo "[seed-image-smoke] Success. Artifact: ${OUTPUT_JSON}" >&2
