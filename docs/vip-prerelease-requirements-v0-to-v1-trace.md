# VI Package Develop Pre-Release Requirements Trace Matrix (v0 -> v1)

This trace matrix maps v1 requirement changes for develop prerelease publication to requirement IDs and acceptance scenarios.

| Change ID | Affected prior VR IDs | v1 VR IDs | Profile | Change Type | Rationale | Verification |
|---|---|---|---|---|---|---|
| V1-C0 | none (new contract) | VR-SCOPE-001, VR-SCOPE-002, VR-SCOPE-003, VR-SCOPE-004, VR-PUR-001, VR-PUR-002, VR-PUR-003, VR-PUR-004, VR-PUR-005, VR-PUR-006 | Core | Clarifying | Establish profile semantics, applicability rules, and publication scope boundaries for the new requirement set. | A-001 |
| V1-C1 | none (new contract) | VR-TRIG-001, VR-TRIG-002, VR-TRIG-003, VR-TRIG-006, VR-FAIL-001 | Core | Clarifying | Define develop merged-PR eligibility and explicit skip behavior for ineligible runs. | A-002, A-003, A-014 |
| V1-C2 | none (new contract) | VR-VER-001 | Core | Clarifying | Bind release tag/title to computed workflow version output for deterministic publication identity. | A-007 |
| V1-C3 | none (new contract) | VR-VER-002, VR-VER-003, VR-VER-004, VR-VER-005, VR-VER-006, VR-FAIL-004 | Core | Contract-expanding | Add merged-PR label-derived bump behavior and override interface for push-to-develop eligibility. | A-005, A-006 |
| V1-C4 | none (new contract) | VR-PUB-001, VR-PUB-002, VR-PUB-003, VR-PUB-004, VR-PUB-005, VR-PUB-006, VR-PUB-007, VR-AST-003, VR-FAIL-002 | Core | Clarifying | Define prerelease upsert semantics, release body/failure behavior, publish outputs, and status artifact contract. | A-008, A-009, A-013, A-014 |
| V1-C5 | none (new contract) | VR-AST-001, VR-AST-002, VR-AST-004, VR-FAIL-003 | Core | Clarifying | Require fixed asset set including diagnostics and fail when required assets are missing. | A-010, A-011 |
| V1-C6 | none (new contract) | VR-TRIG-004, VR-TRIG-005, VR-OPS-001, VR-OPS-002, VR-OPS-003, VR-OPS-004, VR-SEC-001, VR-SEC-002, VR-SEC-003, VR-GOV-001, VR-GOV-002, VR-GOV-003, VR-GOV-004 | Extended/Full | Contract-expanding | Add manual backfill dispatch controls, SHA pinning contract, security expectations, and governance/traceability requirements. | A-004, A-012, A-015 |

Coverage summary:
- Changed/new v1 VR IDs are fully mapped to trace rows.
- Acceptance scenarios A-001 through A-015 cover Core, Extended, and Full profile expectations.
