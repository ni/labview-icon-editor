# FGC-REQ-CI-003 — Codex execute
Version: 1.0

## Description
Run a codex job inside a GitHub Actions runner on demand.
- `.github/workflows/codex-execute.yml` accepts manual dispatch events.
- The workflow spins up a container and invokes the requested codex task.

## Rationale
On-demand codex execution enables targeted validation without full pipeline runs.

## Verification
Method(s): Test | Demonstration | Inspection
Acceptance Criteria:
- AC1. Objective pass/fail evidence exists for RQ1.
## Statement(s)
- RQ1. The system shall run a codex job inside a GitHub Actions runner on demand.
## Attributes
Priority: Medium
Owner: QA
Source: Team policy
Status: Proposed
Trace: docs/srs/FGC-REQ-CI-003.md