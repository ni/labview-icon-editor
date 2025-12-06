param(
    [string]$RepoRoot = (Resolve-Path "$PSScriptRoot/.." | Select-Object -First 1).Path,
    [string]$InputCsv = "docs/requirements/requirements.csv",
    [string]$Schema = "",
    [string]$OutputRoot = "builds/srs/headless",
    [switch]$WhatIf
)

$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'

$RepoRoot = (Resolve-Path $RepoRoot).Path
Set-Location $RepoRoot

if (-not (Test-Path $InputCsv)) {
    throw "Input CSV not found: $InputCsv"
}

$runId = if ($env:GITHUB_RUN_ID) { $env:GITHUB_RUN_ID } else { Get-Date -Format 'yyyyMMdd-HHmmss' }
$runDir = Join-Path $OutputRoot $runId
$null = New-Item -ItemType Directory -Force -Path $runDir

$importJson = Join-Path $runDir 'requirements.json'
$validateJson = Join-Path $runDir 'srs-result.json'
$logPath = Join-Path $runDir 'srs.log'

$env:DOTNET_CLI_TELEMETRY_OPTOUT = '1'
$env:TZ = 'UTC'

function Invoke-Step {
    param(
        [string[]]$Command,
        [string]$Name
    )
    Write-Host "==> $Name" -ForegroundColor Cyan
    if ($WhatIf) {
        Write-Host "WHATIF: $($Command -join ' ')"
        return 0
    }
    $cmdPath = $Command[0]
    $cmdArgs = if ($Command.Length -gt 1) { $Command[1..($Command.Length - 1)] } else { @() }
    $null = & $cmdPath @cmdArgs *>&1 | Tee-Object -FilePath $logPath -Append | Out-Host
    return [int]($LASTEXITCODE ?? 0)
}

$importArgs = @(
    'dotnet','run','--project',"$RepoRoot/Tooling/x-cli/src/XCli/XCli.csproj",'--',
    'srs','import-csv','--input',$InputCsv,'--output',$importJson
)

$validateArgs = @(
    'dotnet','run','--project',"$RepoRoot/Tooling/x-cli/src/XCli/XCli.csproj",'--',
    'srs','validate','--input',$importJson,'--schema-strict','--output-json',$validateJson
)
if ($Schema) { $validateArgs += @('--schema', $Schema) }

$start = Get-Date
$importExit = Invoke-Step -Command $importArgs -Name 'import-csv'
$validateExit = -1
if ($importExit -eq 0) {
    $validateExit = Invoke-Step -Command $validateArgs -Name 'validate'
} else {
    Write-Host "import-csv failed (exit $importExit); skipping validate" -ForegroundColor Yellow
    $validateExit = $importExit
}

$summary = [pscustomobject]@{
    runId = $runId
    startedUtc = $start.ToString('o')
    finishedUtc = (Get-Date).ToString('o')
    inputCsv = $InputCsv
    schema = if ($Schema) { $Schema } else { $null }
    importJson = $importJson
    validateJson = $validateJson
    log = $logPath
    importExitCode = $importExit
    validateExitCode = $validateExit
}

$summaryPath = Join-Path $runDir 'srs-summary.json'
$summary | ConvertTo-Json -Depth 6 | Set-Content -Path $summaryPath -Encoding UTF8

exit $validateExit
