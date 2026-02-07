# Runner CLI Requirements v5 Acceptance Matrix

This matrix defines executable acceptance scenarios and pass criteria for the v5 requirement contract.

| Scenario ID | Scope/Profile | Target RC IDs | Setup | Execution | Pass Criteria |
|---|---|---|---|---|---|
| A-001 | Core | RC-CONV-003, RC-CONV-006 | Load `docs/runner-cli-requirements.md`. | Parse requirement definition lines matching `^RC-[A-Z]+-\\d{3}:`. | No duplicate definition IDs; IDs are monotonic ascending within each prefix family. |
| A-002 | Core | RC-GEN-008, RC-GEN-010, RC-GEN-011 | Build runner-cli test harness with JSON-mode commands. | Run `version-gate --json` and `pylavi summarize --json`. | Stdout is valid JSON only; any diagnostics are emitted on stderr. |
| A-003 | Core | RC-PS-005, RC-PS-014, RC-MIP-004 | Prepare runs for `pylavi scan` and `missing-in-project`. | Execute commands in non-json and json contexts. | Command echo and informational lines are on stderr as specified by stream matrix. |
| A-004 | Core | RC-DET-003, RC-DET-004 | Use offender datasets containing equal counts. | Generate ranked offender/delta outputs. | Ties are ordered by ascending item with case-insensitive ordinal comparison. |
| A-005 | Core | RC-CONV-005 | Static lint over requirement statements. | Detect multi-obligation patterns and atomicity violations. | Each changed/new RC in v5 expresses one independently testable obligation. |
| A-006 | Extended | RC-MAN-001, RC-MAN-002, RC-JSN-070 | Execute `runner-cli manifest --json`. | Parse JSON response. | Fields `spec_document_id`, `spec_version`, `supported_commands`, `supported_profiles`, `build_version`, `generated_utc` are present and typed correctly. |
| A-007 | Extended | RC-MAN-003, RC-MAN-004 | Execute `runner-cli manifest` (non-json). | Inspect stdout/stderr content. | Human summary includes required manifest fields; unknown additional fields do not remove required fields in JSON mode. |
| A-008 | Extended | RC-CONF-001, RC-CONF-004, RC-JSN-080, RC-JSN-090 | Execute `runner-cli conformance check --profile core --json`. | Parse result payload and checks array. | `profile`, `generated_utc`, `summary`, `checks` exist; each check entry includes `id`, `status`, `severity`, `message`, `evidence`. |
| A-009 | Extended | RC-CONF-002, RC-CONF-003, RC-ENV-010, RC-ENV-011 | Set `RC_PROFILE=extended`, `RC_STRICT_MODE=true`. | Execute `runner-cli conformance check` without explicit flags. | Command consumes env defaults and reports execution against expected profile/strict semantics. |
| A-010 | Extended | RC-CONF-006, RC-CONF-007, RC-CONF-008 | Prepare check sets yielding pass, fail, and warn outcomes. | Execute with and without strict mode. | Exit code is 0 for pass; 2 when failures exist; 3 when strict mode escalates warnings. |
| A-011 | Full | RC-GOV-001, RC-GOV-002, RC-GOV-003, RC-GOV-004 | Load release notes + requirement docs for current revision. | Validate governance metadata and lifecycle fields. | Change classification is present; breaking changes include migration notes; deprecations include announce/warn/remove with version boundaries. |
| A-012 | Full | RC-GOV-005 | Load `docs/runner-cli-requirements-v4-to-v5-trace.md` and this file. | Cross-check changed/new RC IDs against trace rows and scenarios. | Every changed/new v5 RC ID is traceable to verification evidence and at least one acceptance scenario. |
| A-013 | Core | RC-PLAT-009, RC-PLAT-010, RC-CONF-010, RC-CONF-011, RC-CONF-012 | Prepare hosted Linux and hosted Windows CI lanes at the same source revision. | Run Core JSON checks (`version-gate --json`, `pylavi summarize --json`) on both lanes; evaluate `missing-in-project` on Windows only and inspect non-Windows treatment in conformance output. | Core cross-platform checks pass on both hosted lanes; Windows-only command checks are recorded as not applicable on non-Windows and do not fail Core conformance. |
| A-014 | Core/Extended/Full | RC-PUR-001, RC-PUR-002, RC-CONV-004, RC-SCOPE-001, RC-SCOPE-002, RC-SCOPE-003, RC-GEN-009, RC-VG-007, RC-VG-008, RC-PS-018, RC-PS-019, RC-PS-020, RC-PS-021, RC-PS-022, RC-PS-023, RC-PSUM-021, RC-PF-014, RC-PF-015, RC-PF-016, RC-PF-017, RC-PF-018, RC-PLAT-007, RC-CONF-005, RC-CONF-009, RC-PLAT-008, RC-PLAT-001, RC-PLAT-002, RC-COMP-002 | Prepare repo with current v5 requirements and runner-cli implementation. | Execute profile-specific static/dynamic checks covering command presence, failure semantics, platform declarations, and compatibility clauses referenced by the listed RC IDs. | All listed RC IDs are explicitly covered by at least one executable or static acceptance check and produce verifiable evidence artifacts. |

Acceptance coverage summary:
- Profiles covered: `core`, `extended`, `full`
- New command surfaces covered: `manifest`, `conformance check`
- New JSON types covered: `RunnerCliManifest`, `ConformanceCheckResult`, `ConformanceCheckEntry`

## Evidence Records

| Scenario ID | Status | Commit | CI Run | Notes |
|---|---|---|---|---|
| A-013 | Pass | `e70e010783c4a33e8730da610be8ecbe3af08e78` | `21786875251` | Hosted Linux + hosted Windows Core checks completed in `CI Pipeline (Composite)` with successful `Conformance Check (Full, Strict)` and no malformed `actions-runner_work` path occurrences in logs. |
