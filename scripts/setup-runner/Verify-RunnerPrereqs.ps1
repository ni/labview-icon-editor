<#
.SYNOPSIS
Verifies baseline prerequisites on the Windows self-hosted runner before using it for CI.
Checks .NET 8 SDK, LabVIEW 2021 x64/x86 installations, Pester, VIPM (optional), and git.
#>
[CmdletBinding()]
param (
    [switch]$SkipLabVIEWX86,
    [switch]$SkipVIPM
)

$errors = @()

function Add-Error([string]$msg) {
    Write-Host "[MISSING] $msg" -ForegroundColor Red
    $script:errors += $msg
}

function Check-DotNet {
    Write-Host "Checking .NET SDK (8.0.x)..."
    $sdks = & dotnet --list-sdks 2>$null
    if (-not $sdks) { Add-Error ".NET SDK not found (dotnet --list-sdks returned nothing)." ; return }
    $has8 = $sdks | Where-Object { $_ -match '^8\.0\.' }
    if (-not $has8) {
        Add-Error ".NET SDK 8.0.x is required; installed: $($sdks -join '; ')"
    } else {
        Write-Host "  OK: $($has8 -join ', ')" -ForegroundColor Green
    }
}

function Get-LabVIEWPath {
    param (
        [ValidateSet('x64','x86')]
        [string]$Bitness
    )
    $paths = @()
    if ($Bitness -eq 'x64') {
        $keys = @(
            'HKLM:\SOFTWARE\National Instruments\LabVIEW\21.0',
            'HKLM:\SOFTWARE\National Instruments\LabVIEW\21.0\CurrentVersion'
        )
    } else {
        $keys = @(
            'HKLM:\SOFTWARE\WOW6432Node\National Instruments\LabVIEW\21.0',
            'HKLM:\SOFTWARE\WOW6432Node\National Instruments\LabVIEW\21.0\CurrentVersion'
        )
    }
    foreach ($k in $keys) {
        if (Test-Path $k) {
            $p = Get-ItemProperty -Path $k -ErrorAction SilentlyContinue
            foreach ($name in @('Path','AppDir','RootPath')) {
                if ($p.$name) {
                    $vals = ($p.$name -split ';') | ForEach-Object { $_.Trim() } | Where-Object { $_ }
                    if ($vals) { $paths += $vals }
                }
            }
        }
    }
    $paths = $paths | Where-Object { $_ -and (Test-Path $_) } | Select-Object -Unique
    foreach ($p in $paths) {
        try {
            return (Resolve-Path -LiteralPath $p).ProviderPath
        } catch {
            # Ignore and try next candidate
        }
    }
    return $null
}

function Check-LabVIEW {
    param (
        [ValidateSet('x64','x86')]
        [string]$Bitness
    )
    Write-Host "Checking LabVIEW 2021 $Bitness..."
    $lvPath = Get-LabVIEWPath -Bitness $Bitness
    if (-not $lvPath) {
        $regRoot = $(if ($Bitness -eq 'x64') { 'National Instruments' } else { 'WOW6432Node\\National Instruments' })
        Add-Error ("LabVIEW 2021 {0} not found via registry; expected install at HKLM:\\SOFTWARE\\{1}\\LabVIEW\\21.0." -f $Bitness, $regRoot)
        return
    }
    $exe = Join-Path $lvPath 'LabVIEW.exe'
    if (-not (Test-Path $exe)) {
        Add-Error "LabVIEW 2021 $Bitness install detected at '$lvPath' but LabVIEW.exe is missing."
    } else {
        Write-Host "  OK: $exe" -ForegroundColor Green
    }
}

function Check-Pester {
    Write-Host "Checking Pester >= 5.3.3..."
    $pester = Get-Module -ListAvailable -Name Pester | Where-Object { $_.Version -ge [version]'5.3.3' } | Sort-Object Version -Descending | Select-Object -First 1
    if (-not $pester) {
        Add-Error "Pester >=5.3.3 not found; install with: Install-Module -Name Pester -MinimumVersion 5.3.3 -Scope CurrentUser -Force -SkipPublisherCheck"
    } else {
        Write-Host "  OK: Pester $($pester.Version) at $($pester.Path)" -ForegroundColor Green
    }
}

function Check-Git {
    Write-Host "Checking git..."
    $git = Get-Command git -ErrorAction SilentlyContinue
    if (-not $git) {
        Add-Error "git not found in PATH."
    } else {
        $ver = (& git --version 2>$null)
        Write-Host "  OK: $ver" -ForegroundColor Green
    }
}

function Check-VIPM {
    Write-Host "Checking VIPM CLI (vipm)..."
    $cmd = Get-Command vipm -CommandType Application -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($cmd) {
        Write-Host ("  OK: {0}" -f $cmd.Source) -ForegroundColor Green
        return
    }

    $cand = @(
        'C:\Program Files\JKI\VI Package Manager\VIPM.exe',
        'C:\Program Files (x86)\JKI\VI Package Manager\VIPM.exe',
        'C:\Program Files\National Instruments\VI Package Manager\VIPM.exe',
        'C:\Program Files (x86)\National Instruments\VI Package Manager\VIPM.exe'
    )
    $found = $cand | Where-Object { Test-Path $_ } | Select-Object -First 1
    if (-not $found) {
        # Last resort: shallow search under Program Files roots
        $roots = @('C:\Program Files','C:\Program Files (x86)')
        foreach ($r in $roots) {
            if (Test-Path $r) {
                $g = Get-ChildItem -Path $r -Filter VIPM.exe -File -Recurse -Depth 3 -ErrorAction SilentlyContinue | Select-Object -First 1
                if ($g) { $found = $g.FullName; break }
            }
        }
    }

    if ($found) {
        Add-Error ("vipm CLI not on PATH. Found VIPM.exe at '{0}' but CI will call 'vipm'. Add it to PATH or set VIPM_PATH accordingly." -f $found)
    } else {
        Add-Error "vipm CLI not found; install VIPM and ensure 'vipm' is on PATH (or set VIPM_PATH)."
    }
}

Check-DotNet
Check-Git
Check-Pester
Check-LabVIEW -Bitness 'x64'
if (-not $SkipLabVIEWX86) { Check-LabVIEW -Bitness 'x86' }
if (-not $SkipVIPM) { Check-VIPM }

if ($errors.Count -gt 0) {
    Write-Host ""
    Write-Host "Prerequisite check failed:" -ForegroundColor Red
    $errors | ForEach-Object { Write-Host " - $_" -ForegroundColor Red }
    exit 1
}

Write-Host ""
Write-Host "All prerequisite checks passed." -ForegroundColor Green
