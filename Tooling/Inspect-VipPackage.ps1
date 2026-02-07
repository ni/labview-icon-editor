#Requires -Version 7.0
<#
.SYNOPSIS
  Inspects a VI Package (.vip) as a zip file and reports internal path usage.

.DESCRIPTION
  A .vip file is a zip container. This script opens it and reports:
    - The longest internal entry paths (zip entry names)
    - Any entries that look like they contain absolute paths
    - Any entries that contain runner/workspace path fragments (heuristic)

  This is useful to diagnose accidental "preserve full path" packaging that can
  cause Windows path-length failures or slow down VIPM builds.

.PARAMETER VipPath
  Path to the .vip file to inspect.

.PARAMETER TopLongest
  Number of longest entries to print.

.PARAMETER WarnPathLength
  Emits a warning if any internal entry path length is >= this value.

.PARAMETER FailPathLength
  If set to a value > 0, fails if any internal entry path length is >= this value.

.PARAMETER FailOnAbsolutePaths
  If set, fails when any entry name looks like an absolute path (drive/UNC/leading slash).

.PARAMETER WriteSummary
  If running in GitHub Actions, writes a summary to $GITHUB_STEP_SUMMARY.
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$VipPath,

    [Parameter(Mandatory = $false)]
    [ValidateRange(1, 200)]
    [int]$TopLongest = 25,

    [Parameter(Mandatory = $false)]
    [ValidateRange(1, 4096)]
    [int]$WarnPathLength = 200,

    [Parameter(Mandatory = $false)]
    [ValidateRange(0, 4096)]
    [int]$FailPathLength = 0,

    [Parameter(Mandatory = $false)]
    [switch]$FailOnAbsolutePaths,

    [Parameter(Mandatory = $false)]
    [switch]$WriteSummary
)

$ErrorActionPreference = 'Stop'

function Write-SummaryLine {
    param(
        [string]$Line,
        [bool]$SummaryEnabled
    )

    if (-not $SummaryEnabled) { return }
    if ([string]::IsNullOrWhiteSpace($env:GITHUB_STEP_SUMMARY)) { return }

    $Line | Out-File -FilePath $env:GITHUB_STEP_SUMMARY -Append -Encoding utf8
}

$summaryEnabled = $WriteSummary.IsPresent

$VipPath = [System.IO.Path]::GetFullPath($VipPath)
if (-not (Test-Path -LiteralPath $VipPath -PathType Leaf)) {
    throw "VI Package not found: $VipPath"
}

try {
    Add-Type -AssemblyName System.IO.Compression.FileSystem -ErrorAction Stop
}
catch {
    # PowerShell 7 usually already has it, but keep a clear error if missing.
    throw "Failed to load System.IO.Compression.FileSystem. $_"
}

Write-Host ("Inspecting VI Package (as zip): {0}" -f $VipPath)
Write-SummaryLine -Line "## VI Package Inspection" -SummaryEnabled $summaryEnabled
Write-SummaryLine -Line "" -SummaryEnabled $summaryEnabled
Write-SummaryLine -Line ('- VIP: `{0}`' -f $VipPath) -SummaryEnabled $summaryEnabled

