# FGC-REQ-DEV-004 — Telemetry entries include agent feedback block
Version: 1.0

## Description
Telemetry JSON entries must contain an agent feedback block with Effectiveness, Obstacles, and Improvements sections. The `scripts/check_telemetry_block.py` script validates this structure.

## Rationale
Structured feedback enables consistent QA analysis across agents.

## Verification
- Run `scripts/check_telemetry_block.py` and confirm `tests/test_check_telemetry_block.py` passes for valid telemetry entries.

