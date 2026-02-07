# Runner CLI Requirements Trace Matrix (v4 -> v5)

This trace matrix maps v5 changes to affected v4 requirements and verification scenarios.

| Change ID | Affected v4 RC IDs | v5 RC IDs | Profile | Change Type | Rationale | Verification |
|---|---|---|---|---|---|---|
| V5-C1 | RC-PUR-001, RC-PUR-002, RC-CONV-004 | RC-SCOPE-001, RC-SCOPE-002, RC-SCOPE-003 | Core | Clarifying | Introduce progressive scope model and conformance hierarchy. | Validate profile section defines `core`, `extended`, `full` and implication rules. |
| V5-C2 | RC-GEN-008, RC-GEN-009, RC-GEN-010 | RC-GEN-008, RC-GEN-009, RC-GEN-010, RC-GEN-011 | Core | Breaking | Guarantee strict JSON stdout purity with explicit stream matrix. | Execute JSON mode command checks and assert stdout is JSON-only while diagnostics route to stderr. |
| V5-C3 | RC-DET-003, RC-CONV-004 | RC-DET-004, RC-CONV-005, RC-CONV-006, RC-VG-007, RC-VG-008, RC-PS-018, RC-PS-019, RC-PS-020, RC-PS-021, RC-PS-022, RC-PS-023, RC-PSUM-021, RC-PF-014, RC-PF-015, RC-PF-016, RC-PF-017, RC-PF-018 | Core | Clarifying | Expand deterministic ordering and split multi-obligation requirements into atomic clauses. | Static review ensures one independently testable obligation per changed RC and deterministic tie-break references for ranked arrays. |
| V5-C4 | none (new command surface) | RC-MAN-001, RC-MAN-002, RC-MAN-003, RC-MAN-004, RC-JSN-070, RC-PLAT-007 | Extended | Breaking | Add introspection command for contract/spec capability discovery. | Validate `manifest --json` schema fields and non-json human summary requirements. |
| V5-C5 | none (new command surface) | RC-CONF-001, RC-CONF-002, RC-CONF-003, RC-CONF-004, RC-CONF-005, RC-CONF-006, RC-CONF-007, RC-CONF-008, RC-CONF-009, RC-JSN-080, RC-JSN-090, RC-ENV-010, RC-ENV-011, RC-PLAT-008 | Extended | Breaking | Add profile-scoped conformance evaluation and machine-readable results. | Validate `conformance check` profile, strict mode, exit codes, and JSON contract for result/check entries. |
| V5-C7 | RC-PLAT-001, RC-PLAT-002, RC-CONF-001 | RC-PLAT-009, RC-PLAT-010, RC-CONF-010, RC-CONF-011, RC-CONF-012 | Core | Clarifying | Define hosted cross-platform Core conformance evidence and explicit non-applicable handling for Windows-only command checks. | Execute Core checks on hosted Linux and hosted Windows and verify Windows-only checks are not-applicable on non-Windows platforms. |
| V5-C6 | RC-COMP-002 | RC-GOV-001, RC-GOV-002, RC-GOV-003, RC-GOV-004, RC-GOV-005 | Full | Clarifying | Add release governance, deprecation lifecycle, and evidence traceability. | Validate governance section includes change classification, deprecation phases, and release traceability requirements. |

Coverage: 100% of listed changed/new v5 RC IDs are mapped to at least one trace row.
