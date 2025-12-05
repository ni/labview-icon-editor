$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

function Resolve-LVIniPath {
    param(
        [Parameter(Mandatory)][string]$LvVersion,
        [Parameter(Mandatory)][ValidateSet('32','64')][string]$Arch
    )

    $pf = if ($Arch -eq '32') { ${env:ProgramFiles(x86)} } else { $env:ProgramFiles }
    if (-not $pf) { throw "Program Files folder not found for bitness $Arch." }

    $iniPath = Join-Path $pf "National Instruments/LabVIEW $LvVersion/LabVIEW.ini"
    if (-not (Test-Path -LiteralPath $iniPath)) {
        throw "LabVIEW.ini not found for LabVIEW $LvVersion ($Arch-bit): $iniPath"
    }
    return $iniPath
}

function Clear-StaleLibraryPaths {
    param(
        [Parameter(Mandatory)][string]$LvVersion,
        [Parameter(Mandatory)][ValidateSet('32','64')][string]$Arch,
        [AllowEmptyString()][string]$RepositoryRoot,
        [AllowEmptyString()][string]$TargetPath,
        [switch]$Force
    )

    $iniPath = Resolve-LVIniPath -LvVersion $LvVersion -Arch $Arch
    $lines = @(Get-Content -LiteralPath $iniPath -ErrorAction Stop)
    $pattern = 'LocalHost\.LibraryPaths\d*\s*=\s*(?<val>.*)'

    $targetNorm = if ([string]::IsNullOrWhiteSpace($TargetPath)) { $null } else { ([System.IO.Path]::GetFullPath($TargetPath)).ToLowerInvariant() }
    $filtered = New-Object System.Collections.Generic.List[string]
    foreach ($line in $lines) {
        $m = [regex]::Match($line, $pattern, 'IgnoreCase')
        if (-not $m.Success) { $filtered.Add($line); continue }

        $val = $m.Groups['val'].Value.Trim()
        $norm = if ([string]::IsNullOrWhiteSpace($val)) { $null } else { ([System.IO.Path]::GetFullPath($val)).ToLowerInvariant() }

        $keep = $false
        if ($Force) {
            $keep = $false
        }
        elseif ($targetNorm -and $norm -eq $targetNorm) {
            $keep = $true
        }

        if ($keep) { $filtered.Add($line) }
    }

    $filtered | Set-Content -LiteralPath $iniPath -Encoding utf8
    return $true
}

function Add-LibraryPathToken {
    param(
        [Parameter(Mandatory)][string]$LvVersion,
        [Parameter(Mandatory)][ValidateSet('32','64')][string]$Arch,
        [Parameter(Mandatory)][string]$TokenPath,
        [AllowEmptyString()][string]$RepositoryRoot
    )

    if ([string]::IsNullOrWhiteSpace($TokenPath)) {
        throw "TokenPath cannot be empty when adding LocalHost.LibraryPaths."
    }

    $iniPath = Resolve-LVIniPath -LvVersion $LvVersion -Arch $Arch
    $resolved = [System.IO.Path]::GetFullPath($TokenPath)

    $lines = @()
    $pattern = 'LocalHost\.LibraryPaths\d*\s*=\s*(?<val>.*)'
    if (Test-Path -LiteralPath $iniPath) {
        $existing = Get-Content -LiteralPath $iniPath -ErrorAction Stop
        $lines = $existing | Where-Object { $_ -notmatch $pattern }
    }

    $lines += "LocalHost.LibraryPaths=$resolved"
    $lines | Set-Content -LiteralPath $iniPath -Encoding utf8
    return $true
}
