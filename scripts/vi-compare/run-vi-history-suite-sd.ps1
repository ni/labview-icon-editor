param(
    [string] $SdRoot = '.',
    [switch] $IncludeSample,
    [switch] $AllowExecute
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$resolvedRoot = Resolve-Path -Path $SdRoot -ErrorAction Stop
$repoRoot = $resolvedRoot.ProviderPath

if ($repoRoot -like 'C:\Program Files*') {
    throw "Refusing to run vi-history analysis from Program Files: $repoRoot"
}

$logDir = Join-Path $repoRoot 'reports/logs'
New-Item -ItemType Directory -Force -Path $logDir | Out-Null

$scenarios = [ordered]@{
    'sample'   = 'configs/vi-compare-run-request.sample.json'
    'failure'  = 'configs/vi-compare-run-request.failure.json'
    'disabled' = 'configs/vi-compare-run-request.disabled.json'
}

if (-not $IncludeSample) {
    $scenarios.Remove('sample')
}

foreach ($scenario in $scenarios.GetEnumerator()) {
    $name = $scenario.Key
    $requestRelative = $scenario.Value
    $requestPath = Join-Path $repoRoot $requestRelative
    if (-not (Test-Path -LiteralPath $requestPath)) {
        throw "Request file not found: $requestPath"
    }

    $timestamp = (Get-Date).ToString('yyyyMMddHHmmss')
    $logPath = Join-Path $logDir ("vi-history-sd-$name-run-$timestamp.log")

    Write-Host "[vi-history-suite-sd] Running scenario '$name' using $requestRelative in $repoRoot"
    Start-Transcript -Path $logPath -Force
    $forceDryRun = -not $AllowExecute

    try {
        pwsh -NoProfile -File (Join-Path $repoRoot 'scripts/vi-compare/RunViCompareReplay.ps1') -RequestPath $requestPath -ForceDryRun:$forceDryRun
        $exitCode = $LASTEXITCODE
        if ($exitCode -ne 0) {
            Write-Host "[vi-history-suite-sd] Script exited with code $exitCode"
        }
    }
    finally {
        Stop-Transcript | Out-Null
        Write-Host ("[vi-history-suite-sd] Transcript logged to {0}" -f $logPath)
    }
}
Write-Host "[vi-history-suite-sd] Completed all scenarios."
