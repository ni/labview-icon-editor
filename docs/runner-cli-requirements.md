# Runner CLI Requirements v4 (Proposed)

**Document Control**

| Field | Value |
|---|---|
| Document ID | LVIE-RC-REQ-v4 |
| Product | runner-cli |
| Scope | Current command set only (no new commands) |
| Status | Draft v4 (ISO-hardened) |

## v4 Change Summary (Normative)

- [Breaking] `--json` now requires strict JSON-only `stdout`; all non-JSON diagnostics and annotations are directed to `stderr`.
- [Breaking] Stream behavior for command-line echo/informational lines is explicitly defined and aligned to strict JSON mode.
- [Clarifying] Purpose requirements are rewritten as measurable command and statelessness obligations.
- [Clarifying] Multi-obligation requirements are split into atomic statements with new RC IDs for testability.
- [Clarifying] Repository and safe.directory command examples are moved to non-normative notes; normative text states behavior only.
- [Clarifying] Line-ending and timestamp format requirements now define deterministic, machine-testable formats.

## v4 Changelog (Normative)

v4 is required because strict JSON-only `stdout` semantics in `--json` mode tighten the externally observable CLI contract and may break consumers that previously accepted non-JSON annotation lines on `stdout`.

| Change | RC IDs | Impact | Reason | Trace row reference |
|---|---|---|---|---|
| Enforce strict JSON-only `stdout` in `--json` mode | RC-GEN-008, RC-GEN-009, RC-GEN-010 | Breaking | Remove ambiguity and preserve parse-safe JSON output | T-H1 |
| Specify output streams for constructed command and report-only informational lines | RC-PS-005, RC-PS-014, RC-MIP-004 | Clarifying | Eliminate stream ambiguity and align with JSON contract | T-H2 |
| Rewrite purpose requirements as verifiable obligations | RC-PUR-001, RC-PUR-002, RC-PUR-003 | Clarifying | Improve verifiability and testability | T-M1 |
| Split multi-obligation requirements into atomic clauses | RC-PS-011, RC-PS-017, RC-PSUM-006, RC-PSUM-019, RC-PSUM-020, RC-PF-005, RC-PF-012, RC-PF-013 | Clarifying | Improve singularity and traceability; original multi-obligation clauses are superseded by the listed atomic RC IDs | T-M2 |
| Reduce mechanism coupling in normative text | RC-PATH-002, RC-VC-004 | Clarifying | State required outcome, keep command examples non-normative | T-M3 |
| Convert negative-form requirements to positive-form constraints where practical | RC-CONV-003, RC-PUR-004, RC-PUR-005, RC-RED-002, RC-SEC-001 | Clarifying | Improve requirement readability and conformance style | T-L1 |
| Clarify newline and timestamp precision semantics | RC-GEN-005, RC-TIME-001 | Clarifying | Remove interpretation variance across platforms/runtimes | T-L2 |

## 1. Purpose and Non-goals

RC-PUR-001: runner-cli shall expose the commands init-contract, validate-contract, and emit-env with behaviors defined in section 6.
RC-PUR-002: runner-cli shall expose the commands version-gate, pylavi scan, pylavi summarize, and pylavi fetch with behaviors defined in section 6 and platform constraints defined in section 3.
RC-PUR-003: runner-cli command execution shall be stateless: each invocation result shall be determined only by command options, supported environment variables, and observable external state at execution time.
RC-PUR-004: Workflow orchestration responsibility shall remain in CI/workflow engines, and runner-cli shall limit behavior to helper operations defined in section 6.
RC-PUR-005: CI scheduling and job-level policy enforcement responsibilities shall remain outside runner-cli, and runner-cli shall expose exit codes and outputs for external policy consumers.

## 2. Conventions and Normative Language

RC-CONV-001: The keywords shall be interpreted as: shall (mandatory), should (recommended), may (permitted).
RC-CONV-002: Each requirement statement shall include a unique identifier.
RC-CONV-003: Requirement identifiers shall be unique within this document.
RC-CONV-004: Requirement statements should follow well-formed requirement language practices (clarity, singularity, verifiability) consistent with ISO/IEC/IEEE 29148:2018.

## 3. Supported Platforms and Dependencies

This table applies to the current command set only.

