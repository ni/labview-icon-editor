# FGC-REQ-CI-001 — Build pipelines
Version: 1.0

## Description
Ensure the project builds and publishes cross-platform binaries through continuous integration.
- `.github/workflows/build.yml` and `.github/workflows/stage2-3-ci.yml` compile the solution in Release.
- The workflows run the full test suite.
- They publish single-file artifacts for `linux-x64` and `win-x64` and run smoke tests against them.

## Rationale
Automated cross-platform builds catch regressions early and produce verified binaries for release.

## Verification
Method(s): Test | Demonstration | Inspection
Acceptance Criteria:
- AC1. Objective pass/fail evidence exists for RQ1.
## Statement(s)
- RQ1. The system shall build and publish cross-platform binaries through continuous integration.
## Attributes
Priority: Medium
Owner: QA
Source: Team policy
Status: Proposed
Trace: docs/srs/FGC-REQ-CI-001.md