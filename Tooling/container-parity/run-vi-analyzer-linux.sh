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

resolve_lvie_repo_root "${PWD:-}" > /dev/null
LVIE_REPO_ROOT="${LVIE_RESOLVED_REPO_ROOT:-}"
LVIE_REPO_ROOT_SOURCE="${LVIE_RESOLVED_REPO_ROOT_SOURCE:-unknown}"
TASKS_PATH="${LVIE_VI_ANALYZER_TASKS_PATH:-$(join_lvie_repo_path "$LVIE_REPO_ROOT" "Tooling/vi-analyzer/tasks.json")}"
REPORTS_ROOT="${LVIE_VI_ANALYZER_REPORTS_ROOT:-$(join_lvie_repo_path "$LVIE_REPO_ROOT" "builds/vi-analyzer")}"
LOG_ROOT="${LVIE_VI_ANALYZER_LOG_ROOT:-$(join_lvie_repo_path "$LVIE_REPO_ROOT" "TestResults/container-parity/linux/vi-analyzer/logs")}"
TARGET_DIR_REL="${LVIE_VI_ANALYZER_MASSCOMPILE_TARGET_REL:-Test/Templates}"
TARGET_DIR="$(join_lvie_repo_path "$LVIE_REPO_ROOT" "$TARGET_DIR_REL")"
EXCLUDE_LIST="${LVIE_VI_ANALYZER_EXCLUDE_FILES:-Polymorphic Template.vi}"
LV_YEAR="${LVIE_VI_ANALYZER_LABVIEW_YEAR:-${CONTAINER_PARITY_LABVIEW_VERSION:-${LV_YEAR:-2026}}}"
LABVIEW_PATH="${LVIE_VI_ANALYZER_LABVIEW_PATH:-/usr/local/natinst/LabVIEW-${LV_YEAR}-64/labviewprofull}"
LABVIEW_ROOT="$(dirname "$LABVIEW_PATH")"

echo "Resolved repo root: $LVIE_REPO_ROOT (source: $LVIE_REPO_ROOT_SOURCE)"
echo "Resolved tasks path: $TASKS_PATH"
echo "Resolved reports root: $REPORTS_ROOT"
echo "Resolved logs root: $LOG_ROOT"
echo "Resolved target directory: $TARGET_DIR (source: \$LVIE_VI_ANALYZER_MASSCOMPILE_TARGET_REL)"
echo "Using LabVIEW path: $LABVIEW_PATH"

if ! command -v LabVIEWCLI >/dev/null 2>&1; then
  echo "ERROR: LabVIEWCLI is not available on PATH inside the container." >&2
  exit 1
fi

if [[ ! -f "$TASKS_PATH" ]]; then
  echo "ERROR: VI Analyzer task registry was not found: $TASKS_PATH" >&2
  exit 1
fi

if [[ ! -e "$LABVIEW_PATH" ]]; then
  echo "ERROR: LabVIEW executable path does not exist: $LABVIEW_PATH" >&2
  exit 1
fi

if [[ ! -d "$TARGET_DIR" ]]; then
  echo "ERROR: MassCompile target directory does not exist: $TARGET_DIR" >&2
  exit 1
fi

mkdir -p "$REPORTS_ROOT" "$LOG_ROOT"

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

  for path in "${required_paths[@]}"; do
    if [[ ! -e "$path" ]]; then
      echo "ERROR: Required Icon Editor source path is missing: $path" >&2
      return 1
    fi
  done

  mkdir -p "$install_plugins"
  cp -a "$repo_plugins/NIIconEditor" "$install_plugins/"
  for file_name in lv_IconEditor.lvlib lv_icon.vi lv_icon.vit SAMPLE_lv_icon.vi; do
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

  echo "Synchronized Icon Editor sources into LabVIEW install:"
  echo "  resource/plugins -> $install_plugins"
  echo "  vi.lib/LabVIEW Icon API -> $install_icon_api"
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

  local status
  set +e
  LabVIEWCLI "$@"
  status=$?
  set -e

  local timestamp
  timestamp="$(date +%Y%m%d-%H%M%S)"

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

