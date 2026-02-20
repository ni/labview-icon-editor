#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PATH_CONTRACT_SCRIPT="$SCRIPT_DIR/path-contract.sh"
if [[ ! -f "$PATH_CONTRACT_SCRIPT" ]]; then
  echo "ERROR: Path contract helper was not found: $PATH_CONTRACT_SCRIPT" >&2
  exit 1
fi

# shellcheck disable=SC1090
source "$PATH_CONTRACT_SCRIPT"
SYNC_MANIFEST_SCRIPT="$SCRIPT_DIR/source-sync-manifest.sh"
if [[ ! -f "$SYNC_MANIFEST_SCRIPT" ]]; then
  echo "ERROR: Source sync manifest helper was not found: $SYNC_MANIFEST_SCRIPT" >&2
  exit 1
fi

# shellcheck disable=SC1090
source "$SYNC_MANIFEST_SCRIPT"

LV_YEAR="${CONTAINER_PARITY_LABVIEW_VERSION:-${LV_YEAR:-2026}}"
LVIE_PROJECT_RELATIVE_PATH="${LVIE_PROJECT_RELATIVE_PATH:-${PROJECT_PATH_REL:-lv_icon_editor.lvproj}}"
resolve_lvie_repo_root "/workspace" > /dev/null
LVIE_REPO_ROOT="${LVIE_RESOLVED_REPO_ROOT:-}"
LVIE_REPO_ROOT_SOURCE="${LVIE_RESOLVED_REPO_ROOT_SOURCE:-unknown}"
resolve_lvie_project_path "$LVIE_REPO_ROOT" "$LVIE_PROJECT_RELATIVE_PATH" > /dev/null
LVIE_PROJECT_PATH="${LVIE_RESOLVED_PROJECT_PATH:-}"
LVIE_PROJECT_PATH_SOURCE="${LVIE_RESOLVED_PROJECT_PATH_SOURCE:-unknown}"

TARGET_DIR_REL="${TARGET_DIR_REL:-Test/Templates}"
TARGET_DIR_SOURCE="\$TARGET_DIR"
if [[ -z "${TARGET_DIR:-}" ]]; then
  TARGET_DIR="$(join_lvie_repo_path "$LVIE_REPO_ROOT" "$TARGET_DIR_REL")"
  TARGET_DIR_SOURCE="\$TARGET_DIR_REL"
fi

EXCLUDE_LIST="${CONTAINER_PARITY_EXCLUDE_FILES:-Polymorphic Template.vi}"
LABVIEW_PATH="${LABVIEW_PATH:-/usr/local/natinst/LabVIEW-${LV_YEAR}-64/labviewprofull}"
PROJECT_PATH="$LVIE_PROJECT_PATH"
BUILD_SPEC_NAME="${CONTAINER_PARITY_BUILD_SPEC_NAME:-Editor Packed Library}"
TARGET_NAME="${CONTAINER_PARITY_TARGET_NAME:-My Computer}"
BUILD_OUTPUT_RELATIVE_PATH="${CONTAINER_PARITY_BUILD_OUTPUT_RELATIVE_PATH:-resource/plugins/lv_icon.lvlibp}"
BUILD_OUTPUT_PATH="$(join_lvie_repo_path "$LVIE_REPO_ROOT" "$BUILD_OUTPUT_RELATIVE_PATH")"
LOG_ROOT="$(join_lvie_repo_path "$LVIE_REPO_ROOT" "TestResults/container-parity/linux/logs")"
SOURCE_SYNC_MANIFEST_PATH="${LVIE_SOURCE_SYNC_MANIFEST_PATH:-$(join_lvie_repo_path "$LVIE_REPO_ROOT" "builds/status/source-sync-manifest-parity-linux.json")}"
LABVIEW_ROOT="$(dirname "$LABVIEW_PATH")"
SUPPRESS_OPTIONAL_DOTNET_INTEROP_WARNING_RAW="${LVIE_SUPPRESS_OPTIONAL_DOTNET_INTEROP_WARNING:-true}"
OPTIONAL_DOTNET_INTEROP_WARNING_REGEX="^(Can't load library libniDotNETCoreInterop\\.so|libniDotNETCoreInterop\\.so: cannot open shared object file: No such file or directory|Can't find library libniDotNETCoreInterop\\.so|Make sure this library is installed in your LD_LIBRARY_PATH|search path, or in /usr/lib64)$"
SUPPRESS_OPTIONAL_DOTNET_INTEROP_WARNING=false