| Command | Supported OS | Dependencies |
|---|---|---|
| validate-contract | Windows, Linux, macOS | Requires git when safe.directory validation is enabled. |
| init-contract | Windows, Linux, macOS | none |
| emit-env | Windows, Linux, macOS | none |
| version-gate | Windows, Linux, macOS | git is optional for repo root resolution when --repo-root is not provided. |
| pylavi scan | Windows, Linux, macOS | Requires vi_validate on PATH; .lvversion is required when version gating is enabled. |
| pylavi summarize | Windows, Linux, macOS | none (reads offenders JSON). |
| pylavi fetch | Windows, Linux, macOS | Requires GitHub API token via --token, GH_TOKEN, or GITHUB_TOKEN. |
| missing-in-project | Windows only | Requires pwsh on PATH; .github/actions/missing-in-project/Invoke-MissingInProjectCLI.ps1 is required to exist; LabVIEW + g-cli are required by the PowerShell script. |

RC-PLAT-001: Commands other than missing-in-project shall be supported on Windows, Linux, and macOS.
RC-PLAT-002: missing-in-project shall be supported on Windows only.
RC-PLAT-003: pylavi scan shall require vi_validate to be available on PATH.
RC-PLAT-004: validate-contract shall require git availability when safe.directory validation is enabled.
RC-PLAT-005: pylavi fetch shall require a GitHub API token from --token, GH_TOKEN, or GITHUB_TOKEN.
RC-PLAT-006: missing-in-project shall require pwsh on PATH and the missing-in-project PowerShell script to be present.

## 4. Cross-cutting Requirements

### 4.1 Exit codes

RC-GEN-001: Each command shall exit with code 0 on success unless otherwise specified.
RC-GEN-002: Each command shall exit with a non-zero code on failure as specified in its section.
RC-GEN-003: If a failure occurs that is not assigned a specialized exit code, the command shall exit with code 1.

### 4.2 Output encoding and line endings

RC-GEN-004: JSON written to stdout or files by runner-cli shall be encoded as UTF-8.
RC-GEN-005: Console output line endings shall use the executing platform default newline sequence (LF on Linux/macOS, CRLF on Windows).

### 4.3 Error, warning, and JSON stdout contract

RC-GEN-006: When a command fails, it shall write at least one error line to stderr beginning with ERROR:.
RC-GEN-007: Warnings shall be emitted to stderr beginning with WARNING: unless otherwise specified by a command section.
RC-GEN-008: When a command is invoked with --json, stdout shall contain only the JSON output for that command (no additional human-readable lines).
RC-GEN-009: When GITHUB_ACTIONS is set to true, pylavi scan warnings shall use ::warning:: formatting as specified in its section.
RC-GEN-010: When --json is set, non-JSON diagnostic, informational, warning, and annotation lines shall be emitted to stderr.

### 4.4 Repo root resolution

RC-PATH-001: If --repo-root is provided, runner-cli shall use it (after resolving to an absolute path) as the resolved repo root.
RC-PATH-002: If --repo-root is not provided, runner-cli shall attempt to determine the repository top-level directory using git repository metadata.
RC-PATH-003: If repository metadata resolution is unavailable or fails, runner-cli shall use the current working directory as the resolved repo root.

Note (non-normative): One implementation approach for RC-PATH-002 is `git rev-parse --show-toplevel`.

### 4.5 Path resolution rules

RC-PATH-004: For commands that resolve a repo root (section 4.4), unless a command section states otherwise, path options shall be treated as absolute if they are absolute, otherwise relative to the resolved repo root.
RC-PATH-005: For commands that do not resolve a repo root, path options shall be treated as absolute if they are absolute, otherwise relative to the current working directory.

### 4.6 Deterministic outputs

RC-DET-001: For a fixed input report, offender summaries and report content produced by runner-cli shall be deterministic.
RC-DET-002: Filenames may include timestamps, but report content (JSON structure, counts, ordering rules) shall remain deterministic for the same input data.
RC-DET-003: When outputs require ordering by descending count, ties shall be broken by ascending item (ordinal, case-insensitive comparison) to ensure deterministic ordering.

### 4.7 Redaction

