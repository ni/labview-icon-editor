# FGC-REQ-SDK-001 - External SDK orchestration (x-sdk)
Version: 1.0

## Description
Enable an external SDK repository (`x-sdk`) to orchestrate x-cli's Stage 1/2/3 pipelines using reusable workflows and consume their outputs for higher-order tooling and analytics.

## Rationale
Separating orchestration (x-sdk) from implementation (x-cli) clarifies ownership, simplifies permissions, and supports reuse.

## Verification
Method(s): Demonstration | Inspection
Acceptance Criteria:
- AC1. Orchestration examples exist under `docs/integration/x-sdk/` for Stage 2 and full Stage 123 chains.
- AC2. The examples collect Stage outputs and write a job summary and JSON artifact (`orchestration.json`).

## Statement(s)
- RQ1. The system SHALL document SDK orchestration samples invoking Stage 1/2/3 as reusable workflows.
- RQ2. The system SHALL surface Stage outputs required by the SDK: Stage 1 (`run_id`, `summary_path`), Stage 2 (`run_id`, `manifest_path`, `summary_path`, `diagnostics_path`), and Stage 3 (`summary_path`, `diagnostics_path`, `published`).

## Attributes
Priority: Low
Owner: DevRel
Source: Team policy
Status: Accepted
Trace: docs/srs/FGC-REQ-SDK-001.md

