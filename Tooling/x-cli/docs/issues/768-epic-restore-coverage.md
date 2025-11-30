# Epic 768 — Restore Release Coverage Floors and Strict Gate

- Issue: https://github.com/LabVIEW-Community-CI-CD/x-cli/issues/768
- Goal: Restore unified coverage floors and re‑enable strict coverage gate (line ≥ 75%, branch ≥ 60%).

## Initial Tasks (Scaffold)

- [ ] .NET: Expand tests to improve branch coverage (Telemetry command paths; Simulation flows)
  - tests/XCli.Tests/Coverage/TelemetryCoverageScaffold.cs (scaffold)
  - tests/XCli.Tests/Coverage/SimulationCoverageScaffold.cs (scaffold)
- [ ] Python: Focused tests for codex_rules.storage (prune_guidance) and telemetry validate subcommands
  - tests/test_codex_rules_storage_scaffold.py (scaffold)
  - tests/test_cli_telemetry_validate_scaffold.py (scaffold)
- [ ] Merge coverage: include Python Cobertura in ReportGenerator (CI + release)
  - Updated: `.github/workflows/coverage-gate.yml` and `.github/workflows/release.yml`
- [ ] Docs: Minimal test strategy and floors
  - Reference thresholds: `docs/compliance/coverage-thresholds.json`
- [ ] Trial release with gate ON; report outcomes

## Notes

- Python coverage XML is emitted to `artifacts/python-coverage/coverage.xml`.
- ReportGenerator merges: `**/coverage.cobertura.xml;artifacts/python-coverage/coverage.xml`.
- Scaffolds are marked as skipped to avoid CI failures until tests are implemented.
