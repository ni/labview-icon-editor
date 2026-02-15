# Runner CLI Requirements v5.1 (Clarifying Revision)

**Document Control**

| Field | Value |
|---|---|
| Document ID | LVIE-RC-REQ-v5 |
| Semantic Revision | v5.1 |
| Product | runner-cli |
| Scope | Progressive scope expansion (core -> extended -> full) |
| Status | Draft v5.1 (ISO 29148 remediation) |
| Next planned set | v6 candidate C1 (conformance coverage automation) |

## Scope Expansion Model (Normative)

Profiles:
- `Core`: mandatory baseline requirements for existing command set behavior.
- `Extended`: adds new command interfaces and conformance surfaces.
- `Full`: adds governance, deprecation, and release evidence controls.

Profile rule:
- Full conformance implies Extended conformance.
- Extended conformance implies Core conformance.

## v5.1 Change Summary (Normative)

- [Clarifying] Preserves existing command names and options for current command set.
- [Breaking] Enforces global `--json` precedence: non-JSON diagnostics never appear on `stdout`.
- [Clarifying] Adds normative stream matrix for all commands and output modes.
- [Clarifying] Expands deterministic tie-break requirements to all ranked offender/delta outputs.
- [Clarifying] Adds singularity gate for requirement statements (one independently testable obligation each).
- [Clarifying] Adds hosted cross-platform Core conformance evidence requirements and explicit non-applicable handling for Windows-only command checks.
- [Contract-expanding] Adds new command interfaces: `manifest` and `conformance check`.
- [Clarifying] Adds governance controls for change classification, deprecation lifecycle, and evidence traceability.
- [Clarifying] Resolves ISO/IEC/IEEE 29148 well-formedness issues for conformance gating, atomicity, and requirement language precision.
- [Contract-expanding] Adds `missing-in-project --dry-run` for deterministic command-surface validation on Windows.

## v5.1 Changelog (Normative)

v5.1 is a clarifying revision that preserves the v5 command surface while tightening requirement language for unambiguity, verifiability, and modifiability.

| Change | RC IDs | Impact | Reason | Trace row reference |
|---|---|---|---|---|
| Establish profile model and conformance hierarchy | RC-SCOPE-001, RC-SCOPE-002, RC-SCOPE-003 | Clarifying | Support gradual scope expansion with explicit applicability | V5-C1 |
| Harden stream precedence and add stream matrix | RC-GEN-008, RC-GEN-009, RC-GEN-010, RC-GEN-011 | Breaking | Guarantee JSON parser-safe `stdout` in JSON mode | V5-C2 |
| Extend deterministic and singularity controls | RC-DET-003, RC-DET-004, RC-CONV-005, RC-CONV-006 | Clarifying | Improve repeatability and independent verifiability | V5-C3 |
| Add hosted cross-platform Core conformance boundaries | RC-PLAT-009, RC-PLAT-010, RC-CONF-010, RC-CONF-011, RC-CONF-012 | Clarifying | Ensure Core evidence is collected on hosted Linux and hosted Windows while preserving Windows-only applicability constraints | V5-C7 |
| Add `manifest` command and JSON type | RC-MAN-001, RC-MAN-002, RC-MAN-003, RC-JSN-070 | Contract-expanding | Provide introspection surface for spec/version capability discovery | V5-C4 |
| Add `conformance check` command and JSON types | RC-CONF-001, RC-CONF-002, RC-CONF-003, RC-JSN-080, RC-JSN-090 | Contract-expanding | Provide profile-scoped, machine-readable conformance result surface | V5-C5 |
| Add governance and deprecation lifecycle controls | RC-GOV-001, RC-GOV-002, RC-GOV-003, RC-GOV-004, RC-GOV-005 | Clarifying | Standardize release/change/deprecation evidence requirements | V5-C6 |
| Clarify requirement quality and governance linkage for ISO 29148 | RC-SCOPE-004, RC-JSN-004, RC-GOV-006 | Clarifying | Make conformance applicability, JSON compatibility, and breaking-change governance explicit | V5.1-C1 |
| Add `missing-in-project --dry-run` command behavior | RC-MIP-002, RC-MIP-005, RC-MIP-006 | Contract-expanding | Provide deterministic Windows command-surface validation without launching script execution | V5.1-C4 |

## v6 Candidate C1 Summary (Draft, Non-active)

The v6 candidate C1 set introduces machine-verifiable RC coverage automation for `conformance check`.
These draft requirements are not required for v5.1 conformance claims until the semantic revision is advanced to v6.

| Planned change | RC IDs | Impact | Reason | Planned trace row |
|---|---|---|---|---|
| Add coverage automation to `conformance check` | RC-CONF-013, RC-CONF-014, RC-CONF-015, RC-CONF-016, RC-CONF-017, RC-CONF-018 | Contract-expanding | Make RC-to-acceptance/trace coverage machine-checkable in the command itself | V6-C1 |
| Add coverage JSON contracts | RC-JSN-100, RC-JSN-101, RC-JSN-102, RC-JSN-103 | Contract-expanding | Standardize coverage summary/report fields for CI parsing and policy gates | V6-C1 |
| Require machine-parseable trace RC IDs for automation | RC-GOV-007 | Clarifying | Ensure coverage automation has deterministic governance input artifacts | V6-C1 |

