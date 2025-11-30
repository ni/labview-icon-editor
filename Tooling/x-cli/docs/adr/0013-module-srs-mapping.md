# ADR 0013: Module-SRS Mapping

- Status: Accepted
- Date: 2025-09-06
- Deciders: x-cli maintainers
- Tags: process, traceability

## Context
Source files must reference the requirements they satisfy, but tracking those
links individually is error-prone. Without a central map, modules may add files
that lack SRS coverage, eroding traceability.

## Decision
- `docs/module-srs-map.yaml` defines the authoritative mapping from module
  directories to the SRS requirement IDs they implement.
- Keys are directory prefixes ending with `/`; nested files inherit the
  requirements of the longest matching prefix.
- `scripts/scan_srs_refs.py` parses the map and scans source directories for
  files without coverage.
- `scripts/qa.sh` runs this script during local QA and in the CI pipeline,
  failing the build when any file is missing a mapped requirement.

## Guidelines
- Append new modules to `docs/module-srs-map.yaml` using a trailing slash and a
  list of SRS IDs.
- Ensure each referenced requirement ID exists under `docs/srs/` and is
  registered with the SRS API.
- After updating the map, execute `python scripts/scan_srs_refs.py` (or
  `./scripts/qa.sh`) to verify that every file is covered. By default QA runs tests
  serially to avoid cross-test interference; enable parallel with `QA_ENABLE_PARALLEL=1`.
  CI runs the same check
  automatically.

## Consequences
Maintainers gain a single, machine-readable map tying modules to their
requirements. The QA and CI gates reject contributions that introduce files
without SRS coverage, keeping traceability intact.
