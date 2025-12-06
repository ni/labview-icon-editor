# ADR 0006: Requirements Traceability

- Status: Accepted
- Date: 2025-09-01
- Deciders: x-cli maintainers
- Tags: process, traceability

## Context
Maintaining a reliable link between Software Requirements Specification (SRS) documents, tests, and code changes is essential for auditability.
Without a structured policy, requirements could drift from implementation or lack test coverage.

## Decision
- Every requirement in the SRS MUST map to:
  - a specification file under `docs/srs/FGC-REQ-*.md`;
  - corresponding tests under `tests/XCli.Tests/...`;
  - commit metadata that lists the requirement ID using the template `codex: <change_type> | SRS: ... | issue: #<n>` (see ADR 0015).
- The SRS registry (`src/SrsApi`) enforces registration:
  - `FileSrsRegistry` scans `docs/srs` for markdown files and extracts IDs.
  - Loading fails when a file declares an invalid or duplicate ID, ensuring each requirement is uniquely registered.
- Continuous Integration validates traceability:
  - commit-message and metadata workflows verify that referenced SRS IDs exist and are registered;
  - pull requests must declare the same IDs in Codex metadata, and CI rejects mismatches or unknown IDs;
  - automated tests under `tests/XCli.Tests` exercise the behaviors described by each mapped requirement.

## Consequences
- Contributors must update specs, tests, and commit metadata together.
- CI can block changes that break traceability, preventing orphaned requirements or untested features.