RC-RED-001: When absolute roots are configured for pylavi scan, runner-cli shall replace configured root prefixes with the literal string <redacted> in pylavi log files, pylavi JSON reports, and pylavi warning outputs.
RC-RED-002: Redaction shall preserve non-path data fields such as counts, labels, and exit codes.

### 4.8 Time format

RC-TIME-001: UTC timestamps written by runner-cli shall be formatted as RFC 3339/ISO 8601 `YYYY-MM-DDTHH:MM:SS.fffffffZ` (exactly 7 fractional digits), for example 2026-02-07T13:45:12.1234567Z.

### 4.9 Secrets handling

RC-SEC-001: runner-cli shall redact or omit GitHub access tokens from stdout and stderr.
RC-SEC-002: If a token is required but not available, runner-cli shall fail with an ERROR: message without echoing candidate token values.

## 5. Data Formats

### 5.1 JSON formatting rules

RC-JSN-001: JSON objects emitted by runner-cli shall be valid JSON and contain all required fields listed in this section.
RC-JSN-002: When determinism is required, runner-cli shall output arrays in a stable order as described in the producing command section and RC-DET-003.
RC-JSN-003: JSON objects emitted by runner-cli may include additional fields not specified in this document; all fields marked Required in this document shall remain present and semantically stable.

### 5.2 RunnerContract

RC-JSN-010: RunnerContract JSON shall include the fields listed in Table 5-1.

Table 5-1: RunnerContract fields

| Field | Required | Notes |
|---|---|---|
| version | Yes | Integer schema version. |
| runner_root | Yes | Runner installation root. |
| work_root | Yes | Runner work root. |
| worktree_root | Yes | Worktree root under work_root. |
| artifact_root | Yes | Artifact root under work_root. |
| lock_root | Yes | Lock root under work_root. |
| log_root | Yes | Log root under work_root. |
| runner_label | Yes | Primary runner label. |
| runner_labels | Yes | Array of labels, may be empty. |
| canonical_runner_label | Yes | Canonical runner label. |
| updated_at_utc | Yes | ISO 8601 UTC timestamp. |
| created_at_utc | Yes | ISO 8601 UTC timestamp. |

### 5.3 LabVIEWVersionInfo

RC-JSN-020: LabVIEWVersionInfo JSON shall include the fields listed in Table 5-2.

Table 5-2: LabVIEWVersionInfo fields

| Field | Required | Notes |
|---|---|---|
| Raw | Yes | Raw version string. |
| Year | Yes | Year value as string. |
| MinorRevision | Yes | Minor revision number. |
| NumericMajor | Yes | Numeric major version. |
| NumericVersion | Yes | Numeric version string (major.minor). |

### 5.4 PylaviOffendersReport

RC-JSN-030: PylaviOffendersReport JSON shall include the fields listed in Table 5-3.
RC-JSN-031: configured_roots shall be <redacted> when absolute roots are configured, otherwise an empty string.

Table 5-3: PylaviOffendersReport fields

| Field | Required | Notes |
|---|---|---|
| label | Yes | Report label. |
| generated_utc | Yes | UTC timestamp. |
| source_sha | No | Source SHA when known. |
| total_fails | Yes | Total FAIL entries. |
| configured_roots | Yes | Redacted string or empty. |
| configured_root_count | Yes | Number of configured absolute roots. |
| top_offenders | Yes | Array of PylaviOffenderEntry. |
| top_absolute_offenders | Yes | Array of PylaviOffenderEntry. |

### 5.5 PylaviSummarizeOutput

RC-JSN-040: PylaviSummarizeOutput JSON shall include the fields listed in Table 5-4.

Table 5-4: PylaviSummarizeOutput fields

| Field | Required | Notes |
|---|---|---|
| label | Yes | Report label. |
| generated_utc | Yes | UTC timestamp. |
| total_fails | Yes | Total FAIL entries. |
| configured_root_count | Yes | Number of configured absolute roots. |
| has_findings | Yes | Boolean. |
| file | Yes | Offenders report file path. |
| top_offenders | Yes | Array of PylaviOffenderEntry. |
| top_absolute_offenders | Yes | Array of PylaviOffenderEntry. |
| source_sha | No | Source SHA when known. |
| baseline_file | No | Baseline report path. |
| baseline_total_fails | No | Baseline total FAILs. |
| baseline_configured_root_count | No | Baseline configured root count. |
| baseline_has_findings | No | Baseline findings boolean. |
| has_delta | No | Boolean. |
| delta_total_fails | No | Delta total fails. |
| delta_offenders | No | Array of PylaviOffenderEntry. |
| delta_absolute_offenders | No | Array of PylaviOffenderEntry. |

