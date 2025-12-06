# ADR 0011: SRS Registry Loading

- Status: Accepted
- Date: 2025-09-05
- Deciders: x-cli maintainers
- Tags: srs, traceability

## Context
The project relies on a centralized registry so that requirement identifiers in commits and tests map to actual SRS documents. Without a strict loader, malformed or duplicate files could break traceability.

## Decision
- `FileSrsRegistry` scans the `docs/srs` directory for markdown files when constructed or reloaded.
- Each discovered file has its requirement identifier normalized through `SrsNormalization` so lookups are case-insensitive.
- The loader parses a `Version:` line from each file, defaulting to `1.0` when absent.
- Files named like `FGC-REQ-...` that lack a valid requirement ID or contain malformed IDs cause loading to fail.
- Duplicate requirement IDs across files raise an error, ensuring each requirement maps to a single document.
- The registry exposes its index via `Get` and `Documents`, allowing tools to verify that referenced IDs exist.

## Consequences
- Contributors must name and structure SRS files correctly; invalid or duplicate IDs are rejected at load time.
- A reliable registry lets commit metadata and tests resolve requirement files, maintaining end-to-end traceability.
