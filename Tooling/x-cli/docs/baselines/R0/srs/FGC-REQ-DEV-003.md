# FGC-REQ-DEV-003 — Telemetry modules expose agent feedback
Version: 1.0

## Description
Telemetry modules must expose an `agent_feedback` argument or `--agent-feedback` flag. The `scripts/check_agent_feedback.py` script scans modules to enforce this interface.

## Rationale
Standard feedback options let agents capture contextual insights.

## Verification
- Execute `scripts/check_agent_feedback.py` and verify `tests/test_check_agent_feedback.py` passes when modules include the argument.

