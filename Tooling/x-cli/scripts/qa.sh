#!/usr/bin/env bash
set -euo pipefail

source "$(dirname "$0")/common.sh"
"$ROOT/scripts/load_github_token.sh" || true
SOLUTION=$ROOT/XCli.sln
PROJECT=$ROOT/src/XCli/XCli.csproj
CHANGED_ONLY=0
PYTEST_LF=0
NO_PARALLEL=0
LOG_FILE=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --changed-only)
      CHANGED_ONLY=1
      ;;
    --lf)
      PYTEST_LF=1
      ;;
    --no-parallel)
      NO_PARALLEL=1
      ;;
    *)
      LOG_FILE="$1"
      ;;
  esac
  shift
done
TELEMETRY_STUB=$ROOT/.codex/telemetry.json
if [ ! -f "$TELEMETRY_STUB" ]; then
  python "$ROOT/scripts/generate_telemetry_stub.py" "$TELEMETRY_STUB"
fi
# shellcheck disable=SC1091
if [ -d "$ROOT/.venv" ]; then
  source "$ROOT/.venv/bin/activate"
fi
TELEMETRY_FILE=$ROOT/artifacts/qa-telemetry.jsonl
mkdir -p "$(dirname "$TELEMETRY_FILE")"
: > "$TELEMETRY_FILE"

[ -z "${NOTIFICATIONS_DRY_RUN:-}" ] && export NOTIFICATIONS_DRY_RUN=1

LOG_DIR="$ROOT/artifacts/logs"
mkdir -p "$LOG_DIR"

steps=()
durations=()

run_step() {
  local name="$1"
  shift
  local start=$(date +%s%3N)
  echo "==> [$name] start $start"
  local log_file="$LOG_DIR/$name.log"
  local status
  if "$ROOT/scripts/stream-output.sh" "$@" 2>&1 | tee "$log_file"; then
    status=0
  else
    status=${PIPESTATUS[0]}
  fi
  local end=$(date +%s%3N)
  local runtime=$((end - start))
  echo "<== [$name] end $end (${runtime}ms) (exit $status)"
  steps+=("$name")
  durations+=("$runtime")
  if [ "$status" -eq 0 ]; then
    printf '{"step":"%s","start":%s,"end":%s,"duration_ms":%s,"status":"pass","exit_code":%s}\n' \
      "$name" "$start" "$end" "$runtime" "$status" >> "$TELEMETRY_FILE"
  else
    printf '{"step":"%s","start":%s,"end":%s,"duration_ms":%s,"status":"fail","exit_code":%s}\n' \
      "$name" "$start" "$end" "$runtime" "$status" >> "$TELEMETRY_FILE"
    exit $status
  fi
}

trap_summary() {
  echo
  printf "%-20s %15s\n" "Step" "Duration (ms)"
  printf "%-20s %15s\n" "--------------------" "---------------"
  for i in "${!steps[@]}"; do
    printf "%-20s %15s\n" "${steps[$i]}" "${durations[$i]}"
  done
}

get_changed_files() {
  local base
  if git rev-parse --verify origin/HEAD >/dev/null 2>&1; then
    base=$(git merge-base HEAD origin/HEAD)
    git diff --name-only "$base"...
  else
    git diff --name-only
  fi
}

