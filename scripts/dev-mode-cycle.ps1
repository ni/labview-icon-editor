param(
    [string]$RepositoryPath,
    [ValidateSet('32','64')]
    [string]$SupportedBitness = '64',
    [switch]$ShowIni,
    [switch]$VerifyPaths,
    [switch]$VerifyViLib
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

# Resolve repository root (default: git top-level)
if (-not $RepositoryPath) {
    $repo = (git -C $PSScriptRoot rev-parse --show-toplevel 2>$null)
    if (-not $repo) { $repo = (Get-Location).ProviderPath }
    $RepositoryPath = $repo
}
$RepositoryPath = (Resolve-Path -LiteralPath $RepositoryPath).Path

$setScript    = Join-Path $PSScriptRoot '..\.github\actions\set-development-mode\run-dev-mode.ps1'
$revertScript = Join-Path $PSScriptRoot '..\.github\actions\revert-development-mode\run-dev-mode.ps1'
$readScript   = Join-Path $PSScriptRoot 'read-library-paths.ps1'
$showIniScript= Join-Path $PSScriptRoot 'show-ini.ps1'
$verifyState  = Join-Path $PSScriptRoot 'verify-dev-mode-state.ps1'

function Invoke-Step {
    param(
        [string]$Name,
        [ScriptBlock]$Action
    )
    Write-Host "==> $Name"
    & $Action
}

try {
    Invoke-Step -Name "Set Dev Mode ($SupportedBitness-bit)" -Action {
        & $setScript -RepositoryPath $RepositoryPath -SupportedBitness $SupportedBitness
    }

    if ($VerifyPaths) {
        Invoke-Step -Name "Verify LocalHost.LibraryPaths" -Action {
            & $readScript -RepositoryPath $RepositoryPath -SupportedBitness $SupportedBitness -FailOnMissing
        }
    }

    if ($VerifyViLib) {
        Invoke-Step -Name "Verify Dev Mode state (vi.lib + INI)" -Action {
            & $verifyState -RepositoryPath $RepositoryPath -SupportedBitness $SupportedBitness -State 'dev'
        }
    }

    if ($ShowIni) {
        Invoke-Step -Name "Show LabVIEW.ini" -Action {
            & $showIniScript -RepositoryPath $RepositoryPath -SupportedBitness $SupportedBitness
        }
    }

    Invoke-Step -Name "Revert Dev Mode ($SupportedBitness-bit)" -Action {
        & $revertScript -RepositoryPath $RepositoryPath -SupportedBitness $SupportedBitness
    }

    if ($VerifyViLib) {
        Invoke-Step -Name "Verify Normal state (vi.lib + INI)" -Action {
            & $verifyState -RepositoryPath $RepositoryPath -SupportedBitness $SupportedBitness -State 'normal'
        }
    }
}
catch {
    Write-Error "dev-mode cycle failed: $($_.Exception.Message)"
    exit 1
}

Write-Host "Dev-mode cycle completed."
exit 0
