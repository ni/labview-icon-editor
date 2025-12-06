#!/usr/bin/env bash
set -euo pipefail

repo=""
version="v1.0.0"
branch="main"
dry_run=false

usage(){ cat <<EOF
Usage: $0 --repo owner/name [--version v1.0.0] [--branch main] [--dry-run]
Requires gh CLI authenticated: gh auth status
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --repo) repo="$2"; shift 2;;
    --version) version="$2"; shift 2;;
    --branch) branch="$2"; shift 2;;
    --dry-run) dry_run=true; shift;;
    -h|--help) usage; exit 0;;
    *) echo "Unknown arg: $1" >&2; usage; exit 2;;
  esac
done

[[ -n "$repo" ]] || { echo "--repo owner/name required" >&2; exit 2; }

if ! $dry_run; then
  if ! gh auth status >/dev/null 2>&1; then
    echo "gh not authenticated; run: gh auth login" >&2
    exit 1
  fi
fi

owner=${repo%/*}; name=${repo#*/}
[[ -n "$name" && -n "$owner" ]] || { echo "invalid repo slug" >&2; exit 2; }

tmp=$(mktemp -d 2>/dev/null || mktemp -d -t actionrepo)
echo "Working dir: $tmp"

if ! $dry_run; then
  if ! gh repo view "$repo" >/dev/null 2>&1; then
    gh repo create "$repo" --public --description "Label-gated PR comments + artifacts metadata loader composites" --disable-wiki
  fi
fi

if ! $dry_run; then gh repo clone "$repo" "$tmp" -- -q; fi

copy_rel(){
  src="$1"; dst="$2"; mkdir -p "$(dirname "$dst")"; cp -R "$src" "$dst"
}

root=$(pwd)
dst="$tmp"
echo "Copying composites and helpers…"
[[ -d .github/actions/post-comment-or-artifact ]] && copy_rel .github/actions/post-comment-or-artifact "$dst/.github/actions/post-comment-or-artifact"
[[ -d .github/actions/load-artifacts-meta ]] && copy_rel .github/actions/load-artifacts-meta "$dst/.github/actions/load-artifacts-meta"
[[ -f scripts/ghops/tools/post-comment-or-artifact.ps1 ]] && copy_rel scripts/ghops/tools/post-comment-or-artifact.ps1 "$dst/scripts/ghops/tools/post-comment-or-artifact.ps1"
[[ -f scripts/ghops/tools/post-comment-or-artifact.sh ]] && copy_rel scripts/ghops/tools/post-comment-or-artifact.sh "$dst/scripts/ghops/tools/post-comment-or-artifact.sh"
for f in .github/workflows/post-comment-or-artifact-ci.yml .github/workflows/action-pr-target-ci.yml .github/workflows/post-comment-or-artifact-release.yml .github/workflows/codeql.yml; do
  [[ -f "$f" ]] && copy_rel "$f" "$dst/$f"
done

readme="$dst/.github/actions/post-comment-or-artifact/README.md"
if [[ -f "$readme" ]]; then
  sed -i.bak "s|LabVIEW-Community-CI-CD/x-cli|$repo|g" "$readme" && rm -f "$readme.bak"
fi

if [[ ! -f "$dst/README.md" ]]; then
  printf "# PR Comment + Artifacts Composites\n\n- action-post: label-gated PR comments\n- action-artifacts: load normalized run artifacts metadata\n\nPin by major: uses: %s/action-post@v1\n" "$repo" > "$dst/README.md"
fi

if $dry_run; then
  echo "[dry-run] Skipping push/tag. Repo staged at: $dst"
  exit 0
fi

(
  cd "$dst"
  git config user.name github-actions
  git config user.email github-actions@users.noreply.github.com
  git add .
  if ! git diff --cached --quiet; then
    git commit -m "feat: initial composites (post, artifacts)"
    git push origin "HEAD:$branch"
  fi
  git tag "$version" -f || true
  git push origin "$version" --force || true
  git tag -fa v1 -m "rolling v1 -> $version" "$version"
  git push origin v1 --force
  gh release view "$version" >/dev/null 2>&1 || gh release create "$version" --title "$version" --generate-notes
)

echo "Done. Consume via:"
echo "- uses: $repo/action-post@v1"
echo "- uses: $repo/action-artifacts@v1"
