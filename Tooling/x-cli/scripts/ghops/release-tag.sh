#!/usr/bin/env bash
set -euo pipefail
DIR="$(cd "$(dirname "$0")" && pwd)"
. "$DIR/util-common.sh"

usage() {
  cat <<USAGE
Usage: $0 <tag> [--notes <file>] [--attach <glob>]

Creates a Git tag and GitHub Release with optional notes and attachments.
USAGE
}

if [[ $# -lt 1 ]]; then usage; exit 2; fi

TAG="$1"; shift
NOTES=""; ATTACH=""; DRY_RUN=0; GHOPS_JSON=0
while [[ $# -gt 0 ]]; do
  case "$1" in
    --notes) NOTES="$2"; shift 2;;
    --attach) ATTACH="$2"; shift 2;;
    --json) GHOPS_JSON=1; shift;;
    --dry-run) DRY_RUN=1; shift;;
    *) shift;;
  esac
done

export DRY_RUN GHOPS_JSON
ensure_git; ensure_gh

log_ctx tag "$TAG"
if [[ -n "$NOTES" ]]; then log_ctx notes "$NOTES"; fi
if [[ -n "$ATTACH" ]]; then log_ctx attach "$ATTACH"; fi

if [[ $DRY_RUN -eq 1 ]]; then
  log_cmd git tag -s "$TAG" -m "$TAG"
  log_cmd git push origin "$TAG"
else
  git tag -s "$TAG" -m "$TAG" || git tag "$TAG" -m "$TAG"
  git push origin "$TAG"
fi

ARGS=( -R "$REPO" "$TAG" )
if [[ -n "$NOTES" && -f "$NOTES" ]]; then ARGS+=( -F "$NOTES" ); else ARGS+=( --generate-notes ); fi
if [[ -n "$ATTACH" ]]; then ARGS+=( $ATTACH ); fi

if [[ $DRY_RUN -eq 1 ]]; then
  log_cmd gh release create "${ARGS[@]}"
  log_cmd echo "Release created for $TAG"
else
  gh release create "${ARGS[@]}"
  echo "Release created for $TAG"
fi

flush_json
