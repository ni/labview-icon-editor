#!/usr/bin/env bash
set -euo pipefail

repo_root="$(git rev-parse --show-toplevel)"
hook_dir="$repo_root/.git/hooks"

mkdir -p "$hook_dir"
ln -sf "$repo_root/scripts/run_pre_commit.py" "$hook_dir/pre-commit"
ln -sf "$repo_root/scripts/commit-msg" "$hook_dir/commit-msg"
ln -sf "$repo_root/scripts/prepare-commit-msg.py" "$hook_dir/prepare-commit-msg"
ln -sf "$repo_root/scripts/post-commit" "$hook_dir/post-commit"

git config commit.template scripts/commit-template.txt

echo "Git hooks configured."
