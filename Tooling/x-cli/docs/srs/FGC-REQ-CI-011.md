# FGC-REQ-CI-011 - Test workflow
Version: 1.0

## Description
Run the unit test suite in isolation from build and release workflows and ensure individual tests do not share state.
- `.github/workflows/test.yml` restores dependencies, builds the solution, and runs all tests.
- `.github/workflows/tests-parallel-probe.yml` executes the suite in parallel to detect shared state.
- An autouse fixture isolates each test in a unique temporary working directory.
- The workflow publishes test results as artifacts.

## Rationale
Separating tests from build workflows surfaces failures earlier and speeds feedback.

## Verification
Method(s): Test | Demonstration | Inspection
Acceptance Criteria:
- AC1. Objective pass/fail evidence exists for RQ1.
- AC2. Parallel execution (`pytest -n 2`) passes without state leakage.
## Statement(s)
- RQ1. The system shall run the unit test suite in isolation from build and release workflows.
- RQ2. The test harness shall isolate each test in a unique temporary working directory and expose the path via `FAKEG_REPO_ROOT`.
## Attributes
Priority: Medium
Owner: QA
Source: Team policy
Status: Proposed
Trace: docs/srs/FGC-REQ-CI-011.md
