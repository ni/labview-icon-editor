# FGC-REQ-QA-PAR-001 - Parameterized CI Artifacts
Version: 1.0

## Statement(s)
- RQ1. The release dry‑run and release workflows shall accept a `version` parameter and embed it in produced binaries and records, publishing artifacts with canonical names.

## Rationale
Parameterized builds ensure traceable, reproducible artifacts and predictable naming for downstream automation.

## Verification
Method(s): Test | Demonstration | Inspection
Acceptance Criteria:
- AC1. Running the dry‑run with an input version writes artifacts under `artifacts/release/**` with the version embedded in filenames.
- AC2. The Release‑Record contains the input version and coverage totals.

## Attributes
Priority: Medium
Owner: Release
Source: Team policy
Status: Proposed
Trace: .github/workflows/release-dryrun.yml, .github/workflows/release.yml
