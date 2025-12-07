#!/bin/bash
set -euo pipefail

WORKDIR="${INPUT_WORKING_DIRECTORY:-}"
if [[ -n "$WORKDIR" ]]; then
  cd "$WORKDIR"
fi

if [[ -n "${INPUT_LOG_LEVEL:-}" ]]; then
  export XCLI_LOG_LEVEL="${INPUT_LOG_LEVEL}"
fi

args=()
if [[ -n "${INPUT_ARGS:-}" ]]; then
  while IFS= read -r line; do
    [[ -z "$line" ]] && continue
    args+=("$line")
  done <<< "${INPUT_ARGS}"
fi

if [[ $# -gt 0 ]]; then
  args+=("$@")
fi

if [[ ${#args[@]} -eq 0 ]]; then
  args+=("--help")
fi

exec /usr/local/bin/x-cli "${args[@]}"
