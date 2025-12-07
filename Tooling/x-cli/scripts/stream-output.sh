#!/usr/bin/env bash
set -euo pipefail

if [[ $# -eq 0 ]]; then
  echo "Usage: stream-output.sh <command> [args...]" >&2
  exit 1
fi

# Execute the command with line-buffered stdout/stderr so output streams immediately.
exec stdbuf -oL -eL "$@"
