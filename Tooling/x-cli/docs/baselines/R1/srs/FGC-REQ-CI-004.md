# FGC-REQ-CI-004 — Codex orchestrator
Version: 1.0

## Description
Coordinate codex execution across repositories.
- `.github/workflows/codex-orchestrator.yml` triggers codex runs for configured repositories.
- The workflow waits for dispatched runs to complete and reports their status.

## Rationale
Central orchestration ensures dependent repositories complete codex tasks before promotion.

## Verification
Method(s): Test | Demonstration | Inspection
Acceptance Criteria:
- AC1. Objective pass/fail evidence exists for RQ1.
## Statement(s)
- RQ1. The system shall coordinate codex execution across repositories.
## Attributes
Priority: Medium
Owner: QA
Source: Team policy
Status: Proposed
Trace: docs/srs/FGC-REQ-CI-004.md