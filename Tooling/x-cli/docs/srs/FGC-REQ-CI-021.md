# FGC-REQ-CI-021 - Reusable workflow contracts (Stage 1 and 3)
Version: 1.0

## Description
Expose Stage 1 (container telemetry) and Stage 3 (Windows validate & publish) as reusable workflows with explicit inputs/outputs to enable external orchestration (e.g., from x-sdk) without duplicating CI logic.

## Rationale
Reusable workflows provide a stable integration surface for SDKs and other repos while preserving local triggers for regular development.

## Verification
Method(s): Inspection | Test | Demonstration
Acceptance Criteria:
- AC1. Stage 1 declares `workflow_call` and emits `run_id` and `summary_path` outputs.
- AC2. Stage 3 declares `workflow_call`, accepts `stage2_repo` and `stage2_run_id` inputs, and emits `summary_path`, `diagnostics_path`, and `published` outputs.
- AC3. Stage 3 supports `force_dry_run` and `validate_schema` flags.

## Statement(s)
- RQ1. The system SHALL expose Stage 1 as a reusable workflow that outputs `run_id` and `summary_path`.
- RQ2. The system SHALL expose Stage 3 as a reusable workflow that accepts `stage2_repo` and `stage2_run_id` and outputs `summary_path`, `diagnostics_path`, and `published`.
- RQ3. The system SHALL implement optional inputs `force_dry_run` (skip posting) and `validate_schema` (validate diagnostics via JSON Schema) for Stage 3.

## Attributes
Priority: Medium
Owner: CI
Source: Team policy
Status: Accepted
Trace: docs/srs/FGC-REQ-CI-021.md

