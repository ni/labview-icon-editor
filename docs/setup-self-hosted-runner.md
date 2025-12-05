# Automating the Windows Self-Hosted Runner

This repository targets a `self-hosted-windows-lv` runner for LabVIEW workflows. The scripts under `scripts/setup-runner` automate downloading the official GitHub runner package, registering it against your fork, installing it as a Windows service, and tearing it down when it is no longer needed.

## Prerequisites

- Windows host with Git, PowerShell (5.1 or later), and network access to `github.com`.
- A GitHub personal access token (PAT) that has `repo` scope for the target repository; the runner registration token endpoint additionally requires `actions:read` and `actions:write` rights, so the token should include the `admin:repo` or equivalent scopes.
- Permissions to configure Windows services on the host system.

## Registering the runner

1. Open PowerShell on the Windows host and export the PAT (`GH_PAT` or `GITHUB_PAT`); e.g.:

   ```powershell
   $env:GH_PAT = 'ghp_0123456789abcdefghijklmno'
   ```

2. Run the registration helper (adjust parameters as needed):

   ```powershell
   pwsh -ExecutionPolicy Bypass -File scripts/setup-runner/RegisterSelfHostedRunner.ps1 `
     -Repo your-username/labview-icon-editor-sandbox `
     -RunnerDir 'C:\actions-runners\labview-windows' `
     -RunnerName 'self-hosted-windows-lv' `
     -Labels @('self-hosted','windows','self-hosted-windows-lv')
   ```

   The script will:

   - Download the latest `actions-runner-win-x64` payload.
   - Request a registration token for `your-username/labview-icon-editor-sandbox`.
   - Configure `config.cmd` with the provided name/labels.
   - Install and start the Windows service so the runner spins up on boot and reconnects automatically.

3. Confirm the runner appears under **Settings > Actions > Runners** in your fork, and that the service is running (`Get-Service actions.runner.*`).

4. Before kicking off CI, verify the host has the expected toolchain (LabVIEW 2021 x64/x86, .NET 8 SDK, Pester, git, VIPM):

   ```powershell
   pwsh -ExecutionPolicy Bypass -File scripts/setup-runner/Verify-RunnerPrereqs.ps1
   ```

   The script exits non-zero if any required component is missing; add `-SkipLabVIEWX86` or `-SkipVIPM` if you intentionally omit those. VIPM is normally installed alongside LabVIEW and bitness-agnostic; the checker requires the `vipm` CLI to be on PATH (or resolvable via `VIPM_PATH`) and will fail if it only finds VIPM.exe in Program Files without a PATH entry. .NET SDK 8.0.x is required per `docs/requirements/dotnet-runner.md`.

### Non-elevated/interactive runs

If you cannot install services (no administrator rights), re-run the registration script with `-InstallService $false` so it configures the runner without installing the Windows service:

```powershell
pwsh -ExecutionPolicy Bypass -File scripts/setup-runner/RegisterSelfHostedRunner.ps1 `
  -Repo your-username/labview-icon-editor-sandbox `
  -RunnerDir 'C:\actions-runners\labview-windows' `
  -RunnerName 'self-hosted-windows-lv' `
  -Labels @('self-hosted','windows','self-hosted-windows-lv') `
  -InstallService $false
```

This leaves a configured runner you can start by running `run.cmd` manually in that directory; keep the PowerShell session open so the runner keeps polling (or wrap the call in a scheduled task). The cleanup script still works, and you can stop the runner by Ctrl+C or closing the session.

## Updating or reinstalling

To change labels, upgrade to a newer runner version, or replace the machine, re-run the registration helper with the same `RunnerDir`. The script removes any existing directory before unpacking and runs `config.cmd --replace` so you can rerun it safely.

## Removing the runner

To unregister and remove the runner:

```powershell
pwsh -ExecutionPolicy Bypass -File scripts/setup-runner/RemoveSelfHostedRunner.ps1 `
  -Repo your-username/labview-icon-editor-sandbox
```

- The script stops and uninstalls the Windows service.
- It requests a remove token from GitHub and runs `config.cmd remove`.
- It deletes the unpacked runner directory when cleanup finishes.

If you prefer, you can pass `-Token` instead of relying on `GH_PAT/GITHUB_PAT`.

## Troubleshooting

- If registration fails, verify the PAT scopes (`actions:read`, `actions:write`, `repo`) and that the machine’s clock is accurate.
- The scripts log details to the console (`Write-Host`). Review the output for API errors or download failures.
- For additional runner options (work directory, runner group), re-run the registration script with custom parameters; see the script header comments for every parameter.
