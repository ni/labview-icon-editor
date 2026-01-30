<#
.SYNOPSIS
    Reverts the repository from development mode.

.DESCRIPTION
    Restores the packaged LabVIEW sources for both 32-bit and 64-bit
    environments using RestoreSetupLVSource.vi. LabVIEW is closed after
    each run so downstream steps load the changes.

.PARAMETER MinimumSupportedLVVersion
    LabVIEW 2021 (21.0) only.

.PARAMETER SupportedBitness
    One or more bitness values ("32", "64") to run (default: both).

.PARAMETER RepoRoot
    Optional path to the repository root.

.PARAMETER ConnectTimeoutMs
    g-cli connect timeout in milliseconds (0 disables the timeout).

.PARAMETER ProcessTimeoutMs
    Maximum time to wait for g-cli to finish in milliseconds (0 disables the timeout).

.EXAMPLE
    .\RevertDevelopmentMode.ps1 -MinimumSupportedLVVersion 2021
#>

param(
    [Parameter(Mandatory = $false)]
    [ValidateSet('2021')]
    [string]$MinimumSupportedLVVersion = '2021',

    [Parameter(Mandatory = $false)]
    [ValidateSet('32', '64', IgnoreCase = $true)]
    [string[]]$SupportedBitness = @('32', '64'),

    [Parameter(Mandatory = $false)]
    [string]$RepoRoot,

    [Parameter(Mandatory = $false)]
    [ValidateRange(0, 600000)]
    [int]$ConnectTimeoutMs = 120000,

    [Parameter(Mandatory = $false)]
    [ValidateRange(0, 1200000)]
    [int]$ProcessTimeoutMs = 300000
)

# Determine the directory where this script is located
$ScriptDirectory = Split-Path -Parent -Path $MyInvocation.MyCommand.Definition
Write-Host "Script Directory: $ScriptDirectory"

$RestoreScript = Join-Path -Path $ScriptDirectory -ChildPath '..\restore-setup-lv-source\RestoreSetupLVSource.ps1'
$CloseScript = Join-Path -Path $ScriptDirectory -ChildPath '..\close-labview\Close_LabVIEW.ps1'
Write-Host "RestoreSetupLVSource script: $RestoreScript"
Write-Host "Close_LabVIEW script: $CloseScript"

$ErrorActionPreference = 'Stop'

function Invoke-RestoreLabviewSource {
    param(
        [string]$Bitness
    )

    if (-not (Test-Path -Path $CloseScript)) {
        throw "Close_LabVIEW.ps1 not found at $CloseScript"
    }

    & $CloseScript -MinimumSupportedLVVersion $MinimumSupportedLVVersion -SupportedBitness $Bitness
    if ($LASTEXITCODE -ne 0 -and $LASTEXITCODE -ne $null) {
        throw "Close_LabVIEW.ps1 failed for $Bitness-bit with exit code $LASTEXITCODE."
    }

    Write-Host "Restoring LabVIEW sources for $Bitness-bit."
    $scriptArgs = @{
        MinimumSupportedLVVersion = $MinimumSupportedLVVersion
        SupportedBitness          = $Bitness
        ConnectTimeoutMs          = $ConnectTimeoutMs
        ProcessTimeoutMs          = $ProcessTimeoutMs
    }

    if ($RepoRoot) {
        $scriptArgs.RepoRoot = $RepoRoot
    }

    & $RestoreScript @scriptArgs

    if ($LASTEXITCODE -ne 0 -and $LASTEXITCODE -ne $null) {
        throw "RestoreSetupLVSource.ps1 failed for $Bitness-bit with exit code $LASTEXITCODE."
    }
}

try {
    $bitnesses = $SupportedBitness | Select-Object -Unique
    foreach ($bitness in $bitnesses) {
        Invoke-RestoreLabviewSource -Bitness $bitness
    }
} catch {
    Write-Error "An unexpected error occurred during script execution: $($_.Exception.Message)"
    exit 1
}