export LVIE_REPO_ROOT
export LVIE_PROJECT_PATH
export LVIE_PROJECT_RELATIVE_PATH
export WORKSPACE_ROOT="$LVIE_REPO_ROOT"
export REPO_ROOT="$LVIE_REPO_ROOT"
export PROJECT_PATH="$LVIE_PROJECT_PATH"

echo "Resolved repo root: $LVIE_REPO_ROOT (source: $LVIE_REPO_ROOT_SOURCE)"
echo "Resolved project path: $LVIE_PROJECT_PATH (source: $LVIE_PROJECT_PATH_SOURCE)"
echo "Resolved target directory: $TARGET_DIR (source: $TARGET_DIR_SOURCE)"
echo "Resolved source sync manifest path: $SOURCE_SYNC_MANIFEST_PATH"

is_enabled_value() {
  local value="${1:-}"
  shopt -s nocasematch
  if [[ "$value" == "1" || "$value" == "true" || "$value" == "yes" ]]; then
    shopt -u nocasematch
    return 0
  fi
  shopt -u nocasematch
  return 1
}

append_ld_library_path() {
  local candidate="$1"
  if [[ -z "$candidate" || ! -d "$candidate" ]]; then
    return
  fi

  if [[ -z "${LD_LIBRARY_PATH:-}" ]]; then
    export LD_LIBRARY_PATH="$candidate"
    return
  fi

  case ":$LD_LIBRARY_PATH:" in
    *":$candidate:"*) ;;
    *) export LD_LIBRARY_PATH="$candidate:$LD_LIBRARY_PATH" ;;
  esac
}

configure_optional_dotnet_interop() {
  append_ld_library_path "$LABVIEW_ROOT"
  append_ld_library_path "$LABVIEW_ROOT/linux"

  local interop_file=""
  interop_file="$(find "$LABVIEW_ROOT" /usr/local/natinst -name 'libniDotNETCoreInterop.so' -print -quit 2>/dev/null || true)"
  if [[ -n "$interop_file" ]]; then
    local interop_dir
    interop_dir="$(dirname "$interop_file")"
    append_ld_library_path "$interop_dir"
    echo "Configured LD_LIBRARY_PATH for optional libniDotNETCoreInterop.so: $interop_dir"
  else
    echo "Optional libniDotNETCoreInterop.so not found in container image; continuing."
  fi

  echo "Effective LD_LIBRARY_PATH: ${LD_LIBRARY_PATH:-<unset>}"
}

emit_labviewcli_output() {
  local output_file="$1"
  local suppress_optional_warning="$2"

  if [[ "$suppress_optional_warning" == "true" ]]; then
    local suppressed_count
    suppressed_count="$(grep -Ec "$OPTIONAL_DOTNET_INTEROP_WARNING_REGEX" "$output_file" || true)"
    if [[ "$suppressed_count" -gt 0 ]]; then
      grep -Ev "$OPTIONAL_DOTNET_INTEROP_WARNING_REGEX" "$output_file" || true
      echo "Suppressed $suppressed_count known optional libniDotNETCoreInterop.so warning line(s)."
      return
    fi
  fi

  cat "$output_file"
}

