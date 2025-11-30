# FGC-REQ-QA-002 - Isolated test environment
Version: 1.0

## Description
An autouse pytest fixture shall isolate each test by:
- creating a unique temporary working directory;
- copying the repository's `docs/` tree into that directory;
- exporting `FAKEG_REPO_ROOT` pointing to the temporary directory; and
- forbidding tests from writing to the repository root.

## Rationale
Isolation prevents tests from mutating the repository and ensures deterministic behaviour.

## Verification
Method(s): Test | Demonstration | Inspection
Acceptance Criteria:
- AC1. Each test executes in a unique temporary directory.
- AC2. The fixture exposes a writable `docs/` tree inside that directory.
- AC3. `FAKEG_REPO_ROOT` references the temporary directory.
- AC4. No test writes to the original repository root.

## Statement(s)
- RQ1. The test harness shall provide an autouse fixture that isolates tests as described.

## Attributes
Priority: Medium
Owner: QA
Source: Team policy
Status: Proposed
Trace: tests/conftest.py
