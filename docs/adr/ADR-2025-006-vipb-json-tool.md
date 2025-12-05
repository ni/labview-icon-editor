# ADR: VipbJsonTool Round-Trip Guardrails

- **ID**: ADR-2025-006  
- **Status**: Accepted  
- **Date**: 2025-11-26

## Context
The seed VIPB and LVPROJ artifacts (`Tooling/deployment/seed.vipb`, `Tooling/seed/tests/Samples/seed.lvproj`) need deterministic JSON round-trips for auditing, patching, and CI without risking corruption of the source specs. We previously used ad-hoc conversions with weak validation, no directory creation, and unclear failure modes when files were missing or malformed.

## Options
- **A** - Maintain ad-hoc PowerShell/XML tooling per format (fragmented UX; no shared guardrails).
- **B** - Fold all conversions into `LvprojJsonTool` (single binary but conflates VIPB and LVPROJ concerns).
- **C** - Keep a multi-mode VIPB/LVPROJ converter with strict root validation and explicit modes (chosen).

## Decision
- Use the .NET 8 console `VipbJsonTool` as the canonical converter. It accepts `VipbJsonTool <mode> <input> <output>`, creates the output directory, preserves XML whitespace, and enforces allowed roots before writing output. Modes: `vipb2json`/`json2vipb`, `lvproj2json`/`json2lvproj`, and `buildspec2json`/`json2buildspec` (the latter dispatches based on file extension).
- **Scope/out-of-scope**: In scope: convert VIPB/LVPROJ specs to/from JSON with structural root validation and explicit non-zero exits on errors. Out of scope: editing contents, mutating source files in place, or performing semantic validation of package/build settings.
- **Interfaces/CLI examples**:  
  `pwsh scripts/common/invoke-repo-cli.ps1 -Cli VipbJsonTool -- vipb2json Tooling/deployment/seed.vipb reports/tooling/seed.vipb.json`  
  `pwsh scripts/common/invoke-repo-cli.ps1 -Cli VipbJsonTool -- json2vipb reports/tooling/seed.vipb.json reports/tooling/seed_roundtrip.vipb`
- **Verification**: TOOL-005 (round-trip `seed.vipb` and `seed.lvproj` retains `<Package`/`<Project>` roots, exit 0) and TOOL-006 (missing or wrong-root inputs return non-zero with clear errors). TOOL-001/TOOL-002 are covered by running the same commands inside the devcontainer.

## Consequences
- **+** Predictable conversions with guardrails against wrong-root or missing inputs; no in-place edits reduce corruption risk.
- **+** Shared tool handles both VIPB and LVPROJ variants, simplifying CI wiring for seed artifacts.
- **Risks/mitigations**: JSON/XML drift or schema changes (mitigate with round-trip tests on seeds); accidental overwrite of desired outputs (mitigate by writing to caller-specified paths under `reports/`); cross-platform discrepancies (mitigate by pinning to .NET 8 and deterministic serialization).

## Follow-ups
- [ ] Add automated round-trip and negative-path tests for `seed.vipb` and `seed.lvproj` in CI.
- [ ] Extend documentation in `Tooling/dotnet/README.md` to call out buildspec modes and recommended `reports/tooling` output paths.
- [ ] Monitor Newtonsoft.Json serialization settings for compatibility with VIPM expectations before shipping packages.
