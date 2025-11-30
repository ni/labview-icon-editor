# FGC-REQ-SPEC-001 — SRS Document Registry
Version: 1.0

## Description
The repository provides an SRS registry that discovers definition files in `docs/srs/` and enables lookup by requirement ID. Implemented in `src/SrsApi`, loading fails with an `InvalidDataException` if a document lacks a valid requirement ID or defines a duplicate.

## Rationale
Centralized lookup ensures tools can validate requirement references consistently.

## Verification
- Run `dotnet test` to execute `tests/XCli.Tests/SrsRegistryTests.cs`, which confirms invalid documents raise `InvalidDataException`.
