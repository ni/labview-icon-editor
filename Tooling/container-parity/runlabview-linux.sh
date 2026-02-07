#!/usr/bin/env bash
set -euo pipefail

LV_YEAR="${LV_YEAR:-2026}"
WORKSPACE_ROOT="${WORKSPACE_ROOT:-/workspace}"
TARGET_DIR="${TARGET_DIR:-$WORKSPACE_ROOT/Test/Templates}"
EXCLUDE_LIST="${CONTAINER_PARITY_EXCLUDE_FILES:-Polymorphic Template.vi}"
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
echo "Excluded templates: $EXCLUDE_LIST"

STAGING_DIR="$(mktemp -d)"
trap 'rm -rf "$STAGING_DIR"' EXIT
cp -a "$TARGET_DIR/." "$STAGING_DIR/"

IFS=';' read -r -a _exclude_items <<< "$EXCLUDE_LIST"
for _item in "${_exclude_items[@]}"; do
  _trimmed="$(echo "$_item" | xargs)"
  if [[ -z "$_trimmed" ]]; then
    continue
  fi
  _candidate="$STAGING_DIR/$_trimmed"
  if [[ -e "$_candidate" ]]; then
    echo "Excluding template from parity compile: $_trimmed"
    rm -rf "$_candidate"
  fi
done

LabVIEWCLI -LogToConsole TRUE \
  -OperationName MassCompile \
  -DirectoryToCompile "$STAGING_DIR" \
  -LabVIEWPath "$LABVIEW_PATH" \
  -Headless

echo "MassCompile completed successfully."
