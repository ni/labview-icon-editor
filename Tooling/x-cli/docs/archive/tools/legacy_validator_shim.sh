#!/usr/bin/env bash
set -euo pipefail

# Usage:
#  Legacy external validator shim (archived)
#  JARVIS_SHIM_MODE=validate|ingest
#  JARVIS_SHIM_ROOT=<dir> or JARVIS_SHIM_ZIP=<file>
#  Optional: JARVIS_INGEST_ROOT
#
# Outputs (GitHub Actions): JARVIS_OVERALL, JARVIS_INGESTED, JARVIS_JSON
#
# Requires: jarvis CLI in repo (dotnet run --project ...), or installed globally if you swap the command.

REPO_ROOT="${REPO_ROOT:-$(git rev-parse --show-toplevel 2>/dev/null || pwd)}"
MODE="${JARVIS_SHIM_MODE:-validate}"
ROOT="${JARVIS_SHIM_ROOT:-}"
ZIPF="${JARVIS_SHIM_ZIP:-}"
PROJECT_PATH="${PROJECT_PATH:-src/Jarvis/Jarvis.csproj}"

if [[ "$MODE" != "validate" && "$MODE" != "ingest" ]]; then
  echo "ERROR: JARVIS_SHIM_MODE must be validate or ingest" >&2
  exit 2
fi

CMD=(dotnet run --project "$PROJECT_PATH" -- "$MODE")
if [[ -n "${ROOT}" ]]; then
  CMD+=("--root" "$ROOT")
elif [[ -n "${ZIPF}" ]]; then
  CMD+=("--zip" "$ZIPF")
else
  echo "ERROR: provide JARVIS_SHIM_ROOT or JARVIS_SHIM_ZIP" >&2
  exit 2
fi
CMD+=("--json")

set +e
STDOUT=$("${CMD[@]}" 2>stderr.log)
CODE=$?
set -e

# Write raw JSON to file for consumers
OUT_JSON="${OUT_JSON:-jarvis-result.json}"
printf "%s" "$STDOUT" > "$OUT_JSON"

# Parse JSON using jq if present, fallback to Python
OVERALL=""
INGESTED=""
if command -v jq >/dev/null 2>&1; then
  OVERALL=$(jq -r '(.overallPassed // .isValid) // false' "$OUT_JSON")
  INGESTED=$(jq -r '(.ingested // false)' "$OUT_JSON" 2>/dev/null || echo "false")
else
  python3 - "$OUT_JSON" <<'PY'
import json,sys
data=json.load(open(sys.argv[1]))
print((str(data.get("overallPassed", data.get("isValid", False))).lower()))
print((str(data.get("ingested", False)).lower()))
PY
fi | {
  read OVERALL || OVERALL="false"
  read INGESTED || INGESTED="false"
  echo "OVERALL=$OVERALL" > shim.vars
  echo "INGESTED=$INGESTED" >> shim.vars
}

# Export to GitHub Actions output if available
if [[ -n "${GITHUB_OUTPUT:-}" && -f shim.vars ]]; then
  . shim.vars
  {
    echo "JARVIS_OVERALL=$OVERALL"
    echo "JARVIS_INGESTED=$INGESTED"
    echo "JARVIS_JSON=$OUT_JSON"
  } >> "$GITHUB_OUTPUT"
fi

# Mirror exit codes: 0 pass, 1 validation fail, 2 error
exit "$CODE"
