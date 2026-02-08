#!/usr/bin/env bash
set -euo pipefail

MODE="${1:-}"
LABVIEW_ROOT="${2:-${LABVIEW_ROOT:-}}"
WORKSPACE_ROOT="${3:-${WORKSPACE_ROOT:-/workspace}}"

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
  line="$(grep -i -m1 '^[[:space:]]*localhost\.librarypaths[[:space:]]*=' "$INI_PATH" || true)"
  if [[ -z "$line" ]]; then
    return
  fi

  local value="${line#*=}"
  IFS=';' read -r -a raw_paths <<< "$value"
  for item in "${raw_paths[@]}"; do
    local cleaned
    cleaned="$(trim "$item")"
    cleaned="${cleaned%\"}"
    cleaned="${cleaned#\"}"
    cleaned="$(trim "$cleaned")"
    if [[ -n "$cleaned" ]]; then
      printf '%s\n' "$cleaned"
    fi
  done
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
    set_line="1"
    local serialized=()
    for value in "${paths[@]}"; do
      if [[ "$value" == *" "* ]]; then
        serialized+=("\"$value\"")
      else
        serialized+=("$value")
      fi
    done
    local joined
    IFS=';'
    joined="${serialized[*]}"
    IFS=$' \t\n'
    newline="Localhost.LibraryPaths=$joined"
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

add_library_path() {
  local target="$1"
  local target_key
  target_key="$(normalize_path_for_compare "$target")"
  mapfile -t paths < <(read_library_paths)

  local exists=0
  for value in "${paths[@]}"; do
    if [[ "$(normalize_path_for_compare "$value")" == "$target_key" ]]; then
      exists=1
      break
    fi
  done

  if [[ "$exists" -eq 0 ]]; then
    paths+=("$target")
  fi

  write_library_paths "${paths[@]}"
}

remove_library_path() {
  local target="$1"
  local target_key
  target_key="$(normalize_path_for_compare "$target")"
  mapfile -t paths < <(read_library_paths)

  local remaining=()
  for value in "${paths[@]}"; do
    if [[ "$(normalize_path_for_compare "$value")" != "$target_key" ]]; then
      remaining+=("$value")
    fi
  done

  write_library_paths "${remaining[@]}"
}

contains_library_path() {
  local target="$1"
  local target_key
  target_key="$(normalize_path_for_compare "$target")"
  mapfile -t paths < <(read_library_paths)

  for value in "${paths[@]}"; do
    if [[ "$(normalize_path_for_compare "$value")" == "$target_key" ]]; then
      return 0
    fi
  done

  return 1
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

  add_library_path "$WORKSPACE_ROOT"

  local issues=()
  if [[ ! -f "$SHIP_PATH" || -f "$LVLIBP_PATH" || -d "$ICON_API_DIR" || ! -f "$ICON_API_ZIP" ]]; then
    issues+=("install files did not reach enabled state")
  fi
  if ! contains_library_path "$WORKSPACE_ROOT"; then
    issues+=("Localhost.LibraryPaths does not include workspace root")
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

  remove_library_path "$WORKSPACE_ROOT"

  local issues=()
  if [[ ! -f "$LVLIBP_PATH" || -f "$SHIP_PATH" || ! -d "$ICON_API_DIR" || -f "$ICON_API_ZIP" ]]; then
    issues+=("install files did not reach disabled state")
  fi
  if contains_library_path "$WORKSPACE_ROOT"; then
    issues+=("Localhost.LibraryPaths still includes workspace root")
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
