# Copilot Instructions for x-cli

Purpose
- Cross-platform CLI for test scenarios and log replay/diff. Core code under `src/XCli`; requirement registry APIs under `src/SrsApi`. Tests mirror structure in `tests/XCli.Tests` (xUnit); Python contract/telemetry tooling lives in `tests/__ci__`.

Architecture & Code Layout
- Entry point: `src/XCli/Program.cs` wires command handlers from feature folders (`Cli/`, `Simulation/`, `Logging/`, `Upper/`).
- CLI wiring pattern:
  - Allowed subcommands are declared in `src/XCli/Cli/Cli.cs` (`Cli.Subcommands`). `Cli.HelpText` prints them automatically.
  - `Program.cs` parses args with `Cli.Parse(args)`, validates the subcommand, and dispatches via explicit branches (e.g., to `EchoCommand`, `ReverseCommand`, `UpperCommand`, `Replay.LogReplayCommand`, `Telemetry.TelemetryCommand`).
  - To add a subcommand: add its name to `Cli.Subcommands`, implement handler in `src/XCli/<Feature>/` (or extend `TelemetryCommand`/`Replay.*`), and add a branch in `Program.cs`. Add xUnit tests under `tests/XCli.Tests/<Feature>`.
  - Invocation logging uses `InvocationLogger` and `SimulationResult`; env-driven simulation knobs: `XCLI_FAIL`, `XCLI_FAIL_ON`, `XCLI_EXIT_CODE`, `XCLI_MESSAGE`, `XCLI_DELAY_MS`, `XCLI_MAX_DURATION_MS`.
- Telemetry is built into the CLI (see `docs/cli/telemetry.md`) and written/read in `artifacts/` and `telemetry/`.
- Specs/docs live in `docs/`; automation helpers and QA scripts in `scripts/`.

Critical Workflows
- Build: `dotnet build XCli.sln -c Release`
- Test: `dotnet test XCli.sln -c Release`
- Run help/version: `dotnet run --project src/XCli/XCli.csproj -- --help|--version`
- Examples: `echo`, `upper`, `reverse` subcommands (see `README.md`).
- QA (Windows): `pwsh ./scripts/qa.ps1` (serial by default; set `QA_ENABLE_PARALLEL=1` to parallelize; use `-NoParallel` to force serial). Optional schema validation: `QA_VALIDATE_SCHEMA=1`.
- Telemetry summarize (called by QA): `dotnet run -- telemetry summarize --in artifacts/qa-telemetry.jsonl --out telemetry/summary.json [--history telemetry/qa-summary-history.jsonl]`.
- VS Code tasks (Terminal → Run Task):
  - x-cli: Pack CLI (nupkg)
  - x-cli: Build container (package) / (source)
  - x-cli: Container smoke
- Coverage (Windows, step-by-step):
  - dotnet Cobertura: `dotnet test XCli.sln -c Release --collect:"XPlat Code Coverage" -- DataCollectionRunSettings.DataCollectors.DataCollector.Configuration.Format=cobertura`
  - Python Cobertura: `python -m pytest tests --cov=codex_rules --cov-branch --cov-report=xml:coverage-python.xml -q`
  - Merge reports: `reportgenerator -reports:"**/coverage.cobertura.xml;coverage-python.xml" -targetdir:artifacts/coverage -reporttypes:Cobertura,HtmlInline_AzurePipelines`
  - Enforce floors: copy `artifacts/coverage/Cobertura.xml` to `coverage.xml`, then `python scripts/enforce_coverage_thresholds.py --config docs/compliance/coverage-thresholds.json --summary artifacts/coverage-summary.md`

