#!/usr/bin/env bash
set -euo pipefail

if [[ $# -ne 1 ]]; then
    echo "Usage: $0 <path>" >&2
    exit 1
fi

file="$1"
if [[ ! -f "$file" ]]; then
    echo "File not found: $file" >&2
    exit 1
fi

repo_root="$(git rev-parse --show-toplevel)"
abs_path="$(realpath "$file")"
rel_path="$(realpath --relative-to="$repo_root" "$abs_path")"
hash=$(sha256sum "$abs_path" | awk '{print $1}')
printf '%s digest: SHA256 %s\n' "$rel_path" "$hash"
