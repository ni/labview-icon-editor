#!/usr/bin/env bash
set -euo pipefail
DIR="$(cd "$(dirname "$0")" && pwd)"
. "$DIR/util-common.sh"

usage() {
  cat <<USAGE
Usage: $0 [--run <id>] [--workflow <file>] [--branch <name>] -o <outdir>

Downloads artifacts for the given run into the output directory.
USAGE
}

RUN_ID=""; WORKFLOW=""; BRANCH=""; OUT=""; DRY_RUN=0; GHOPS_JSON=0
while [[ $# -gt 0 ]]; do
  case "$1" in
    --run) RUN_ID="$2"; shift 2;;
    --workflow) WORKFLOW="$2"; shift 2;;
    --branch) BRANCH="$2"; shift 2;;
    -o|--out) OUT="$2"; shift 2;;
    --json) GHOPS_JSON=1; shift;;
    --dry-run) DRY_RUN=1; shift;;
    -h|--help) usage; exit 0;;
    *) shift;;
  esac
done

if [[ -z "$OUT" ]]; then echo "error: -o <outdir> is required" >&2; exit 2; fi
mkdir -p "$OUT"

export DRY_RUN GHOPS_JSON
ensure_gh

if [[ -z "$RUN_ID" ]]; then
  if [[ -n "$WORKFLOW" ]]; then
    if [[ -n "$RUN_ID" ]]; then log_ctx run "$RUN_ID"; fi
    if [[ -n "$WORKFLOW" ]]; then log_ctx workflow "$WORKFLOW"; fi
    if [[ -n "$BRANCH" ]]; then log_ctx branch "$BRANCH"; fi
    if [[ $DRY_RUN -eq 1 ]]; then
      if [[ -n "$BRANCH" ]]; then
        log_cmd gh run list -R "$REPO" --workflow "$WORKFLOW" --branch "$BRANCH" -L 1 --json databaseId --jq '.[0].databaseId'
      else
        log_cmd gh run list -R "$REPO" --workflow "$WORKFLOW" -L 1 --json databaseId --jq '.[0].databaseId'
      fi
      RUN_ID='<resolved-run-id>'
    else
      if [[ -n "$BRANCH" ]]; then
        RUN_ID=$(gh run list -R "$REPO" --workflow "$WORKFLOW" --branch "$BRANCH" -L 1 --json databaseId --jq '.[0].databaseId')
      else
        RUN_ID=$(gh run list -R "$REPO" --workflow "$WORKFLOW" -L 1 --json databaseId --jq '.[0].databaseId')
      fi
    fi
  else
    usage
    usage_error "Provide --run <id> or --workflow <file> [--branch <name>]"
  fi
fi

if [[ $DRY_RUN -eq 1 ]]; then
  log_cmd gh run download -R "$REPO" "$RUN_ID" -D "$OUT"
  log_cmd echo "Artifacts downloaded to: $OUT"
else
  gh run download -R "$REPO" "$RUN_ID" -D "$OUT"
  echo "Artifacts downloaded to: $OUT"
fi

log_ctx runId "$RUN_ID"
log_ctx out "$OUT"

flush_json
