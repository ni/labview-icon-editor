# FGC-REQ-CI-007 — Dispatch codex
Version: 1.0

## Description
Allow external systems to trigger codex runs via repository dispatch.
- `.github/workflows/dispatch-codex.yml` listens for `repository_dispatch` events.
- The workflow forwards the request to `codex-execute.yml` with the provided payload.

## Rationale
External dispatch enables integration with other automation systems.

## Verification
Method(s): Test | Demonstration | Inspection
Acceptance Criteria:
- AC1. Objective pass/fail evidence exists for RQ1.
## Statement(s)
- RQ1. The system shall allow external systems to trigger codex runs via repository dispatch.
## Attributes
Priority: Medium
Owner: QA
Source: Team policy
Status: Proposed
Trace: docs/srs/FGC-REQ-CI-007.md