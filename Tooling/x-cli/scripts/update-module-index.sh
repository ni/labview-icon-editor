#!/usr/bin/env bash
set -euo pipefail

source "$(dirname "$0")/common.sh"

OUT="$ROOT/docs/module-index.md"

# Discover entries across key trees. Accept common file types and comment styles.
dirs=(
  "$ROOT/src/XCli"
  "$ROOT/src/Telemetry"
  "$ROOT/src/SrsApi"
  "$ROOT/scripts"
)

<<<<<<< HEAD
# Only search directories that exist to avoid grep errors on CI matrices
search=( )
for d in "${dirs[@]}"; do
  [ -d "$d" ] && search+=("$d")
done

# Use portable grep instead of ripgrep to avoid extra dependencies on CI
entries=""
if [ ${#search[@]} -gt 0 ]; then
  # Match only comment-annotated lines to avoid false positives in code
  # Accept C# (// ...) and shell/python/powershell (# ...)
  entries=$(grep -R -n -E \
    --include='*.cs' \
    --include='*.py' \
    --include='*.ps1' \
    --include='*.sh' \
    '^[[:space:]]*(//|#)[[:space:]]*ModuleIndex:' "${search[@]}" 2>/dev/null \
      | sed "s|$ROOT/||" \
      | sort || true)
fi
=======
# Only search directories that exist to avoid grep errors on CI matrices
search=( )
for d in "${dirs[@]}"; do
  [ -d "$d" ] && search+=("$d")
done

# Use portable grep instead of ripgrep to avoid extra dependencies on CI
entries=""
if [ ${#search[@]} -gt 0 ]; then
  # Match only comment-annotated lines to avoid false positives in code
  # Accept C# (// ...) and shell/python/powershell (# ...)
  entries=$(grep -R -n -E \
    --include='*.cs' \
    --include='*.py' \
    --include='*.ps1' \
    --include='*.sh' \
    '^[[:space:]]*(//|#)[[:space:]]*ModuleIndex:' "${search[@]}" 2>/dev/null \
      | sed "s|$ROOT/||" \
      | sort || true)
fi
>>>>>>> origin/develop

{
  echo "# Module Index"
  echo
  while IFS=: read -r file line content; do
    # Strip any leading comment markers then trim the ModuleIndex: prefix
    desc=$(echo "$content" \
      | sed -e 's/^[[:space:]]*\(\/\/\|#\)[[:space:]]*ModuleIndex:[[:space:]]*//')
    echo "- \`$file\` – $desc"
  done <<< "$entries"
} > "$OUT"