## 1. Scope Profiles

RC-SCOPE-001: The requirements in this document shall be grouped into Core, Extended, and Full profiles.
RC-SCOPE-002: Full conformance shall require satisfaction of all applicable mandatory requirements in Extended and Core profiles.
RC-SCOPE-003: Extended conformance shall require satisfaction of all applicable mandatory requirements in the Core profile.
RC-SCOPE-004: Requirements using should or may are non-blocking for conformance claims.

## 2. Purpose and Non-goals

Non-goal (non-normative): Workflow orchestration is handled by CI/workflow engines.
Non-goal (non-normative): CI scheduling and job-level policy enforcement are handled outside runner-cli.

RC-PUR-001: runner-cli shall expose the commands init-contract, validate-contract, emit-env, version-gate, pylavi scan, pylavi summarize, pylavi fetch, and missing-in-project with behaviors defined in section 7.
RC-PUR-002: runner-cli shall expose the commands manifest and conformance check with behaviors defined in section 7 and profile constraints defined in section 1.
RC-PUR-003: runner-cli command execution shall be stateless, meaning each invocation result is determined only by command options, supported environment variables, and observable external state at execution time.
RC-PUR-004: runner-cli shall limit behavior to helper operations defined in section 7.
RC-PUR-005: runner-cli shall expose the exit codes and outputs defined in this document for external policy consumers.

## 3. Conventions and Normative Language

RC-CONV-001: The keywords shall be interpreted as: shall (mandatory), should (recommended), may (permitted).
RC-CONV-002: Each requirement statement shall include a unique identifier.
RC-CONV-003: Requirement identifiers shall be unique within this document.
RC-CONV-004: Requirement statements should follow well-formed requirement language practices (clarity, singularity, verifiability) consistent with ISO/IEC/IEEE 29148:2018.
RC-CONV-005: Each normative requirement statement shall define one independently testable obligation.
RC-CONV-006: Requirement identifiers shall be unique and monotonic ascending within each RC prefix family.

## 4. Supported Platforms and Dependencies

This table applies to commands in scope for v5.1 Core and Extended profiles.

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
| manifest | Windows, Linux, macOS | none |
| conformance check | Windows, Linux, macOS | none (uses local requirement and trace artifacts). |

RC-PLAT-001: Commands other than missing-in-project shall be supported on Windows, Linux, and macOS.
RC-PLAT-002: missing-in-project shall be supported on Windows only.
RC-PLAT-003: pylavi scan shall require vi_validate to be available on PATH.
RC-PLAT-004: validate-contract shall require git availability when safe.directory validation is enabled.
RC-PLAT-005: pylavi fetch shall require a GitHub API token from --token, GH_TOKEN, or GITHUB_TOKEN.
RC-PLAT-006: missing-in-project shall require pwsh on PATH and the missing-in-project PowerShell script to be present.
RC-PLAT-007: manifest shall be supported on Windows, Linux, and macOS.
RC-PLAT-008: conformance check shall be supported on Windows, Linux, and macOS.
RC-PLAT-009: Core conformance evidence for commands supported on Windows, Linux, and macOS shall include at least one hosted Linux execution and one hosted Windows execution.
RC-PLAT-010: Core conformance checks for Windows-only commands shall be evaluated on Windows and treated as not applicable on Linux and macOS.

## 5. Cross-cutting Requirements

### 5.1 Exit codes

RC-GEN-001: Each command shall exit with code 0 on success unless otherwise specified.
RC-GEN-002: Each command shall exit with a non-zero code on failure as specified in its section.
RC-GEN-003: If a failure occurs that is not assigned a specialized exit code, the command shall exit with code 1.

### 5.2 Output encoding and line endings

RC-GEN-004: JSON written to stdout or files by runner-cli shall be encoded as UTF-8.
RC-GEN-005: Console output line endings shall use the executing platform default newline sequence (LF on Linux/macOS, CRLF on Windows).

### 5.3 Error, warning, and JSON stdout contract

RC-GEN-006: When a command fails, it shall write at least one error line to stderr beginning with ERROR:.
RC-GEN-007: Warnings shall be emitted to stderr beginning with WARNING: unless otherwise specified by a command section.
RC-GEN-008: When a command is invoked with --json, stdout shall contain only the JSON output for that command (no additional human-readable lines).
RC-GEN-009: When GITHUB_ACTIONS equals the string true (case-insensitive), pylavi scan warnings shall use ::warning:: formatting as specified in its section.
RC-GEN-010: When --json is set, non-JSON diagnostic, informational, warning, and annotation lines shall be emitted to stderr.
RC-GEN-011: For commands that support both json and non-json modes, stream behavior shall conform to Table 5-1.

