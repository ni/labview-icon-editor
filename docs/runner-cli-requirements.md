**Runner CLI Requirements (Current Commands)**

**Purpose and Non-Goals**
The runner-cli exists to provide stateless runner contract helpers and cross-platform parity helpers for the LabVIEW Icon Editor toolchain.
The runner-cli does not orchestrate GitHub Actions workflows or replace CI job logic.

**Supported Platforms and Dependencies**
The following applies to the current command set only.

| Command | Supported OS | Dependencies |
|---|---|---|
| validate-contract | Windows, Linux, macOS | git must be available to pass safe.directory checks when `--fail-on-missing-safe-directory` is true. |
| init-contract | Windows, Linux, macOS | none |
| emit-env | Windows, Linux, macOS | none |
| version-gate | Windows, Linux, macOS | git optional for repo root resolution when `--repo-root` is not provided. |
| pylavi scan | Windows, Linux, macOS | `vi_validate` must be on PATH; `.lvversion` is required unless `--labview` is provided and `--skip-version-gate` is true. |
| pylavi summarize | Windows, Linux, macOS | none (reads offenders JSON). |
| pylavi fetch | Windows, Linux, macOS | GitHub API access token via `--token`, `GH_TOKEN`, or `GITHUB_TOKEN`. |
| missing-in-project | Windows only | `pwsh` on PATH; `.github/actions/missing-in-project/Invoke-MissingInProjectCLI.ps1` must exist; LabVIEW + g-cli required by the PowerShell script. |

**Cross-Cutting Requirements**
- Exit codes: `0` indicates success. `1` indicates a general failure unless otherwise noted.
- JSON output MUST be UTF-8 encoded.
- Paths provided as relative values MUST be resolved relative to `--repo-root` when that option is present, otherwise relative to the resolved repo root.
- The resolved repo root MUST be determined by `--repo-root` when provided, otherwise by `git rev-parse --show-toplevel` when available, otherwise the current working directory.
- Pylavi absolute roots MUST be redacted as `<redacted>` in logs and reports.
- Offender reports and summaries MUST be deterministic for a given input report; filenames that include timestamps are still acceptable as long as content is deterministic.

**Command Requirements**

**validate-contract**
Usage:
```text
runner-cli validate-contract --contract-path <path> [--fail-on-missing-safe-directory]
```
Options:

| Option | Required | Default | Notes |
|---|---|---|---|
| `--contract-path` | Yes | none | Path to runner contract JSON. |
| `--fail-on-missing-safe-directory` | No | `true` | When true, missing git safe.directory is an error. |

Behavior:
- MUST load the contract JSON and validate required directory paths.
- MUST return exit code `1` and print `ERROR:` lines to stderr for missing/invalid paths.
- MUST check `git config --system --get-all safe.directory` for the work root pattern `<work_root>/*`.
- MUST fail with exit code `1` if safe.directory is missing and `--fail-on-missing-safe-directory` is true.
- SHOULD print `Runner contract OK: <path>` on success.

**init-contract**
Usage:
```text
runner-cli init-contract --contract-path <path> --runner-root <path> --work-root <path> [--runner-label <label>] [--canonical-label <label>]
```
Options:

| Option | Required | Default | Notes |
|---|---|---|---|
| `--contract-path` | Yes | none | Path to write runner contract JSON. |
| `--runner-root` | Yes | none | Runner installation root. |
| `--work-root` | Yes | none | Runner work root. |
| `--runner-label` | No | `self-hosted-windows-lv` | Primary runner label. |
| `--canonical-label` | No | `self-hosted-windows-lv` | Canonical runner label. |

