# FGC-REQ-DEV-001 - Traceability updater records commit evidence
Version: 1.0

## Description
The traceability tooling comprises two scripts:

- `scripts/update_traceability.py` records commit hashes for referenced requirement IDs in `docs/traceability.yaml` based on the latest commit message and PR body.
- `scripts/generate-traceability.py` scans `docs/srs` and the `tests/` tree with Python's built‑in glob and text search, using `git ls-files` to honour `.gitignore` rules, to produce `telemetry/traceability.json` without relying on external tools such as ripgrep.

## Rationale
Linking commits to requirements preserves an auditable history of changes. Removing the ripgrep dependency makes the generator portable to minimal environments at the cost of performance (~0.26 s vs 0.024 s for ~2 k files in local benchmarks) while `git ls-files` maintains `.gitignore` compatibility.

## Verification
Method(s): Test | Demonstration | Inspection
Acceptance Criteria:
- AC1. Objective pass/fail evidence exists for RQ1.
- AC2. On a GitHub-hosted Ubuntu runner, scanning ~2000 test files completes within five seconds using only the Python standard library.
## Statement(s)
- RQ1. The system shall record commit hashes for referenced requirement IDs in the traceability registry based on the latest commit message and PR body.
- RQ2. The traceability generator shall locate tests for each requirement without external search dependencies and finish a ~2000-file scan within five seconds on a GitHub-hosted Ubuntu runner.
## Attributes
Priority: Medium
Owner: QA
Source: Team policy
Status: Proposed
Trace: docs/srs/FGC-REQ-DEV-001.md