sync_icon_editor_sources_for_build_spec() {
  local repo_plugins
  repo_plugins="$(join_lvie_repo_path "$LVIE_REPO_ROOT" "resource/plugins")"
  local install_plugins="$LABVIEW_ROOT/resource/plugins"
  local repo_icon_api
  repo_icon_api="$(join_lvie_repo_path "$LVIE_REPO_ROOT" "vi.lib/LabVIEW Icon API")"
  local install_icon_api="$LABVIEW_ROOT/vi.lib/LabVIEW Icon API"

  local required_paths=(
    "$repo_plugins/NIIconEditor"
    "$repo_plugins/lv_IconEditor.lvlib"
    "$repo_plugins/lv_icon.vi"
    "$repo_icon_api"
  )
  local plugin_root_files=(
    "lv_IconEditor.lvlib"
    "lv_icon.vi"
    "lv_icon.vit"
    "SAMPLE_lv_icon.vi"
  )
  local plugin_root_stage
  plugin_root_stage="$(mktemp -d)"
  local snapshot_plugins_dir
  snapshot_plugins_dir="$(mktemp)"
  local snapshot_plugins_root_files
  snapshot_plugins_root_files="$(mktemp)"
  local snapshot_icon_api
  snapshot_icon_api="$(mktemp)"
  trap 'rm -f "$snapshot_plugins_dir" "$snapshot_plugins_root_files" "$snapshot_icon_api"; rm -rf "$plugin_root_stage"' RETURN

  for path in "${required_paths[@]}"; do
    if [[ ! -e "$path" ]]; then
      echo "ERROR: Required Icon Editor source path is missing: $path" >&2
      return 1
    fi
  done

  for file_name in "${plugin_root_files[@]}"; do
    local source_path="$repo_plugins/$file_name"
    if [[ -f "$source_path" ]]; then
      cp -a "$source_path" "$plugin_root_stage/"
    fi
  done

  sync_manifest_capture_before_state "$repo_plugins/NIIconEditor" "$install_plugins/NIIconEditor" "$snapshot_plugins_dir"
  sync_manifest_capture_before_state "$plugin_root_stage" "$install_plugins" "$snapshot_plugins_root_files"
  sync_manifest_capture_before_state "$repo_icon_api" "$install_icon_api" "$snapshot_icon_api"

  mkdir -p "$install_plugins"
  cp -a "$repo_plugins/NIIconEditor" "$install_plugins/"
  for file_name in "${plugin_root_files[@]}"; do
    local source_path="$repo_plugins/$file_name"
    if [[ -e "$source_path" ]]; then
      cp -a "$source_path" "$install_plugins/"
    fi
  done

  mkdir -p "$install_icon_api"
  cp -a "$repo_icon_api/." "$install_icon_api/"

  local probe="$install_plugins/NIIconEditor/Miscellaneous/Classes Initialization.vi"
  if [[ ! -f "$probe" ]]; then
    echo "ERROR: Icon Editor source synchronization failed. Missing probe file: $probe" >&2
    return 1
  fi

  sync_manifest_write \
    "$SOURCE_SYNC_MANIFEST_PATH" \
    "$LVIE_REPO_ROOT" \
    "$LABVIEW_ROOT" \
    "parity-linux-buildspec" \
    "resource-plugins-niiconeditor" "$repo_plugins/NIIconEditor" "$install_plugins/NIIconEditor" "$snapshot_plugins_dir" \
    "resource-plugins-root-files" "$plugin_root_stage" "$install_plugins" "$snapshot_plugins_root_files" \
    "labview-icon-api" "$repo_icon_api" "$install_icon_api" "$snapshot_icon_api"

  echo "Synchronized Icon Editor sources into LabVIEW install:"
  echo "  resource/plugins -> $install_plugins"
  echo "  vi.lib/LabVIEW Icon API -> $install_icon_api"
  echo "  source sync manifest -> $SOURCE_SYNC_MANIFEST_PATH"
}

list_labviewcli_temp_logs() {
  if compgen -G '/tmp/lvtemporary_*.log' > /dev/null; then
    compgen -G '/tmp/lvtemporary_*.log' | sort -u
  fi
}

invoke_labviewcli() {
  local operation="$1"
  shift

  local before_logs_file
  before_logs_file="$(mktemp)"
  list_labviewcli_temp_logs > "$before_logs_file"

  local output_file
  output_file="$(mktemp)"
  local status
  set +e
  LabVIEWCLI "$@" >"$output_file" 2>&1
  status=$?
  set -e
  emit_labviewcli_output "$output_file" "$SUPPRESS_OPTIONAL_DOTNET_INTEROP_WARNING"
  rm -f "$output_file"

  local timestamp
  timestamp="$(date +%Y%m%d-%H%M%S)"
  mkdir -p "$LOG_ROOT"

  local index=0
  while IFS= read -r candidate; do
    if [[ -z "$candidate" || ! -f "$candidate" ]]; then
      continue
    fi
    if grep -Fxq "$candidate" "$before_logs_file"; then
      continue
    fi
    index=$((index + 1))
    local destination="$LOG_ROOT/${operation,,}-${timestamp}-${index}.log"
    cp "$candidate" "$destination"
    echo "Captured LabVIEWCLI log: $destination"
  done < <(list_labviewcli_temp_logs)

  if [[ "$index" -eq 0 ]]; then
    local fallback
    fallback="$(ls -1t /tmp/lvtemporary_*.log 2>/dev/null | head -n 1 || true)"
    if [[ -n "$fallback" && -f "$fallback" ]]; then
      local destination="$LOG_ROOT/${operation,,}-${timestamp}-fallback.log"
      cp "$fallback" "$destination"
      echo "Captured LabVIEWCLI log (fallback): $destination"
    fi
  fi

  rm -f "$before_logs_file"
  return "$status"
}

