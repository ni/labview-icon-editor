# Orchestration CLI

.NET CLI entrypoint that standardizes PowerShell-driven workflows behind consistent flags, timing, exit codes, and JSON envelopes. Subcommands wrap existing scripts; JSON output is log-stash-friendly (includes script paths and inputs).

## Common flags
- `--repo <path>` (default: cwd)
- `--bitness <both|64|32>` (default: both, where applicable)
- `--lv-version <year>` (where applicable)
- `--pwsh <path>` (default: pwsh)
- `--timeout-sec <n>` (0 = no timeout)
- `--plain`, `--verbose` (reserved/diagnostics)

## Subcommands
- `apply-deps` — applies VIPC via `scripts/task-verify-apply-dependencies.ps1`  
  Details: `{ bitness, vipcPath, lvVersion, scriptPath, exit, stdout, stderr }`
- `restore-sources` — guarded restore via g-cli calling `Tooling/RestoreSetupLVSourceCore.vi` (no legacy PS delegate)  
  Details: `{ bitness, lvVersion, viPath, projectPath, tokenPresent, gcliExit, stdout, stderr, connectionIssue }` (`status=skip` when token absent or g-cli cannot connect)
- `labview-close` — closes LabVIEW via `scripts/close-labview/Close_LabVIEW.ps1`  
  Details: `{ bitness, lvVersion, scriptPath, closed, exit, stdout, stderr }`
- `devmode-bind` / `devmode-unbind` — dev mode via bind/revert scripts  
  Details: `{ bitness, mode, lvVersion, scriptPath, exit, stdout, stderr }`
- `vi-analyzer` — runs analyzer via `scripts/vi-analyzer/RunWithDevMode.ps1`  
  Details: `{ bitness, requestPath, scriptPath, exit, stdout, stderr }`
- `missing-check` — runs missing-in-project via `scripts/missing-in-project/RunMissingCheckWithGCLI.ps1`  
  Details: `{ bitness, lvVersion, projectPath, scriptPath, exit, stdout, stderr }`
- `unit-tests` — runs LUnit via `scripts/run-unit-tests/RunUnitTests.ps1`  
  Details: `{ bitness, lvVersion, projectPath, scriptPath, exit, stdout, stderr }`
- `package-build` — calls IntegrationEngineCli with build/version metadata  
  Details: `{ repo, refName, bitness, lvlibpBitness, version, company, author, labviewMinor, managed, runBothBitnessSeparately, projectPath, exit, stdout, stderr }`

## JSON envelope (all)
Output is a JSON array of command results:
```json
[
  {
    "command": "apply-deps",
    "status": "success|fail|skip",
    "exitCode": 0,
    "durationMs": 1234,
    "details": { ... }
  }
]
```

Logs/stdout/stderr in `details` support log-stash ingestion; timing lines appear as `[orchestration-cli][(T+Xs Δ+Yms)] ...`.
