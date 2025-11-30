# Dotnet Tooling

All C# utilities live under `Tooling/dotnet/` and target .NET 8:

- `IntegrationEngineCli` - runs the Integration Engine build (PowerShell wrapper or managed mode).
- `VipbJsonTool` - converts VIPB/LVPROJ JSON; used by the seed action.
- `LvprojJsonTool` - lightweight LVPROJ JSON converter.
- `RequirementsSummarizer` - renders summaries/tables from `docs/requirements/requirements.csv`.
- `TestsCli` - runs `scripts/test/Test.ps1` for missing-in-project + unit tests.

## Dev container

A Dev Container is provided in `.devcontainer/` (Dockerfile + devcontainer.json) with .NET 8 SDK, PowerShell, git, and a NuGet cache volume. Open the repo in VS Code and choose **Reopen in Container** to get a ready-to-build environment. On create, it runs `dotnet restore && dotnet build Tooling/dotnet/RequirementsSummarizer/RequirementsSummarizer.csproj` as a health check.

## Common commands

- Build any CLI: `dotnet build Tooling/dotnet/IntegrationEngineCli/IntegrationEngineCli.csproj` (swap project path as needed).
- Requirements summary (also available as a VS Code task):  
  `dotnet run --project Tooling/dotnet/RequirementsSummarizer/RequirementsSummarizer.csproj -- --csv docs/requirements/requirements.csv --summary-output reports/requirements-summary.md --summary-full --details --details-open`
- Requirements summary (filtered):  
  `dotnet run --project Tooling/dotnet/RequirementsSummarizer/RequirementsSummarizer.csproj -- --csv docs/requirements/requirements.csv --summary-output reports/requirements-summary-high.md --filter-priority High --sort Priority --summary-full --details --details-open`
- Vipb/Lvproj conversion example:  
  `dotnet run --project Tooling/dotnet/VipbJsonTool/VipbJsonTool.csproj -- vipb2json Tooling/deployment/seed.vipb builds/seed.json`
- Tests (wrapper over `scripts/test/Test.ps1`):  
  `dotnet run --project Tooling/dotnet/TestsCli/TestsCli.csproj -- --repo . --bitness both`