if ! command -v LabVIEWCLI >/dev/null 2>&1; then
  echo "ERROR: LabVIEWCLI is not available on PATH inside the container." >&2
  exit 1
fi

if is_enabled_value "$SUPPRESS_OPTIONAL_DOTNET_INTEROP_WARNING_RAW"; then
  SUPPRESS_OPTIONAL_DOTNET_INTEROP_WARNING=true
fi
echo "Suppress optional libniDotNETCoreInterop.so warning output: $SUPPRESS_OPTIONAL_DOTNET_INTEROP_WARNING"
configure_optional_dotnet_interop

if [[ -n "${CONTAINER_PARITY_BUILD_SPEC:-}" ]] && ! is_enabled_value "${CONTAINER_PARITY_BUILD_SPEC}"; then
  echo "ERROR: CONTAINER_PARITY_BUILD_SPEC disable is unsupported. Build-spec execution is mandatory; unset CONTAINER_PARITY_BUILD_SPEC or set it to true." >&2
  exit 1
fi

if [[ ! -d "$TARGET_DIR" ]]; then
  echo "ERROR: Target directory does not exist: $TARGET_DIR" >&2
  exit 1
fi

STAGING_DIR="$(mktemp -d)"
cleanup() {
  rm -rf "$STAGING_DIR"
}
trap cleanup EXIT

cp -a "$TARGET_DIR/." "$STAGING_DIR/"

IFS=';' read -r -a _exclude_items <<< "$EXCLUDE_LIST"
for _item in "${_exclude_items[@]}"; do
  _trimmed="$(echo "$_item" | xargs)"
  if [[ -z "$_trimmed" ]]; then
    continue
  fi
  _candidate="$STAGING_DIR/$_trimmed"
  if [[ -e "$_candidate" ]]; then
    echo "Excluding template from parity compile: $_trimmed"
    rm -rf "$_candidate"
  fi
done

echo "Running LabVIEWCLI MassCompile in headless mode."
echo "Target directory: $TARGET_DIR"
echo "LabVIEW path: $LABVIEW_PATH"
echo "Excluded templates: $EXCLUDE_LIST"
echo "Staging directory: $STAGING_DIR"
if ! invoke_labviewcli "MassCompile" \
  -LogToConsole TRUE \
  -OperationName MassCompile \
  -DirectoryToCompile "$STAGING_DIR" \
  -LabVIEWPath "$LABVIEW_PATH" \
  -Headless; then
  echo "ERROR: LabVIEWCLI MassCompile failed." >&2
  exit 1
fi

echo "MassCompile completed successfully."

if [[ ! -f "$PROJECT_PATH" ]]; then
  echo "ERROR: Project file does not exist: $PROJECT_PATH" >&2
  exit 1
fi

echo "Synchronizing workspace Icon Editor sources into LabVIEW install before build-spec execution."
if ! sync_icon_editor_sources_for_build_spec; then
  exit 1
fi

echo "Running LabVIEWCLI ExecuteBuildSpec in headless mode."
echo "Project path: $PROJECT_PATH"
echo "Build specification: $BUILD_SPEC_NAME"
echo "Target name: $TARGET_NAME"
echo "Expected output: $BUILD_OUTPUT_PATH"

if ! invoke_labviewcli "ExecuteBuildSpec" \
  -LogToConsole TRUE \
  -OperationName ExecuteBuildSpec \
  -ProjectPath "$PROJECT_PATH" \
  -BuildSpecName "$BUILD_SPEC_NAME" \
  -TargetName "$TARGET_NAME" \
  -LabVIEWPath "$LABVIEW_PATH" \
  -Headless; then
  echo "ERROR: LabVIEWCLI ExecuteBuildSpec failed." >&2
  exit 1
fi

if [[ ! -f "$BUILD_OUTPUT_PATH" ]]; then
  echo "ERROR: Build specification output not found at expected path: $BUILD_OUTPUT_PATH" >&2
  exit 1
fi

bytes="$(wc -c < "$BUILD_OUTPUT_PATH" | xargs)"
echo "Build specification completed: $BUILD_OUTPUT_PATH ($bytes bytes)"
