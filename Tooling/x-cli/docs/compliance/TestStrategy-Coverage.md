# Test Strategy — Coverage (Concise)
- **Tools**: .NET (coverlet collector via `XPlat Code Coverage`), Python (`pytest-cov`), merged with **ReportGenerator**.
- **Format**: Cobertura XML (`coverage.xml`) + HTML (`artifacts/coverage/index.html` or `coverage-html.zip`).
- **Scope**: All PRs and semver-tag releases run tests for **.NET** (`XCli.sln`) and **Python** (`codex_rules`).
- **Thresholds**: Total **≥75%**; file floors seeded for critical modules; raise over time.
- **Gates**:
  - **PR**: job `coverage` blocks merge on breach.
  - **Release (vX.Y.Z)**: re-runs coverage and **aborts** on breach.
- **Artifacts**: `coverage.xml`, zipped HTML at `artifacts/coverage-html.zip`, `.trx` under `artifacts/dotnet-tests/`.
