#!/usr/bin/env bash
set -euo pipefail
DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=util-common.sh
. "$DIR/util-common.sh"

usage() {
  cat <<USAGE
Usage: $0 <branch-name> <title> [body-file] [--base develop] [--labels "a,b"] [--draft]

Creates a branch from base (default: develop), pushes it, and opens a PR.

Environment:
  GITHUB_REPOSITORY  Repo slug (default: LabVIEW-Community-CI-CD/x-cli)
USAGE
}

if [[ $# -lt 2 ]]; then usage; exit 2; fi

BRANCH="$1"; shift
TITLE="$1"; shift
BODY_FILE="${1:-}"
if [[ -n "${BODY_FILE}" && ! -f "${BODY_FILE}" ]]; then BODY_FILE=""; fi

BASE="develop"; LABELS=""; DRAFT=""; DRY_RUN=0; GHOPS_JSON=0
while [[ $# -gt 0 ]]; do
  case "$1" in
    --base) BASE="$2"; shift 2;;
    --labels) LABELS="$2"; shift 2;;
    --draft) DRAFT="--draft"; shift;;
    --json) GHOPS_JSON=1; shift;;
    --dry-run) DRY_RUN=1; shift;;
    *) shift;;
  esac
done


export DRY_RUN GHOPS_JSON
ensure_git; ensure_gh

# context fields
log_ctx branch "$BRANCH"
log_ctx base "$BASE"
log_ctx draft "$( [[ -n "$DRAFT" ]] && echo true || echo false )"

if [[ $DRY_RUN -eq 1 ]]; then
  log_cmd git fetch origin "$BASE"
  log_cmd git checkout -B "$BRANCH" "origin/$BASE"
  log_cmd git push -u origin "$BRANCH"
else
  git fetch origin "$BASE" || true
  git checkout -B "$BRANCH" "origin/$BASE" || git checkout -B "$BRANCH" "$BASE"
  git push -u origin "$BRANCH"
fi

ARGS=( -R "$REPO" -B "$BASE" -H "$BRANCH" -t "$TITLE" )
if [[ -n "$BODY_FILE" ]]; then ARGS+=( -F "$BODY_FILE" ); fi
if [[ -n "$LABELS" ]]; then ARGS+=( $(printf -- "--label %s " ${LABELS//,/ }) ); fi
if [[ -n "$DRAFT" ]]; then ARGS+=( --draft ); fi

if [[ $DRY_RUN -eq 1 ]]; then
  log_cmd gh pr create "${ARGS[@]}"
else
  gh pr create "${ARGS[@]}"
fi

# more context (optional)
if [[ -n "$BODY_FILE" ]]; then log_ctx bodyFile "$(cd . && printf '%s' "$BODY_FILE")"; fi
if [[ -n "$LABELS" ]]; then
  IFS=',' read -r -a __lbls <<< "$LABELS"
  __tmp=()
  for __l in "${__lbls[@]}"; do
    # trim leading/trailing spaces
    __l="${__l#${__l%%[![:space:]]*}}"; __l="${__l%${__l##*[![:space:]]}}"
    [[ -n "$__l" ]] && __tmp+=("$__l")
  done
  if [[ ${#__tmp[@]} -gt 0 ]]; then log_ctx_array labels "${__tmp[@]}"; fi
fi

flush_json
