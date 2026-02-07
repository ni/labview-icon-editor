#Requires -Version 7.0
[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [ValidateSet('enable', 'disable')]
    [string]$Mode,

    [Parameter(Mandatory)]
    [string]$CsvPath,

    [Parameter(Mandatory)]
    [ValidateSet('32', '64')]
    [string]$Bitness,

    [AllowNull()]
    [AllowEmptyString()]
    [string]$LabVIEWVersion = '',

    [Parameter(Mandatory)]
    [string]$RepoRoot,

    [string]$WorktreeRoot,

    [switch]$SkipWorktreeRootCheck
)

$ErrorActionPreference = 'Stop'

$headers = @('File Path', 'Bytes', 'Last modified')

function Resolve-RepoRoot {
    param(
        [string]$PathOverride
    )

    if ([string]::IsNullOrWhiteSpace($PathOverride)) {
        throw "RepoRoot is required."
    }

    if (-not (Test-Path -Path $PathOverride)) {
        throw "RepoRoot does not exist: $PathOverride"
    }

    return (Resolve-Path -Path $PathOverride).Path
}

function Import-IconEditorCsv {
    param(
        [string]$Path
    )

    $firstLine = Get-Content -Path $Path -TotalCount 1
    $headerLine = ($headers -join ',')
    $headerQuoted = '"' + ($headers -join '","') + '"'
    $hasHeader = ($firstLine -eq $headerLine) -or ($firstLine -eq $headerQuoted)

    if ($hasHeader) {
        return (Import-Csv -Path $Path)
    }

    return (Import-Csv -Path $Path -Header $headers)
}

function Normalize-Path {
    param(
        [string]$Path
    )

    try {
        return [System.IO.Path]::GetFullPath($Path)
    }
    catch {
        return $null
    }
}

function Test-PathUnderRoot {
    param(
        [string]$Path,
        [string]$Root
    )

    if ([string]::IsNullOrWhiteSpace($Path)) {
        return $false
    }

    $fullPath = Normalize-Path -Path $Path
    if (-not $fullPath) {
        return $false
    }

    return $fullPath.StartsWith($Root, [System.StringComparison]::OrdinalIgnoreCase)
}

function Get-LabVIEWInstallRoot {
    param(
        [string]$Version,
        [string]$Bitness
    )

    $candidates = @()
    $regPaths = @()
    if ($Bitness -eq '32') {
        $candidates += "C:\Program Files (x86)\National Instruments\LabVIEW $Version"
        $regPaths += "HKLM:\SOFTWARE\WOW6432Node\National Instruments\LabVIEW $Version"
    } else {
        $candidates += "C:\Program Files\National Instruments\LabVIEW $Version"
        $regPaths += "HKLM:\SOFTWARE\National Instruments\LabVIEW $Version"
    }

    foreach ($candidate in $candidates) {
        if (Test-Path -Path $candidate) {
            return $candidate
        }
    }

    foreach ($regPath in $regPaths) {
        try {
            $props = Get-ItemProperty -Path $regPath -ErrorAction Stop
            foreach ($name in @('Path', 'InstallDir', 'InstallPath')) {
                $value = $props.$name
                if (-not [string]::IsNullOrWhiteSpace($value) -and (Test-Path -Path $value)) {
                    return $value
                }
            }
        } catch {
            continue
        }
    }

    return $null
}

function Get-IniLibraryPaths {
    param(
        [string]$IniPath
    )

    if (-not (Test-Path -Path $IniPath)) {
        return @()
    }

    $line = Get-Content -Path $IniPath | Where-Object { $_ -match '(?i)^\s*localhost\.librarypaths\s*=' } | Select-Object -First 1
    if (-not $line) {
        return @()
    }

    $value = $line -replace '(?i)^\s*localhost\.librarypaths\s*=\s*', ''
    if ([string]::IsNullOrWhiteSpace($value)) {
        return @()
    }

    return ($value -split ';' | ForEach-Object { $_.Trim().Trim('"') } | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })
}

function Test-LibraryPathContainsRepoRoot {
    param(
        [string]$IniPath,
        [string]$RepoRoot
    )

    $repoRootNormalized = $null
    try {
        $repoRootNormalized = [System.IO.Path]::GetFullPath($RepoRoot).TrimEnd([System.IO.Path]::DirectorySeparatorChar)
    }
    catch {
        $repoRootNormalized = $RepoRoot.TrimEnd([System.IO.Path]::DirectorySeparatorChar)
    }

    foreach ($path in (Get-IniLibraryPaths -IniPath $IniPath)) {
        $candidate = $null
        try {
            $candidate = [System.IO.Path]::GetFullPath($path).TrimEnd([System.IO.Path]::DirectorySeparatorChar)
        }
        catch {
            $candidate = $path.TrimEnd([System.IO.Path]::DirectorySeparatorChar)
        }

        if ($candidate.Equals($repoRootNormalized, [System.StringComparison]::OrdinalIgnoreCase)) {
            return $true
        }
    }

    return $false
}

if (-not (Test-Path -Path $CsvPath)) {
    throw "Diagnostics CSV not found: $CsvPath"
}

