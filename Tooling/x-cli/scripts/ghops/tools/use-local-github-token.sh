#!/usr/bin/env bash
set -euo pipefail

here="$(cd "$(dirname "$0")" && pwd)"
root="$(cd "$here/../../.." && pwd)"
bindir="$root/.tools/bin"
secrets="$root/.secrets"
token="$secrets/github_token.txt"

mkdir -p "$secrets"
gi="$secrets/.gitignore"
if [[ ! -f "$gi" ]]; then
  printf "*\n!.gitignore\n!README.md\n" > "$gi"
fi

# Ensure .tools/bin is on PATH for this shell
mkdir -p "$bindir"
case ":$PATH:" in
  *":$bindir:"*) ;; # already present
  *) export PATH="$bindir:$PATH"; echo "Added to PATH for this shell: $bindir";;
esac

if [[ ! -f "$token" ]]; then
  : > "$token"
  echo "Created placeholder: $token"
  echo "Paste your PAT (single line) and re-run."
  exit 0
fi

# Load env vars into current shell
if [[ -f "$root/scripts/load_github_token.sh" ]]; then
  # shellcheck source=/dev/null
  . "$root/scripts/load_github_token.sh"
fi

if [[ -z "${GITHUB_TOKEN:-}" ]]; then
  echo "warning: no token loaded; ensure $token contains your PAT" >&2
  exit 1
fi

validate=false
login=false
for a in "$@"; do
  case "$a" in
    --login) login=true;;
    --validate) validate=true;;
  esac
done

if $validate || $login; then
  if command -v curl >/dev/null 2>&1; then
    case "${GITHUB_TOKEN:-}" in
      ghp_*|github_pat_*) : ;; # looks typical
      *) echo "warning: token format looks unusual (expected ghp_ or github_pat_ prefix); continuing with HTTP validation." >&2 ;;
    esac
    if ! curl -sSf -H "authorization: token $GITHUB_TOKEN" -H 'accept: application/vnd.github+json' https://api.github.com/rate_limit >/dev/null; then
      echo "warning: token validation failed (HTTP ping). Ensure the PAT is valid and not expired." >&2
      echo "warning: reminder — for publishing/comments, the PAT should include at least the 'repo' scope." >&2
      exit 3
    else
      echo "Token validation succeeded."
    fi
  fi
fi

if $login; then
  if ! command -v gh >/dev/null 2>&1; then
    echo "error: gh CLI not found. Install gh and re-run, or place a portable binary at: $bindir/gh" >&2
    exit 2
  fi
  # Temporarily unset GH_TOKEN so gh accepts stdin token
  _prev_gh_token="${GH_TOKEN:-}"
  _prev_github_token="${GITHUB_TOKEN:-}"
  unset GH_TOKEN
  unset GITHUB_TOKEN
  gh auth login --with-token < "$token"
  # Restore GH_TOKEN for this shell
  if [[ -n "${_prev_gh_token}" ]]; then export GH_TOKEN="${_prev_gh_token}"; else export GH_TOKEN="${GITHUB_TOKEN:-}"; fi
  if [[ -n "${_prev_github_token}" ]]; then export GITHUB_TOKEN="${_prev_github_token}"; else export GITHUB_TOKEN="${GH_TOKEN:-}"; fi
  gh auth status || true
fi

echo "Loaded token into env for this session (GITHUB_TOKEN, GH_TOKEN)."