Table 5-1: Stream contract matrix

| Command | Mode | stdout contract | stderr contract |
|---|---|---|---|
| validate-contract | non-json | Success line only | ERROR/WARNING lines |
| init-contract | non-json | Success line only | ERROR/WARNING lines |
| emit-env | non-json | KEY=VALUE lines and export summary | WARNING/ERROR lines |
| version-gate | json | LabVIEWVersionInfo JSON only | ERROR lines |
| version-gate | non-json | raw/year/minor/numeric lines | ERROR lines |
| pylavi scan | json and not quiet | PylaviScanSummary JSON only | Command echo, WARNING, ERROR, info lines |
| pylavi scan | non-json and not quiet | Human summary lines | Command echo, WARNING, ERROR, info lines |
| pylavi scan | quiet | none required by contract | Command echo and ERROR lines |
| pylavi summarize | json | PylaviOffendersReport JSON only | WARNING/ERROR lines |
| pylavi summarize | non-json | Human summary and machine lines | WARNING/ERROR lines |
| pylavi summarize | non-json and quiet | PYLAVI_OFFENDERS_* machine lines | WARNING/ERROR lines |
| pylavi fetch | non-json | PYLAVI_OFFENDERS_* machine lines | WARNING/ERROR lines |
| missing-in-project | non-json | none required by contract | Command echo, ERROR lines |
| manifest | json | RunnerCliManifest JSON only | ERROR lines |
| manifest | non-json | Human-readable capability summary | ERROR lines |
| conformance check | json | ConformanceCheckResult JSON only | ERROR lines |
| conformance check | non-json | Human-readable check summary | ERROR lines |

### 5.4 Repo root resolution

RC-PATH-001: If --repo-root is provided, runner-cli shall use it (after resolving to an absolute path) as the resolved repo root.
RC-PATH-002: If --repo-root is not provided, runner-cli shall attempt to determine the repository top-level directory using git repository metadata.
RC-PATH-003: If repository metadata resolution is unavailable or fails, runner-cli shall use the current working directory as the resolved repo root.

Note (non-normative): One implementation approach for RC-PATH-002 is `git rev-parse --show-toplevel`.

### 5.5 Path resolution rules

RC-PATH-004: For commands that resolve a repo root (section 5.4), unless a command section states otherwise, path options shall be treated as absolute if they are absolute, otherwise relative to the resolved repo root.
RC-PATH-005: For commands that do not resolve a repo root, path options shall be treated as absolute if they are absolute, otherwise relative to the current working directory.

### 5.6 Deterministic outputs

RC-DET-001: For a fixed input report, offender summaries and report content produced by runner-cli shall be deterministic.
RC-DET-002: Filenames may include timestamps, but report content (JSON structure, counts, ordering rules) shall remain deterministic for the same input data.
RC-DET-003: When outputs require ordering by descending count, ties shall be broken by ascending item (ordinal, case-insensitive comparison) to ensure deterministic ordering.
RC-DET-004: All ranked offender and delta arrays shall apply the tie-break rule defined in RC-DET-003.

### 5.7 Redaction

RC-RED-001: When absolute roots are configured for pylavi scan, runner-cli shall replace configured root prefixes with the literal string <redacted> in pylavi log files, pylavi JSON reports, and pylavi warning outputs.
RC-RED-002: Redaction shall preserve non-path data fields such as counts, labels, and exit codes.

### 5.8 Time format

RC-TIME-001: UTC timestamps written by runner-cli shall be formatted as RFC 3339/ISO 8601 `YYYY-MM-DDTHH:MM:SS.fffffffZ` (exactly 7 fractional digits), for example 2026-02-07T13:45:12.1234567Z.

### 5.9 Secrets handling

RC-SEC-001: runner-cli shall redact or omit GitHub access tokens from stdout and stderr.
RC-SEC-002: If a token is required but not available, runner-cli shall fail with an ERROR: message without echoing candidate token values.

## 6. Data Formats

### 6.1 JSON formatting rules

RC-JSN-001: JSON objects emitted by runner-cli shall be valid JSON and contain all required fields listed in this section.
RC-JSN-002: When determinism is required, runner-cli shall output arrays in a stable order as described in the producing command section and RC-DET-003.
RC-JSN-003: JSON objects emitted by runner-cli may include additional fields not specified in this document.
RC-JSN-004: Fields marked Required in this document shall preserve field name, JSON type, units/format, and semantic meaning within the same major specification version.

### 6.2 RunnerContract

RC-JSN-010: RunnerContract JSON shall include the fields listed in Table 6-1.

Table 6-1: RunnerContract fields

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

### 6.3 LabVIEWVersionInfo

RC-JSN-020: LabVIEWVersionInfo JSON shall include the fields listed in Table 6-2.

