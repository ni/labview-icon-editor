# FGC-REQ-CI-017 - Agents contract check
Version: 1.0

## Description
Validate that commits and pull requests adhere to the AGENTS contract.
- `.github/workflows/agents-contract-check.yml` verifies commit messages, AGENTS digests, and required metadata.
- The workflow fails when the contract is violated.

## Rationale
Enforcing the contract maintains traceability and consistent automation across contributions.

## Verification
Method(s): Test | Demonstration | Inspection
Acceptance Criteria:
- AC1. Objective pass/fail evidence exists for RQ1.
## Statement(s)
- RQ1. The system shall validate that commits and pull requests adhere to the AGENTS contract.
## Attributes
Priority: Medium
Owner: QA
Source: Team policy
Status: Proposed
Trace: docs/srs/FGC-REQ-CI-017.md
