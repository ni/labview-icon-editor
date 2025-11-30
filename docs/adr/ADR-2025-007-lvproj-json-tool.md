# ADR: LvprojJsonTool Focused Converter

- **ID**: ADR-2025-007  
- **Status**: Accepted  
- **Date**: 2025-11-26

## Context
We need a lightweight, LVPROJ-only converter with explicit flag parsing and clearer help than the multi-mode VipbJsonTool. The goal is to round-trip LabVIEW project files for automation and review without touching the source `Tooling/seed/tests/Samples/seed.lvproj` and to fail fast on bad inputs.

## Options
- **A** - Use `VipbJsonTool` for LVPROJ conversions (works but keeps overloaded UX and positional args).
- **B** - Rely on manual XML editing or ad-hoc scripts (error-prone; no validation).
- **C** - Provide a focused LVPROJ-only CLI with named args and strict validation (chosen).

## Decision
- Maintain a dedicated CLI (`LvprojJsonTool`) that only handles LabVIEW projects and requires named arguments: `LvprojJsonTool <mode> --input <file> --output <file>`. Modes are `lvproj2json` and `json2lvproj`; unknown flags or missing values return exit 1 with usage guidance.
- The tool creates output directories, preserves XML formatting, enforces `<Project>` root validation both directions, and avoids in-place mutation of inputs.
- **Scope/out-of-scope**: In scope: LVPROJ-to-JSON and JSON-to-LVPROJ conversions with structural validation and deterministic exits. Out of scope: VIPB conversions, schema migration, or semantic inspection of LabVIEW projects.
- **Interfaces/CLI examples**:  
  `dotnet run --project Tooling/dotnet/LvprojJsonTool/LvprojJsonTool.csproj -- lvproj2json --input Tooling/seed/tests/Samples/seed.lvproj --output reports/tooling/seed.lvproj.json`  
  `dotnet run --project Tooling/dotnet/LvprojJsonTool/LvprojJsonTool.csproj -- json2lvproj --input reports/tooling/seed.lvproj.json --output reports/tooling/seed_roundtrip.lvproj`
- **Verification**: TOOL-005 (LVPROJ round-trip retains `<Project>` root and exits 0) and TOOL-006 (missing-path or wrong-root inputs return non-zero with clear errors). TOOL-001/TOOL-002 apply when running inside the devcontainer.

## Consequences
- **+** Narrow scope reduces blast radius compared to the multi-mode converter and improves help clarity.
- **+** Deterministic exit codes and root checks protect the seed project from corruption.
- **Risks/mitigations**: Flag misuse or path typos (mitigate via strict argument parsing and help text); changes in LabVIEW project schema (mitigate with regression round-trip tests on seed files); accidental overwrite of outputs (mitigate by requiring explicit `--output` paths).

## Follow-ups
- [ ] Add CI smoke tests for lvproj round-trip and missing-input failure cases.
- [ ] Cross-link tooling docs to clarify when to use this focused tool versus `VipbJsonTool`.
- [ ] Consider optional JSON schema validation for LVPROJ if future automation requires stricter checks.
