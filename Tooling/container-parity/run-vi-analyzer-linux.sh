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

resolve_lvie_repo_root "${PWD:-}" > /dev/null
LVIE_REPO_ROOT="${LVIE_RESOLVED_REPO_ROOT:-}"
LVIE_REPO_ROOT_SOURCE="${LVIE_RESOLVED_REPO_ROOT_SOURCE:-unknown}"
TASKS_PATH="${LVIE_VI_ANALYZER_TASKS_PATH:-$(join_lvie_repo_path "$LVIE_REPO_ROOT" "Tooling/vi-analyzer/tasks.json")}"
REPORTS_ROOT="${LVIE_VI_ANALYZER_REPORTS_ROOT:-$(join_lvie_repo_path "$LVIE_REPO_ROOT" "builds/vi-analyzer")}"
LOG_ROOT="${LVIE_VI_ANALYZER_LOG_ROOT:-$(join_lvie_repo_path "$LVIE_REPO_ROOT" "TestResults/container-parity/linux/vi-analyzer/logs")}"
SOURCE_SYNC_MANIFEST_PATH="${LVIE_SOURCE_SYNC_MANIFEST_PATH:-$(join_lvie_repo_path "$LVIE_REPO_ROOT" "builds/status/source-sync-manifest-vi-analyzer-linux.json")}"
MASSCOMPILE_TARGET_MODE="${LVIE_VI_ANALYZER_MASSCOMPILE_TARGET_MODE:-workspace-relative}"
MASSCOMPILE_TARGET_REL="${LVIE_VI_ANALYZER_MASSCOMPILE_TARGET_REL:-.}"
SYNC_TO_INSTALL_RAW="${LVIE_VI_ANALYZER_SYNC_TO_INSTALL:-false}"
MASSCOMPILE_ENABLED_RAW="${LVIE_VI_ANALYZER_ENABLE_MASSCOMPILE:-false}"
MASSCOMPILE_REQUIRED_RAW="${LVIE_VI_ANALYZER_MASSCOMPILE_REQUIRED:-false}"
LV_YEAR="${LVIE_VI_ANALYZER_LABVIEW_YEAR:-${CONTAINER_PARITY_LABVIEW_VERSION:-${LV_YEAR:-2026}}}"
LABVIEW_PATH="${LVIE_VI_ANALYZER_LABVIEW_PATH:-/usr/local/natinst/LabVIEW-${LV_YEAR}-64/labviewprofull}"
LABVIEW_ROOT="$(dirname "$LABVIEW_PATH")"
PORT_NUMBER="${LVIE_VI_ANALYZER_PORT_NUMBER:-${LABVIEWCLI_PORT:-3363}}"
CLOSE_BETWEEN_TASKS_RAW="${LVIE_VI_ANALYZER_CLOSE_BETWEEN_TASKS:-false}"
XVFB_SERVER_ARGS="${LVIE_XVFB_SERVER_ARGS:--screen 0 1920x1080x24}"
XVFB_BIN="${LVIE_XVFB_BIN:-$(command -v Xvfb || true)}"
XVFB_DISPLAY="${LVIE_XVFB_DISPLAY:-:99}"
XVFB_PID=""
LABVIEWCLI_HEARTBEAT_SECONDS="${LVIE_LABVIEWCLI_HEARTBEAT_SECONDS:-30}"
TARGET_DIR=""
TARGET_DIR_SOURCE=""
SYNCED_ICON_API_DIR=""
SYNCED_PLUGIN_DIR=""

echo "Resolved repo root: $LVIE_REPO_ROOT (source: $LVIE_REPO_ROOT_SOURCE)"
echo "Resolved tasks path: $TASKS_PATH"
echo "Resolved reports root: $REPORTS_ROOT"
echo "Resolved logs root: $LOG_ROOT"
echo "Resolved source sync manifest path: $SOURCE_SYNC_MANIFEST_PATH"
echo "Using LabVIEW path: $LABVIEW_PATH"
echo "Using LabVIEWCLI port: $PORT_NUMBER"
echo "Close between tasks: $CLOSE_BETWEEN_TASKS_RAW"
echo "LabVIEWCLI heartbeat interval: ${LABVIEWCLI_HEARTBEAT_SECONDS}s"
echo "Install sync enabled: $SYNC_TO_INSTALL_RAW"
echo "MassCompile enabled: $MASSCOMPILE_ENABLED_RAW"
echo "MassCompile required: $MASSCOMPILE_REQUIRED_RAW"
if [[ -n "${DISPLAY:-}" ]]; then
  echo "Using existing DISPLAY=$DISPLAY"
