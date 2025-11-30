#Requires -Version 7.0
[CmdletBinding()]
param(
    [string]$RepoRoot,
    [string]$IconEditorRoot,
    [int[]]$Versions,
    [int[]]$Bitness,
    [string]$LabVIEWProject = 'lv_icon_editor',
    [string]$BuildSpec = 'Editor Packed Library',
    [switch]$SkipClose
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

if (-not $RepoRoot) {
    $RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..' '..')).Path
} else {
    $RepoRoot = (Resolve-Path -LiteralPath $RepoRoot).Path
}

if (-not $IconEditorRoot) {
    $IconEditorRoot = Join-Path $RepoRoot 'vendor' 'icon-editor'
} else {
    $IconEditorRoot = (Resolve-Path -LiteralPath $IconEditorRoot).Path
}

$restoreScript = Join-Path $IconEditorRoot '.github' 'actions' 'restore-setup-lv-source' 'RestoreSetupLVSource.ps1'
$closeScript   = Join-Path $IconEditorRoot '.github' 'actions' 'close-labview' 'Close_LabVIEW.ps1'

foreach ($required in @($restoreScript, $closeScript)) {
    if (-not (Test-Path -LiteralPath $required -PathType Leaf)) {
        throw "Required icon editor helper script '$required' was not found."
    }
}

if (-not $Versions -or $Versions.Count -eq 0) {
    $Versions = @(2023)
}

if (-not $Bitness -or $Bitness.Count -eq 0) {
    $Bitness = @(32)
}
$versionSource = @($Versions)
$bitnessSource = @($Bitness)

Write-Verbose ("[Reset] Versions requested: {0}" -f ([string]::Join(',', $versionSource)))
Write-Verbose ("[Reset] Bitness requested : {0}" -f ([string]::Join(',', $bitnessSource)))

$versionList = @()
foreach ($version in $versionSource) {
    if ($version -is [System.Array]) {
        foreach ($subVersion in $version) {
            try { $versionList += [int]$subVersion } catch {}
        }
        continue
    }
    try {
        $versionList += [int]$version
    } catch {
        # skip invalid entries
    }
}

$bitnessList = @()
function Add-BitnessValue {
    param([Parameter(Mandatory=$true)]$Candidate)

    if ($Candidate -is [System.Array]) {
        foreach ($subCandidate in $Candidate) {
            Add-BitnessValue -Candidate $subCandidate
        }
        return
    }

    try {
        $bitnessValue = [int]$Candidate
        if ($bitnessValue -in @(32,64)) {
            $script:bitnessList += $bitnessValue
        } else {
            Write-Verbose ("[Reset] Ignoring unsupported bitness value '{0}'." -f $bitnessValue)
        }
    } catch {
        Write-Verbose ("[Reset] Failed to parse bitness entry '{0}': {1}" -f $Candidate, $_.Exception.Message)
    }
}

foreach ($bitness in $bitnessSource) {
    Add-BitnessValue -Candidate $bitness
}
if ($versionList.Count -eq 0) {
    throw "No valid LabVIEW versions were supplied to Reset-IconEditorWorkspace."
}
if ($bitnessList.Count -eq 0) {
    throw "No valid bitness values were supplied to Reset-IconEditorWorkspace."
}

foreach ($versionValue in ($versionList | Sort-Object -Unique)) {
    foreach ($bitnessValue in ($bitnessList | Sort-Object -Unique)) {
        $versionText = [string]$versionValue
        $bitnessText = [string]$bitnessValue
        Write-Host ("[Reset] Restoring LabVIEW {0} ({1}-bit) workspace..." -f $versionText, $bitnessText)
        try {
            & $restoreScript `
                -MinimumSupportedLVVersion $versionText `
                -SupportedBitness $bitnessText `
                -RelativePath $IconEditorRoot `
                -LabVIEW_Project $LabVIEWProject `
                -Build_Spec $BuildSpec
        } catch {
            throw "RestoreSetupLVSource failed for LabVIEW $versionText ($bitnessText-bit): $($_.Exception.Message)"
        }

        if (-not $SkipClose) {
            Write-Host ("[Reset] Closing LabVIEW {0} ({1}-bit)..." -f $versionText, $bitnessText)
            try {
                & $closeScript `
                    -MinimumSupportedLVVersion $versionText `
                    -SupportedBitness $bitnessText
            } catch {
                throw "Close-LabVIEW helper failed for LabVIEW $versionText ($bitnessText-bit): $($_.Exception.Message)"
            }
        }
    }
}

function Test-ValidLabel {
  param([Parameter(Mandatory)][string]$Label)
  if ($Label -notmatch '^[A-Za-z0-9._-]{1,64}$') { throw "Invalid label: $Label" }
}

function Invoke-WithTimeout {
  [CmdletBinding()]
  param(
    [Parameter(Mandatory)][scriptblock]$ScriptBlock,
    [Parameter()][int]$TimeoutSec = 600
  )
  $job = Start-Job -ScriptBlock $ScriptBlock
  if (-not (Wait-Job $job -Timeout $TimeoutSec)) {
    try { Stop-Job $job -Force } catch {}
    throw "Operation timed out in $TimeoutSec s"
  }
  Receive-Job $job -ErrorAction Stop
}