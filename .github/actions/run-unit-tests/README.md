# Run Unit Tests (Deprecated)

This composite action is deprecated and intentionally fails fast.
Use `runner-cli lunit run` for canonical g-cli execution and `runner-cli lunit validate` for parse-only report validation.

Canonical LUnit execution is now:

```pwsh
dotnet run --project Tooling/runner-cli/RunnerCli/RunnerCli.csproj -- `
  lunit run `
  --repo-root . `
  --year 2020 `
  --labview-version 20.0 `
  --bitness 64 `
  --project-path .\lv_icon_editor.lvproj `
  --report-path .\.github\actions\run-unit-tests\UnitTestReport-Windows-64.xml
```

Parse-only validation remains available via:

```pwsh
dotnet run --project Tooling/runner-cli/RunnerCli/RunnerCli.csproj -- `
  lunit validate `
  --repo-root . `
  --labview-version 20.0 `
  --bitness 64 `
  --report-path .\.github\actions\run-unit-tests\UnitTestReport-Windows-64.xml
```