fi

if ! command -v LabVIEWCLI >/dev/null 2>&1; then
  echo "ERROR: LabVIEWCLI is not available on PATH inside the container." >&2
  exit 1
fi

if [[ -z "${DISPLAY:-}" && -z "$XVFB_BIN" ]]; then
  echo "ERROR: DISPLAY is unset and Xvfb was not found. Install Xvfb or provide DISPLAY for LabVIEWCLI operations." >&2
  exit 1
fi

if [[ -z "${DISPLAY:-}" ]]; then
  if [[ -e "/tmp/.X11-unix/X${XVFB_DISPLAY#:}" ]]; then
    echo "DISPLAY $XVFB_DISPLAY already exists; reusing it."
    export DISPLAY="$XVFB_DISPLAY"
  else
    echo "Starting Xvfb on DISPLAY $XVFB_DISPLAY (args: $XVFB_SERVER_ARGS)"
    "$XVFB_BIN" "$XVFB_DISPLAY" $XVFB_SERVER_ARGS >/tmp/lvie-xvfb.log 2>&1 &
    XVFB_PID="$!"
    sleep 1
    if ! kill -0 "$XVFB_PID" 2>/dev/null; then
      echo "ERROR: Xvfb failed to start on $XVFB_DISPLAY. Log: /tmp/lvie-xvfb.log" >&2
      exit 1
    fi
    export DISPLAY="$XVFB_DISPLAY"
  fi
  echo "Virtual display is ready on DISPLAY=$DISPLAY"
fi

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

if [[ ! -f "$TASKS_PATH" ]]; then
  echo "ERROR: VI Analyzer task registry was not found: $TASKS_PATH" >&2
  exit 1
fi

if [[ ! -e "$LABVIEW_PATH" ]]; then
  echo "ERROR: LabVIEW executable path does not exist: $LABVIEW_PATH" >&2
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
    "vi-analyzer-linux" \
    "resource-plugins-niiconeditor" "$repo_plugins/NIIconEditor" "$install_plugins/NIIconEditor" "$snapshot_plugins_dir" \
    "resource-plugins-root-files" "$plugin_root_stage" "$install_plugins" "$snapshot_plugins_root_files" \
    "labview-icon-api" "$repo_icon_api" "$install_icon_api" "$snapshot_icon_api"

  SYNCED_PLUGIN_DIR="$install_plugins/NIIconEditor"
  SYNCED_ICON_API_DIR="$install_icon_api"

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
  local cli_pid
  local started_at
  started_at="$(date +%s)"

  LabVIEWCLI "$@" >"$output_file" 2>&1 &
  cli_pid="$!"
  while kill -0 "$cli_pid" 2>/dev/null; do
    sleep "$LABVIEWCLI_HEARTBEAT_SECONDS"
    if kill -0 "$cli_pid" 2>/dev/null; then
      local now elapsed
      now="$(date +%s)"
      elapsed="$((now - started_at))"
      echo "[${operation}] LabVIEWCLI still running (${elapsed}s elapsed)..."
    fi
  done

  set +e
  wait "$cli_pid"
  status=$?
  set -e

  cat "$output_file"
  rm -f "$output_file"

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
  local pids_before=()
  mapfile -t pids_before < <(pgrep -f "$LABVIEW_PATH" || true)
  if [[ "${#pids_before[@]}" -eq 0 ]]; then
    echo "No active LabVIEW process detected for '$label'; close not required."
    return 0
  fi

  echo "Closing LabVIEW process(es) ($label); PID(s): ${pids_before[*]}"
  kill "${pids_before[@]}" 2>/dev/null || true
  sleep 2
  local pids_after=()
  mapfile -t pids_after < <(pgrep -f "$LABVIEW_PATH" || true)
  if [[ "${#pids_after[@]}" -gt 0 ]]; then
    echo "WARNING: Force-killing LabVIEW PID(s): ${pids_after[*]}" >&2
    kill -9 "${pids_after[@]}" 2>/dev/null || true
    sleep 1
    mapfile -t pids_after < <(pgrep -f "$LABVIEW_PATH" || true)
  fi

  if [[ "${#pids_after[@]}" -gt 0 ]]; then
    echo "ERROR: LabVIEW process remained after deterministic close for '$label': ${pids_after[*]}" >&2
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

