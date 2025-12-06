param(
    [string]$RepoRoot = '.',
    [string]$OutputRoot = 'builds/tests/dotnet',
    [string]$ForceSimulationSubcommands = 'srs',
    [switch]$WhatIf
)

$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'

$RepoRoot = (Resolve-Path $RepoRoot).Path
Set-Location $RepoRoot

$runId = Get-Date -Format 'yyyyMMdd-HHmmss'
$runDir = Join-Path $OutputRoot $runId
$null = New-Item -ItemType Directory -Force -Path $runDir

if (-not [string]::IsNullOrWhiteSpace($ForceSimulationSubcommands)) {
    $env:XCLI_FORCE_SIMULATION_SUBCOMMANDS = $ForceSimulationSubcommands
}

function Invoke-Step {
    param(
        [string[]]$Command,
        [string]$Name,
        [string]$LogPath
    )
    Write-Host "==> $Name" -ForegroundColor Cyan
    if ($WhatIf) {
        Write-Host "WHATIF: $($Command -join ' ')"
        return 0
    }
    $cmd = $Command[0]
    $cmdArgs = if ($Command.Length -gt 1) { $Command[1..($Command.Length-1)] } else { @() }
    $null = & $cmd @cmdArgs *>&1 | Tee-Object -FilePath $LogPath -Append | Out-Host
    return [int]($LASTEXITCODE ?? 0)
}

$tests = @(
    @{ Name = 'XCli.Tests'; Project = 'Tooling/x-cli/tests/XCli.Tests/XCli.Tests.csproj' },
    @{ Name = 'SrsApi.Tests'; Project = 'Tooling/x-cli/tests/SrsApi.Tests/SrsApi.Tests.csproj' },
    @{ Name = 'ManifestValidationTests'; Project = 'Tooling/x-cli/tests/ManifestValidationTests/ManifestValidationTests.csproj' }
)

$failures = @()
foreach ($t in $tests) {
    $logPath = Join-Path $runDir ("{0}.log" -f $t.Name)
    $trxName = "{0}.trx" -f $t.Name
    $cmd = @('dotnet','test',$t.Project,'--logger',"trx;LogFileName=$trxName",'--results-directory',$runDir)
    $code = Invoke-Step -Command $cmd -Name $t.Name -LogPath $logPath
    if ($code -ne 0) { $failures += "{0} (exit {1})" -f $t.Name,$code }
}

$summary = [pscustomobject]@{
    runId = $runId
    repo = $RepoRoot
    output = $runDir
    forceSimulation = $ForceSimulationSubcommands
    failures = $failures
}
$summary | ConvertTo-Json -Depth 4 | Set-Content -Path (Join-Path $runDir 'summary.json') -Encoding UTF8

if ($failures.Count -gt 0) { exit 1 }
exit 0