Table 6-2: LabVIEWVersionInfo fields

| Field | Required | Notes |
|---|---|---|
| Raw | Yes | Raw version string. |
| Year | Yes | Year value as string. |
| MinorRevision | Yes | Minor revision number. |
| NumericMajor | Yes | Numeric major version. |
| NumericVersion | Yes | Numeric version string (major.minor). |

### 6.4 PylaviOffendersReport

RC-JSN-030: PylaviOffendersReport JSON shall include the fields listed in Table 6-3.
RC-JSN-031: configured_roots shall be <redacted> when absolute roots are configured, otherwise an empty string.

Table 6-3: PylaviOffendersReport fields

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

### 6.5 PylaviSummarizeOutput

RC-JSN-040: PylaviSummarizeOutput JSON shall include the fields listed in Table 6-4.

Table 6-4: PylaviSummarizeOutput fields

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

### 6.6 PylaviScanSummary

RC-JSN-050: PylaviScanSummary JSON shall include the fields listed in Table 6-5.

Table 6-5: PylaviScanSummary fields

| Field | Required | Notes |
|---|---|---|
| label | Yes | Report label. |
| total_fails | Yes | Total FAIL entries. |
| configured_root_count | Yes | Number of configured absolute roots. |
| has_findings | Yes | Boolean. |
| offenders_path | No | Offenders report path. |
| log_path | No | Redacted log path. |

### 6.7 PylaviOffenderEntry

RC-JSN-060: PylaviOffenderEntry JSON shall include the fields listed in Table 6-6.

Table 6-6: PylaviOffenderEntry fields

| Field | Required | Notes |
|---|---|---|
| item | Yes | Offending item. |
| count | Yes | Occurrence count. |
| sample_reason | No | Sample FAIL reason. |

### 6.8 RunnerCliManifest

RC-JSN-070: RunnerCliManifest JSON shall include the fields listed in Table 6-7.

Table 6-7: RunnerCliManifest fields

| Field | Required | Notes |
|---|---|---|
| spec_document_id | Yes | Requirement document identifier. |
| spec_version | Yes | Requirement semantic version label. |
| supported_commands | Yes | Array of command identifiers. |
| supported_profiles | Yes | Array containing core, extended, and full as supported. |
| build_version | Yes | Runner CLI build or package version string. |
| generated_utc | Yes | UTC timestamp formatted per RC-TIME-001. |

### 6.9 ConformanceCheckResult

RC-JSN-080: ConformanceCheckResult JSON shall include the fields listed in Table 6-8.

Table 6-8: ConformanceCheckResult fields

| Field | Required | Notes |
|---|---|---|
| profile | Yes | Requested profile (`core`, `extended`, or `full`). |
| generated_utc | Yes | UTC timestamp formatted per RC-TIME-001. |
| summary | Yes | Conformance summary object. |
| checks | Yes | Array of ConformanceCheckEntry objects. |

### 6.10 ConformanceCheckEntry

RC-JSN-090: ConformanceCheckEntry JSON shall include the fields listed in Table 6-9.

Table 6-9: ConformanceCheckEntry fields

| Field | Required | Notes |
|---|---|---|
| id | Yes | Stable check identifier. |
| status | Yes | `pass`, `fail`, or `warn`. |
| severity | Yes | `info`, `warning`, or `error`. |
| message | Yes | Human-readable result detail. |
| evidence | Yes | Short evidence string for traceability. |

### 6.11 CoverageSummary (v6 draft)

RC-JSN-100: CoverageSummary JSON shall include the fields listed in Table 6-10.

Table 6-10: CoverageSummary fields

| Field | Required | Notes |
|---|---|---|
| rc_total | Yes | Total RC IDs in the evaluated coverage set. |
| rc_covered | Yes | RC IDs covered by acceptance + trace evidence rules. |
| rc_uncovered | Yes | RC IDs not covered by acceptance + trace evidence rules. |
| coverage_percent | Yes | Percentage `rc_covered / rc_total * 100`. |
| uncovered_rc_ids | Yes | Array of uncovered RC IDs; empty array when none. |

### 6.12 ConformanceCoverageReport (v6 draft)

RC-JSN-101: ConformanceCoverageReport JSON shall include the fields listed in Table 6-11.
RC-JSN-102: uncovered_rc_ids in CoverageSummary and ConformanceCoverageReport JSON shall be sorted by ascending RC ID using case-insensitive ordinal comparison.
RC-JSN-103: CoverageSummary and ConformanceCoverageReport JSON may include additional fields not specified in this document.

Table 6-11: ConformanceCoverageReport fields

| Field | Required | Notes |
|---|---|---|
| profile | Yes | Evaluated profile (`core`, `extended`, or `full`). |
| generated_utc | Yes | UTC timestamp formatted per RC-TIME-001. |
| semantic_revision | Yes | Semantic revision label used for coverage evaluation. |
| requirements_path | Yes | Requirements document path used for RC enumeration. |
| acceptance_path | Yes | Acceptance matrix path used for RC coverage mapping. |
| trace_path | Yes | Trace matrix path used for RC coverage mapping. |
| coverage | Yes | CoverageSummary object. |