sync_to_install_enabled=false
if is_enabled_value "$SYNC_TO_INSTALL_RAW"; then
  sync_to_install_enabled=true
fi

if [[ "$sync_to_install_enabled" == "true" ]]; then
  echo "Synchronizing workspace Icon Editor sources into LabVIEW install before VI Analyzer."
  if ! sync_icon_editor_sources_for_build_spec; then
    exit 1
  fi
else
  echo "Install sync is disabled; operating from workspace sources only."
fi

cleanup() {
  if [[ -n "$XVFB_PID" ]]; then
    kill "$XVFB_PID" 2>/dev/null || true
  fi
}
trap cleanup EXIT

masscompile_enabled=false
if is_enabled_value "$MASSCOMPILE_ENABLED_RAW"; then
  masscompile_enabled=true
fi

masscompile_required=false
if is_enabled_value "$MASSCOMPILE_REQUIRED_RAW"; then
  masscompile_required=true
fi

if [[ "$masscompile_enabled" == "true" ]]; then
  if [[ "$MASSCOMPILE_TARGET_MODE" == "copied-source" ]]; then
    if [[ "$sync_to_install_enabled" != "true" ]]; then
      echo "ERROR: copied-source masscompile mode requires LVIE_VI_ANALYZER_SYNC_TO_INSTALL=true." >&2
      exit 1
    fi
    TARGET_DIR="$SYNCED_ICON_API_DIR"
    TARGET_DIR_SOURCE="copied-source (vi.lib/LabVIEW Icon API)"
  elif [[ "$MASSCOMPILE_TARGET_MODE" == "workspace-relative" ]]; then
    TARGET_DIR="$(join_lvie_repo_path "$LVIE_REPO_ROOT" "$MASSCOMPILE_TARGET_REL")"
    TARGET_DIR_SOURCE="\$LVIE_VI_ANALYZER_MASSCOMPILE_TARGET_REL"
  else
    echo "ERROR: Unsupported masscompile target mode '$MASSCOMPILE_TARGET_MODE'. Use 'copied-source' or 'workspace-relative'." >&2
    exit 1
  fi

  if [[ ! -d "$TARGET_DIR" ]]; then
    echo "ERROR: MassCompile target directory does not exist: $TARGET_DIR" >&2
    exit 1
  fi

  echo "Running LabVIEWCLI MassCompile before VI Analyzer tasks."
  echo "MassCompile target directory: $TARGET_DIR (source: $TARGET_DIR_SOURCE)"
  if ! invoke_labviewcli "MassCompile-ViAnalyzer" \
    -LogToConsole TRUE \
    -OperationName MassCompile \
    -DirectoryToCompile "$TARGET_DIR" \
    -LabVIEWPath "$LABVIEW_PATH" \
    -PortNumber "$PORT_NUMBER" \
    -Headless; then
    if [[ "$masscompile_required" == "true" ]]; then
      echo "ERROR: LabVIEWCLI MassCompile failed before VI Analyzer." >&2
      exit 1
    fi
    echo "WARNING: LabVIEWCLI MassCompile failed; continuing because LVIE_VI_ANALYZER_MASSCOMPILE_REQUIRED is false."
  else
    echo "MassCompile completed successfully."
  fi
else
  echo "Skipping LabVIEWCLI MassCompile before VI Analyzer tasks (LVIE_VI_ANALYZER_ENABLE_MASSCOMPILE=false)."
fi

close_between_tasks_enabled=false
if is_enabled_value "$CLOSE_BETWEEN_TASKS_RAW"; then
  close_between_tasks_enabled=true
fi

if [[ "$close_between_tasks_enabled" == "true" ]]; then
  if ! close_labview_deterministic "pre-run"; then
    echo "WARNING: Initial CloseLabVIEW failed; continuing with task execution."
  fi
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

  safe_task_id="$(printf '%s' "$task_id" | tr -cs 'A-Za-z0-9_.-' '-')"
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
    -PortNumber "$PORT_NUMBER" \
    -ConfigPath "$config_path" \
    -ReportPath "$report_path" \
    -ReportSaveType ASCII \
    -LabVIEWPath "$LABVIEW_PATH" \
    -Headless; then
    echo "ERROR: RunVIAnalyzer failed for task '$task_id'." >&2
    task_failed=1
  fi

  if [[ "$close_between_tasks_enabled" == "true" ]]; then
    if ! close_labview_deterministic "$safe_task_id"; then
      task_failed=1
    fi
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
