#!/usr/bin/env bash
set -euo pipefail

MODE="${1:-}"
LABVIEW_ROOT="${2:-${LABVIEW_ROOT:-}}"
REPO_ROOT_INPUT="${3:-}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PATH_CONTRACT_SCRIPT="$SCRIPT_DIR/path-contract.sh"
if [[ ! -f "$PATH_CONTRACT_SCRIPT" ]]; then
  echo "ERROR: Path contract helper was not found: $PATH_CONTRACT_SCRIPT" >&2
  exit 1
fi

# shellcheck disable=SC1090
source "$PATH_CONTRACT_SCRIPT"

if [[ -n "$REPO_ROOT_INPUT" ]]; then
  LVIE_REPO_ROOT="$REPO_ROOT_INPUT"
  LVIE_REPO_ROOT_SOURCE="arg:repo_root_input"
else
  resolve_lvie_repo_root "/workspace" > /dev/null
  LVIE_REPO_ROOT="${LVIE_RESOLVED_REPO_ROOT:-}"
  LVIE_REPO_ROOT_SOURCE="${LVIE_RESOLVED_REPO_ROOT_SOURCE:-unknown}"
fi

WORKSPACE_ROOT="$LVIE_REPO_ROOT"
export LVIE_REPO_ROOT
export WORKSPACE_ROOT
export REPO_ROOT="$LVIE_REPO_ROOT"

if [[ -z "$MODE" ]]; then
  echo "Usage: $0 <enable|revert> [labview_root] [workspace_root]" >&2
  exit 2
fi

if [[ -z "$LABVIEW_ROOT" ]]; then
  echo "ERROR: LabVIEW root is required." >&2
  exit 2
fi

ICON_API_DIR="$LABVIEW_ROOT/vi.lib/LabVIEW Icon API"
ICON_API_ZIP="$LABVIEW_ROOT/vi.lib/LabVIEW Icon API.zip"
PLUGIN_DIR="$LABVIEW_ROOT/resource/plugins"
LVLIBP_PATH="$PLUGIN_DIR/lv_icon.lvlibp"
SHIP_PATH="$PLUGIN_DIR/lv_icon.ship"

resolve_ini_path() {
  if [[ -n "${LVIE_LABVIEW_INI_PATH:-}" ]]; then
    printf '%s' "$LVIE_LABVIEW_INI_PATH"
    return
  fi

  if [[ -f "$LABVIEW_ROOT/LabVIEW.ini" ]]; then
    printf '%s' "$LABVIEW_ROOT/LabVIEW.ini"
    return
  fi

  if [[ -f "$LABVIEW_ROOT/labviewprofull.ini" ]]; then
    printf '%s' "$LABVIEW_ROOT/labviewprofull.ini"
    return
  fi

  printf '%s' "$LABVIEW_ROOT/LabVIEW.ini"
}

INI_PATH="$(resolve_ini_path)"

