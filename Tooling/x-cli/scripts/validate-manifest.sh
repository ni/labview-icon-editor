#!/usr/bin/env bash
set -euo pipefail

manifest=${1:-telemetry/manifest.json}

if [[ ! -f "$manifest" ]]; then
  echo "ERROR: Manifest file not found: $manifest" >&2
  exit 1
fi

if ! jq -e . "$manifest" >/dev/null 2>&1; then
  echo "ERROR: Manifest invalid JSON: $manifest" >&2
  exit 1
fi

schema=$(jq -r '.schema // ""' "$manifest")
if [[ "$schema" != "pipeline.manifest/v1" ]]; then
  echo "ERROR: Manifest schema expected 'pipeline.manifest/v1' but found '$schema'" >&2
  exit 1
fi

missing=()
jq -e '.artifacts.win_x64' "$manifest" >/dev/null 2>&1 || missing+=("artifacts.win_x64")
jq -e '.artifacts.linux_x64' "$manifest" >/dev/null 2>&1 || missing+=("artifacts.linux_x64")
jq -e '.telemetry.summary' "$manifest" >/dev/null 2>&1 || missing+=("telemetry.summary")
if ((${#missing[@]})); then
  echo "ERROR: Manifest missing required entries: ${missing[*]}" >&2
  exit 1
fi

entries=$(jq -r '
  [
    {name:"artifacts.win_x64",   path:.artifacts.win_x64.path,   sha:.artifacts.win_x64.sha256},
    {name:"artifacts.linux_x64", path:.artifacts.linux_x64.path, sha:.artifacts.linux_x64.sha256},
    {name:"telemetry.summary",   path:.telemetry.summary.path,   sha:.telemetry.summary.sha256},
    {name:"telemetry.raw",       path:(.telemetry.raw.path // ""), sha:(.telemetry.raw.sha256 // "")}
  ] | .[] | select((.path // "") != "" or (.sha // "") != "") | [.name, (.path // ""), (.sha // "")] | @tsv
' "$manifest")

status=0
while IFS=$'\t' read -r name path sha; do
  if [[ -z "$path" ]]; then
    echo "ERROR: Entry '$name' has empty path." >&2
    status=1
    continue
  fi
  if [[ -z "$sha" ]]; then
    echo "ERROR: Entry '$name' has empty sha256." >&2
    status=1
    continue
  fi
  if [[ ! -f "$path" ]]; then
    echo "ERROR: Entry '$name' path does not exist: $path" >&2
    status=1
    continue
  fi
  actual=$(sha256sum "$path" | awk '{print tolower($1)}')
  expected=$(echo "$sha" | tr 'A-F' 'a-f')
  if [[ "$actual" != "$expected" ]]; then
    echo "ERROR: SHA256 mismatch for '$name'. expected=$expected actual=$actual file=$path" >&2
    status=1
  else
    echo "OK: $name -> $path"
  fi

done <<< "$entries"

if [[ $status -ne 0 ]]; then
  exit $status
fi

echo "Manifest validated successfully."
