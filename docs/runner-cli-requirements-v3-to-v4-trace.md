# Runner CLI Requirements Trace Matrix (v3 -> v4)

This trace matrix maps each audit finding to the affected v3 requirements and the corresponding v4 requirements.

| Audit Finding | Affected v3 RC IDs | v4 RC IDs | Change Type | Rationale | Verification Scenario |
|---|---|---|---|---|---|
| T-H1 JSON-only stdout vs annotation warnings | RC-GEN-008, RC-GEN-009, RC-PS-011 | RC-GEN-008, RC-GEN-009, RC-GEN-010, RC-PS-011, RC-PS-017 | Breaking | Strict JSON parser safety requires zero non-JSON lines on stdout in `--json` mode. | Invoke JSON-mode commands under `GITHUB_ACTIONS=true`; verify stdout is valid JSON only and warning/annotation lines are on stderr. |
| T-H2 Unspecified output stream for print/emit behaviors | RC-PS-005, RC-PS-014, RC-MIP-004 | RC-PS-005, RC-PS-014, RC-MIP-004 | Clarifying | Explicit stream contracts remove ambiguity and prevent JSON-mode violations. | Validate each requirement text explicitly names `stderr` for diagnostic/info command echoes. |
| T-M1 Goal-like/non-verifiable purpose requirements | RC-PUR-001, RC-PUR-002, RC-PUR-003 | RC-PUR-001, RC-PUR-002, RC-PUR-003 | Clarifying | Purpose requirements now define testable command/capability and statelessness obligations. | Confirm each RC has an observable pass/fail criterion tied to command presence/behavior. |
| T-M2 Multi-action requirements (singularity) | RC-PS-011, RC-PSUM-006, RC-PF-005 | RC-PS-011, RC-PS-017, RC-PSUM-006, RC-PSUM-019, RC-PSUM-020, RC-PF-005, RC-PF-012, RC-PF-013 | Clarifying | Atomic requirements improve traceability and independent verification. | Check each split clause can be tested independently without compound assertions. |
| T-M3 "How" vs "what" coupling | RC-PATH-002, RC-VC-004 | RC-PATH-002, RC-VC-004 | Clarifying | Normative text now specifies outcomes; implementation command examples are non-normative notes. | Ensure normative RC text does not require specific command strings; notes contain optional examples. |
| T-L1 Negative-form requirements | RC-CONV-003, RC-PUR-004, RC-PUR-005, RC-RED-002, RC-SEC-001 | RC-CONV-003, RC-PUR-004, RC-PUR-005, RC-RED-002, RC-SEC-001 | Clarifying | Positive-form constraints improve readability and standards conformance style. | Verify target RC statements are expressed positively while preserving intended behavior. |
| T-L2 Line ending and timestamp precision clarity | RC-GEN-005, RC-TIME-001 | RC-GEN-005, RC-TIME-001 | Clarifying | Deterministic newline and timestamp rules reduce cross-platform interpretation variance. | Validate RC-GEN-005 specifies LF/CRLF policy and RC-TIME-001 specifies fixed 7-digit fractional seconds. |

Coverage: 7/7 audit findings mapped to v4 changes (100%).