trim() {
  local value="$1"
  value="${value#"${value%%[![:space:]]*}"}"
  value="${value%"${value##*[![:space:]]}"}"
  printf '%s' "$value"
}

normalize_path_for_compare() {
  local value="$1"
  value="${value//\\//}"
  while [[ "$value" == */ ]]; do
    value="${value%/}"
  done
  printf '%s' "${value,,}"
}

is_invalid_library_path_token() {
  local value
  value="$(trim "$1")"
  value="${value%\"}"
  value="${value#\"}"
  value="$(trim "$value")"
  if [[ -z "$value" ]]; then
    return 0
  fi
  if [[ "$value" =~ ^[A-Za-z]:\\?$ ]]; then
    return 0
  fi
  return 1
}

flatten_icon_api_layout() {
  shopt -s dotglob nullglob
  local current="$ICON_API_DIR"
  while [[ -d "$current" ]]; do
    local entries=("$current"/*)
    if [[ ${#entries[@]} -eq 1 && -d "${entries[0]}" && "$(basename "${entries[0]}")" == "LabVIEW Icon API" ]]; then
      local inner="${entries[0]}"
      local tmp_path="$current.__tmp.$$"
      mv "$inner" "$tmp_path"
      rm -rf "$current"
      mv "$tmp_path" "$current"
      continue
    fi
    break
  done
  shopt -u dotglob nullglob
}

read_library_paths() {
  if [[ ! -f "$INI_PATH" ]]; then
    return
  fi

  local line
  while IFS= read -r line; do
    [[ -z "$line" ]] && continue
    local value="${line#*=}"
    IFS=';' read -r -a raw_paths <<< "$value"
    for item in "${raw_paths[@]}"; do
      local cleaned
      cleaned="$(trim "$item")"
      cleaned="${cleaned%\"}"
      cleaned="${cleaned#\"}"
      cleaned="$(trim "$cleaned")"
      if is_invalid_library_path_token "$cleaned"; then
        continue
      fi
      if [[ -n "$cleaned" ]]; then
        printf '%s\n' "$cleaned"
      fi
    done
  done < <(grep -i '^[[:space:]]*localhost\.librarypaths[[:space:]]*=' "$INI_PATH" || true)
}

library_path_key_count() {
  if [[ ! -f "$INI_PATH" ]]; then
    printf '0'
    return
  fi
  grep -i -c '^[[:space:]]*localhost\.librarypaths[[:space:]]*=' "$INI_PATH" || true
}

library_path_entry_count() {
  local count=0
  while IFS= read -r _line; do
    ((count += 1))
  done < <(read_library_paths)
  printf '%s' "$count"
}

is_workspace_library_path_only() {
  local target_key
  target_key="$(normalize_path_for_compare "$WORKSPACE_ROOT")"
  mapfile -t paths < <(read_library_paths)
  if [[ ${#paths[@]} -ne 1 ]]; then
    return 1
  fi
  if [[ "$(normalize_path_for_compare "${paths[0]}")" != "$target_key" ]]; then
    return 1
  fi
  if [[ "$(library_path_key_count)" -ne 1 ]]; then
    return 1
  fi
  return 0
}

is_library_path_absent() {
  if [[ "$(library_path_key_count)" -ne 0 ]]; then
    return 1
  fi
  if [[ "$(library_path_entry_count)" -ne 0 ]]; then
    return 1
  fi
  return 0
}

write_single_library_path() {
  local target="$1"
  write_library_paths "$target"
}

clear_library_paths() {
  write_library_paths
}

write_library_paths() {
  local paths=("$@")
  mkdir -p "$(dirname "$INI_PATH")"
  if [[ ! -f "$INI_PATH" ]]; then
    touch "$INI_PATH"
  fi

  local set_line="0"
  local newline=""
  if [[ ${#paths[@]} -gt 0 ]]; then
    local value="${paths[0]}"
    if [[ -n "$value" ]]; then
      set_line="1"
      if [[ "$value" == *" "* ]]; then
        newline="Localhost.LibraryPaths=\"$value\""
      else
        newline="Localhost.LibraryPaths=$value"
      fi
    fi
  fi

  local tmp
  tmp="$(mktemp)"
  awk -v newline="$newline" -v set_line="$set_line" '
    BEGIN {
      IGNORECASE = 1
      found = 0
    }
    {
      if ($0 ~ /^[[:space:]]*localhost\.librarypaths[[:space:]]*=/) {
        found = 1
        next
      }
      print
    }
    END {
      if (set_line == "1") {
        print newline
      }
    }
  ' "$INI_PATH" > "$tmp"
  mv "$tmp" "$INI_PATH"
}

require_command() {
  local name="$1"
  if ! command -v "$name" >/dev/null 2>&1; then
    echo "ERROR: Required command '$name' is not available." >&2
    exit 1
  fi
}

enable_mode() {
  require_command zip
  mkdir -p "$PLUGIN_DIR"

  if [[ -d "$ICON_API_DIR" ]]; then
    flatten_icon_api_layout
    rm -f "$ICON_API_ZIP"
    (
      cd "$LABVIEW_ROOT/vi.lib"
      zip -qr "LabVIEW Icon API.zip" "LabVIEW Icon API"
    )
    rm -rf "$ICON_API_DIR"
  elif [[ -f "$ICON_API_ZIP" ]]; then
    echo "LabVIEW Icon API is already zipped."
  else
    echo "ERROR: Neither '$ICON_API_DIR' nor '$ICON_API_ZIP' exists." >&2
    exit 1
  fi

  if [[ -f "$LVLIBP_PATH" ]]; then
    rm -f "$SHIP_PATH"
    mv "$LVLIBP_PATH" "$SHIP_PATH"
  elif [[ -f "$SHIP_PATH" ]]; then
    echo "lv_icon is already in dev-mode ship state."
  else
    echo "ERROR: Neither '$LVLIBP_PATH' nor '$SHIP_PATH' exists." >&2
    exit 1
  fi

  write_single_library_path "$WORKSPACE_ROOT"

  local issues=()
  if [[ ! -f "$SHIP_PATH" || -f "$LVLIBP_PATH" || -d "$ICON_API_DIR" || ! -f "$ICON_API_ZIP" ]]; then
    issues+=("install files did not reach enabled state")
  fi
  if ! is_workspace_library_path_only; then
    issues+=("Localhost.LibraryPaths must contain exactly one workspace-root path entry")
  fi
  if [[ ${#issues[@]} -gt 0 ]]; then
    echo "ERROR: Dev mode enable verification failed: ${issues[*]}" >&2
    exit 1
  fi
}

revert_mode() {
  require_command unzip
  mkdir -p "$PLUGIN_DIR"

  if [[ -f "$ICON_API_ZIP" ]]; then
    rm -rf "$ICON_API_DIR"
    (
      cd "$LABVIEW_ROOT/vi.lib"
      unzip -oq "LabVIEW Icon API.zip"
    )
    rm -f "$ICON_API_ZIP"
    flatten_icon_api_layout
  elif [[ -d "$ICON_API_DIR" ]]; then
    flatten_icon_api_layout
    echo "LabVIEW Icon API folder already restored."
  else
    echo "ERROR: Neither '$ICON_API_ZIP' nor '$ICON_API_DIR' exists." >&2
    exit 1
  fi

  if [[ -f "$SHIP_PATH" ]]; then
    rm -f "$LVLIBP_PATH"
    mv "$SHIP_PATH" "$LVLIBP_PATH"
  elif [[ -f "$LVLIBP_PATH" ]]; then
    echo "lv_icon is already in packaged lvlibp state."
  else
    echo "ERROR: Neither '$SHIP_PATH' nor '$LVLIBP_PATH' exists." >&2
    exit 1
  fi

  clear_library_paths

  local issues=()
  if [[ ! -f "$LVLIBP_PATH" || -f "$SHIP_PATH" || ! -d "$ICON_API_DIR" || -f "$ICON_API_ZIP" ]]; then
    issues+=("install files did not reach disabled state")
  fi
  if ! is_library_path_absent; then
    issues+=("Localhost.LibraryPaths token must be absent after revert")
  fi
  if [[ ${#issues[@]} -gt 0 ]]; then
    echo "ERROR: Dev mode revert verification failed: ${issues[*]}" >&2
    exit 1
  fi
}

case "$MODE" in
  enable)
    enable_mode
    ;;
  revert)
    revert_mode
    ;;
  *)
    echo "ERROR: Unsupported mode '$MODE'. Use enable or revert." >&2
    exit 2
    ;;
esac
