# FGC-REQ-CI-011 — Test workflow
Version: 1.0

## Description
Run the unit test suite in isolation from build and release workflows.
- `.github/workflows/test.yml` restores dependencies, builds the solution, and runs all tests.
- The workflow publishes test results as artifacts.

## Rationale
Separating tests from build workflows surfaces failures earlier and speeds feedback.

## Verification
Method(s): Test | Demonstration | Inspection
Acceptance Criteria:
- AC1. Objective pass/fail evidence exists for RQ1.
## Statement(s)
- RQ1. The system shall run the unit test suite in isolation from build and release workflows.
## Attributes
Priority: Medium
Owner: QA
Source: Team policy
Status: Proposed
Trace: docs/srs/FGC-REQ-CI-011.md