Behavior:
- MUST write a contract JSON file to `--contract-path`.
- MUST preserve `created_at_utc` when updating an existing contract.
- MUST set `updated_at_utc` to the current UTC time.
- MUST populate derived roots under `<work_root>\lvie\` for worktree, artifacts, locks, and logs.
- SHOULD print `Runner contract written: <path>` on success.

**emit-env**
Usage:
```text
runner-cli emit-env --contract-path <path> [--github-env <path>]
```
Options:

| Option | Required | Default | Notes |
|---|---|---|---|
| `--contract-path` | Yes | none | Path to runner contract JSON. |
| `--github-env` | No | `GITHUB_ENV` | Explicit file path for environment exports. |

Behavior:
- MUST emit the following lines to stdout: `LVIE_RUNNER_ROOT`, `LVIE_RUNNER_WORK_ROOT`, `LVIE_WORKTREE_ROOT`, `LVIE_ARTIFACT_ROOT`, `LVIE_LOCK_ROOT`, `LVIE_LOG_ROOT`, `LVIE_RUNNER_CONTRACT_PATH`, `LVIE_RUNNER_LABEL`, `LVIE_RUNNER_LABELS`, `LVIE_CANONICAL_RUNNER_LABEL`.
- SHOULD append the same lines to the `--github-env` file when provided.
- MUST print a warning to stderr if no env file is available.

**version-gate**
Usage:
```text
runner-cli version-gate [--repo-root <path>] [--version <value>] [--json]
```
Options:

| Option | Required | Default | Notes |
|---|---|---|---|
| `--repo-root` | No | resolved | Repo root resolution as described in cross-cutting rules. |
| `--version` | No | none | When provided, MUST match `.lvversion`. |
| `--json` | No | `false` | Emit JSON output. |

Behavior:
- MUST read `.lvversion` from the resolved repo root when `--version` is not provided.
- MUST fail if `.lvversion` is missing and no `--version` is provided.
- MUST fail if `--version` is provided but does not match `.lvversion`.
- When `--json` is set, MUST emit a `LabVIEWVersionInfo` JSON object to stdout.
- When `--json` is not set, MUST emit key/value lines: `raw=`, `year=`, `minor=`, `numeric=`.

**pylavi scan**
Usage:
```text
runner-cli pylavi scan [--repo-root <path>] [--config <path>] [--label <label>] [--labview <value>] [--skip-version-gate] [--report-only] [--absolute-roots <list>] [--log-path <path>] [--offenders-path <path>] [--json] [--quiet]
```
Options:

| Option | Required | Default | Notes |
|---|---|---|---|
| `--config` | No | `Tooling/pylavi/vi-validate.yml` | Relative to repo root when not absolute. |
| `--label` | No | `pylavi` | Used in warnings and reports. |
| `--labview` | No | none | LabVIEW version input; defaults to `.lvversion`. |
| `--skip-version-gate` | No | `false` | When false, `--eq <numeric>` is passed to `vi_validate`. |
| `--report-only` | No | `false` | When true, non-zero `vi_validate` exit codes become zero. |
| `--absolute-roots` | No | none | Semicolon-delimited roots to flag and redact. |
| `--log-path` | No | none | Writes a redacted log file. |
| `--offenders-path` | No | none | Writes offenders JSON report. |
| `--json` | No | `false` | Emits `PylaviScanSummary` JSON when not quiet. |
| `--quiet` | No | `false` | Suppresses warnings and summary output. |

Behavior:
- MUST print the exact `vi_validate` command it will run, including the label.
- MUST pass `--eq <numericVersion>` to `vi_validate` unless `--skip-version-gate` is set.
- MUST write a redacted log file when `--log-path` is provided.
- MUST write an offenders report JSON when `--offenders-path` is provided.
- MUST emit `PylaviScanSummary` JSON to stdout when `--json` is set and `--quiet` is not set.
- MUST redact configured absolute roots as `<redacted>` in logs and reports.
- MUST return `0` when `--report-only` is set and `vi_validate` returns non-zero.

**pylavi summarize**
Usage:
```text
runner-cli pylavi summarize [--repo-root <path>] [--path <file>] [--label <label>] [--sha <sha>] [--top <n>] [--output-path <path>] [--write-summary] [--validate-exists] [--fail-on-empty] [--fail-on-findings] [--fail-on-threshold <n>] [--baseline <file>] [--baseline-required] [--fail-on-delta] [--json] [--quiet]
```
Options:

| Option | Required | Default | Notes |
|---|---|---|---|
| `--path` | No | none | When omitted, resolves to `TestResults/agent-logs/pylavi-offenders.*.json`. |
| `--label` | No | none | Used for resolving label-specific reports. |
| `--sha` | No | none | Used for deterministic report resolution. |
| `--top` | No | `10` | Maximum offenders to print or include in summary output. |
| `--output-path` | No | none | Writes `PylaviSummarizeOutput` JSON. |
| `--write-summary` | No | `false` | Appends to `GITHUB_STEP_SUMMARY`. |
| `--validate-exists` | No | `false` | Exit code `2` if report is missing. |
| `--fail-on-empty` | No | `false` | Exit code `3` if report has no entries. |
| `--fail-on-findings` | No | `false` | Exit code `4` if report has findings. |
| `--fail-on-threshold` | No | `-1` | Exit code `5` if total FAILs exceeds threshold. |
| `--baseline` | No | none | Baseline report for delta computation. |
| `--baseline-required` | No | `false` | Exit code `7` if baseline missing. |
| `--fail-on-delta` | No | `false` | Exit code `6` if new offenders detected. |
| `--json` | No | `false` | Emits `PylaviOffendersReport` JSON. |
| `--quiet` | No | `false` | Suppresses stdout output. |

Behavior:
- MUST resolve report path using the provided `--path` or default resolution rules.
- MUST return exit code `2` when `--validate-exists` is set and the report does not exist.
- MUST write `PylaviSummarizeOutput` JSON when `--output-path` is provided.
- MUST compute deltas when a baseline report exists.
- MUST apply exit codes `3`, `4`, `5`, `6`, `7` as described above.
- MUST redact configured roots in printed output.
- MUST emit machine-readable lines in non-json mode: `PYLAVI_OFFENDERS_FILE`, `PYLAVI_OFFENDERS_LABEL`, `PYLAVI_OFFENDERS_SHA` (if known), `PYLAVI_OFFENDERS_TOTAL_FAILS`, `PYLAVI_OFFENDERS_HAS_FINDINGS`, `PYLAVI_OFFENDERS_EXIT_CODE`.

**pylavi fetch**
Usage:
```text
runner-cli pylavi fetch [--repo <owner/name>] [--token <token>] [--workflow <file>] [--branch <name>] [--sha <sha>] [--run-id <id>] [--label <label>] [--artifact-prefix <prefix>] [--out-dir <path>] [--prefer-label <label>]
```
Options:

| Option | Required | Default | Notes |
|---|---|---|---|
| `--repo` | No | resolved | Defaults to repo derived from git remote. |
| `--token` | No | none | Falls back to `GH_TOKEN` or `GITHUB_TOKEN`. |
| `--workflow` | No | `ci-composite.yml` | Workflow file name. |
| `--branch` | No | `develop` | Branch to query for runs. |
| `--sha` | No | none | Deterministic selection by commit SHA. |
| `--run-id` | No | `0` | Deterministic selection by run id. |
| `--label` | No | none | Filter artifact label suffix. |
| `--artifact-prefix` | No | `pylavi-validate-offenders` | Artifact name prefix. |
| `--out-dir` | No | `TestResults/agent-logs` | Output directory. |
| `--prefer-label` | No | `strict` | Preferred label when multiple artifacts exist. |

Behavior:
- MUST require exactly one of `--run-id` or `--sha` when both are provided (error).
- MUST require a GitHub token from `--token`, `GH_TOKEN`, or `GITHUB_TOKEN`.
- MUST download offenders artifacts and extract `vi_validate_offenders.json`.
- MUST write files to `--out-dir` (relative to repo root when not absolute): `pylavi-offenders.latest.<label>.json`, `pylavi-offenders.<label>.<timestamp>.json`, `pylavi-offenders.<label>.<sha>.json` when run SHA is known, `pylavi-offenders.latest.json` (canonical), and `pylavi-offenders.<sha>.json` when run SHA is known.
- MUST emit machine-readable lines to stdout: `PYLAVI_OFFENDERS_FETCHED=1`, `PYLAVI_OFFENDERS_FILE=<path>`, `PYLAVI_OFFENDERS_LABEL=<label>`, `PYLAVI_OFFENDERS_RUN_ID=<id>`, `PYLAVI_OFFENDERS_SHA=<sha>` when available, `PYLAVI_OFFENDERS_WORKFLOW=<workflow>`, `PYLAVI_OFFENDERS_BRANCH=<branch>`.

**missing-in-project**
Usage:
```text
runner-cli missing-in-project --arch <32|64> --project-file <path> [--repo-root <path>] [--labview <value>] [--worktree-root <path>] [--skip-worktree-root-check] [--connect-timeout-ms <ms>]
```
Options:

| Option | Required | Default | Notes |
|---|---|---|---|
| `--arch` | Yes | none | LabVIEW bitness. |
| `--project-file` | Yes | none | Path to `.lvproj`. |
| `--labview` | No | none | LabVIEW version input. |
| `--worktree-root` | No | none | Worktree root override. |
| `--skip-worktree-root-check` | No | `false` | Skip worktree root validation in the script. |
| `--connect-timeout-ms` | No | `0` | g-cli connect timeout override. |

Behavior:
- MUST fail with exit code `1` on non-Windows platforms.
- MUST invoke `.github/actions/missing-in-project/Invoke-MissingInProjectCLI.ps1` via `pwsh`.
- MUST print the exact command it will run.
- MUST forward the exit code from the PowerShell script.

**JSON Schemas (Required Fields)**

`LabVIEWVersionInfo` (JSON output from `version-gate --json`):
- `Raw` (string)
- `Year` (string)
- `MinorRevision` (number)
- `NumericMajor` (number)
- `NumericVersion` (string)

`PylaviOffendersReport`:
- `label` (string)
- `generated_utc` (string)
- `total_fails` (number)
- `configured_root_count` (number)
- `top_offenders` (array of `PylaviOffenderEntry`)
- `top_absolute_offenders` (array of `PylaviOffenderEntry`)
- `source_sha` (string, optional)

`PylaviSummarizeOutput`:
- `label` (string)
- `generated_utc` (string)
- `total_fails` (number)
- `configured_root_count` (number)
- `has_findings` (boolean)
- `file` (string)
- `top_offenders` (array of `PylaviOffenderEntry`)
- `top_absolute_offenders` (array of `PylaviOffenderEntry`)
- `source_sha` (string, optional)
- `baseline_file` (string, optional)
- `baseline_total_fails` (number, optional)
- `baseline_configured_root_count` (number, optional)
- `baseline_has_findings` (boolean, optional)
- `has_delta` (boolean, optional)
- `delta_total_fails` (number, optional)
- `delta_offenders` (array of `PylaviOffenderEntry`, optional)
- `delta_absolute_offenders` (array of `PylaviOffenderEntry`, optional)

`PylaviScanSummary`:
- `label` (string)
- `total_fails` (number)
- `configured_root_count` (number)
- `has_findings` (boolean)
- `offenders_path` (string, optional)
- `log_path` (string, optional)

`PylaviOffenderEntry`:
- `item` (string)
- `count` (number)
- `sample_reason` (string, optional)

**Environment Variables**
Read by runner-cli:
- `GITHUB_ENV` (emit-env writes to this file when provided or set).
- `GITHUB_SHA` (pylavi scan sets `source_sha` in offenders report when present).
- `GH_TOKEN` or `GITHUB_TOKEN` (pylavi fetch authentication).

Written by runner-cli:
- emit-env writes LVIE_* variables listed above to the env file.
- pylavi summarize writes `PYLAVI_OFFENDERS_*` machine lines in non-json mode.
- pylavi fetch writes `PYLAVI_OFFENDERS_*` machine lines.

**Compatibility and Error Handling**
- All commands MUST prefix error messages with `ERROR:` on stderr when failing.
- Commands MUST return non-zero exit codes documented above on failure.