close_labview_deterministic() {
  local label="$1"
  echo "Closing LabVIEW ($label)."
  if ! invoke_labviewcli "CloseLabVIEW-${label}" \
    -LogToConsole TRUE \
    -OperationName CloseLabVIEW \
    -LabVIEWPath "$LABVIEW_PATH"; then
    echo "ERROR: CloseLabVIEW failed for '$label'." >&2
    return 1
  fi
  return 0
}

read_vi_analyzer_tasks() {
  local registry_path="$1"
  awk -F'"' '
    /"id"[[:space:]]*:/ { current_id = $4 }
    /"config_path"[[:space:]]*:/ {
      config_path = $4
      if (current_id == "" || config_path == "") {
        next
      }
      printf "%s|%s\n", current_id, config_path
      current_id = ""
    }
  ' "$registry_path"
}

echo "Running LabVIEWCLI MassCompile before VI Analyzer tasks."
echo "MassCompile target directory: $TARGET_DIR"
echo "Excluded templates: $EXCLUDE_LIST"

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

if ! invoke_labviewcli "MassCompile-ViAnalyzer" \
  -LogToConsole TRUE \
  -OperationName MassCompile \
  -DirectoryToCompile "$STAGING_DIR" \
  -LabVIEWPath "$LABVIEW_PATH" \
  -Headless; then
  echo "ERROR: LabVIEWCLI MassCompile failed before VI Analyzer." >&2
  exit 1
fi

echo "MassCompile completed successfully."
echo "Synchronizing workspace Icon Editor sources into LabVIEW install before VI Analyzer."
if ! sync_icon_editor_sources_for_build_spec; then
  exit 1
fi

if ! close_labview_deterministic "pre-run"; then
  echo "WARNING: Initial CloseLabVIEW failed; continuing with task execution."
fi

mapfile -t task_pairs < <(read_vi_analyzer_tasks "$TASKS_PATH")
if [[ "${#task_pairs[@]}" -eq 0 ]]; then
  echo "ERROR: No VI Analyzer tasks were discovered in $TASKS_PATH" >&2
  exit 1
fi

failed_tasks=()
for entry in "${task_pairs[@]}"; do
  task_id="${entry%%|*}"
  config_rel="${entry#*|}"
  if [[ -z "$task_id" || -z "$config_rel" ]]; then
    echo "ERROR: Malformed task entry '$entry' in $TASKS_PATH" >&2
    failed_tasks+=("${task_id:-unknown}")
    continue
  fi

  config_path="$(join_lvie_repo_path "$LVIE_REPO_ROOT" "$config_rel")"
  if [[ ! -f "$config_path" ]]; then
    echo "ERROR: VI Analyzer config for task '$task_id' was not found: $config_path" >&2
    failed_tasks+=("$task_id")
    continue
  fi

  safe_task_id="$(echo "$task_id" | tr -cs 'A-Za-z0-9_.-' '-')"
  report_path="$REPORTS_ROOT/vi-analyzer-${safe_task_id}.txt"
  rm -f "$report_path"

  echo ""
  echo "=== VI Analyzer task: $task_id ==="
  echo "Config: $config_path"
  echo "Report: $report_path"

  task_failed=0
  if ! invoke_labviewcli "RunVIAnalyzer-${safe_task_id}" \
    -LogToConsole TRUE \
    -OperationName RunVIAnalyzer \
    -ConfigPath "$config_path" \
    -ReportPath "$report_path" \
    -ReportSaveType ASCII \
    -LabVIEWPath "$LABVIEW_PATH" \
    -Headless; then
    echo "ERROR: RunVIAnalyzer failed for task '$task_id'." >&2
    task_failed=1
  fi

  if ! close_labview_deterministic "$safe_task_id"; then
    task_failed=1
  fi

  if [[ "$task_failed" -ne 0 ]]; then
    failed_tasks+=("$task_id")
  fi
done

if [[ "${#failed_tasks[@]}" -gt 0 ]]; then
  echo "ERROR: VI Analyzer task execution failed for: ${failed_tasks[*]}" >&2
  exit 1
fi

echo "VI Analyzer Linux worker completed successfully (${#task_pairs[@]} task(s))."
