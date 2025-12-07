#!/usr/bin/env bash
set -euo pipefail

# Prints which GitHub token source would be used by helper scripts.
# Order: GITHUB_USER_TOKEN -> keyring(x-cli/github_user_token) -> .secrets/github_user_token.txt -> GITHUB_TOKEN -> GH_TOKEN -> .secrets/github_token.txt
# Output: JSON with source, kind, length, and masked prefix.

here="$(cd "$(dirname "$0")" && pwd)"
root="$(cd "$here/.." && pwd)"

mask_json() {
  local tok="$1"
  if [[ -z "$tok" ]]; then
    echo '""'
    return
  fi
  local pref len
  pref="${tok:0:4}"
  len=${#tok}
  printf '"%s***"' "$pref"
}

emit_json() {
  local found="$1" kind="$2" source="$3" tok="$4"
  local len=${#tok}
  local masked
  masked=$(mask_json "$tok")
  printf '{"found":%s,"kind":"%s","source":"%s","length":%d,"token_preview":%s}\n' \
    "$found" "$kind" "$source" "$len" "$masked"
}

# 1) User token via env
if [[ -n "${GITHUB_USER_TOKEN:-}" ]]; then
  emit_json true user "env:GITHUB_USER_TOKEN" "${GITHUB_USER_TOKEN}"
  exit 0
fi

# 2) User token via keyring (best-effort)
key_tok=""
if command -v python >/dev/null 2>&1; then
  key_tok=$(python - <<'PY'
try:
    import keyring  # type: ignore
    t = keyring.get_password("x-cli", "github_user_token") or ""
    print(t.strip())
except Exception:
    print("")
PY
)
fi
if [[ -n "$key_tok" ]]; then
  emit_json true user "keyring:x-cli/github_user_token" "$key_tok"
  exit 0
fi

# 3) User token via file
if [[ -f "$root/.secrets/github_user_token.txt" ]]; then
  u_tok=$(tr -d '\r\n' < "$root/.secrets/github_user_token.txt")
  if [[ -n "$u_tok" ]]; then
    emit_json true user ".secrets/github_user_token.txt" "$u_tok"
    exit 0
  fi
fi

# 4) Repo token via env (GITHUB_TOKEN/GH_TOKEN)
if [[ -n "${GITHUB_TOKEN:-}" ]]; then
  emit_json true repo "env:GITHUB_TOKEN" "${GITHUB_TOKEN}"
  exit 0
fi
if [[ -n "${GH_TOKEN:-}" ]]; then
  emit_json true repo "env:GH_TOKEN" "${GH_TOKEN}"
  exit 0
fi

# 5) Repo token via file
if [[ -f "$root/.secrets/github_token.txt" ]]; then
  r_tok=$(tr -d '\r\n' < "$root/.secrets/github_token.txt")
  if [[ -n "$r_tok" ]]; then
    emit_json true repo ".secrets/github_token.txt" "$r_tok"
    exit 0
  fi
fi
if [[ -f "$root/github_token.txt" ]]; then
  r_tok=$(tr -d '\r\n' < "$root/github_token.txt")
  if [[ -n "$r_tok" ]]; then
    emit_json true repo "github_token.txt" "$r_tok"
    exit 0
  fi
fi

emit_json false "" "none" ""