### 5.6 PylaviScanSummary

RC-JSN-050: PylaviScanSummary JSON shall include the fields listed in Table 5-5.

Table 5-5: PylaviScanSummary fields

| Field | Required | Notes |
|---|---|---|
| label | Yes | Report label. |
| total_fails | Yes | Total FAIL entries. |
| configured_root_count | Yes | Number of configured absolute roots. |
| has_findings | Yes | Boolean. |
| offenders_path | No | Offenders report path. |
| log_path | No | Redacted log path. |

### 5.7 PylaviOffenderEntry

RC-JSN-060: PylaviOffenderEntry JSON shall include the fields listed in Table 5-6.

Table 5-6: PylaviOffenderEntry fields

| Field | Required | Notes |
|---|---|---|
| item | Yes | Offending item. |
| count | Yes | Occurrence count. |
| sample_reason | No | Sample FAIL reason. |

## 6. Command Requirements

### 6.1 validate-contract

Usage

```text
runner-cli validate-contract --contract-path <path> [--fail-on-missing-safe-directory <true|false>]
```

Options

| Option | Required | Default | Notes |
|---|---|---|---|
| --contract-path | Yes | none | Path to runner contract JSON. |
| --fail-on-missing-safe-directory | No | true | When true, missing safe.directory is treated as an error. |

Behavior

