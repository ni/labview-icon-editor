#!/usr/bin/env bash
set -euo pipefail

repo_root="$(git rev-parse --show-toplevel)"
cd "$repo_root"

./scripts/setup-pre-commit.sh
git config commit.template scripts/commit-template.txt

if [ -n "${ISSUE_NUMBER:-}" ]; then
  python3 scripts/hydrate_metadata_from_issue.py "$ISSUE_NUMBER"
fi

echo "Bootstrap complete."
