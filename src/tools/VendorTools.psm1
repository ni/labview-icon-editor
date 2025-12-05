# Minimal VendorTools implementation for local LabVIEW installs

function Resolve-LabVIEWExePath {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][int]$Version,
        [Parameter(Mandatory)][ValidateSet(32,64)][int]$Bitness
    )

    $pf = if ($Bitness -eq 32) { ${env:ProgramFiles(x86)} } else { $env:ProgramFiles }
    if (-not $pf) { throw "Program Files folder not found for bitness $Bitness." }
    $exe = Join-Path $pf "National Instruments/LabVIEW $Version/LabVIEW.exe"
    if (-not (Test-Path -LiteralPath $exe -PathType Leaf)) {
        throw "LabVIEW.exe not found for LabVIEW $Version ($Bitness-bit): $exe"
    }
    return (Resolve-Path -LiteralPath $exe).Path
}

function Get-LabVIEWIniPath {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$LabVIEWExePath
    )

    $ini = [System.IO.Path]::ChangeExtension($LabVIEWExePath, '.ini')
    return $ini
}

function Get-LabVIEWIniValue {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$LabVIEWExePath,
        [Parameter(Mandatory)][string]$LabVIEWIniPath,
        [Parameter(Mandatory)][string]$Key
    )

    if (-not (Test-Path -LiteralPath $LabVIEWIniPath -PathType Leaf)) { return $null }
    $pattern = "^{0}\s*=\s*(?<val>.*)$" -f [regex]::Escape($Key)
    foreach ($line in Get-Content -LiteralPath $LabVIEWIniPath -ErrorAction Stop) {
        $m = [regex]::Match($line, $pattern, 'IgnoreCase')
        if ($m.Success) { return $m.Groups['val'].Value.Trim() }
    }
    return $null
}

function Resolve-LabVIEWCliPath {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][int]$Version,
        [Parameter(Mandatory)][ValidateSet(32,64)][int]$Bitness
    )

    $pf = if ($Bitness -eq 32) { ${env:ProgramFiles(x86)} } else { $env:ProgramFiles }
    if (-not $pf) { throw "Program Files folder not found for bitness $Bitness." }
    $cli = Join-Path $pf "National Instruments/LabVIEW $Version/LabVIEWCLI.exe"
    if (Test-Path -LiteralPath $cli -PathType Leaf) {
        return (Resolve-Path -LiteralPath $cli).Path
    }
    return $null
}

function Test-VIAnalyzerToolkit {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][int]$Version,
        [Parameter(Mandatory)][ValidateSet(32,64)][int]$Bitness
    )

    $root = if ($Bitness -eq 32) { ${env:ProgramFiles(x86)} } else { $env:ProgramFiles }
    $toolkitPath = Join-Path $root "National Instruments/LabVIEW $Version/project/_VI Analyzer"
    $exists = Test-Path -LiteralPath $toolkitPath
    return [pscustomobject]@{
        exists      = $exists
        toolkitPath = if ($exists) { (Resolve-Path -LiteralPath $toolkitPath).Path } else { $toolkitPath }
        reason      = if ($exists) { '' } else { 'Toolkit folder not found' }
    }
}

function Get-VendorToolkitInfo {
    [CmdletBinding()] param()
    return @{ name = 'StubToolkit'; version = '0.0.0'; status = 'available'; notes = 'Local minimal VendorTools' }
}

Export-ModuleMember -Function Resolve-LabVIEWExePath,Get-LabVIEWIniPath,Get-LabVIEWIniValue,Resolve-LabVIEWCliPath,Test-VIAnalyzerToolkit,Get-VendorToolkitInfo
