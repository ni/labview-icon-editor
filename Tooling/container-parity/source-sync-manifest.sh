#!/usr/bin/env bash

sync_manifest_json_escape() {
  local value="${1:-}"
  value="${value//\\/\\\\}"
  value="${value//\"/\\\"}"
  value="${value//$'\n'/\\n}"
  value="${value//$'\r'/\\r}"
  value="${value//$'\t'/\\t}"
  printf '%s' "$value"
}

sync_manifest_sha256() {
  local path="$1"
  sha256sum "$path" | awk '{print $1}'
}

sync_manifest_capture_before_state() {
  local source_root="$1"
  local destination_root="$2"
  local snapshot_path="$3"

  : > "$snapshot_path"
  if [[ ! -d "$source_root" ]]; then
    return 0
  fi

  while IFS= read -r source_path; do
    local relative_path="${source_path#"$source_root"/}"
    local destination_path="$destination_root/$relative_path"
    if [[ -f "$destination_path" ]]; then
      local destination_hash
      destination_hash="$(sync_manifest_sha256 "$destination_path")"
      printf '%s\t1\t%s\n' "$relative_path" "$destination_hash" >> "$snapshot_path"
    else
      printf '%s\t0\t\n' "$relative_path" >> "$snapshot_path"
    fi
  done < <(find "$source_root" -type f | LC_ALL=C sort)
}

