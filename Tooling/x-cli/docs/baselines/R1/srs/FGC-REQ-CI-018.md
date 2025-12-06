# FGC-REQ-CI-018 — Codex mirror sign
Version: 1.0

## Description
Mirror repository contents and produce signed artifacts for release.
- `.github/workflows/codex-mirror-sign.yml` mirrors the repository to the designated target.
- The workflow signs published artifacts and verifies signatures.

## Rationale
Signed mirrors enable trusted distribution and archival of releases.

## Verification
Method(s): Test | Demonstration | Inspection
Acceptance Criteria:
- AC1. Objective pass/fail evidence exists for RQ1.
## Statement(s)
- RQ1. The system shall mirror repository contents and produce signed artifacts for release.
## Attributes
Priority: Medium
Owner: QA
Source: Team policy
Status: Proposed
Trace: docs/srs/FGC-REQ-CI-018.md