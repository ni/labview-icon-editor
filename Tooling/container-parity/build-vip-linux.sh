#!/usr/bin/env bash
set -euo pipefail

WORKSPACE_ROOT="${WORKSPACE_ROOT:-/workspace}"
LV_RELEASE="${LV_RELEASE:-2026q1}"
LV_YEAR="${LV_YEAR:-${LV_RELEASE:0:4}}"
CONTAINER_VIPB_PATH="${CONTAINER_VIPB_PATH:-Tooling/deployment/NI Icon editor.vipb}"
CONTAINER_VIP_VERSION="${CONTAINER_VIP_VERSION:-}"
CONTAINER_RELEASE_NOTES_PATH="${CONTAINER_RELEASE_NOTES_PATH:-Tooling/deployment/release_notes.md}"
CONTAINER_VIPM_TIMEOUT_SECONDS="${CONTAINER_VIPM_TIMEOUT_SECONDS:-900}"

LOG_DIR="${WORKSPACE_ROOT}/builds/logs"
GCLI_LOG="${LOG_DIR}/gcli-build-linux.log"
VIP_OUTPUT_DIR="${WORKSPACE_ROOT}/builds/VI Package"

fail() {
  echo "ERROR: $*" >&2
  exit 1
}

resolve_workspace_path() {
  local path_value="$1"
  if [[ "$path_value" = /* ]]; then
    printf '%s\n' "$path_value"
  else
    printf '%s\n' "${WORKSPACE_ROOT}/${path_value}"
  fi
}

require_file() {
  local path_value="$1"
  local label="$2"
  if [[ ! -f "$path_value" ]]; then
    fail "$label not found: $path_value"
  fi
}

if [[ -z "$CONTAINER_VIP_VERSION" ]]; then
  fail "CONTAINER_VIP_VERSION is required (expected format: major.minor.patch.build)."
fi

if [[ ! "$LV_YEAR" =~ ^[0-9]{4}$ ]]; then
  fail "LV_YEAR must be a 4-digit year. Resolved value: '$LV_YEAR'"
fi

if ! command -v g-cli >/dev/null 2>&1; then
  fail "g-cli is not available on PATH in this container."
fi

VIPB_PATH="$(resolve_workspace_path "$CONTAINER_VIPB_PATH")"
RELEASE_NOTES_PATH="$(resolve_workspace_path "$CONTAINER_RELEASE_NOTES_PATH")"
PPL_X86_PATH="${WORKSPACE_ROOT}/resource/plugins/lv_icon_x86.lvlibp"
PPL_X64_PATH="${WORKSPACE_ROOT}/resource/plugins/lv_icon_x64.lvlibp"

require_file "$VIPB_PATH" "VIPB file"
require_file "$RELEASE_NOTES_PATH" "Release notes file"
require_file "$PPL_X86_PATH" "32-bit packed library"
require_file "$PPL_X64_PATH" "64-bit packed library"

mkdir -p "$LOG_DIR"
mkdir -p "$VIP_OUTPUT_DIR"

build_started_epoch="$(date +%s)"

gcli_args=(
  --lv-ver "$LV_YEAR"
  --arch 64
  --connect-timeout 120000
  --kill
  --kill-timeout 20000
  --verbose
  vipb --
  --buildspec "$VIPB_PATH"
  -v "$CONTAINER_VIP_VERSION"
  --release-notes "$RELEASE_NOTES_PATH"
  --timeout "$CONTAINER_VIPM_TIMEOUT_SECONDS"
)

echo "Building VI Package on Linux container."
echo "Workspace root: $WORKSPACE_ROOT"
echo "LabVIEW release/year: $LV_RELEASE / $LV_YEAR"
echo "VIPB path: $VIPB_PATH"
echo "Release notes path: $RELEASE_NOTES_PATH"
echo "Required PPLs:"
echo "  - $PPL_X86_PATH"
echo "  - $PPL_X64_PATH"
echo "Log path: $GCLI_LOG"

printf 'Executing: g-cli'
for arg in "${gcli_args[@]}"; do
  printf ' %q' "$arg"
done
printf '\n'

set +e
g-cli "${gcli_args[@]}" 2>&1 | tee "$GCLI_LOG"
gcli_exit="${PIPESTATUS[0]}"
set -e

if [[ "$gcli_exit" -ne 0 ]]; then
  fail "g-cli VIP build failed with exit code $gcli_exit. See $GCLI_LOG"
fi

latest_vip_line="$(
  find "$VIP_OUTPUT_DIR" -type f -name '*.vip' -printf '%T@|%p\n' 2>/dev/null \
    | sort -nr \
    | head -n 1
)"

if [[ -z "$latest_vip_line" ]]; then
  fail "No .vip output was found under $VIP_OUTPUT_DIR"
fi

latest_vip_path="${latest_vip_line#*|}"
if [[ ! -f "$latest_vip_path" ]]; then
  fail "Resolved VIP output path does not exist: $latest_vip_path"
fi

latest_vip_epoch="$(stat -c %Y "$latest_vip_path")"
if [[ "$latest_vip_epoch" -lt "$build_started_epoch" ]]; then
  fail "No newly generated .vip file detected after build start. Latest file: $latest_vip_path"
fi

latest_vip_size="$(wc -c < "$latest_vip_path" | xargs)"
echo "VI Package build succeeded: $latest_vip_path ($latest_vip_size bytes)"
echo "VIP_PATH=$latest_vip_path"
