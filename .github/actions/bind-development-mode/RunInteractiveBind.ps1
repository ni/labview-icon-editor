[CmdletBinding()]
param(
    [string]$RepositoryPath = (Get-Location).Path
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$RepositoryPath = (Resolve-Path -LiteralPath $RepositoryPath).Path
$bindScript = Join-Path $PSScriptRoot 'BindDevelopmentMode.ps1'

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

Write-Host ("Running bind helper: mode={0} bitness={1} force={2} dry={3}" -f $mode, $bit, $forceFlag, $dryFlag)

$argsList = @(
    '-RepositoryPath', $RepositoryPath,
    '-Mode', $mode,
    '-Bitness', $bit
)
if ($forceFlag) { $argsList += '-Force' }
if ($dryFlag)   { $argsList += '-DryRun' }

& $bindScript @argsList
