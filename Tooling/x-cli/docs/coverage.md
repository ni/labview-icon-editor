# Coverage Guide

This project enforces unified coverage across .NET and Python.

- Policy: line ≥ 75%, branch ≥ 60%; per‑file floors in `docs/compliance/coverage-thresholds.json`.
- CI Artifacts: `coverage.xml`, HTML at `artifacts/coverage/index.html`, `.trx` under `artifacts/dotnet-tests/`.

## Collect Locally

1) .NET (Cobertura XML)

```pwsh
cd x-cli
 dotnet test XCli.sln -c Release --collect:"XPlat Code Coverage" -- \
  DataCollectionRunSettings.DataCollectors.DataCollector.Configuration.Format=cobertura
```

2) Python (Cobertura XML)

```pwsh
python -m pytest tests --cov=codex_rules --cov-branch --cov-report=xml:coverage-python.xml -q
```

## Merge & Enforce

```pwsh
# Merge to Cobertura + HTML
 dotnet tool install -g dotnet-reportgenerator-globaltool
 reportgenerator -reports:"**/coverage.cobertura.xml;coverage-python.xml" `
  -targetdir:artifacts/coverage -reporttypes:Cobertura,HtmlInline_AzurePipelines

# Copy merged XML to project root for the gate
 Copy-Item artifacts/coverage/Cobertura.xml coverage.xml

# Enforce thresholds and write a brief summary
 python scripts/enforce_coverage_thresholds.py `
  --config docs/compliance/coverage-thresholds.json `
  --summary artifacts/coverage-summary.md
```

Open `artifacts/coverage/index.html` for the visual report. If the gate reports
“coverage.xml not found”, ensure you copied `artifacts/coverage/Cobertura.xml` to `coverage.xml` first.
