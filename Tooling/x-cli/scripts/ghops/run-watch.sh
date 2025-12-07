#!/usr/bin/env bash
set -euo pipefail
DIR="$(cd "$(dirname "$0")" && pwd)"
. "$DIR/util-common.sh"

usage() {
  cat <<USAGE
Usage: $0 <workflow.yml|run-id> [--branch <name>]

Watches the latest run for a workflow on the given branch, or a specific run ID,
and exits with its status.
USAGE
}

if [[ $# -lt 1 ]]; then usage; exit 2; fi

TARGET="$1"; shift
BRANCH=""; DRY_RUN=0; GHOPS_JSON=0
while [[ $# -gt 0 ]]; do
  case "$1" in
    --branch) BRANCH="$2"; shift 2;;
    --json) GHOPS_JSON=1; shift;;
    --dry-run) DRY_RUN=1; shift;;
    *) shift;;
  esac
done

export DRY_RUN GHOPS_JSON
ensure_gh

RUN_ID=""
if [[ "$TARGET" =~ ^[0-9]+$ ]]; then
  RUN_ID="$TARGET"
else
  log_ctx target "$TARGET"
  if [[ -n "$BRANCH" ]]; then log_ctx branch "$BRANCH"; fi
  if [[ $DRY_RUN -eq 1 ]]; then
    if [[ -n "$BRANCH" ]]; then
      log_cmd gh run list -R "$REPO" --workflow "$TARGET" --branch "$BRANCH" -L 1 --json databaseId --jq '.[0].databaseId'
    else
      log_cmd gh run list -R "$REPO" --workflow "$TARGET" -L 1 --json databaseId --jq '.[0].databaseId'
    fi
    RUN_ID='<resolved-run-id>'
  else
    # resolve by workflow + branch
    if [[ -n "$BRANCH" ]]; then
      RUN_ID=$(gh run list -R "$REPO" --workflow "$TARGET" --branch "$BRANCH" -L 1 --json databaseId --jq '.[0].databaseId')
    else
      RUN_ID=$(gh run list -R "$REPO" --workflow "$TARGET" -L 1 --json databaseId --jq '.[0].databaseId')
    fi
  fi
fi

if [[ -z "$RUN_ID" ]]; then
  echo "error: No workflow run found" >&2
  exit 1
fi

log_ctx runId "$RUN_ID"

if [[ $DRY_RUN -eq 1 ]]; then
  log_cmd gh run watch -R "$REPO" "$RUN_ID" --exit-status
  log_cmd gh run view -R "$REPO" "$RUN_ID"
else
  gh run watch -R "$REPO" "$RUN_ID" --exit-status
  gh run view -R "$REPO" "$RUN_ID"
fi

flush_json
