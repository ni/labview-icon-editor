#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$(cd "$script_dir/.." && pwd)"

dotnet_bin="${DOTNET_BIN:-dotnet}"
runner_cli_project="${LVIE_RUNNER_CLI_PROJECT:-$repo_root/Tooling/runner-cli/RunnerCli/RunnerCli.csproj}"
mode="${LVIE_PARITY_MODE:-linux-container}"
configuration="${LVIE_DOTNET_CONFIGURATION:-Release}"
run_psscriptanalyzer_raw="${LVIE_RUN_PSSCRIPTANALYZER:-true}"
run_pylavi_raw="${LVIE_RUN_PYLAVI:-true}"
run_vi_analyzer_raw="${LVIE_RUN_VI_ANALYZER:-auto}"
pwsh_bin="${LVIE_PWSH_BIN:-pwsh}"
pylavi_profile="${LVIE_PYLAVI_PROFILE:-strict}"
pylavi_config_path="${LVIE_PYLAVI_CONFIG_PATH:-}"
pylavi_report_only_raw="${LVIE_PYLAVI_REPORT_ONLY:-false}"
pylavi_skip_version_gate_raw="${LVIE_PYLAVI_SKIP_VERSION_GATE:-false}"
context_path="${LVIE_PARITY_CONTEXT_PATH:-$repo_root/TestResults/container-parity/${mode}-context.json}"

if ! command -v "$dotnet_bin" >/dev/null 2>&1; then
  echo "ERROR: dotnet SDK was not found on PATH (DOTNET_BIN=${dotnet_bin})." >&2
  exit 1
fi

if [[ ! -f "$runner_cli_project" ]]; then
  echo "ERROR: runner-cli project not found: $runner_cli_project" >&2
  exit 1
fi

normalize_bool() {
  local raw="${1:-}"
  shopt -s nocasematch
  case "$raw" in
    1|true|yes|on) shopt -u nocasematch; return 0 ;;
    *) shopt -u nocasematch; return 1 ;;
  esac
}

validate_mandatory_build_spec() {
  if [[ -z "${LVIE_PARITY_BUILD_SPEC+x}" ]]; then
    return 0
  fi

  if normalize_bool "${LVIE_PARITY_BUILD_SPEC}"; then
    return 0
  fi

  echo "ERROR: LVIE_PARITY_BUILD_SPEC disable is unsupported. Build-spec execution is mandatory; unset LVIE_PARITY_BUILD_SPEC or set it to true." >&2
  exit 1
}

run_powershell_lint() {
  local enabled_raw="${1:-true}"
  if ! normalize_bool "$enabled_raw"; then
    echo "Skipping PSScriptAnalyzer (LVIE_RUN_PSSCRIPTANALYZER=${enabled_raw})"
    return 0
  fi

  if ! command -v "$pwsh_bin" >/dev/null 2>&1; then
    echo "ERROR: pwsh was not found on PATH (LVIE_PWSH_BIN=${pwsh_bin})." >&2
    exit 1
  fi

  echo "Ensuring PSScriptAnalyzer module is installed..."
  (
    cd "$repo_root"
    "$pwsh_bin" -NoProfile -Command "\$ErrorActionPreference='Stop'; if (-not (Get-Module -ListAvailable -Name PSScriptAnalyzer)) { Install-Module PSScriptAnalyzer -Scope CurrentUser -Force -AllowClobber }"
  )

  echo "Running PSScriptAnalyzer..."
  (
    cd "$repo_root"
    "$pwsh_bin" -NoProfile -File "./Tooling/Invoke-PSScriptAnalyzer.ps1" -WriteSummary
  )
}

run_pylavi_gate() {
  local enabled_raw="${1:-true}"
  if ! normalize_bool "$enabled_raw"; then
    echo "Skipping pylavi vi_validate gate (LVIE_RUN_PYLAVI=${enabled_raw})"
    return 0
  fi

  if ! command -v "$pwsh_bin" >/dev/null 2>&1; then
    echo "ERROR: pwsh was not found on PATH (LVIE_PWSH_BIN=${pwsh_bin}); cannot run Tooling/Run-ViValidate.ps1." >&2
    exit 1
  fi

  local vi_validate_args=(-NoProfile -File "./Tooling/Run-ViValidate.ps1" -ViValidateProfile "$pylavi_profile")
  if [[ -n "$pylavi_config_path" ]]; then
    vi_validate_args+=(-ViValidateConfigPath "$pylavi_config_path")
  fi
  if normalize_bool "$pylavi_report_only_raw"; then
    vi_validate_args+=(-ViValidateReportOnly)
  fi
  if normalize_bool "$pylavi_skip_version_gate_raw"; then
    vi_validate_args+=(-ViValidateSkipVersionGate)
  fi

  echo "Running pylavi vi_validate gate..."
  (
    cd "$repo_root"
    "$pwsh_bin" "${vi_validate_args[@]}"
  )
}

