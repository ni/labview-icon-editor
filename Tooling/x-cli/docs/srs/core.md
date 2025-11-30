<!--
  SRS — X-CLI (ISO/IEC/IEEE 29148:2018)
  This document is NORMATIVE. All “shall” statements are binding.
-->

# Software Requirements Specification - Core
**Version:** 1.0 (**Revision 1 baseline**)  
**Baseline ID:** R1  
**Date:** 2025-09-05  
**Owner:** LabVIEW-Community-CI-CD

### Conformance intent
This SRS is structured to conform with ISO/IEC/IEEE 29148:2018:
- §5.2.5 Individual requirements (atomic, unambiguous, verifiable “shall” statements)
- §5.2.6 Set of requirements (complete, consistent, feasible, ranked)
- §5.2.7 Language criteria (binding terms; avoidance of vague words)
- §5.2.8 Requirement attributes (priority, rationale, verification method, source, status, trace)

### Baseline policy
- **R1** converts the SRS set into the 29148 template (atomic *shall* + RQ/AC + Attributes), adds strict linting/consistency checks, VCRM, and Verified→Evidence guard.
- Future baselines (R2+) shall reflect additional scope or policy changes, if any.

### Definitions
- **Normative baseline** — the version-controlled set of approved requirements that is binding on all stakeholders and governs verification and change control.

## Statement(s)
- RQ1. The requirements specification set shall serve as the project's single normative baseline organized in accordance with ISO/IEC/IEEE 29148:2018.

## Rationale
Provides a single auditable source of truth aligned with the standard. Attribute values are version-controlled and reviewed at each baseline to stay current.

## Verification
Method(s): Inspection
Acceptance Criteria:
- AC1. Each SRS page includes **Statement(s)** with atomic “shall” bullets numbered RQ1… and **Verification** with **Acceptance Criteria** numbered AC1…. 
- AC2. Each SRS page includes **Attributes** (Priority, Owner, Status, Trace), and `docs/srs/core.md` shows a current baseline ID and date.
- AC3. Attribute values are maintained through version-controlled edits and reviewed during baseline updates.
- AC4. CI runs `scripts/lint_srs_29148.py` over `docs/srs`, reports no errors, and archives the lint results as telemetry evidence.

## Attributes
Priority: Medium
Owner: QA
Source: Process policy
Status: Approved
Trace: docs/srs/core.md
Maintenance: QA updates these attributes via version-controlled commits whenever values change.

## Requirement References
The following requirement IDs originate from earlier specifications and are retained for traceability:

- FGC-REQ-CLI-001
- FGC-REQ-CLI-002
- FGC-REQ-CLI-003
- FGC-REQ-SIM-001
- FGC-REQ-SIM-002
- FGC-REQ-SIM-003
- FGC-REQ-SIM-004
- FGC-REQ-LOG-001
- FGC-REQ-LOG-002
- FGC-REQ-ENV-001
- FGC-REQ-PERF-001
- FGC-REQ-DIST-001
- FGC-REQ-ROB-001
- FGC-REQ-ROB-002
- FGC-REQ-ROB-003
- FGC-REQ-QA-001

## Non‑Normative Notes
- x-cli emits `VersionInfo.Version` for `--version` and prefixes diagnostics with `x-cli`; external wrappers or alias detection are out of scope.
