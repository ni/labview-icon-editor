# FGC-REQ-DEV-003 - Telemetry modules expose agent feedback
Version: 1.0

## Description
Telemetry modules shall expose an `agent_feedback` argument or `--agent-feedback` flag. The `scripts/check_agent_feedback.py` script scans modules to enforce this interface.

## Rationale
Standard feedback options let agents capture contextual insights.

## Verification
Method(s): Test | Demonstration | Inspection
Acceptance Criteria:
- AC1. Objective pass/fail evidence exists for RQ1.
## Statement(s)
- RQ1. Telemetry modules shall expose an `agent_feedback` argument or `--agent-feedback` flag.
## Attributes
Priority: Medium
Owner: QA
Source: Team policy
Status: Proposed
Trace: docs/srs/FGC-REQ-DEV-003.md