run_vi_analyzer_gate() {
  local mode_raw="${1:-auto}"
  local mode="${mode_raw,,}"

  case "$mode" in
    false|0|no|off)
      echo "Skipping VI Analyzer gate (LVIE_RUN_VI_ANALYZER=${mode_raw})"
      return 0
      ;;
    auto|true|1|yes|on)
      ;;
    *)
      echo "ERROR: LVIE_RUN_VI_ANALYZER must be one of auto|true|false (received '${mode_raw}')." >&2
      exit 1
      ;;
  esac

  if ! command -v "$pwsh_bin" >/dev/null 2>&1; then
    if [[ "$mode" == "auto" ]]; then
      echo "Skipping VI Analyzer gate in auto mode: pwsh not found on PATH (LVIE_PWSH_BIN=${pwsh_bin})."
      return 0
    fi
    echo "ERROR: pwsh was not found on PATH (LVIE_PWSH_BIN=${pwsh_bin}); cannot run Tooling/Run-ViAnalyzer.ps1." >&2
    exit 1
  fi

  if ! command -v docker >/dev/null 2>&1; then
    if [[ "$mode" == "auto" ]]; then
      echo "Skipping VI Analyzer gate in auto mode: docker not found on PATH."
      return 0
    fi
    echo "ERROR: docker was not found on PATH; Linux VI Analyzer gate cannot run." >&2
    exit 1
  fi

  echo "Running LabVIEWCLI VI Analyzer gate via Linux container..."
  (
    cd "$repo_root"
    "$pwsh_bin" -NoProfile -File "./Tooling/Run-ViAnalyzer.ps1" -RepoRoot "$repo_root" -SupportedBitness 64
  )
}

derive_lv_year() {
  local lv_path="$repo_root/.lvversion"
  if [[ ! -f "$lv_path" ]]; then
    echo "ERROR: .lvversion was not found at $lv_path" >&2
    return 1
  fi

  local raw
  raw="$(tr -d '\r\n' < "$lv_path" | xargs)"
  if [[ -z "$raw" ]]; then
    echo "ERROR: .lvversion is empty at $lv_path" >&2
    return 1
  fi

  local major="${raw%%.*}"
  if [[ "$major" =~ ^[0-9]{4}$ ]]; then
    echo "$major"
    return 0
  fi

  if [[ "$major" =~ ^[0-9]{2}$ ]]; then
    echo "$((2000 + 10#$major))"
    return 0
  fi

  echo "ERROR: Unable to derive LabVIEW year from .lvversion value '$raw'." >&2
  return 1
}

validate_mandatory_build_spec
run_powershell_lint "$run_psscriptanalyzer_raw"
run_pylavi_gate "$run_pylavi_raw"
run_vi_analyzer_gate "$run_vi_analyzer_raw"

if [[ "$mode" == "linux-container" ]]; then
  if ! command -v docker >/dev/null 2>&1; then
    echo "ERROR: docker was not found on PATH. Linux container parity requires docker." >&2
    exit 1
  fi

  if [[ -z "${LABVIEW_LINUX_IMAGE:-}" ]]; then
    lv_year="$(derive_lv_year)"
    export LABVIEW_LINUX_IMAGE="nationalinstruments/labview:${lv_year}q1-linux"
  fi

  echo "Using LABVIEW_LINUX_IMAGE=${LABVIEW_LINUX_IMAGE}"
  docker pull "${LABVIEW_LINUX_IMAGE}"
fi

mkdir -p "$(dirname "$context_path")"

echo "Generating parity context: $context_path"
"$dotnet_bin" run --project "$runner_cli_project" --configuration "$configuration" -- parity context --repo-root "$repo_root" --output "$context_path"

run_args=(parity run --mode "$mode" --context "$context_path" --build-spec true)

echo "Running parity mode '$mode' (build-spec: true, mandatory)"
"$dotnet_bin" run --project "$runner_cli_project" --configuration "$configuration" -- "${run_args[@]}" "$@"