## 7. Command Requirements

### 7.1 validate-contract

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

### 7.2 init-contract

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

### 7.3 emit-env

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

### 7.4 version-gate

Usage

```text
runner-cli version-gate [--repo-root <path>] [--version <value>] [--json]
```

Options

| Option | Required | Default | Notes |
|---|---|---|---|
| --repo-root | No | resolved | Repo root resolution per section 5.4. |
| --version | No | none | When provided, is required to match .lvversion. |
| --json | No | false | Emit JSON output. |

Behavior

RC-VG-001: The command shall resolve repo root per section 5.4.
RC-VG-002: If --version is not provided, the command shall read .lvversion from the resolved repo root.
RC-VG-003: If --version is provided, the command shall read .lvversion from the resolved repo root.
RC-VG-004: The command shall accept version inputs matching the pattern of a 2 to 4 digit major value with an optional .minor suffix, for example 21.0 or 2021.
RC-VG-005: When --json is set, the command shall emit a LabVIEWVersionInfo JSON object to stdout.
RC-VG-006: When --json is not set, the command shall emit raw=, year=, minor=, and numeric= lines to stdout.
RC-VG-007: The command shall fail with exit code 1 when .lvversion is missing.
RC-VG-008: The command shall fail with exit code 1 when --version is provided and does not match .lvversion.

### 7.5 pylavi scan

Usage

```text
runner-cli pylavi scan [--repo-root <path>] [--config <path>] [--label <label>] [--labview <value>] [--skip-version-gate] [--report-only] [--absolute-roots <list>] [--log-path <path>] [--offenders-path <path>] [--json] [--quiet]
```

Options

| Option | Required | Default | Notes |
|---|---|---|---|
| --repo-root | No | resolved | Repo root resolution per section 5.4. |
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

RC-PS-001: The command shall resolve repo root per section 5.4.
RC-PS-002: The command shall resolve --config relative to the resolved repo root when it is not absolute.
RC-PS-003: When --skip-version-gate is false, the command shall determine the LabVIEW version using --labview when provided and .lvversion from the resolved repo root.
RC-PS-004: When --skip-version-gate is false, the command shall include --eq <numericVersion> in the vi_validate arguments.
RC-PS-005: The command shall write the constructed vi_validate command line string, including the label, to stderr before invoking vi_validate.
RC-PS-006: The command shall execute vi_validate from PATH and capture stdout and stderr lines.
RC-PS-007: If --log-path is provided, the command shall write a redacted log file to that path.
RC-PS-008: The command shall write a PylaviOffendersReport JSON file to --offenders-path when provided; otherwise to <repo_root>/vi_validate_offenders.json.
RC-PS-009: The PylaviOffendersReport shall include up to 20 entries in top_offenders and top_absolute_offenders, ordered by descending count with ties broken per RC-DET-003.
RC-PS-010: When --absolute-roots is provided, the command shall apply redaction per section 5.7.
RC-PS-011: Unless --quiet is set, the command shall emit warnings for FAIL entries and absolute root detections to stderr.
RC-PS-012: When --json is set and --quiet is not set, the command shall emit a PylaviScanSummary JSON object to stdout.
RC-PS-013: When --json is not set and --quiet is not set, the command shall emit Total FAILs: <n> to stdout.
RC-PS-014: If vi_validate exits non-zero and --report-only is set, the command shall exit with code 0 and emit an informational line to stderr about the original exit code.
RC-PS-015: Otherwise, the command shall propagate the vi_validate exit code.
RC-PS-016: For pylavi scan, --log-path and --offenders-path shall be resolved per RC-PATH-004.
RC-PS-017: When GITHUB_ACTIONS equals the string true (case-insensitive) and --quiet is not set, warnings emitted per RC-PS-011 shall use ::warning:: formatting.
RC-PS-018: The command shall fail if the resolved config file does not exist.
RC-PS-019: When --skip-version-gate is false, the command shall fail if .lvversion is missing.
RC-PS-020: When --skip-version-gate is false, the command shall fail if --labview is provided and does not match .lvversion.
RC-PS-021: If --log-path is provided, the command shall create the parent directory when needed.
RC-PS-022: When --absolute-roots is provided, the command shall set configured_roots to <redacted>.
RC-PS-023: When --absolute-roots is provided, the command shall set configured_root_count to the number of distinct roots.

### 7.6 pylavi summarize

Usage

```text
runner-cli pylavi summarize [--repo-root <path>] [--path <file>] [--label <label>] [--sha <sha>] [--top <n>] [--output-path <path>] [--write-summary] [--validate-exists] [--fail-on-empty] [--fail-on-findings] [--fail-on-threshold <n>] [--baseline <file>] [--baseline-required] [--fail-on-delta] [--json] [--quiet]
```