get_changed_dotnet_projects() {
  get_changed_files | while read -r file; do
    if [[ $file == src/* ]]; then
      local proj
      proj=$(echo "$file" | cut -d/ -f2)
      local test_proj="tests/${proj}.Tests/${proj}.Tests.csproj"
      if [[ -f $test_proj ]]; then
        echo "$test_proj"
      fi
    elif [[ $file == tests/* ]]; then
      local proj
      proj=$(echo "$file" | cut -d/ -f2)
      local csproj
      csproj=$(find "tests/$proj" -name '*.csproj' -print -quit 2>/dev/null)
      if [[ -n $csproj && $csproj =~ ^tests/$proj/[^/]+\.csproj$ ]]; then
        echo "$csproj"
      fi
    fi
  done | sort -u
}

get_changed_pytests() {
  get_changed_files | grep '^tests/.*\.py$' || true
}

if [ -n "$LOG_FILE" ]; then
  trap 'trap_summary | tee "$LOG_FILE"' EXIT
else
  trap 'trap_summary' EXIT
fi

# Install .NET SDK and Python dependencies
run_step "install-deps" "$ROOT/scripts/install_dependencies.sh"

# Ensure telemetry modules expose agent feedback
run_step "agent-feedback" python "$ROOT/scripts/check_agent_feedback.py"

# Ensure telemetry includes cross-agent feedback block
run_step "telemetry-block" python "$ROOT/scripts/check_telemetry_block.py"

# Ensure PR description includes cross-agent feedback block
run_step "agent-feedback-block" python "$ROOT/scripts/check_agent_feedback_block.py" "$ROOT/PR_DESCRIPTION.md"

# Ensure commit message follows template
run_step "commit-msg" python "$ROOT/scripts/check-commit-msg.py" "$ROOT/.git/COMMIT_EDITMSG"

# Validate Codex guard configuration
run_step "validate-codex-guard" "$ROOT/scripts/validate_codex_guard.sh"

# Verify each source file has an associated SRS ID
run_step "scan-srs-refs" python "$ROOT/scripts/scan_srs_refs.py" src notifications scripts .github/workflows

# Ensure SRS documents avoid prohibited terminology
run_step "check-srs-terms" python "$ROOT/scripts/check_srs_terms.py"

# Ensure each requirement specifies measurable acceptance criteria
run_step "check-srs-acceptance" python "$ROOT/scripts/check_srs_acceptance.py"

# Enforce ASCII-only H1 titles for changed SRS files
run_step "srs-title-ascii" python "$ROOT/scripts/check_srs_title_ascii.py"

# Verify changed SRS IDs are mapped in traceability and module maps
run_step "verify-new-srs-mappings" python "$ROOT/scripts/verify_new_srs_mappings.py"

# Ensure pre-commit hook IDs have doc links
run_step "precommit-hook-links" python "$ROOT/scripts/check_precommit_hook_links.py"

# Lint pre-commit templates (dry-run)
run_step "precommit-template-dryrun" python "$ROOT/scripts/sync_precommit_templates.py" --dry-run

# Build both Release and Debug to prevent stale outputs
run_step "build-release" dotnet build "$SOLUTION" -c Release
run_step "build-debug" dotnet build "$SOLUTION" -c Debug

# Ensure required pytest plugins are available
PYTEST_HELP=$(python -m pytest --help 2>&1 || true)
if ! grep -q -- '--timeout=' <<< "$PYTEST_HELP"; then
  echo "pytest-timeout not installed—run scripts/install_dependencies.sh" >&2
  exit 1
fi
if ! grep -q '^  -n ' <<< "$PYTEST_HELP"; then
  echo "pytest-xdist not installed—run scripts/install_dependencies.sh" >&2
  exit 1
fi

# Run Python tests with hang detection
PYTEST_ARGS=(-vv --timeout=300 --durations=20 --maxfail=1)
if (( ! NO_PARALLEL )); then
  PYTEST_ARGS+=(-n auto --dist loadfile)
fi
if (( PYTEST_LF )); then
  PYTEST_ARGS+=(--lf)
fi
if (( CHANGED_ONLY )); then
  mapfile -t changed_pytests < <(get_changed_pytests)
  if (( ${#changed_pytests[@]} )); then
    run_step "test-python" python -m pytest "${changed_pytests[@]}" "${PYTEST_ARGS[@]}"
  else
    echo "No changed Python tests detected; skipping."
  fi
else
  run_step "test-python" python -m pytest tests "${PYTEST_ARGS[@]}"
fi

# Run tests against Release build with hang detection
DOTNET_TEST_ARGS=(-c Release --no-build --logger:"console;verbosity=minimal" --blame --blame-hang --blame-hang-timeout 5m)
if (( NO_PARALLEL )); then
  DOTNET_TEST_ARGS+=(-- RunConfiguration.DisableParallelization=true)
fi

run_dotnet_projects() {
  local step_name="$1"
  shift
  local projects=("$@")
  if (( NO_PARALLEL )); then
    for proj in "${projects[@]}"; do
      local name=$(basename "${proj%.csproj}")
      local args=("${DOTNET_TEST_ARGS[@]}" "--logger:\"trx;LogFileName=test-${name}.trx\"")
      run_step "test-${name}" dotnet test "$proj" "${args[@]}"
    done
  else
    local start=$(date +%s%3N)
    echo "==> [${step_name}] start ${start}"
    local pids=()
    for proj in "${projects[@]}"; do
      local name=$(basename "${proj%.csproj}")
      local log_file="$LOG_DIR/test-${name}.log"
      local args=("${DOTNET_TEST_ARGS[@]}" "--logger:\"trx;LogFileName=test-${name}.trx\"")
      "$ROOT/scripts/stream-output.sh" dotnet test "$proj" "${args[@]}" 2>&1 | tee "$log_file" &
      pids+=("$!")
    done
    local status=0
    for pid in "${pids[@]}"; do
      if ! wait "$pid"; then
        status=1
      fi
    done
    local end=$(date +%s%3N)
    local runtime=$((end - start))
    echo "<== [${step_name}] end ${end} (${runtime}ms) (exit ${status})"
    steps+=("${step_name}")
    durations+=("${runtime}")
    if (( status == 0 )); then
      printf '{"step":"%s","start":%s,"end":%s,"duration_ms":%s,"status":"pass","exit_code":0}\n' \
        "${step_name}" "${start}" "${end}" "${runtime}" >> "$TELEMETRY_FILE"
    else
      printf '{"step":"%s","start":%s,"end":%s,"duration_ms":%s,"status":"fail","exit_code":%s}\n' \
        "${step_name}" "${start}" "${end}" "${runtime}" "${status}" >> "$TELEMETRY_FILE"
      exit ${status}
    fi
  fi
}

if (( CHANGED_ONLY )); then
  mapfile -t projects < <(get_changed_dotnet_projects)
  if (( ${#projects[@]} )); then
    run_dotnet_projects "test-changed" "${projects[@]}"
  else
    echo "No changed .NET test projects detected; skipping."
  fi
else
  mapfile -t projects < <(find "$ROOT/tests" -name '*.csproj' -print | sort)
  if (( ${#projects[@]} )); then
    run_dotnet_projects "test-release" "${projects[@]}"
  else
    echo "No .NET test projects found; skipping."
  fi
fi
run_step "summarize-tests" python "$ROOT/scripts/summarize_dotnet_tests.py" "$ROOT"

# Validate notification milestones (no milestone filter to ensure M10 runs)
# Default to dry-run mode to avoid sending real alerts. To test a provider live,
# set ENABLE_<PROVIDER>_LIVE=1 (e.g. ENABLE_DISCORD_LIVE=1) before running.
if [ -z "${NOTIFICATIONS_DRY_RUN:-}" ]; then
  run_step "validate-notifications" env NOTIFICATIONS_DRY_RUN=1 "$ROOT/scripts/validate_notifications.sh"
else
  run_step "validate-notifications" "$ROOT/scripts/validate_notifications.sh"
fi

# Simulate end-to-end dry-run notification via Discord
run_step "dry-run-discord" bash -c '
  tmp=$(mktemp)
  cat <<EOF >"$tmp"
{"timestamp":"t1","slow_test_count":0,"dependency_failures":{}}
{"timestamp":"t2","slow_test_count":1,"dependency_failures":{}}
EOF
  if NOTIFICATIONS_DRY_RUN=true DISCORD_WEBHOOK_URL=dummy \
    python "$ROOT/scripts/render_telemetry_dashboard.py" "$tmp"; then
    # Expected regression should yield non-zero exit; treat success as failure
    exit 1
  fi
'

# Publish single-file binaries for linux-x64 and win-x64
# FGC-REQ-DIST-001: cross-platform artifact publication
run_step "publish" "$ROOT/scripts/build.sh"

# Smoke run `--help`
run_step "smoke-help" dotnet run --project "$PROJECT" --no-build -- --help
