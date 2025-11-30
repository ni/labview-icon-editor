#!/usr/bin/env sh
set -u

emit() {
  ts=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
  printf '{"timestamp":"%s","check":"%s","status":"%s","details":"%s"}\n' "$ts" "$1" "$2" "$3"
}

fail=0

files=$(grep -R -l "Codex Authorship Guard" .github/workflows 2>/dev/null || true)
if [ -n "$files" ]; then
  emit "workflows-codex-authorship-guard" "pass" "found in $(echo "$files" | tr '\n' ' ')"
else
  emit "workflows-codex-authorship-guard" "fail" "missing Codex Authorship Guard job"
  fail=$((fail + 1))
fi

if [ -f .github/pull_request_template.md ] && grep -q "Codex-Mirror-Signature" .github/pull_request_template.md; then
  emit "pr-template-codex-mirror-signature" "pass" "section present"
else
  emit "pr-template-codex-mirror-signature" "fail" "section missing"
  fail=$((fail + 1))
fi

if [ -x scripts/codex_guard_verify.js ]; then
  emit "verify-script-executable" "pass" "scripts/codex_guard_verify.js executable"
else
  emit "verify-script-executable" "fail" "scripts/codex_guard_verify.js missing or not executable"
  fail=$((fail + 1))
fi

if [ -f docs/codex-mirror.md ]; then
  emit "codex-mirror-doc" "pass" "docs/codex-mirror.md exists"
else
  emit "codex-mirror-doc" "fail" "docs/codex-mirror.md missing"
  fail=$((fail + 1))
fi

exit $fail