Options

| Option | Required | Default | Notes |
|---|---|---|---|
| --repo-root | No | resolved | Repo root resolution per section 5.4. |
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

RC-PSUM-001: The command shall resolve repo root per section 5.4.
RC-PSUM-002: If --path is provided and is not absolute, the command shall resolve it relative to the resolved repo root.
RC-PSUM-003: If --path is not provided, the command shall resolve a default report path under <repo_root>/TestResults/agent-logs in the following order: pylavi-offenders.<label>.<sha>.json, pylavi-offenders.<sha>.json, pylavi-offenders.latest.<label>.json, pylavi-offenders.latest.json.
RC-PSUM-004: If the resolved report file does not exist and --validate-exists is set, the command shall exit with code 2 and emit an ERROR: line.
RC-PSUM-005: If the resolved report file does not exist and --validate-exists is not set, the command shall exit with code 1 and emit an ERROR: line.
RC-PSUM-006: If --validate-exists is set and the report exists, the command shall exit with code 0.
RC-PSUM-007: If --output-path is provided, the command shall write a PylaviSummarizeOutput JSON file.
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
RC-PSUM-021: If --output-path is provided, the command shall create the parent directory when needed.

### 7.7 pylavi fetch

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
RC-PF-002: The command shall require a GitHub token from --token, GH_TOKEN, or GITHUB_TOKEN.
RC-PF-003: The command shall fail with exit code 1 if both --run-id is non-zero and --sha is provided.
RC-PF-004: The command shall resolve the workflow id for --workflow.
RC-PF-005: The command shall filter artifacts by --artifact-prefix and --label when provided.
RC-PF-006: The command shall extract vi_validate_offenders.json from each selected artifact.
RC-PF-007: The command shall resolve --out-dir relative to the resolved repo root when it is not absolute.
RC-PF-008: The command shall write pylavi-offenders.latest.<label>.json and pylavi-offenders.<label>.<timestamp>.json for each downloaded label.
RC-PF-009: When a run SHA is known, the command shall also write pylavi-offenders.<label>.<sha>.json for each label, and pylavi-offenders.<sha>.json for the canonical label.
RC-PF-010: The command shall select a canonical label by --label if provided, otherwise by --prefer-label, otherwise the first downloaded label.
RC-PF-011: The command shall emit PYLAVI_OFFENDERS_FETCHED, PYLAVI_OFFENDERS_FILE, PYLAVI_OFFENDERS_LABEL, PYLAVI_OFFENDERS_RUN_ID, PYLAVI_OFFENDERS_SHA when available, PYLAVI_OFFENDERS_WORKFLOW, and PYLAVI_OFFENDERS_BRANCH to stdout.
RC-PF-012: If --sha is provided and no selected artifact name contains the sha, the command shall emit a WARNING: line to stderr.
RC-PF-013: When RC-PF-012 is satisfied, the command shall fall back to prefix matching.
RC-PF-014: The command shall exit with code 1 if no GitHub token is available.
RC-PF-015: The command shall fetch a run by --run-id when provided.
RC-PF-016: The command shall fetch the latest completed run for the specified branch and optional sha when --run-id is not provided.
RC-PF-017: The command shall create --out-dir when needed.
RC-PF-018: The command shall copy the canonical label report to pylavi-offenders.latest.json.

### 7.8 missing-in-project

Usage

```text
runner-cli missing-in-project --arch <32|64> --project-file <path> [--repo-root <path>] [--labview <value>] [--worktree-root <path>] [--skip-worktree-root-check] [--connect-timeout-ms <ms>] [--dry-run]
```

Options

| Option | Required | Default | Notes |
|---|---|---|---|
| --arch | Yes | none | LabVIEW bitness. |
| --project-file | Yes | none | Path to .lvproj. |
| --repo-root | No | resolved | Repo root resolution per section 5.4. |
| --labview | No | none | LabVIEW version input. |
| --worktree-root | No | none | Worktree root override. |
| --skip-worktree-root-check | No | false | Skip worktree root validation in the script. |
| --connect-timeout-ms | No | 0 | g-cli connect timeout override. |
| --dry-run | No | false | Emit the command line to stderr and exit without launching the script. |

Behavior

RC-MIP-001: On non-Windows platforms, the command shall exit with code 1 and emit an ERROR: line stating the command is Windows-only.
RC-MIP-002: On Windows and when --dry-run is not set, the command shall invoke .github/actions/missing-in-project/Invoke-MissingInProjectCLI.ps1 using pwsh.
RC-MIP-003: The command shall resolve --project-file relative to the resolved repo root when it is not absolute.
RC-MIP-004: The command shall write the constructed pwsh command line string to stderr before conditional script invocation behavior is evaluated.
RC-MIP-005: When --dry-run is set, the command shall exit with code 0 and shall not launch the PowerShell script process.
RC-MIP-006: When --dry-run is not set, the command shall forward the exit code from the PowerShell script as its own exit code.

