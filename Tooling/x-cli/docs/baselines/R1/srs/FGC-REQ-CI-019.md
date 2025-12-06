# FGC-REQ-CI-019 — Commit message policy
Version: 1.0

## Description
Enforce the repository's commit message conventions.
- `.github/workflows/commit-message-policy.yml` verifies that every commit message matches the required template.
- The workflow fails when a commit message violates the policy.

## Rationale
Consistent commit messages improve traceability and automation tooling.

## Verification
Method(s): Test | Demonstration | Inspection
Acceptance Criteria:
- AC1. Objective pass/fail evidence exists for RQ1.
## Statement(s)
- RQ1. The system shall enforce the repository's commit message conventions.
## Attributes
Priority: Medium
Owner: QA
Source: Team policy
Status: Proposed
Trace: docs/srs/FGC-REQ-CI-019.md