[CmdletBinding()]
param(
    [string]$RepositoryPath = (Get-Location).Path
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$RepositoryPath = (Resolve-Path -LiteralPath $RepositoryPath).Path
$bindScript = Join-Path $PSScriptRoot 'BindDevelopmentMode.ps1'
$defaultJson = Join-Path $RepositoryPath 'reports/dev-mode-bind.json'

$defaultMode = 'bind'
$defaultBitness = 'both'

$mode = Read-Host ("Mode (bind/unbind/status) [{0}]" -f $defaultMode)
if ([string]::IsNullOrWhiteSpace($mode)) { $mode = $defaultMode }

$bit = Read-Host ("Bitness (32/64/both) [{0}]" -f $defaultBitness)
if ([string]::IsNullOrWhiteSpace($bit)) { $bit = $defaultBitness }

$forceResp = Read-Host 'Force? (y/N)'
$forceFlag = $forceResp -match '^(?i:y|yes)$'

$dryResp = Read-Host 'Dry run? (y/N)'
$dryFlag = $dryResp -match '^(?i:y|yes)$'

$forceRecommended = $false
if (Test-Path -LiteralPath $defaultJson) {
    try {
        $last = Get-Content -LiteralPath $defaultJson -Raw | ConvertFrom-Json
        foreach ($entry in @($last)) {
            if ($entry.status -eq 'fail' -and $entry.message -match 'use -Force') {
                $forceRecommended = $true
                break
            }
        }
    }
    catch {
        Write-Verbose ("Unable to read previous bind summary at {0}: {1}" -f $defaultJson, $_.Exception.Message)
    }
}

if ($forceRecommended -and -not $forceFlag) {
    $confirm = Read-Host "Last run recommended Force to overwrite/clear tokens. Proceed without Force? (y/N)"
    if (-not ($confirm -match '^(?i:y|yes)$')) {
        Write-Host "Aborted by user; rerun and enable Force to follow the hint."
        exit 1
    }
}

Write-Host ("Running bind helper: mode={0} bitness={1} force={2} dry={3}" -f $mode, $bit, $forceFlag, $dryFlag)

$argsList = @(
    '-RepositoryPath', $RepositoryPath,
    '-Mode', $mode,
    '-Bitness', $bit
)
if ($forceFlag) { $argsList += '-Force' }
if ($dryFlag)   { $argsList += '-DryRun' }

& $bindScript @argsList