### 7.9 manifest

Usage

```text
runner-cli manifest [--repo-root <path>] [--json]
```

Options

| Option | Required | Default | Notes |
|---|---|---|---|
| --repo-root | No | resolved | Repo root resolution per section 5.4. |
| --json | No | false | Emits RunnerCliManifest JSON to stdout. |

Behavior

RC-MAN-001: The command shall emit a manifest describing the runner-cli requirement contract and supported commands.
RC-MAN-002: When --json is set, the command shall emit a RunnerCliManifest JSON object to stdout.
RC-MAN-003: When --json is not set, the command shall emit a human-readable summary that includes spec_document_id, spec_version, supported_commands, supported_profiles, build_version, and generated_utc.
RC-MAN-004: RunnerCliManifest JSON may include additional fields, and required fields defined by RC-JSN-070 shall remain present and semantics-compatible per RC-JSN-004.

### 7.10 conformance check

Usage

```text
runner-cli conformance check [--profile <core|extended|full>] [--repo-root <path>] [--json] [--strict]
```

Options

| Option | Required | Default | Notes |
|---|---|---|---|
| --profile | No | core | Conformance profile to evaluate. |
| --repo-root | No | resolved | Repo root resolution per section 5.4. |
| --json | No | false | Emits ConformanceCheckResult JSON to stdout. |
| --strict | No | false | Treat warning checks as failures. |

Behavior

RC-CONF-001: The command shall evaluate conformance checks scoped to the selected profile.
RC-CONF-002: The command shall read RC_PROFILE when --profile is not provided.
RC-CONF-003: The command shall read RC_STRICT_MODE when --strict is not provided.
RC-CONF-004: The command shall emit a ConformanceCheckResult JSON object when --json is set.
RC-CONF-005: The command shall emit a human-readable conformance summary when --json is not set.
RC-CONF-006: The command shall return exit code 0 when all checks pass.
RC-CONF-007: The command shall return exit code 2 when one or more checks fail.
RC-CONF-008: The command shall return exit code 3 when strict mode converts warning checks into failures.
RC-CONF-009: The checks array shall include one ConformanceCheckEntry per evaluated check.
RC-CONF-010: For Core profile checks targeting commands supported on Windows, Linux, and macOS, the command shall report evidence from at least one hosted Linux execution and one hosted Windows execution.
RC-CONF-011: For Core profile checks targeting Windows-only commands, non-Windows platforms shall be reported as not applicable.
RC-CONF-012: For Core profile checks targeting Windows-only commands, non-Windows not-applicable results shall not be treated as failures.

v6 draft delta (non-active for v5.1 claims)

Usage delta

```text
runner-cli conformance check ... [--coverage-report <path>] [--coverage-fail-on-gap]
```

Options delta

| Option | Required | Default | Notes |
|---|---|---|---|
| --coverage-report | No | none | Writes ConformanceCoverageReport JSON per RC-JSN-101. |
| --coverage-fail-on-gap | No | false | Fails when uncovered RC IDs remain after evaluation. |

Behavior delta

RC-CONF-013: The command shall compute an RC coverage set for the selected profile using RC IDs listed in trace rows for the current semantic revision.
RC-CONF-014: The command shall classify each RC ID in the coverage set as covered when at least one acceptance scenario target list references that RC ID.
RC-CONF-015: When --json is set, ConformanceCheckResult summary shall include a CoverageSummary object conforming to RC-JSN-100.
RC-CONF-016: When --coverage-report is provided, the command shall write a ConformanceCoverageReport JSON file conforming to RC-JSN-101 at the specified path.
RC-CONF-017: When --coverage-fail-on-gap is set and rc_uncovered is greater than zero, the command shall exit with code 2.
RC-CONF-018: When --coverage-fail-on-gap is set, for each uncovered RC ID the command shall emit one ConformanceCheckEntry with status fail, severity error, and evidence referencing the acceptance and trace artifacts used for coverage evaluation.

## 8. Environment Variables

RC-ENV-001: emit-env shall use GITHUB_ENV when --github-env is not provided.
RC-ENV-002: pylavi summarize shall use GITHUB_STEP_SUMMARY when --write-summary is set.
RC-ENV-003: pylavi scan shall use GITHUB_SHA to populate source_sha when present.
RC-ENV-004: pylavi scan shall use GITHUB_ACTIONS to determine ::warning:: formatting for warnings.
RC-ENV-005: pylavi fetch shall use GH_TOKEN or GITHUB_TOKEN when --token is not provided.
RC-ENV-006: pylavi fetch shall use GITHUB_REPOSITORY when --repo is not provided.
RC-ENV-007: emit-env shall write LVIE_* variables to the env file when available.
RC-ENV-008: pylavi summarize shall emit PYLAVI_OFFENDERS_* machine lines in non-json mode (unless RC-PSUM-006 exits early).
RC-ENV-009: pylavi fetch shall emit PYLAVI_OFFENDERS_* machine lines on success.
RC-ENV-010: RC_PROFILE shall be the canonical environment variable name for conformance profile defaulting.
RC-ENV-011: RC_STRICT_MODE shall be the canonical environment variable name for conformance strict-mode defaulting.

