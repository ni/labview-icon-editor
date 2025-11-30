#!/usr/bin/env bash
set -euo pipefail

REPO="${GITHUB_REPOSITORY:-}"
if [[ -z "${REPO}" ]]; then
  REPO="LabVIEW-Community-CI-CD/x-cli"
fi

is_dry_run() {
  [[ "${DRY_RUN:-0}" == "1" ]]
}

is_json() {
  [[ "${GHOPS_JSON:-0}" == "1" ]]
}

# lightweight JSON logging for bash wrappers
__GHOPS_CMDS=()
declare -A __GHOPS_CTX
__GHOPS_ARR_KEYS=()

json_escape() {
  local s="${1//\\/\\\\}"
  s="${s//"\""/\\\"}"
  s="${s//$'\n'/\\n}"
  s="${s//$'\r'/\\r}"
  s="${s//$'\t'/\\t}"
  printf '%s' "$s"
}

log_cmd() {
  local line="$*"
  __GHOPS_CMDS+=("$line")
  if ! is_json; then
    echo "[dry-run] $line"
  fi
}

flush_json() {
  if ! is_json; then return 0; fi
  printf '{"dryRun":%s,"repo":"%s"' \
    "$(is_dry_run && echo true || echo false)" "$(json_escape "$REPO")"

  # emit context fields
  local k
  for k in "${!__GHOPS_CTX[@]}"; do
    local v="${__GHOPS_CTX[$k]}"
    printf ',"%s":"%s"' "$(json_escape "$k")" "$(json_escape "$v")"
  done

  # emit array context fields
  local arrKey
  for arrKey in "${__GHOPS_ARR_KEYS[@]}"; do
    local var="__GHOPS_ARR_${arrKey}"
    eval "local -a arr=( \"\${${var}[@]}\" )"
    printf ',"%s":[' "$(json_escape "$arrKey")"
    local i=0
    local item
    for item in "${arr[@]}"; do
      if [[ $i -gt 0 ]]; then printf ','; fi
      printf '"%s"' "$(json_escape "$item")"
      i=$((i+1))
    done
    printf ']'
  done

  printf ',"commands":['
  local first=1
  local c
  for c in "${__GHOPS_CMDS[@]:-}"; do
    if [[ $first -eq 0 ]]; then printf ','; fi
    first=0
    printf '"%s"' "$(json_escape "$c")"
  done
  printf ']}'
}

log_ctx() {
  local key="$1"; shift || true
  local val="$*"
  __GHOPS_CTX["$key"]="$val"
}

log_ctx_array() {
  local key="$1"; shift || true
  local var="__GHOPS_ARR_${key}"
  # track key once
  local seen=0
  local k
  for k in "${__GHOPS_ARR_KEYS[@]}"; do [[ "$k" == "$key" ]] && seen=1 && break; done
  if [[ $seen -eq 0 ]]; then __GHOPS_ARR_KEYS+=("$key"); fi
  # create backing array if missing
  eval "[ \"\${${var}:+set}\" ] || declare -ga ${var}=()"
  local item
  for item in "$@"; do
    eval "${var}+=( \"$item\" )"
  done
}

die() {
  echo "error: $*" >&2
  exit 1
}

usage_error() {
  echo "error: $*" >&2
  exit 2
}

ensure_gh() {
  if is_dry_run; then return 0; fi
  if ! command -v gh >/dev/null 2>&1; then
    echo "error: gh CLI is required. Install from https://cli.github.com/" >&2
    exit 2
  fi
}

ensure_git() {
  if is_dry_run; then return 0; fi
  if ! command -v git >/dev/null 2>&1; then
    echo "error: git is required." >&2
    exit 2
  fi
}
