# FGC-REQ-TEL-003 - Telemetry diagnostics and summaries
Version: 1.0

## Description
Telemetry publication SHALL emit diagnostics suitable for CI operators and reviewers.
- Produce chunk diagnostics JSON and maintain `summary-latest.json` / `diff-latest.json` history pointers.
- Provide optional PR comment markdown output.
- Append a concise job summary (pass/fail/skipped/duration, deltas when available, chunk metadata).

## Rationale
Actionable diagnostics and visible summaries shorten triage and improve CI observability.

## Verification
Method(s): Test | Demonstration | Inspection
Acceptance Criteria:
- AC1. Objective pass/fail evidence exists for RQ1.
## Statement(s)
- RQ1. Telemetry publication SHALL emit diagnostics (history pointers, chunk metadata) and a concise job summary.
## Attributes
Priority: Medium
Owner: QA
Source: Team policy
Status: Accepted
Trace: docs/srs/FGC-REQ-TEL-003.md