$archive = $null
try {
    $archive = [System.IO.Compression.ZipFile]::OpenRead($VipPath)

    $entryInfos =
        $archive.Entries |
        Where-Object { -not [string]::IsNullOrWhiteSpace($_.FullName) } |
        Where-Object { -not $_.FullName.EndsWith('/') } |
        ForEach-Object {
            [pscustomobject]@{
                Name           = $_.FullName
                NameLength     = $_.FullName.Length
                UncompressedB  = $_.Length
                CompressedB    = $_.CompressedLength
            }
        }

    $entryCount = @($entryInfos).Count
    $maxLen = ($entryInfos | Measure-Object -Property NameLength -Maximum).Maximum
    $avgLen = [Math]::Round(($entryInfos | Measure-Object -Property NameLength -Average).Average, 2)

    Write-Host ("Entries: {0}" -f $entryCount)
    Write-Host ("Max internal path length: {0}" -f $maxLen)
    Write-Host ("Avg internal path length: {0}" -f $avgLen)

    Write-SummaryLine -Line ("- Entries: **{0}**" -f $entryCount) -SummaryEnabled $summaryEnabled
    Write-SummaryLine -Line ("- Max internal path length: **{0}**" -f $maxLen) -SummaryEnabled $summaryEnabled
    Write-SummaryLine -Line ("- Avg internal path length: **{0}**" -f $avgLen) -SummaryEnabled $summaryEnabled

    if ($maxLen -ge $WarnPathLength) {
        Write-Warning ("Max internal entry path length ({0}) is >= warn threshold ({1})." -f $maxLen, $WarnPathLength)
        Write-SummaryLine -Line ("- :warning: Max internal entry path length ({0}) is >= warn threshold ({1})." -f $maxLen, $WarnPathLength) -SummaryEnabled $summaryEnabled
    }

    if ($FailPathLength -gt 0 -and $maxLen -ge $FailPathLength) {
        Write-Error ("Max internal entry path length ({0}) is >= fail threshold ({1})." -f $maxLen, $FailPathLength)
        exit 1
    }

    $sorted = $entryInfos | Sort-Object NameLength -Descending
    $top = $sorted | Select-Object -First $TopLongest

    Write-Host ""
    Write-Host ("Top {0} longest internal paths:" -f $TopLongest)
    foreach ($row in $top) {
        Write-Host ("{0,4}  {1}" -f $row.NameLength, $row.Name)
    }

    Write-SummaryLine -Line "" -SummaryEnabled $summaryEnabled
    Write-SummaryLine -Line ("### Top {0} Longest Internal Paths" -f $TopLongest) -SummaryEnabled $summaryEnabled
    Write-SummaryLine -Line "" -SummaryEnabled $summaryEnabled
    Write-SummaryLine -Line "|Len|Entry|" -SummaryEnabled $summaryEnabled
    Write-SummaryLine -Line "|---:|---|" -SummaryEnabled $summaryEnabled
    foreach ($row in $top) {
        $escaped = ($row.Name -replace '\|', '\|')
        Write-SummaryLine -Line ('|{0}|`{1}`|' -f $row.NameLength, $escaped) -SummaryEnabled $summaryEnabled
    }

    # Detect obvious build/test artifacts inside the VIP (these should not ship).
    $artifactFragments = @(
        '/testresults/',
        '/builds/'
    )

    $artifactEntries = @()
    foreach ($e in $entryInfos) {
        $normLower = ($e.Name -replace '\\', '/').ToLowerInvariant()
        foreach ($frag in $artifactFragments) {
            if ($normLower.Contains($frag)) {
                $artifactEntries += $e
                break
            }
        }
    }

    if ($artifactEntries.Count -gt 0) {
        Write-Warning ("VIP contains {0} entries that look like build/test artifacts (e.g. TestResults/builds)." -f $artifactEntries.Count)

        $sample = $artifactEntries | Sort-Object NameLength -Descending | Select-Object -First 25
        foreach ($row in $sample) {
            Write-Host ("ARTIFACT  {0,4}  {1}" -f $row.NameLength, $row.Name)
        }

        Write-SummaryLine -Line "" -SummaryEnabled $summaryEnabled
        Write-SummaryLine -Line "### Build/Test Artifacts Detected" -SummaryEnabled $summaryEnabled
        Write-SummaryLine -Line "" -SummaryEnabled $summaryEnabled
        Write-SummaryLine -Line (":warning: VIP contains **{0}** entries that look like build/test artifacts (e.g. `TestResults`, `builds`)." -f $artifactEntries.Count) -SummaryEnabled $summaryEnabled
        Write-SummaryLine -Line "" -SummaryEnabled $summaryEnabled
        Write-SummaryLine -Line "|Len|Entry|" -SummaryEnabled $summaryEnabled
        Write-SummaryLine -Line "|---:|---|" -SummaryEnabled $summaryEnabled
        foreach ($row in $sample) {
            $escaped = ($row.Name -replace '\|', '\|')
            Write-SummaryLine -Line ('|{0}|`{1}`|' -f $row.NameLength, $escaped) -SummaryEnabled $summaryEnabled
        }
    }

    # Heuristic checks for accidental absolute paths embedded into zip entry names.
    # Zip entries typically use forward slashes, but some creators can emit backslashes.
    $driveRegex = '(?i)(^|[\\/])[a-z]:[\\/]'
    $uncRegex = '^(?:\\\\\\\\|//)[^\\/]+[\\/]'
    $leadingSlash = '^/'

    $runnerFragments = @(
        'actions-runner/_work',
        'actions-runner\\_work',
        'github/workspace',
        'github\\workspace'
    )

    # Use an explicit loop to avoid any ambiguity with nested pipeline scoping.
    $suspicious = @()
    foreach ($e in $entryInfos) {
        $n = $e.Name
        $nLower = $n.ToLowerInvariant()

        $hit = $false
        if ($n -match $driveRegex) { $hit = $true }
        elseif ($n -match $uncRegex) { $hit = $true }
        elseif ($n -match $leadingSlash) { $hit = $true }
        else {
            foreach ($frag in $runnerFragments) {
                if ([string]::IsNullOrWhiteSpace($frag)) { continue }
                if ($nLower.Contains($frag.ToLowerInvariant())) { $hit = $true; break }
            }
        }

        if ($hit) { $suspicious += $e }
    }

    if ($suspicious.Count -gt 0) {
        Write-Warning ("Found {0} suspicious zip entries that look like absolute/runner paths." -f $suspicious.Count)
        Write-SummaryLine -Line "" -SummaryEnabled $summaryEnabled
        Write-SummaryLine -Line ("### Suspicious Paths") -SummaryEnabled $summaryEnabled
        Write-SummaryLine -Line "" -SummaryEnabled $summaryEnabled
        Write-SummaryLine -Line (":warning: Found **{0}** suspicious zip entries that look like absolute/runner paths." -f $suspicious.Count) -SummaryEnabled $summaryEnabled
        Write-SummaryLine -Line "" -SummaryEnabled $summaryEnabled

        $sample = $suspicious | Sort-Object NameLength -Descending | Select-Object -First 25
        foreach ($row in $sample) {
            Write-Host ("SUSPICIOUS {0,4}  {1}" -f $row.NameLength, $row.Name)
        }

        Write-SummaryLine -Line "|Len|Entry|" -SummaryEnabled $summaryEnabled
        Write-SummaryLine -Line "|---:|---|" -SummaryEnabled $summaryEnabled
        foreach ($row in $sample) {
            $escaped = ($row.Name -replace '\|', '\|')
            Write-SummaryLine -Line ('|{0}|`{1}`|' -f $row.NameLength, $escaped) -SummaryEnabled $summaryEnabled
        }

        if ($FailOnAbsolutePaths) {
            Write-Error "FailOnAbsolutePaths is set and suspicious entries were found."
            exit 1
        }
    } else {
        Write-Host "No suspicious absolute/runner path fragments detected in zip entry names."
        Write-SummaryLine -Line "" -SummaryEnabled $summaryEnabled
        Write-SummaryLine -Line "### Suspicious Paths" -SummaryEnabled $summaryEnabled
        Write-SummaryLine -Line "" -SummaryEnabled $summaryEnabled
        Write-SummaryLine -Line "No suspicious absolute/runner path fragments detected in zip entry names." -SummaryEnabled $summaryEnabled
    }
}
catch {
    throw "Failed to inspect VIP as a zip. If needed, copy and rename the .vip to .zip and inspect manually. Error: $_"
}
finally {
    if ($null -ne $archive) { $archive.Dispose() }
}
