# FGC-REQ-AIC-003 - Codex proposes changes as unified diffs
Version: 1.0

## Statement(s)
- RQ1. The Codex agent shall, on `/codex propose <task>`, return a single unified diff and persist it under `.codex/proposals/<thread>/pNNN.patch`.

## Rationale
Creates a minimal, auditable change unit suitable for automated validation and human review.

## Verification
Method(s): Demonstration | Inspection
Acceptance Criteria:
- AC1. Posting `/codex propose <task>` adds a file `pNNN.patch` and commits it with `[skip ci]`.
- AC2. The patch is a valid unified diff that references only allowed repository paths.

## Attributes
Priority: Medium
Owner: DevEx
Source: Team policy
Status: Proposed
Trace: `.github/workflows/codex-2way.yml`, `scripts/codex_bridge.py`, `.codex/system/codex-bridge.md`