$repoRootResolved = Resolve-RepoRoot -PathOverride $RepoRoot
$preflightScript = Join-Path $repoRootResolved 'Tooling\Invoke-Preflight.ps1'
if (Test-Path -Path $preflightScript) {
    . $preflightScript
    $scriptArgs = Convert-BoundParametersToArgumentList -BoundParameters $PSBoundParameters
    $relativeScript = if ($PSCommandPath) { Get-RepoRelativePath -RepoRoot $repoRootResolved -Path $PSCommandPath } else { $null }
    $preflight = Invoke-Preflight `
        -RepoRoot $repoRootResolved `
        -WorktreeRoot $WorktreeRoot `
        -LabVIEWVersion $LabVIEWVersion `
        -LabVIEWBitness $Bitness `
        -SkipWorktreeRootCheck:$SkipWorktreeRootCheck `
        -AutoWorktree:$false `
        -ScriptPath $relativeScript `
        -ScriptArguments $scriptArgs
    if ($preflight.Reinvoked) {
        return
    }
    $repoRootResolved = $preflight.RepoRoot
}
$repoRootNormalized = Normalize-Path -Path $repoRootResolved
if (-not $repoRootNormalized) {
    throw "Unable to normalize RepoRoot: $repoRootResolved"
}

$versionHelper = Join-Path $repoRootResolved 'Tooling\support\LabVIEWVersion.ps1'
$labviewYear = $LabVIEWVersion
if (Test-Path -Path $versionHelper) {
    . $versionHelper
    $versionInfo = Get-LabVIEWVersionInfo -VersionInput $LabVIEWVersion -RepoRoot $repoRootResolved
    $labviewYear = $versionInfo.Year
}
if ([string]::IsNullOrWhiteSpace($labviewYear)) {
    throw "LabVIEW version could not be resolved. Check .lvversion."
}

$separator = [System.IO.Path]::DirectorySeparatorChar
if (-not $repoRootNormalized.EndsWith($separator)) {
    $repoRootNormalized += $separator
}

$rows = Import-IconEditorCsv -Path $CsvPath
if (-not $rows -or $rows.Count -eq 0) {
    throw "Diagnostics CSV is empty or could not be parsed: $CsvPath"
}

$repoRows = $rows | Where-Object { Test-PathUnderRoot -Path $_.'File Path' -Root $repoRootNormalized }
$iconApiRows = $rows | Where-Object { $_.'File Path' -like "*\vi.lib\LabVIEW Icon API\*" }

$installRoot = Get-LabVIEWInstallRoot -Version $labviewYear -Bitness $Bitness
if (-not $installRoot) {
    throw "LabVIEW $labviewYear ($Bitness-bit) install not found."
}

$iconApiDir = Join-Path $installRoot 'vi.lib\LabVIEW Icon API'
$iconApiZip = Join-Path $installRoot 'vi.lib\LabVIEW Icon API.zip'
$lvlibpPath = Join-Path $installRoot 'resource\plugins\lv_icon.lvlibp'
$shipPath = Join-Path $installRoot 'resource\plugins\lv_icon.ship'
$iniPath = Join-Path $installRoot 'LabVIEW.ini'

$iconApiDirExists = Test-Path -Path $iconApiDir
$iconApiZipExists = Test-Path -Path $iconApiZip
$lvlibpExists = Test-Path -Path $lvlibpPath
$shipExists = Test-Path -Path $shipPath
$iniHasRepoRoot = Test-LibraryPathContainsRepoRoot -IniPath $iniPath -RepoRoot $repoRootResolved

Write-Host "Mode: $Mode"
Write-Host "Bitness: $Bitness"
Write-Host "LabVIEW version: $labviewYear"
Write-Host "Repo root: $repoRootResolved"
Write-Host "LabVIEW install root: $installRoot"
Write-Host ("Total rows: {0}" -f $rows.Count)
Write-Host ("Rows under repo root: {0}" -f $repoRows.Count)
Write-Host ("CSV vi.lib rows: {0}" -f $iconApiRows.Count)
Write-Host ("INI token includes repo root: {0}" -f $iniHasRepoRoot)
Write-Host ("lv_icon.lvlibp exists: {0}" -f $lvlibpExists)
Write-Host ("lv_icon.ship exists: {0}" -f $shipExists)
Write-Host ("Icon API folder exists: {0}" -f $iconApiDirExists)
Write-Host ("Icon API zip exists: {0}" -f $iconApiZipExists)

if ($Mode -eq 'enable') {
    $issues = @()
    if (-not $iniHasRepoRoot) {
        $issues += "Localhost.LibraryPaths does not include repo root."
    }
    if (-not $shipExists) {
        $issues += "lv_icon.ship not found."
    }
    if ($lvlibpExists) {
        $issues += "lv_icon.lvlibp still present."
    }
    if ($iconApiDirExists) {
        $issues += "vi.lib\\LabVIEW Icon API folder still present."
    }
    if (-not $iconApiZipExists) {
        $issues += "vi.lib\\LabVIEW Icon API.zip not found."
    }

    if ($issues.Count -gt 0) {
        throw ("Dev mode validation failed: {0}" -f ($issues -join ' '))
    }
}
else {
    $issues = @()
    if ($iniHasRepoRoot) {
        $issues += "Localhost.LibraryPaths still includes repo root."
    }
    if (-not $lvlibpExists) {
        $issues += "lv_icon.lvlibp not found."
    }
    if ($shipExists) {
        $issues += "lv_icon.ship still present."
    }
    if (-not $iconApiDirExists) {
        $issues += "vi.lib\\LabVIEW Icon API folder not found."
    }
    if ($iconApiZipExists) {
        $issues += "vi.lib\\LabVIEW Icon API.zip still present."
    }

    if ($issues.Count -gt 0) {
        throw ("Dev mode validation failed: {0}" -f ($issues -join ' '))
    }
}

Write-Host "Dev mode validation passed."

