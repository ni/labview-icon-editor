# ADR 0012: Traceability Matrix

- Status: Accepted
- Date: 2025-09-06
- Deciders: x-cli maintainers
- Tags: process, traceability

## Context
The project needs a single, machine-readable source that maps requirements to implementations, tests, and commit history. Without a maintained map, requirements could lose verification or drift from code.

## Decision
- `docs/traceability.yaml` holds the canonical requirement→implementation→test mapping. Each entry may include a `commits` list recording evidence for changes.
- `scripts/update_traceability.py` scans the latest commit message and PR body for requirement IDs, appending the current commit hash to the `commits` field or creating a new entry when a requirement is first referenced.
- `scripts/verify-traceability.py` parses `docs/traceability.yaml` and ensures every `source` file exists and contains its requirement identifier, failing if any entry is stale or malformed.
- Continuous Integration hooks maintain the matrix:
  - `.github/workflows/test.yml` runs `scripts/update_traceability.py` and commits updates when needed.
  - `.github/workflows/validate-codex-metadata.yml` runs `scripts/verify-traceability.py` to enforce validity on pull requests.

## Consequences
- Contributors must rerun `scripts/update_traceability.py` locally when referencing new SRS IDs or rely on the CI job to update `docs/traceability.yaml`.
- Pull requests fail if `scripts/verify-traceability.py` reports missing source files or IDs, requiring the map to be corrected before merge.
- Ongoing maintenance is required to review commit histories and prune obsolete entries to keep the matrix meaningful.
