[CmdletBinding()]
param(
    [int]$StartYear = 2018,
    [int]$EndYear = 2030,
    [string]$RepositoryPath = "."
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$here = Split-Path -Parent $MyInvocation.MyCommand.Path
$helper = Join-Path $here 'add-token-to-labview/LocalhostLibraryPaths.ps1'
if (-not (Test-Path -LiteralPath $helper)) {
    throw "Missing helper: $helper"
}
. $helper
$cliResolver = Join-Path $here 'common/resolve-repo-cli.ps1'
if (-not (Test-Path -LiteralPath $cliResolver -PathType Leaf)) {
    throw "Missing CLI resolver: $cliResolver"
}

$repoPath = (Resolve-Path -LiteralPath $RepositoryPath).Path

if (-not (Test-Path Function:\Remove-LibraryPathsEntries)) {
    function Remove-LibraryPathsEntries {
        param(
            [string]$LvVersion,
            [string]$Arch
        )
        try {
            $lvIniPath = Resolve-LVIniPath -LvVersion $LvVersion -Arch $Arch
            $lines = Get-Content -LiteralPath $lvIniPath -ErrorAction Stop
            if ($lines -isnot [System.Array]) { $lines = @($lines) }
            $pattern = 'LocalHost\.LibraryPaths\d*\s*='
            $filtered = $lines | Where-Object { $_ -notmatch $pattern }
            if ($filtered.Count -eq $lines.Count) {
                Write-Information ("No LocalHost.LibraryPaths entries to remove for {0}-bit LabVIEW {1}." -f $Arch, $LvVersion) -InformationAction Continue
            }
            else {
                Set-Content -LiteralPath $lvIniPath -Value ($filtered -join "`r`n")
                Write-Information ("Removed LocalHost.LibraryPaths entries from {0} for {1}-bit LabVIEW {2}." -f $lvIniPath, $Arch, $LvVersion) -InformationAction Continue
            }
            return $true
        }
        catch {
            Write-Warning ("Failed to remove LocalHost.LibraryPaths entries for {0}-bit LabVIEW {1}: {2}" -f $Arch, $LvVersion, $_.Exception.Message)
            return $false
        }
    }
}

function Get-DetectedLabVIEWVersions {
    param(
        [int]$StartYear,
        [int]$EndYear
    )
    $versions = New-Object System.Collections.Generic.List[int]
    for ($y = $StartYear; $y -le $EndYear; $y++) {
        $pf64 = "C:\Program Files\National Instruments\LabVIEW $y"
        $pf32 = "C:\Program Files (x86)\National Instruments\LabVIEW $y"
        if (Test-Path -LiteralPath $pf64) { $versions.Add($y) }
        if (Test-Path -LiteralPath $pf32) { $versions.Add($y) }
    }
    return ($versions | Select-Object -Unique | Sort-Object)
}

$detected = Get-DetectedLabVIEWVersions -StartYear $StartYear -EndYear $EndYear
if (-not $detected) {
    Write-Warning "No LabVIEW installations detected between $StartYear and $EndYear."
    exit 0
}

Write-Host "Clearing LocalHost.LibraryPaths for detected LabVIEW versions (32/64):" -ForegroundColor Cyan
$results = New-Object System.Collections.Generic.List[object]
foreach ($ver in $detected) {
    foreach ($arch in @('32','64')) {
        $status = 'skipped'
        $message = ''
        Write-Host (" - {0} ({1}-bit)" -f $ver, $arch) -ForegroundColor Yellow
        $iniPath = $null
        try {
            $iniPath = Resolve-LVIniPath -LvVersion $ver -Arch $arch
        }
        catch {
            Write-Warning ("LabVIEW {0} ({1}-bit) not installed or LabVIEW.ini missing; skipping." -f $ver, $arch)
            $status = 'not-installed'
            $message = 'INI missing'
            continue
        }

        try {
            Remove-LibraryPathsEntries -LvVersion $ver -Arch $arch | Out-Null
            $status = 'cleared'
        }
        catch {
            Write-Warning ("Failed to clear {0}-bit LabVIEW {1}: {2}" -f $arch, $ver, $_.Exception.Message)
            $status = 'failed'
            $message = $_.Exception.Message
        }

        # Restore setup for this repo/version/bitness to remove dev-mode artifacts.
        $restoreOk = $false
        try {
            $prov = & $cliResolver -CliName 'OrchestrationCli' -RepoPath $repoPath -SourceRepoPath $repoPath -PrintProvenance:$false
            $cmd = $prov.Command + @(
                'restore-sources',
                '--repo', $repoPath,
                '--bitness', $arch,
                '--lv-version', $ver
            )
            Write-Information ("Restore via OrchestrationCli: {0}" -f ($cmd -join ' ')) -InformationAction Continue
            & $cmd[0] @($cmd[1..($cmd.Count-1)])
            if ($LASTEXITCODE -eq 0) { $restoreOk = $true }
        }
        catch {
            Write-Warning ("OrchestrationCli restore-sources failed for {0}-bit {1}: {2}" -f $arch, $ver, $_.Exception.Message)
        }
        if (-not $restoreOk -and $status -eq 'cleared') {
            $status = 'restore-failed'
            if (-not $message) { $message = 'restore-sources failed' }
        }

        $results.Add([pscustomobject]@{
            Version = $ver
            Bitness = $arch
            Status  = $status
            Message = $message
        })
    }
}

Write-Host "Done." -ForegroundColor Green

# Summary table
Write-Host ""
Write-Host "Summary:" -ForegroundColor Cyan
Write-Host ("{0,-8} {1,-6} {2,-14} {3}" -f 'Version','Arch','Status','Message') -ForegroundColor Gray
foreach ($r in $results | Sort-Object Version,Bitness) {
    Write-Host ("{0,-8} {1,-6} {2,-14} {3}" -f $r.Version, $r.Bitness, $r.Status, $r.Message)
}
