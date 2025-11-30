# FGC-REQ-CI-011 — Test workflow
Version: 1.0

## Description
Run the unit test suite in isolation from build and release workflows.
- `.github/workflows/test.yml` restores dependencies, builds the solution, and runs all tests.
- The workflow publishes test results as artifacts.

## Rationale
Separating tests from build workflows surfaces failures earlier and speeds feedback.

## Verification
- Trigger `.github/workflows/test.yml` and ensure all tests execute and results are uploaded.
