#!/usr/bin/env bash
set -euo pipefail
REPO="LabVIEW-Community-CI-CD/x-cli"
START_BRANCH=$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo HEAD)
echo "[bootstrap] Repo slug: $REPO"

if [ "${GITHUB_REPOSITORY:-}" != "$REPO" ]; then
  export GITHUB_REPOSITORY="$REPO"
fi

CAN_PUSH=1
REMOTE_URL="git@github.com:$REPO.git"
if [ -n "${CI:-}" ]; then
  CAN_PUSH=0
  REMOTE_URL="https://github.com/$REPO.git"
fi

if git remote get-url upstream >/dev/null 2>&1; then
  git remote set-url upstream "$REMOTE_URL"
else
  git remote add upstream "$REMOTE_URL"
fi

git fetch upstream

if git show-ref --verify --quiet refs/heads/main; then
  git checkout main
else
  git checkout -b main upstream/main
fi

git pull upstream main

if git show-ref --verify --quiet refs/heads/develop; then
  git checkout develop
  git pull upstream develop || true
else
  if git show-ref --verify --quiet refs/remotes/upstream/develop; then
    git checkout -b develop upstream/develop
  else
    git checkout -b develop
    if [ "$CAN_PUSH" -eq 1 ]; then
      git push upstream develop
    else
      echo "::notice::Skipping git push (CI mode)"
    fi
  fi
fi

if git flow init -h >/dev/null 2>&1; then
  git flow init -d -b main -d develop -f feature/ -r release/ -h hotfix/
else
  echo "::notice::git flow not installed; skipping git flow init"
fi

missing=0
if command -v gh >/dev/null 2>&1; then
  if gh auth status >/dev/null 2>&1; then
    check_secret() {
      local name="$1"
      if ! gh secret list -R "$REPO" | grep -q "^$name\b"; then
        echo "::warning::Secret $name missing in $REPO" >&2
        missing=1
      fi
    }
    check_secret GH_ORG_TOKEN
    check_secret GHCR_USER
    check_secret GHCR_TOKEN
    if [ $missing -ne 0 ]; then
      echo "One or more secrets missing; see docs/issues/cleanup-workflows-and-docs.md" >&2
    fi
  else
    echo "::warning::gh CLI not authenticated; skipping secret check" >&2
  fi
else
  echo "::warning::gh CLI not found; skipping secret check" >&2
fi

if [ "$(uname -s)" = "Linux" ]; then
  if ! command -v pwsh >/dev/null 2>&1; then
    sudo apt-get update
    sudo apt-get install -y wget apt-transport-https software-properties-common
    wget -q https://packages.microsoft.com/config/ubuntu/22.04/packages-microsoft-prod.deb
    sudo dpkg -i packages-microsoft-prod.deb
    sudo apt-get update
    sudo apt-get install -y powershell
  fi
  pwsh -v
fi

pre-commit run lint-pwsh-shell --all-files || true

git checkout "$START_BRANCH" >/dev/null 2>&1 || true
echo "Bootstrap complete for $REPO"


