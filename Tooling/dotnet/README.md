# Dotnet Tooling

All C# utilities live under `Tooling/dotnet/` and target .NET 8:

- `IntegrationEngineCli` - runs the Integration Engine build (PowerShell wrapper or managed mode).
- `VipbJsonTool` - converts VIPB/LVPROJ JSON; used by the seed action.
- `LvprojJsonTool` - lightweight LVPROJ JSON converter.
- `RequirementsSummarizer` - renders summaries/tables from `docs/requirements/requirements.csv`.
- `TestsCli` - runs `scripts/test/Test.ps1` for missing-in-project + unit tests.
- `OllamaSmokeCli` - minimal Ollama POST to `/api/generate`, `/api/chat` (`--chat`), or `/api/embed` (`--embed`) for health checks.
- `OrchestrationCompatCli` - pass-through shim to `OrchestrationCli` (same subcommands/options) plus `devmode-agent` forwarding to `DevModeAgentCli`.

## Dev container

A Dev Container is provided in `.devcontainer/` (Dockerfile + devcontainer.json) with .NET 8 SDK, PowerShell, git, and a NuGet cache volume. Open the repo in VS Code and choose **Reopen in Container** to get a ready-to-build environment. On create, it runs `dotnet restore && dotnet build Tooling/dotnet/RequirementsSummarizer/RequirementsSummarizer.csproj` as a health check.

## Common commands

- Build any CLI: `dotnet build Tooling/dotnet/IntegrationEngineCli/IntegrationEngineCli.csproj` (swap project path as needed).
- Requirements summary (also available as a VS Code task):  
  `pwsh scripts/common/invoke-repo-cli.ps1 -Cli RequirementsSummarizer -- --csv docs/requirements/requirements.csv --summary-output reports/requirements-summary.md --summary-full --details --details-open`
- Requirements summary (filtered):  
  `pwsh scripts/common/invoke-repo-cli.ps1 -Cli RequirementsSummarizer -- --csv docs/requirements/requirements.csv --summary-output reports/requirements-summary-high.md --filter-priority High --sort Priority --summary-full --details --details-open`
- Vipb/Lvproj conversion example:  
  `pwsh scripts/common/invoke-repo-cli.ps1 -Cli VipbJsonTool -- vipb2json Tooling/deployment/seed.vipb builds/seed.json`
- Tests (wrapper over `scripts/test/Test.ps1`):  
  `pwsh scripts/common/invoke-repo-cli.ps1 -Cli TestsCli -- --repo . --bitness both`
- Ollama smoke (direct POST to /api/generate or /api/chat):  
  `pwsh scripts/common/invoke-repo-cli.ps1 -Cli OllamaSmokeCli -- --endpoint http://localhost:11435 --model llama3-8b-local --prompt "Hello smoke"`  
  Add `--chat` to call `/api/chat`, `--embed` to call `/api/embed` (hash + length), `--stream` to print tokens live, `--format text` to output plain text, `--check-model` to preflight the model list, `--retries N --retry-delay-ms M` for transient errors, `--verbose` to echo payload/headers, `--save-body <path>` to capture the raw response, `--prompt-file <path>` to read prompt from file, `--prompt-base64 <b64>` to decode prompt, `--messages-file <path>` or `--messages-base64 <b64>` (JSON array) for chat messages, `--max-bytes N` to guard payload size, `--stop <token>` to truncate generation, `--expect-status N` to assert HTTP status, `--exit-on-empty` to fail on empty response, `--trace` for per-attempt timings, `--skip-cert-check` for self-signed local TLS, `--proxy <url>`, `--header key:value`, `--bearer <token>|--bearer-file <path>`, `--output <path>` to write the final text/JSON summary to a file.
- OrchestrationCompatCli (pass-through to OrchestrationCli and DevModeAgentCli):  
  `pwsh scripts/common/invoke-repo-cli.ps1 -Cli OrchestrationCompatCli -- <orchestration-cli-args>`  
  For DevModeAgent: `pwsh scripts/common/invoke-repo-cli.ps1 -Cli OrchestrationCompatCli -- devmode-agent --phrase "/devmode bind 2021 64-bit force" [--execute] [--summary <path>]`
