#!/usr/bin/env bash
set -euo pipefail

# git-pass.sh — Optional GitKraken passthrough for git commands (POSIX)
# Usage: source this file and then call: invoke_git status

is_ci() {
  [ "${CI:-}" = "1" ] || [ -n "${GITHUB_ACTIONS:-}" ]
}

pick_tool() {
  if is_ci; then echo git; return; fi
  local mode="${GIT_TOOL:-auto}"
  case "$mode" in
    git) echo git ;;
    gk)
      if command -v gk >/dev/null 2>&1; then echo gk; else echo "GIT_TOOL=gk but gk not found" >&2; return 2; fi ;;
    *)
      if [ "${USE_GK_PASSTHROUGH:-}" = "1" ] || [ "${USE_GK_PASSTHROUGH:-}" = "true" ]; then
        if command -v gk >/dev/null 2>&1; then echo gk; else echo git; fi
      else
        echo git
      fi ;;
  esac
}

allow_default="status,log,show,diff,rev-parse,describe,ls-files,remote -v,branch,config --get"

allow_match() {
  local first="$1" second="$2" allow_list="${GIT_PASSTHROUGH_ALLOW:-$allow_default}"
  [ "$allow_list" = "*" ] && return 0
  IFS=',' read -r -a items <<<"$allow_list"
  local pair="$first"; [ -n "$second" ] && pair="$first $second"
  for it in "${items[@]}"; do
    it="${it# }"; it="${it% }"
    [ -z "$it" ] && continue
    case "$pair" in $it) return 0;; esac
    case "$first" in $it) return 0;; esac
  done
  return 1
}

invoke_git() {
  local tool; tool=$(pick_tool) || return $?
  local first="${1:-}" second="${2:-}"
  if [ "$tool" = gk ]; then
    if ! allow_match "$first" "$second"; then
      echo "Blocked by allowlist for gk passthrough: '$*'. Set GIT_PASSTHROUGH_ALLOW='*' or include this command." >&2
      return 2
    fi
    command gk "$@"
    return $?
  else
    command git "$@"
    return $?
  fi
}

if ! is_ci && [ "${GIT_ALIAS:-}" = "1" ]; then
  # shellcheck disable=SC2139
  alias git='invoke_git'
fi

