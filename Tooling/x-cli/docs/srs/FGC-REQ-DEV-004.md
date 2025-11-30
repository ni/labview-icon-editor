# FGC-REQ-DEV-004 - Telemetry entries include agent feedback block
Version: 1.0

## Description
Telemetry JSON entries shall contain an agent feedback block with Effectiveness, Obstacles, and Improvements sections. The `scripts/check_telemetry_block.py` script validates this structure.

## Rationale
Structured feedback enables consistent QA analysis across agents.

## Verification
Method(s): Test | Demonstration | Inspection
Acceptance Criteria:
- AC1. Objective pass/fail evidence exists for RQ1.
## Statement(s)
- RQ1. Each telemetry JSON entry shall contain an agent feedback block with Effectiveness, Obstacles, and Improvements sections.
## Attributes
Priority: Medium
Owner: QA
Source: Team policy
Status: Proposed
Trace: docs/srs/FGC-REQ-DEV-004.md
