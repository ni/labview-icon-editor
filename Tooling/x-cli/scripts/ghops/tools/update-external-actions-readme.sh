#!/usr/bin/env bash
set -euo pipefail

repo=""
post_slug=""
art_slug=""
branch="main"
dry=false
max_wait=12
quiet=false

usage(){ cat <<EOF
Usage: $0 --repo owner/name --post-slug POST_SLUG --artifacts-slug ART_SLUG [--branch main] [--max-wait 12] [--quiet] [--dry]
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --repo) repo="$2"; shift 2;;
    --post-slug) post_slug="$2"; shift 2;;
    --artifacts-slug) art_slug="$2"; shift 2;;
    --branch) branch="$2"; shift 2;;
    --max-wait) max_wait="$2"; shift 2;;
    --quiet) quiet=true; shift;;
    --dry) dry=true; shift;;
    -h|--help) usage; exit 0;;
    *) echo "Unknown arg: $1" >&2; usage; exit 2;;
  esac
done

[[ -n "$repo" && -n "$post_slug" && -n "$art_slug" ]] || { usage; exit 2; }

if ! $dry; then
  gh auth status >/dev/null 2>&1 || { echo "gh not authenticated" >&2; exit 1; }
fi

tmp=$(mktemp -d 2>/dev/null || mktemp -d -t actionsreadme)
if ! $dry; then gh repo clone "$repo" "$tmp" -- -q; fi

post_ci="https://github.com/$repo/actions/workflows/post-comment-or-artifact-ci.yml"
pr_ci="https://github.com/$repo/actions/workflows/action-pr-target-ci.yml"
rel_ci="https://github.com/$repo/actions/workflows/post-comment-or-artifact-release.yml"
releases="https://github.com/$repo/releases"

# Validate marketplace URLs (best-effort)
post_url="https://github.com/marketplace/actions/$post_slug"
art_url="https://github.com/marketplace/actions/$art_slug"
if command -v curl >/dev/null 2>&1; then
  get_code() {
    local url="$1"; local delay=2; local code=""; local remaining=$max_wait; local attempts=0; local elapsed=0
    while true; do
      attempts=$((attempts+1))
      code=$(curl -s -o /dev/null -w "%{http_code}" -L "$url" || true)
      [[ "$code" == "200" ]] && { last_attempts=$attempts; last_elapsed=$elapsed; echo "$code"; return; }
      [[ $remaining -le 0 ]] && { last_attempts=$attempts; last_elapsed=$elapsed; echo "$code"; return; }
      sleep "$delay"
      elapsed=$((elapsed + delay))
      remaining=$((remaining - delay))
      if (( remaining <= 0 )); then last_attempts=$attempts; last_elapsed=$elapsed; echo "$code"; return; fi
      delay=$(( delay * 2 ))
      if (( delay > remaining )); then delay=$remaining; fi
    done
  }
  post_code=$(get_code "$post_url"); post_attempts=${last_attempts:-0}; post_elapsed=${last_elapsed:-0}
  [[ "$quiet" != true ]] && echo "Marketplace (post): HTTP $post_code attempts=$post_attempts elapsed=${post_elapsed}s"
  [[ "$post_code" != "200" && "$quiet" != true ]] && echo "warning: marketplace URL check (post) returned HTTP $post_code for $post_url" >&2
  art_code=$(get_code "$art_url"); art_attempts=${last_attempts:-0}; art_elapsed=${last_elapsed:-0}
  [[ "$quiet" != true ]] && echo "Marketplace (artifacts): HTTP $art_code attempts=$art_attempts elapsed=${art_elapsed}s"
  [[ "$art_code" != "200" && "$quiet" != true ]] && echo "warning: marketplace URL check (artifacts) returned HTTP $art_code for $art_url" >&2
  if [[ -n "${GITHUB_OUTPUT:-}" ]]; then
    printf 'post_http_code=%s\n' "$post_code" >> "$GITHUB_OUTPUT"
    printf 'artifacts_http_code=%s\n' "$art_code" >> "$GITHUB_OUTPUT"
    printf 'post_http_attempts=%s\n' "$post_attempts" >> "$GITHUB_OUTPUT"
    printf 'post_http_elapsed=%s\n' "$post_elapsed" >> "$GITHUB_OUTPUT"
    printf 'artifacts_http_attempts=%s\n' "$art_attempts" >> "$GITHUB_OUTPUT"
    printf 'artifacts_http_elapsed=%s\n' "$art_elapsed" >> "$GITHUB_OUTPUT"
    status=ok; [[ "$post_code" != "200" || "$art_code" != "200" ]] && status=warn
    msg="post=$post_code attempts=$post_attempts elapsed=${post_elapsed}s; artifacts=$art_code attempts=$art_attempts elapsed=${art_elapsed}s"
    printf 'status=%s\n' "$status"  >> "$GITHUB_OUTPUT"
    printf 'message=%s\n' "$msg"    >> "$GITHUB_OUTPUT"
  fi
  if [[ -n "${GITHUB_STEP_SUMMARY:-}" ]]; then
    {
      echo '### Marketplace Probe'
      echo "status: $status"
      echo "$msg"
    } >> "$GITHUB_STEP_SUMMARY"
  fi
fi

readme="$tmp/README.md"
cat > "$readme" <<MD
# PR Comment + Artifacts Composites

[![Action CI]($post_ci/badge.svg)]($post_ci) [![PR Target CI]($pr_ci/badge.svg)]($pr_ci) [![Release Workflow]($rel_ci/badge.svg)]($rel_ci)

[![Latest Release](https://img.shields.io/github/v/release/$repo?label=gha-pr-comment-and-artifacts)]($releases) [![Channel v1](https://img.shields.io/badge/channel-v1-blue)](https://github.com/$repo/releases/tag/v1)

## Actions

### Post PR Comment (label-gated)
[![Marketplace – Post PR Comment](https://img.shields.io/badge/Marketplace-Post%20PR%20Comment-blue)](https://github.com/marketplace/actions/$post_slug)

Install
```yaml
- name: Post telemetry comment (label-gated)
  uses: $repo/action-post@v1
  with:
    label: telemetry-chunk-diag
    comment_path: telemetry/comment.md
```

### Load Artifacts Metadata
[![Marketplace – Load Artifacts Metadata](https://img.shields.io/badge/Marketplace-Load%20Artifacts%20Metadata-blue)](https://github.com/marketplace/actions/$art_slug)

Install
```yaml
- name: Load artifacts metadata
  id: meta
  uses: $repo/action-artifacts@v1
  with:
    prefer_cache: true
    output_path: telemetry/artifacts_meta.json
```

## Notes
- Pin to `@v1` for the rolling major, or to an exact tag like `@v1.0.0`.
- See each action directory for detailed usage and troubleshooting.
MD

if $dry; then
  echo "[dry] Would write README to $repo"; head -n 20 "$readme"
  exit 0
fi

( cd "$tmp" && git config user.name github-actions && git config user.email github-actions@users.noreply.github.com && git add README.md && { git diff --cached --quiet || git commit -m "docs: add badges and install snippets to README"; } && git push origin "HEAD:$branch" )

echo "Updated README in $repo ($branch)."