sync_manifest_write() {
  local manifest_path="$1"
  local repo_root="$2"
  local labview_root="$3"
  local context="$4"
  shift 4

  local generated_utc
  generated_utc="$(date -u +%Y-%m-%dT%H:%M:%SZ)"

  local git_sha="unknown"
  if command -v git >/dev/null 2>&1; then
    local resolved_sha=""
    resolved_sha="$(git -C "$repo_root" rev-parse HEAD 2>/dev/null || true)"
    if [[ -n "$resolved_sha" ]]; then
      git_sha="$resolved_sha"
    fi
  fi

  mkdir -p "$(dirname "$manifest_path")"

  local group_files=()
  local total_files=0
  local total_added=0
  local total_updated=0
  local total_unchanged=0
  local total_missing_after=0
  local total_hash_mismatch=0

  while (( "$#" >= 4 )); do
    local group_id="$1"
    local source_root="$2"
    local destination_root="$3"
    local snapshot_path="$4"
    shift 4

    local files_json_path
    files_json_path="$(mktemp)"
    local first_file=true

    local file_count=0
    local added_count=0
    local updated_count=0
    local unchanged_count=0
    local missing_after_count=0
    local hash_mismatch_count=0

    if [[ -f "$snapshot_path" ]]; then
      while IFS=$'\t' read -r relative_path existed_before before_hash; do
        if [[ -z "$relative_path" ]]; then
          continue
        fi

        local source_path="$source_root/$relative_path"
        local destination_path="$destination_root/$relative_path"
        if [[ ! -f "$source_path" ]]; then
          continue
        fi

        local source_hash
        source_hash="$(sync_manifest_sha256 "$source_path")"

        local destination_exists=false
        local destination_hash=""
        if [[ -f "$destination_path" ]]; then
          destination_exists=true
          destination_hash="$(sync_manifest_sha256 "$destination_path")"
        fi

        local classification=""
        if [[ "$destination_exists" == "false" ]]; then
          classification="missing_after"
          missing_after_count=$((missing_after_count + 1))
        elif [[ "$existed_before" != "1" ]]; then
          classification="added"
          added_count=$((added_count + 1))
        elif [[ "$before_hash" == "$source_hash" ]]; then
          classification="unchanged"
          unchanged_count=$((unchanged_count + 1))
        else
          classification="updated"
          updated_count=$((updated_count + 1))
        fi

        local hash_matches=false
        if [[ "$destination_exists" == "true" && "$destination_hash" == "$source_hash" ]]; then
          hash_matches=true
        else
          hash_mismatch_count=$((hash_mismatch_count + 1))
        fi

        file_count=$((file_count + 1))
        local source_size
        source_size="$(wc -c < "$source_path" | xargs)"
        local destination_size=0
        if [[ "$destination_exists" == "true" ]]; then
          destination_size="$(wc -c < "$destination_path" | xargs)"
        fi

        if [[ "$first_file" != "true" ]]; then
          printf ',\n' >> "$files_json_path"
        fi
        first_file=false

        printf '        {\n' >> "$files_json_path"
        printf '          "relative_path": "%s",\n' "$(sync_manifest_json_escape "$relative_path")" >> "$files_json_path"
        printf '          "source_path": "%s",\n' "$(sync_manifest_json_escape "$source_path")" >> "$files_json_path"
        printf '          "destination_path": "%s",\n' "$(sync_manifest_json_escape "$destination_path")" >> "$files_json_path"
        printf '          "classification": "%s",\n' "$(sync_manifest_json_escape "$classification")" >> "$files_json_path"
        printf '          "source_sha256": "%s",\n' "$(sync_manifest_json_escape "$source_hash")" >> "$files_json_path"
        printf '          "destination_sha256": "%s",\n' "$(sync_manifest_json_escape "$destination_hash")" >> "$files_json_path"
        printf '          "source_size": %s,\n' "$source_size" >> "$files_json_path"
        printf '          "destination_size": %s,\n' "$destination_size" >> "$files_json_path"
        printf '          "hash_matches": %s\n' "$hash_matches" >> "$files_json_path"
        printf '        }' >> "$files_json_path"
      done < "$snapshot_path"
    fi

    local group_json_path
    group_json_path="$(mktemp)"
    {
      printf '    {\n'
      printf '      "id": "%s",\n' "$(sync_manifest_json_escape "$group_id")"
      printf '      "source_root": "%s",\n' "$(sync_manifest_json_escape "$source_root")"
      printf '      "destination_root": "%s",\n' "$(sync_manifest_json_escape "$destination_root")"
      printf '      "file_count": %s,\n' "$file_count"
      printf '      "added_count": %s,\n' "$added_count"
      printf '      "updated_count": %s,\n' "$updated_count"
      printf '      "unchanged_count": %s,\n' "$unchanged_count"
      printf '      "missing_after_count": %s,\n' "$missing_after_count"
      printf '      "hash_mismatch_count": %s,\n' "$hash_mismatch_count"
      printf '      "files": [\n'
      cat "$files_json_path"
      printf '\n      ]\n'
      printf '    }'
    } > "$group_json_path"

    group_files+=("$group_json_path")
    rm -f "$files_json_path"

    total_files=$((total_files + file_count))
    total_added=$((total_added + added_count))
    total_updated=$((total_updated + updated_count))
    total_unchanged=$((total_unchanged + unchanged_count))
    total_missing_after=$((total_missing_after + missing_after_count))
    total_hash_mismatch=$((total_hash_mismatch + hash_mismatch_count))
  done

  {
    printf '{\n'
    printf '  "schema_version": "1.0",\n'
    printf '  "manifest_kind": "source-sync",\n'
    printf '  "generated_utc": "%s",\n' "$generated_utc"
    printf '  "git_sha": "%s",\n' "$(sync_manifest_json_escape "$git_sha")"
    printf '  "context": "%s",\n' "$(sync_manifest_json_escape "$context")"
    printf '  "repo_root": "%s",\n' "$(sync_manifest_json_escape "$repo_root")"
    printf '  "labview_root": "%s",\n' "$(sync_manifest_json_escape "$labview_root")"
    printf '  "groups": [\n'
    local index=0
    for group_file in "${group_files[@]}"; do
      if (( index > 0 )); then
        printf ',\n'
      fi
      cat "$group_file"
      index=$((index + 1))
    done
    printf '\n  ],\n'
    printf '  "summary": {\n'
    printf '    "file_count": %s,\n' "$total_files"
    printf '    "added_count": %s,\n' "$total_added"
    printf '    "updated_count": %s,\n' "$total_updated"
    printf '    "unchanged_count": %s,\n' "$total_unchanged"
    printf '    "missing_after_count": %s,\n' "$total_missing_after"
    printf '    "hash_mismatch_count": %s\n' "$total_hash_mismatch"
    printf '  }\n'
    printf '}\n'
  } > "$manifest_path"

  for group_file in "${group_files[@]}"; do
    rm -f "$group_file"
  done
}
