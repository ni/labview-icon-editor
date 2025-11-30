# FGC-REQ-CI-012 — Trigger codex orchestration
Version: 1.0

## Description
Provide a lightweight entry point for initiating codex orchestration.
- `.github/workflows/trigger-codex-orchestration.yml` emits a `repository_dispatch` event to start `codex-orchestrator.yml`.
- The workflow runs on manual dispatch and on a schedule.

## Rationale
A simple trigger isolates orchestration logic and enables periodic runs.

## Verification
Method(s): Test | Demonstration | Inspection
Acceptance Criteria:
- AC1. Objective pass/fail evidence exists for RQ1.
## Statement(s)
- RQ1. The system shall provide a lightweight entry point for initiating codex orchestration.
## Attributes
Priority: Medium
Owner: QA
Source: Team policy
Status: Proposed
Trace: docs/srs/FGC-REQ-CI-012.md