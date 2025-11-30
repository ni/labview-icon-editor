#!/usr/bin/env bash
set -euo pipefail

echo_once=false
while [[ $# -gt 0 ]]; do
  case "$1" in
    --echo-once) echo_once=true; shift;;
    -h|--help) echo "Usage: $0 [--echo-once]"; exit 0;;
    *) echo "Unknown arg: $1" >&2; exit 2;;
  esac
done

here="$(cd "$(dirname "$0")" && pwd)"
root="$(cd "$here/../../.." && pwd)"
bindir="$root/.tools/bin"

mkdir -p "$bindir"
abs_bindir="$bindir"

begin='# >>> x-cli PATH bootstrap >>>'
end='# <<< x-cli PATH bootstrap <<<'
snippet="$begin
# Added by scripts/ghops/tools/bootstrap-path.sh
if [ -d \"$abs_bindir\" ]; then
  case \":$PATH:\" in *:\"$abs_bindir\":*) ;; *) export PATH=\"$abs_bindir:$PATH\" ;; esac
fi
$end"

notice_begin='# >>> x-cli PATH notice >>>'
notice_end='# <<< x-cli PATH notice <<<'
notice_snippet="$notice_begin
# Optional: echo a short PATH confirmation once per session
if [ -d \"$abs_bindir\" ]; then
  if [ -z \"${XCLI_TOOLS_PATH_NOTICE_SHOWN:-}\" ]; then
    export XCLI_TOOLS_PATH_NOTICE_SHOWN=1
    echo \"x-cli tools on PATH: $abs_bindir\"
  fi
fi
$notice_end"

touch_file(){
  local f="$1"; mkdir -p "$(dirname "$f")"; [ -f "$f" ] || : > "$f"
}

append_if_missing(){
  local f="$1"; local marker="$2"; local block="$3"; touch_file "$f"
  if ! grep -q "$marker" "$f" 2>/dev/null; then
    printf '\n%s\n' "$block" >> "$f"
    echo "$f"
  fi
}

written=()
append(){ local file="$1"; 
  w=$(append_if_missing "$file" "$begin" "$snippet" || true); [ -n "${w:-}" ] && written+=("$w")
  if $echo_once; then w=$(append_if_missing "$file" "$notice_begin" "$notice_snippet" || true); [ -n "${w:-}" ] && written+=("$w"); fi
}

# POSIX login shells
append "$HOME/.profile"
append "$HOME/.bash_profile"
# Interactive bash
append "$HOME/.bashrc"
# zsh
append "$HOME/.zshrc"

if [ ${#written[@]} -gt 0 ]; then
  echo "Added PATH bootstrap for x-cli to:"; printf '  %s\n' "${written[@]}"
  echo "Open a new terminal for changes to take effect."
else
  echo "PATH bootstrap already present in profile(s)."
fi

# Friendly hint for GitKraken CLI passthrough (dev shells only)
if [ -z "${CI:-}" ] && [ -z "${GITHUB_ACTIONS:-}" ]; then
  if command -v gk >/dev/null 2>&1; then
    echo "GitKraken CLI detected. Enable passthrough with USE_GK_PASSTHROUGH=1 or force with GIT_TOOL=gk."
  fi
fi