RC-VC-001: The command shall load and parse the contract JSON at --contract-path.
RC-VC-002: The command shall validate that runner_root, work_root, worktree_root, artifact_root, lock_root, and log_root are non-empty and refer to existing directories.
RC-VC-003: If any validation fails, the command shall exit with code 1 and emit ERROR: lines to stderr for each failure.
RC-VC-004: When --fail-on-missing-safe-directory is true, the command shall query git system-level safe.directory values.
RC-VC-005: The safe.directory requirement shall be satisfied if any entry equals * or equals <work_root> or equals <work_root>/* after normalizing <work_root> to an absolute path, trimming trailing directory separators, and replacing backslashes with forward slashes.
RC-VC-006: If the safe.directory requirement is not satisfied and --fail-on-missing-safe-directory is true, the command shall exit with code 1 and emit an ERROR: line.
RC-VC-007: If the safe.directory requirement is not satisfied and --fail-on-missing-safe-directory is false, the command shall emit a WARNING: line to stderr and continue.
RC-VC-008: On success, the command shall print Runner contract OK: <path> to stdout.
RC-VC-009: For validate-contract, --contract-path shall be resolved per RC-PATH-005.

Note (non-normative): One implementation approach for RC-VC-004 is `git config --system --get-all safe.directory`.

### 6.2 init-contract

Usage

```text
runner-cli init-contract --contract-path <path> --runner-root <path> --work-root <path> [--runner-label <label>] [--canonical-label <label>]
```

Options

| Option | Required | Default | Notes |
|---|---|---|---|
| --contract-path | Yes | none | Path to write runner contract JSON. |
| --runner-root | Yes | none | Runner installation root. |
| --work-root | Yes | none | Runner work root. |
| --runner-label | No | self-hosted-windows-lv | Primary runner label. |
| --canonical-label | No | self-hosted-windows-lv | Canonical runner label. |

Behavior

RC-IC-001: The command shall create or update the contract file at --contract-path.
RC-IC-002: If an existing contract is successfully loaded and contains created_at_utc, the command shall preserve that value.
RC-IC-003: The command shall set updated_at_utc to the current UTC time.
RC-IC-004: The command shall set version to 1.
RC-IC-005: The command shall set runner_root and work_root from the provided options.
RC-IC-006: The command shall derive worktree_root, artifact_root, lock_root, and log_root under <work_root>/lvie/w, <work_root>/lvie/artifacts, <work_root>/lvie/locks, and <work_root>/lvie/logs.
RC-IC-007: The command shall set runner_label and canonical_runner_label from the provided options or defaults.
RC-IC-008: The command shall set runner_labels to a normalized, de-duplicated list containing runner_label and canonical_runner_label.
RC-IC-009: If an existing contract cannot be loaded, the command shall emit a WARNING: line to stderr and proceed with a new contract.
RC-IC-010: On success, the command shall print Runner contract written: <path> to stdout.
RC-IC-011: For init-contract, --contract-path shall be resolved per RC-PATH-005.
RC-IC-012: If the contract directory does not exist, the command shall create it before writing.

### 6.3 emit-env

Usage

```text
runner-cli emit-env --contract-path <path> [--github-env <path>]
```

Options

| Option | Required | Default | Notes |
|---|---|---|---|
| --contract-path | Yes | none | Path to runner contract JSON. |
| --github-env | No | value of GITHUB_ENV | Explicit file path for environment exports. |

Behavior

RC-EE-001: The command shall read the runner contract at --contract-path.
RC-EE-002: The command shall emit the following KEY=VALUE lines to stdout: LVIE_RUNNER_ROOT, LVIE_RUNNER_WORK_ROOT, LVIE_WORKTREE_ROOT, LVIE_ARTIFACT_ROOT, LVIE_LOCK_ROOT, LVIE_LOG_ROOT, LVIE_RUNNER_CONTRACT_PATH, LVIE_RUNNER_LABEL, LVIE_RUNNER_LABELS, LVIE_CANONICAL_RUNNER_LABEL.
RC-EE-003: If an env file path is available from --github-env or GITHUB_ENV, the command shall append the same lines to that file.
RC-EE-004: If no env file path is available, the command shall emit a WARNING: line to stderr.
RC-EE-005: When the env file path is available, the command shall print Exported <n> variables to <path> to stdout.
RC-EE-006: For emit-env, --contract-path shall be resolved per RC-PATH-005.

### 6.4 version-gate

Usage

```text
runner-cli version-gate [--repo-root <path>] [--version <value>] [--json]
```

Options

| Option | Required | Default | Notes |
|---|---|---|---|
| --repo-root | No | resolved | Repo root resolution per section 4.4. |
| --version | No | none | When provided, is required to match .lvversion. |
| --json | No | false | Emit JSON output. |

Behavior

RC-VG-001: The command shall resolve repo root per section 4.4.
RC-VG-002: If --version is not provided, the command shall read .lvversion from the resolved repo root and shall fail with exit code 1 if the file is missing.
RC-VG-003: If --version is provided, the command shall read .lvversion from the resolved repo root and shall fail with exit code 1 if the file is missing or does not match the provided version.
RC-VG-004: The command shall accept version inputs matching the pattern of a 2 to 4 digit major value with an optional .minor suffix, for example 21.0 or 2021.
RC-VG-005: When --json is set, the command shall emit a LabVIEWVersionInfo JSON object to stdout.
RC-VG-006: When --json is not set, the command shall emit raw=, year=, minor=, and numeric= lines to stdout.

### 6.5 pylavi scan

Usage

```text
runner-cli pylavi scan [--repo-root <path>] [--config <path>] [--label <label>] [--labview <value>] [--skip-version-gate] [--report-only] [--absolute-roots <list>] [--log-path <path>] [--offenders-path <path>] [--json] [--quiet]
```

Options

| Option | Required | Default | Notes |
|---|---|---|---|
| --repo-root | No | resolved | Repo root resolution per section 4.4. |
| --config | No | Tooling/pylavi/vi-validate.yml | Relative paths resolved from repo root. |
| --label | No | pylavi | Used in warnings and reports. |
| --labview | No | none | LabVIEW version input; compared to .lvversion when version gating is enabled. |
| --skip-version-gate | No | false | When true, vi_validate does not receive --eq. |
| --report-only | No | false | When true, non-zero vi_validate exit codes are converted to success. |
| --absolute-roots | No | none | Semicolon-delimited roots to redact. |
| --log-path | No | none | Writes a redacted log file. |
| --offenders-path | No | none | Writes offenders JSON report. |
| --json | No | false | Emits PylaviScanSummary JSON when not quiet. |
| --quiet | No | false | Suppresses warnings and summary output. |

Behavior

RC-PS-001: The command shall resolve repo root per section 4.4.
RC-PS-002: The command shall resolve --config relative to the resolved repo root when it is not absolute and shall fail if the config file does not exist.
RC-PS-003: When --skip-version-gate is false, the command shall determine the LabVIEW version using --labview when provided and .lvversion from the resolved repo root, and shall fail if .lvversion is missing or does not match the provided --labview value.
RC-PS-004: When --skip-version-gate is false, the command shall include --eq <numericVersion> in the vi_validate arguments.
RC-PS-005: The command shall write the constructed vi_validate command line string, including the label, to stderr before invoking vi_validate.
RC-PS-006: The command shall execute vi_validate from PATH and capture stdout and stderr lines.
RC-PS-007: If --log-path is provided, the command shall write a redacted log file to that path and shall create the parent directory when needed.
RC-PS-008: If --offenders-path is provided, the command shall write a PylaviOffendersReport JSON file to that path; otherwise it shall write the report to <repo_root>/vi_validate_offenders.json.
RC-PS-009: The PylaviOffendersReport shall include up to 20 entries in top_offenders and top_absolute_offenders, ordered by descending count with ties broken per RC-DET-003.
RC-PS-010: When --absolute-roots is provided, the command shall apply redaction per section 4.7 and shall set configured_roots to <redacted> and configured_root_count to the number of distinct roots.
RC-PS-011: Unless --quiet is set, the command shall emit warnings for FAIL entries and absolute root detections to stderr.
RC-PS-012: When --json is set and --quiet is not set, the command shall emit a PylaviScanSummary JSON object to stdout.
RC-PS-013: When --json is not set and --quiet is not set, the command shall emit Total FAILs: <n> to stdout.
RC-PS-014: If vi_validate exits non-zero and --report-only is set, the command shall exit with code 0 and emit an informational line to stderr about the original exit code.
RC-PS-015: Otherwise, the command shall propagate the vi_validate exit code.
RC-PS-016: For pylavi scan, --log-path and --offenders-path shall be resolved per RC-PATH-004.
RC-PS-017: When GITHUB_ACTIONS=true and --quiet is not set, warnings emitted per RC-PS-011 shall use ::warning:: formatting.

### 6.6 pylavi summarize

Usage

```text
runner-cli pylavi summarize [--repo-root <path>] [--path <file>] [--label <label>] [--sha <sha>] [--top <n>] [--output-path <path>] [--write-summary] [--validate-exists] [--fail-on-empty] [--fail-on-findings] [--fail-on-threshold <n>] [--baseline <file>] [--baseline-required] [--fail-on-delta] [--json] [--quiet]
```

Options

| Option | Required | Default | Notes |
|---|---|---|---|
| --repo-root | No | resolved | Repo root resolution per section 4.4. |
| --path | No | none | When omitted, a default report path is resolved under TestResults/agent-logs. |
| --label | No | none | Used for label-specific report selection. |
| --sha | No | none | Used for deterministic report selection. |
| --top | No | 10 | Maximum offenders to include in summaries. |
| --output-path | No | none | Writes PylaviSummarizeOutput JSON. |
| --write-summary | No | false | Appends to GITHUB_STEP_SUMMARY when available. |
| --validate-exists | No | false | Exit code 2 if report is missing; when present, exit code 0 without further processing. |
| --fail-on-empty | No | false | Exit code 3 if report has no findings. |
| --fail-on-findings | No | false | Exit code 4 if report has findings. |
| --fail-on-threshold | No | -1 | Exit code 5 if total FAILs exceeds threshold. |
| --baseline | No | none | Baseline report for delta computation. |
| --baseline-required | No | false | Exit code 7 if baseline missing or not provided. |
| --fail-on-delta | No | false | Exit code 6 if new offenders are detected. |
| --json | No | false | Emits PylaviOffendersReport JSON to stdout. |
| --quiet | No | false | Suppresses non-json human-readable output. |

Behavior

RC-PSUM-001: The command shall resolve repo root per section 4.4.
RC-PSUM-002: If --path is provided and is not absolute, the command shall resolve it relative to the resolved repo root.
RC-PSUM-003: If --path is not provided, the command shall resolve a default report path under <repo_root>/TestResults/agent-logs in the following order: pylavi-offenders.<label>.<sha>.json, pylavi-offenders.<sha>.json, pylavi-offenders.latest.<label>.json, pylavi-offenders.latest.json.
RC-PSUM-004: If the resolved report file does not exist and --validate-exists is set, the command shall exit with code 2 and emit an ERROR: line.
RC-PSUM-005: If the resolved report file does not exist and --validate-exists is not set, the command shall exit with code 1 and emit an ERROR: line.
RC-PSUM-006: If --validate-exists is set and the report exists, the command shall exit with code 0.
RC-PSUM-007: If --output-path is provided, the command shall write a PylaviSummarizeOutput JSON file and shall create the parent directory when needed.
RC-PSUM-008: When --json is set, the command shall emit a PylaviOffendersReport JSON object to stdout regardless of --quiet.
RC-PSUM-009: When --json is not set and --quiet is not set, the command shall emit a human-readable summary including label, generated_utc, total_fails, and configured_root_count.
RC-PSUM-010: If --write-summary is set and GITHUB_STEP_SUMMARY is available, the command shall append a summary and, when baseline data is available, a delta section.
RC-PSUM-011: If --baseline is provided and not absolute, the command shall resolve it relative to the resolved repo root.
RC-PSUM-012: If --baseline is provided and the file is missing, the command shall emit a WARNING: line to stderr.
RC-PSUM-013: If --baseline-required is set and no baseline is provided or the baseline file is missing, the command shall exit with code 7 and emit an ERROR: line.
RC-PSUM-014: If --fail-on-empty is set and the report has no findings, the command shall exit with code 3.
RC-PSUM-015: If --fail-on-findings is set and the report has findings, the command shall exit with code 4.
RC-PSUM-016: If --fail-on-threshold is non-negative and total_fails exceeds the threshold, the command shall exit with code 5.
RC-PSUM-017: If --fail-on-delta is set and a baseline report is available, the command shall exit with code 6 when new offenders are detected.
RC-PSUM-018: In non-json mode (and when not exiting early per RC-PSUM-006), the command shall emit machine-readable PYLAVI_OFFENDERS_* lines to stdout, including PYLAVI_OFFENDERS_HAS_FINDINGS=true|false and PYLAVI_OFFENDERS_EXIT_CODE=<code>.
RC-PSUM-019: When RC-PSUM-006 is satisfied, the command shall skip summarization and delta computation.
RC-PSUM-020: When RC-PSUM-006 is satisfied, the command shall suppress PYLAVI_OFFENDERS_* line emission.

### 6.7 pylavi fetch

Usage

```text
runner-cli pylavi fetch [--repo <owner/name>] [--token <token>] [--workflow <file>] [--branch <name>] [--sha <sha>] [--run-id <id>] [--label <label>] [--artifact-prefix <prefix>] [--out-dir <path>] [--prefer-label <label>]
```

Options

| Option | Required | Default | Notes |
|---|---|---|---|
| --repo | No | resolved | Defaults to --repo, GITHUB_REPOSITORY, or git remote. |
| --token | No | none | Falls back to GH_TOKEN or GITHUB_TOKEN. |
| --workflow | No | ci-composite.yml | Workflow file name. |
| --branch | No | develop | Branch to query for runs. |
| --sha | No | none | Deterministic selection by commit SHA. |
| --run-id | No | 0 | Deterministic selection by run id when non-zero. |
| --label | No | none | Filter artifact label suffix. |
| --artifact-prefix | No | pylavi-validate-offenders | Artifact name prefix. |
| --out-dir | No | TestResults/agent-logs | Output directory. |
| --prefer-label | No | strict | Preferred label for pylavi-offenders.latest.json. |

Behavior

RC-PF-001: The command shall resolve the repository from --repo, GITHUB_REPOSITORY, or the git remote origin URL.
RC-PF-002: The command shall require a GitHub token from --token, GH_TOKEN, or GITHUB_TOKEN and shall exit with code 1 if none is available.
RC-PF-003: The command shall fail with exit code 1 if both --run-id is non-zero and --sha is provided.
RC-PF-004: The command shall resolve the workflow id for --workflow and shall fetch a run by --run-id when provided, otherwise the latest completed run for the specified branch and optional sha.
RC-PF-005: The command shall filter artifacts by --artifact-prefix and --label when provided.
RC-PF-006: The command shall extract vi_validate_offenders.json from each selected artifact.
RC-PF-007: The command shall resolve --out-dir relative to the resolved repo root when it is not absolute and shall create it when needed.
RC-PF-008: The command shall write pylavi-offenders.latest.<label>.json and pylavi-offenders.<label>.<timestamp>.json for each downloaded label.
RC-PF-009: When a run SHA is known, the command shall also write pylavi-offenders.<label>.<sha>.json for each label, and pylavi-offenders.<sha>.json for the canonical label.
RC-PF-010: The command shall select a canonical label by --label if provided, otherwise by --prefer-label, otherwise the first downloaded label, and shall copy it to pylavi-offenders.latest.json.
RC-PF-011: The command shall emit PYLAVI_OFFENDERS_FETCHED, PYLAVI_OFFENDERS_FILE, PYLAVI_OFFENDERS_LABEL, PYLAVI_OFFENDERS_RUN_ID, PYLAVI_OFFENDERS_SHA when available, PYLAVI_OFFENDERS_WORKFLOW, and PYLAVI_OFFENDERS_BRANCH to stdout.
RC-PF-012: If --sha is provided and no selected artifact name contains the sha, the command shall emit a WARNING: line to stderr.
RC-PF-013: When RC-PF-012 is satisfied, the command shall fall back to prefix matching.

### 6.8 missing-in-project

Usage

```text
runner-cli missing-in-project --arch <32|64> --project-file <path> [--repo-root <path>] [--labview <value>] [--worktree-root <path>] [--skip-worktree-root-check] [--connect-timeout-ms <ms>]
```

Options

| Option | Required | Default | Notes |
|---|---|---|---|
| --arch | Yes | none | LabVIEW bitness. |
| --project-file | Yes | none | Path to .lvproj. |
| --repo-root | No | resolved | Repo root resolution per section 4.4. |
| --labview | No | none | LabVIEW version input. |
| --worktree-root | No | none | Worktree root override. |
| --skip-worktree-root-check | No | false | Skip worktree root validation in the script. |
| --connect-timeout-ms | No | 0 | g-cli connect timeout override. |

Behavior

RC-MIP-001: On non-Windows platforms, the command shall exit with code 1 and emit an ERROR: line stating the command is Windows-only.
RC-MIP-002: On Windows, the command shall invoke .github/actions/missing-in-project/Invoke-MissingInProjectCLI.ps1 using pwsh.
RC-MIP-003: The command shall resolve --project-file relative to the resolved repo root when it is not absolute.
RC-MIP-004: The command shall write the constructed pwsh command line string to stderr before invoking the script.
RC-MIP-005: The command shall forward the exit code from the PowerShell script as its own exit code.

## 7. Environment Variables

RC-ENV-001: emit-env shall use GITHUB_ENV when --github-env is not provided.
RC-ENV-002: pylavi summarize shall use GITHUB_STEP_SUMMARY when --write-summary is set.
RC-ENV-003: pylavi scan shall use GITHUB_SHA to populate source_sha when present.
RC-ENV-004: pylavi scan shall use GITHUB_ACTIONS to determine ::warning:: formatting for warnings.
RC-ENV-005: pylavi fetch shall use GH_TOKEN or GITHUB_TOKEN when --token is not provided.
RC-ENV-006: pylavi fetch shall use GITHUB_REPOSITORY when --repo is not provided.
RC-ENV-007: emit-env shall write LVIE_* variables to the env file when available.
RC-ENV-008: pylavi summarize shall emit PYLAVI_OFFENDERS_* machine lines in non-json mode (unless RC-PSUM-006 exits early).
RC-ENV-009: pylavi fetch shall emit PYLAVI_OFFENDERS_* machine lines on success.

## 8. Compatibility and Error Handling

RC-COMP-001: On failure, commands shall emit at least one ERROR: line to stderr and return the non-zero exit code specified in section 6.
RC-COMP-002: runner-cli should avoid breaking changes to command-line options and JSON output fields in minor/patch releases; when breaking changes are required, they should be gated behind a major version increment or a new option.

## 9. References

ISO/IEC/IEEE 29148:2018(E), Systems and software engineering - Life cycle processes - Requirements engineering.
