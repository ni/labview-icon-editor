#!/usr/bin/env bash
set -euo pipefail

here="$(cd "$(dirname "$0")" && pwd)"

case "$(uname -s)" in
  MINGW*|MSYS*|CYGWIN*)
    if command -v pwsh >/dev/null 2>&1; then
      pwsh -NoLogo -NoProfile -File "$here/setup-git-hooks.ps1"
    else
      powershell -NoProfile -ExecutionPolicy Bypass -File "$here/setup-git-hooks.ps1"
    fi
    ;;
  *)
    bash "$here/setup-git-hooks.sh"
    ;;
esac

