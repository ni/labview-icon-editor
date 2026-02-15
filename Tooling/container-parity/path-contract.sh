#!/usr/bin/env bash

resolve_lvie_repo_root() {
  local default_root="${1:-}"
  local candidate=""
  local source=""

  if [[ -n "${LVIE_REPO_ROOT:-}" ]]; then
    candidate="$LVIE_REPO_ROOT"
    source="\$LVIE_REPO_ROOT"
  elif [[ -n "${WORKSPACE_ROOT:-}" ]]; then
    candidate="$WORKSPACE_ROOT"
    source="\$WORKSPACE_ROOT"
  elif [[ -n "${REPO_ROOT:-}" ]]; then
    candidate="$REPO_ROOT"
    source="\$REPO_ROOT"
  elif [[ -n "$default_root" ]]; then
    candidate="$default_root"
    source="default:$default_root"
  else
    printf '%s\n' "Unable to resolve repo root from LVIE_REPO_ROOT/WORKSPACE_ROOT/REPO_ROOT/default." >&2
    return 1
  fi

  LVIE_REPO_ROOT_SOURCE="$source"
  LVIE_RESOLVED_REPO_ROOT="$candidate"
  LVIE_RESOLVED_REPO_ROOT_SOURCE="$source"
  printf '%s\n' "$candidate"
}

join_lvie_repo_path() {
  local repo_root="$1"
  local candidate="$2"

  if [[ "$candidate" = /* || "$candidate" =~ ^[A-Za-z]:[\\/].* ]]; then
    printf '%s\n' "$candidate"
    return 0
  fi

  if [[ "$repo_root" =~ [\\/]$ ]]; then
    printf '%s\n' "${repo_root}${candidate}"
  else
    printf '%s\n' "${repo_root}/${candidate}"
  fi
}

resolve_lvie_project_path() {
  local repo_root="$1"
  local default_relative="${2:-lv_icon_editor.lvproj}"
  local effective_relative="${LVIE_PROJECT_RELATIVE_PATH:-$default_relative}"
  local source=""
  local resolved=""

  if [[ -n "${LVIE_PROJECT_PATH:-}" ]]; then
    source="\$LVIE_PROJECT_PATH"
    resolved="$(join_lvie_repo_path "$repo_root" "$LVIE_PROJECT_PATH")"
    LVIE_PROJECT_PATH_SOURCE="$source"
    LVIE_RESOLVED_PROJECT_PATH="$resolved"
    LVIE_RESOLVED_PROJECT_PATH_SOURCE="$source"
    printf '%s\n' "$resolved"
    return 0
  fi

  if [[ -n "${PROJECT_PATH:-}" ]]; then
    source="\$PROJECT_PATH"
    resolved="$(join_lvie_repo_path "$repo_root" "$PROJECT_PATH")"
    LVIE_PROJECT_PATH_SOURCE="$source"
    LVIE_RESOLVED_PROJECT_PATH="$resolved"
    LVIE_RESOLVED_PROJECT_PATH_SOURCE="$source"
    printf '%s\n' "$resolved"
    return 0
  fi

  source="\$LVIE_PROJECT_RELATIVE_PATH (or default)"
  resolved="$(join_lvie_repo_path "$repo_root" "$effective_relative")"
  LVIE_PROJECT_PATH_SOURCE="$source"
  LVIE_RESOLVED_PROJECT_PATH="$resolved"
  LVIE_RESOLVED_PROJECT_PATH_SOURCE="$source"
  printf '%s\n' "$resolved"
}
