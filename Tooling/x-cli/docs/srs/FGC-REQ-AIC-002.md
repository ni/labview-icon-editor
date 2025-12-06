# FGC-REQ-AIC-002 - Session persistence & audit trail
Version: 1.0

## Statement(s)
- RQ1. The Codex agent shall persist conversation sessions as JSON under `.codex/sessions/` and commit updates with `[skip ci]`.

## Rationale
Creates a durable, versioned record of human↔AI exchanges for compliance and learning.

## Verification
Method(s): Demonstration | Inspection
Acceptance Criteria:
- AC1. After `/codex init` or `/codex say ...`, the repository contains `.codex/sessions/<thread>.json` committed on the default branch.
- AC2. The JSON contains the ordered message history with `role` and `content` fields starting with a `system` message.

## Attributes
Priority: Medium
Owner: QA
Source: Process policy
Status: Proposed
Trace: `scripts/codex_bridge.py`, `.github/workflows/codex-2way.yml`
