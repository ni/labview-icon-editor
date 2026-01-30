<#
.SYNOPSIS
    Forces dev mode to disabled state locally for the specified bitness.

.DESCRIPTION
    Invokes RevertDevelopmentMode.ps1 to restore packaged sources. Intended
    to leave the system in a disabled state after iteration runs.

.PARAMETER MinimumSupportedLVVersion
    LabVIEW 2021 (21.0) only.

.PARAMETER SupportedBitness
    LabVIEW bitness to target ("32" or "64"). Defaults to "64".

.PARAMETER LogPath
    Optional log file path. If omitted, a log file is created under Tooling\logs.

.PARAMETER RepoRoot
    Optional path to the repository root. If omitted, resolved relative to
    this script's location.
#>

param(
    [Parameter(Mandatory = $false)]
    [ValidateSet('2021')]
    [string]$MinimumSupportedLVVersion = '2021',

    [Parameter(Mandatory = $false)]
    [ValidateSet('32', '64', IgnoreCase = $true)]
    [string]$SupportedBitness = '64',

    [Parameter(Mandatory = $false)]
    [string]$LogPath,

    [Parameter(Mandatory = $false)]
    [string]$RepoRoot
)

$ErrorActionPreference = 'Stop'

function Resolve-RepoRoot {
    param(
        [string]$PathOverride
    )

    if ($PathOverride) {
        if (-not (Test-Path -Path $PathOverride)) {
            throw "RepoRoot does not exist: $PathOverride"
        }
        return (Resolve-Path -Path $PathOverride).Path
    }

    return (Resolve-Path -Path (Join-Path $PSScriptRoot '..')).Path
}

function Write-Log {
    param(
        [string]$Message
    )

    $timestamp = Get-Date -Format o
    $line = "$timestamp $Message"
    $line | Out-File -FilePath $logPathResolved -Append -Encoding ascii
    Write-Host $line
}

$repoRoot = Resolve-RepoRoot -PathOverride $RepoRoot
$logPathResolved = $LogPath
if ([string]::IsNullOrWhiteSpace($logPathResolved)) {
    $logDir = Join-Path -Path $repoRoot -ChildPath 'Tooling\logs'
    $null = New-Item -Path $logDir -ItemType Directory -Force
    $logPathResolved = Join-Path -Path $logDir -ChildPath ("dev-mode-final-disable-{0}.log" -f (Get-Date -Format 'yyyyMMdd-HHmmss'))
} else {
    $logDir = Split-Path -Parent -Path $logPathResolved
    if (-not [string]::IsNullOrWhiteSpace($logDir)) {
        $null = New-Item -Path $logDir -ItemType Directory -Force
    }
}

$revertScript = Join-Path -Path $repoRoot -ChildPath '.github\actions\revert-development-mode\RevertDevelopmentMode.ps1'
if (-not (Test-Path -Path $revertScript)) {
    throw "RevertDevelopmentMode.ps1 not found at $revertScript"
}

$scriptArgs = @{
    MinimumSupportedLVVersion = $MinimumSupportedLVVersion
    SupportedBitness          = $SupportedBitness
    RepoRoot              = $repoRoot
}

Write-Log ("start version={0} bitness={1} log={2}" -f $MinimumSupportedLVVersion, $SupportedBitness, $logPathResolved)

try {
    & $revertScript @scriptArgs
    if ($LASTEXITCODE -ne 0 -and $LASTEXITCODE -ne $null) {
        throw "Dev mode disable failed with exit code $LASTEXITCODE."
    }
    $exitCodeValue = if ($LASTEXITCODE -eq $null) { 'null' } else { [string]$LASTEXITCODE }
    Write-Log ("finish exit_code={0}" -f $exitCodeValue)
} catch {
    Write-Log ("error message={0}" -f $($_.Exception.Message))
    throw
}
