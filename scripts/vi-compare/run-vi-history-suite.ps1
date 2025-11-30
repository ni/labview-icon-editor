param(
    [Parameter()]
    [switch]$IncludeSample
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = (Resolve-Path .).ProviderPath
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
    $logPath = Join-Path $logDir ("vi-history-$name-run-$timestamp.log")

    Write-Host "[vi-history-suite] Running scenario '$name' using $requestRelative"
    Start-Transcript -Path $logPath -Force
    try {
        pwsh -NoProfile -File scripts/vi-compare/RunViCompareReplay.ps1 -RequestPath $requestPath
        $exitCode = $LASTEXITCODE
        if ($exitCode -ne 0) {
            Write-Host "[vi-history-suite] Script exited with code $exitCode"
        }
    }
    finally {
        Stop-Transcript | Out-Null
        Write-Host ("[vi-history-suite] Transcript logged to {0}" -f $logPath)
    }
}
Write-Host "[vi-history-suite] Completed all scenarios."
