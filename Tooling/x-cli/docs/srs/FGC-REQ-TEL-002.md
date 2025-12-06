# FGC-REQ-TEL-002 - Telemetry publish robustness
Version: 1.0

## Description
The telemetry publisher SHALL be resilient to formatting and size constraints and SHALL support safe fallbacks.
- Remove brittle string formatting; use interpolation with proper variable escaping.
- Handle Discord message limits via chunking or optional attachment posting.
- Fall back to dry‑run when the webhook is missing or posting fails while still saving history and diagnostics.

## Rationale
Reliable telemetry publication avoids CI flakes and ensures operators can always inspect the latest results.

## Verification
Method(s): Test | Demonstration | Inspection
Acceptance Criteria:
- AC1. Objective pass/fail evidence exists for RQ1–RQ3.
## Statement(s)
- RQ1. The telemetry publisher SHALL support chunked posting when message size exceeds the provider limit.
- RQ2. The telemetry publisher SHALL fall back to dry‑run when the webhook is missing or posting fails, while preserving history and diagnostics.
- RQ3. The telemetry publisher SHALL avoid brittle string formatting by using safe interpolation/encoding.
## Attributes
Priority: Medium
Owner: QA
Source: Team policy
Status: Accepted
Trace: docs/srs/FGC-REQ-TEL-002.md