Project Conventions
- C# style: `.editorconfig`; PascalCase for types/public members; camelCase for locals; `_camelCase` for private readonly fields. Run `dotnet format XCli.sln`.
- Tests: xUnit alongside features under `tests/XCli.Tests`; name methods `MethodUnderTest_Scenario_Expectation`.
- Environment access policy: use `XCli.Util.Env` exclusively; never call `System.Environment.*` in production code (enforced by `tests/XCli.Tests/Analyzers/NoDirectEnvironmentAccessTests.cs`).
- Coverage floors: ≥75% line, ≥60% branch; thresholds in `docs/compliance/coverage-thresholds.json`.
- Commits/PRs: two-line commit template; PRs include Codex metadata JSON, Agent Checklist, and digest lines for any AGENTS snippets touched (see `AGENTS.md`).
- Workflows: keep YAML comments ASCII-only to avoid Windows decode issues.
- Branches: `feat/<topic>` or `feature/<topic>`; `main` protected. Update `docs/settings/branch-protection.expected.json` if patterns change and re-run QA.

New subcommand quick-start
- Files: create `src/XCli/<Feature>/<Feature>Command.cs` with a static API; update `Cli.Subcommands`; add dispatch in `Program.cs`.
- Minimal skeleton:
  ```csharp
  namespace XCli.Foo;
  public static class FooCommand
  {
      public static string Execute(string input) => input + "!");
  }
  // Program.cs: if (subcommand == "foo") { var text = string.Join(" ", parsed.PayloadArgs); Console.WriteLine(FooCommand.Execute(text)); logger.Log("foo", parsed.PayloadArgs, string.Empty, new SimulationResult(true, 0), sw.ElapsedMilliseconds); return 0; }
  // Cli.cs: add "foo" to Subcommands
  ```
- Tests: put CLI tests under `tests/XCli.Tests/FooCliTests.cs` using `ProcRunner.Run("dotnet", "run --no-build -c Release -- foo arg")` and unit tests for `FooCommand`.

Telemetry quick examples
- Emit an event: `dotnet run -- telemetry write --out artifacts/qa-telemetry.jsonl --step build --status pass --duration-ms 1200 --meta sha=abc123`
- Validate summary with schema: `dotnet run -- telemetry validate --summary telemetry/summary.json --schema docs/schemas/v1/telemetry.summary.v1.schema.json`
- Validate events with schema: `dotnet run -- telemetry validate --events artifacts/qa-telemetry.jsonl --schema docs/schemas/v1/telemetry.events.v1.schema.json`
- Gate totals: `dotnet run -- telemetry check --summary telemetry/summary.json --max-failures 0`
- Gate per-step: `dotnet run -- telemetry check --summary telemetry/summary.json --max-failures-step unit=0 --max-failures-step lint=0`

CLI testing pattern
- For CLI-level flows, use `tests/TestUtil/ProcRunner.cs` to run `dotnet run --no-build ...` against `src/XCli`, assert on `ExitCode`, `StdOut`, `StdErr`, and env snapshot.
- For pass-through semantics, remember the rule: tokens after the subcommand are passed through unchanged; `--` only acts as a separator before the subcommand.

CI & Telemetry Integration
- Stage 2 (Ubuntu): build + tests; cross-publish `win-x64`; smoke via Wine; generate `telemetry/manifest.json` with repo-relative paths and SHA-256; validate with `ci/stage2/validate-manifest.sh` before upload.
- Stage 3 (Windows): gate on presence and checksum of manifest/summary/dist; verify with `scripts/validate-manifest.ps1`; run tests and smoke; rebuild natively if Stage 2 marked `win_x64_smoke: failure`; compute telemetry diff and optionally post to Discord.
- Gates: set `MAX_QA_FAILURES` and `MAX_QA_FAILURES_STEP="step=N,..."` to fail on totals/per-step.
- Token helpers and device flow: see `README.md` and `docs/ci-helpers.md`.

Key References
- `AGENTS.md` (repo root) for norms, build/test commands, telemetry toggles, branch/PR rules.
- `README.md` for quick start, orchestration/containers, coverage, and helpers.
- `docs/cli/telemetry.md`, `docs/telemetry.md`, `docs/schemas/` for telemetry schema and manifest rules.
- `scripts/qa.ps1` / `scripts/qa.sh` for end-to-end QA; `scripts/validate-manifest.ps1` for integrity checks.