## 9. Compatibility and Error Handling

RC-COMP-001: Within the same major specification version, command failure signaling shall remain compatible with RC-GEN-002 and RC-GEN-006.
RC-COMP-002: Breaking changes to command-line options or required JSON fields shall be governed by RC-GOV-006.

## 10. Governance and Deprecation

RC-GOV-001: Requirement changes shall be classified as Breaking, Clarifying, or Editorial.
RC-GOV-002: Breaking changes shall include release notes that describe user impact and migration expectations.
RC-GOV-003: Deprecated behavior shall follow the lifecycle phases announce, warn, and remove.
RC-GOV-004: Deprecation records shall include explicit first-version and removal-version boundaries.
RC-GOV-005: Each released requirement revision shall include a trace artifact mapping changed RC IDs to tests or evidence scenarios.
RC-GOV-006: Breaking changes to command-line options or required JSON fields shall occur only in a major specification version and include migration notes in release documentation.
RC-GOV-007: Trace artifacts used for conformance automation shall list RC IDs using the canonical RC-<PREFIX>-<NNN> pattern.

### 10.1 Inline attributes for v5.1 delta requirements

| RC ID | Profile | Verification method |
|---|---|---|
| RC-SCOPE-002 | Core | Inspection (requirements review) |
| RC-SCOPE-003 | Core | Inspection (requirements review) |
| RC-SCOPE-004 | Core | Inspection (conformance language review) |
| RC-PUR-003 | Core | Inspection (atomicity lint + wording check) |
| RC-PUR-004 | Core | Inspection (scope/boundary review) |
| RC-PUR-005 | Core | Inspection (scope/boundary review) |
| RC-GEN-009 | Core | Test (pylavi warning format with GITHUB_ACTIONS=true variants) |
| RC-JSN-003 | Core | Inspection (schema extensibility rule check) |
| RC-JSN-004 | Core | Analysis (schema compatibility analysis) |
| RC-PS-008 | Core | Test (default vs explicit offenders report path) |
| RC-PS-017 | Core | Test (annotation format behavior) |
| RC-MIP-005 | Core | Test (missing-in-project dry-run command echo and no-execution behavior) |
| RC-MIP-006 | Core | Test (missing-in-project exit-code forwarding when not dry-run) |
| RC-MAN-004 | Extended | Test (manifest required-field compatibility) |
| RC-ENV-010 | Extended | Inspection (canonical env variable naming) |
| RC-ENV-011 | Extended | Inspection (canonical env variable naming) |
| RC-COMP-001 | Full | Analysis (compatibility contract audit) |
| RC-COMP-002 | Full | Inspection (governance linkage check) |
| RC-GOV-006 | Full | Inspection (release governance audit) |

### 10.2 Inline attributes for v6 draft C1 delta requirements

| RC ID | Profile | Verification method |
|---|---|---|
| RC-CONF-013 | Extended | Test (coverage-set derivation against trace rows) |
| RC-CONF-014 | Extended | Test (acceptance-reference coverage classification) |
| RC-CONF-015 | Extended | Test (coverage summary present in JSON output) |
| RC-CONF-016 | Extended | Test (coverage report file contract and schema validation) |
| RC-CONF-017 | Full | Test (coverage-fail-on-gap exit-code behavior) |
| RC-CONF-018 | Full | Test (uncovered RC entries emitted in checks array) |
| RC-JSN-100 | Extended | Test (CoverageSummary schema validation) |
| RC-JSN-101 | Extended | Test (ConformanceCoverageReport schema validation) |
| RC-JSN-102 | Extended | Test (deterministic uncovered RC ordering) |
| RC-JSN-103 | Extended | Inspection (forward-compatible schema extensibility) |
| RC-GOV-007 | Full | Inspection (trace artifact format lint) |

## 11. Migration Note

v5.1 migration by profile:
1. Core: align conformance applicability and requirement atomicity language to v5.1 rules, and adopt additive `missing-in-project --dry-run` behavior.
2. Extended: keep `manifest` and `conformance check` command surfaces unchanged while clarifying environment variable naming and manifest compatibility wording.
3. Full: enforce explicit major-version governance for breaking option/required-field changes.

v6 draft C1 migration objective:
1. Extended: add coverage automation output to `conformance check` JSON and optional coverage report file generation.
2. Full: enable policy gating on uncovered RC IDs via `--coverage-fail-on-gap`.
3. Governance: enforce machine-parseable RC identifier formatting in trace artifacts used for coverage automation.

## 12. References

ISO/IEC/IEEE 29148:2018(E), Systems and software engineering - Life cycle processes - Requirements engineering.
