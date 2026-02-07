#!/usr/bin/env bash
set -euo pipefail

LV_YEAR="${LV_YEAR:-2026}"
WORKSPACE_ROOT="${WORKSPACE_ROOT:-/workspace}"
TARGET_DIR="${TARGET_DIR:-$WORKSPACE_ROOT/Test/Templates}"
LABVIEW_PATH="${LABVIEW_PATH:-/usr/local/natinst/LabVIEW-${LV_YEAR}-64/labviewprofull}"

if ! command -v LabVIEWCLI >/dev/null 2>&1; then
  echo "ERROR: LabVIEWCLI is not available on PATH inside the container." >&2
  exit 1
fi

if [[ ! -d "$TARGET_DIR" ]]; then
  echo "ERROR: Target directory does not exist: $TARGET_DIR" >&2
  exit 1
fi

echo "Running LabVIEWCLI MassCompile in headless mode."
echo "Target directory: $TARGET_DIR"
echo "LabVIEW path: $LABVIEW_PATH"

LabVIEWCLI -LogToConsole TRUE \
  -OperationName MassCompile \
  -DirectoryToCompile "$TARGET_DIR" \
  -LabVIEWPath "$LABVIEW_PATH" \
  -Headless

echo "MassCompile completed successfully."
