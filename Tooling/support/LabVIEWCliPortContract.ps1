#Requires -Version 7.0

$ErrorActionPreference = 'Stop'

function Resolve-LabVIEWCliPortContractRepoRoot {
    param(
        [string]$RepoRoot
    )

    if (-not [string]::IsNullOrWhiteSpace($RepoRoot)) {
        return (Resolve-Path -Path $RepoRoot -ErrorAction Stop).Path
    }

    if (-not [string]::IsNullOrWhiteSpace($env:REPO_ROOT) -and (Test-Path -Path $env:REPO_ROOT)) {
        return (Resolve-Path -Path $env:REPO_ROOT -ErrorAction Stop).Path
    }

    $scriptRoot = if ($PSScriptRoot) { $PSScriptRoot } else { Split-Path -Parent $PSCommandPath }
    try {
        $gitRoot = git -C $scriptRoot rev-parse --show-toplevel 2>$null
        if ($LASTEXITCODE -eq 0 -and -not [string]::IsNullOrWhiteSpace($gitRoot)) {
            return (Resolve-Path -Path $gitRoot.Trim() -ErrorAction Stop).Path
        }
    } catch {
        Write-Verbose ("git rev-parse failed while resolving repo root: {0}" -f $_.Exception.Message)
    }

    return (Resolve-Path -Path (Join-Path $scriptRoot '..\..') -ErrorAction Stop).Path
}

function Resolve-LabVIEWCliPortContractPath {
    param(
        [Parameter(Mandatory = $true)]
        [string]$RepoRoot,
        [string]$ContractPath = 'Tooling/labviewcli-port-contract.json'
    )

    if ([System.IO.Path]::IsPathRooted($ContractPath)) {
        return [System.IO.Path]::GetFullPath($ContractPath)
    }

    return [System.IO.Path]::GetFullPath((Join-Path $RepoRoot $ContractPath))
}

function Resolve-LabVIEWCliPortContractYear {
    param(
        [string]$RepoRoot,
        [string]$LabVIEWVersion
    )

    $resolvedYear = $null
    $versionHelper = Join-Path $RepoRoot 'Tooling\support\LabVIEWVersion.ps1'
    if (Test-Path -Path $versionHelper -PathType Leaf) {
        . $versionHelper
        try {
            $versionInfo = Get-LabVIEWVersionInfo -VersionInput $LabVIEWVersion -RepoRoot $RepoRoot
            if ($versionInfo -and -not [string]::IsNullOrWhiteSpace($versionInfo.Year)) {
                $resolvedYear = [string]$versionInfo.Year
            }
        } catch {
            Write-Verbose ("LabVIEWVersion helper did not resolve year: {0}" -f $_.Exception.Message)
        }
    }

    if ([string]::IsNullOrWhiteSpace($resolvedYear)) {
        $raw = $LabVIEWVersion
        if ([string]::IsNullOrWhiteSpace($raw)) {
            $lvVersionPath = Join-Path $RepoRoot '.lvversion'
            if (-not (Test-Path -Path $lvVersionPath -PathType Leaf)) {
                throw ".lvversion not found at $lvVersionPath"
            }
            $raw = (Get-Content -Path $lvVersionPath -Raw -ErrorAction Stop).Trim()
        }

        if ([string]::IsNullOrWhiteSpace($raw)) {
            throw "LabVIEW version is empty and year cannot be resolved."
        }

        $major = ($raw.Trim() -split '\.')[0]
        $parsed = 0
        if (-not [int]::TryParse($major, [ref]$parsed)) {
            throw ("LabVIEW version '{0}' is invalid; expected numeric year or major.minor." -f $raw)
        }
        if ($parsed -ge 2000) {
            $resolvedYear = [string]$parsed
        } elseif ($parsed -ge 0 -and $parsed -lt 100) {
            $resolvedYear = [string](2000 + $parsed)
        } else {
            throw ("LabVIEW version '{0}' cannot be mapped to a contract year." -f $raw)
        }
    }

    return $resolvedYear
}

function Get-LabVIEWIniValueStrict {
    param(
        [Parameter(Mandatory = $true)]
        [string]$IniPath,
        [Parameter(Mandatory = $true)]
        [string]$Key
    )

    foreach ($line in Get-Content -Path $IniPath -ErrorAction Stop) {
        if ([string]::IsNullOrWhiteSpace($line)) {
            continue
        }
        $trimmed = $line.Trim()
        if ($trimmed.StartsWith(';') -or $trimmed.StartsWith('#')) {
            continue
        }
        $separator = $trimmed.IndexOf('=')
        if ($separator -lt 0) {
            continue
        }
        $lineKey = $trimmed.Substring(0, $separator).Trim()
        if ($lineKey.Equals($Key, [System.StringComparison]::OrdinalIgnoreCase)) {
            return $trimmed.Substring($separator + 1).Trim()
        }
    }

    return $null
}

function Set-LabVIEWIniValueStrict {
    param(
        [Parameter(Mandatory = $true)]
        [string]$IniPath,
        [Parameter(Mandatory = $true)]
        [string]$Key,
        [Parameter(Mandatory = $true)]
        [string]$Value
    )

    $lines = @(Get-Content -Path $IniPath -ErrorAction Stop)
    $updated = $false
    for ($index = 0; $index -lt $lines.Count; $index++) {
        $line = [string]$lines[$index]
        $trimmed = $line.Trim()
        if ([string]::IsNullOrWhiteSpace($trimmed) -or $trimmed.StartsWith(';') -or $trimmed.StartsWith('#')) {
            continue
        }

        $separator = $trimmed.IndexOf('=')
        if ($separator -lt 0) {
            continue
        }

        $lineKey = $trimmed.Substring(0, $separator).Trim()
        if ($lineKey.Equals($Key, [System.StringComparison]::OrdinalIgnoreCase)) {
            $lines[$index] = ('{0}={1}' -f $Key, $Value)
            $updated = $true
            break
        }
    }

    if (-not $updated) {
        $lines += ('{0}={1}' -f $Key, $Value)
    }

    Set-Content -Path $IniPath -Value $lines -Encoding ascii
}

function Get-LabVIEWCliPortContract {
    param(
        [Parameter(Mandatory = $true)]
        [string]$RepoRoot,
        [string]$ContractPath = 'Tooling/labviewcli-port-contract.json'
    )

    $resolvedContractPath = Resolve-LabVIEWCliPortContractPath -RepoRoot $RepoRoot -ContractPath $ContractPath
    if (-not (Test-Path -Path $resolvedContractPath -PathType Leaf)) {
        throw "LabVIEWCLI port contract file is missing: $resolvedContractPath"
    }

    $raw = Get-Content -Path $resolvedContractPath -Raw -ErrorAction Stop
    if ([string]::IsNullOrWhiteSpace($raw)) {
        throw "LabVIEWCLI port contract file is empty: $resolvedContractPath"
    }

    $contract = $raw | ConvertFrom-Json -ErrorAction Stop
    if (-not $contract.PSObject.Properties.Name.Contains('labview_cli_ports')) {
        throw "LabVIEWCLI port contract is missing 'labview_cli_ports': $resolvedContractPath"
    }

    return [pscustomobject]@{
        ContractPath = $resolvedContractPath
        Contract = $contract
    }
}

function Resolve-LabVIEWCliPortFromContract {
    param(
        [string]$RepoRoot,
        [string]$LabVIEWVersion,
        [Parameter(Mandatory = $true)]
        [ValidateSet('32', '64')]
        [string]$Bitness,
        [Parameter(Mandatory = $true)]
        [string]$LabVIEWExecutablePath,
        [string]$ContractPath = 'Tooling/labviewcli-port-contract.json',
        [switch]$EnableRemediation
    )

    $resolvedRepoRoot = Resolve-LabVIEWCliPortContractRepoRoot -RepoRoot $RepoRoot
    $contractInfo = Get-LabVIEWCliPortContract -RepoRoot $resolvedRepoRoot -ContractPath $ContractPath
    $year = Resolve-LabVIEWCliPortContractYear -RepoRoot $resolvedRepoRoot -LabVIEWVersion $LabVIEWVersion

    if (-not (Test-Path -Path $LabVIEWExecutablePath -PathType Leaf)) {
        throw "LabVIEW executable was not found: $LabVIEWExecutablePath"
    }

    $portsNode = $contractInfo.Contract.labview_cli_ports
    if (-not $portsNode.PSObject.Properties.Name.Contains($year)) {
        throw ("LabVIEWCLI port contract does not define year '{0}' in {1}" -f $year, $contractInfo.ContractPath)
    }

    $yearNode = $portsNode.$year
    if (-not $yearNode.PSObject.Properties.Name.Contains($Bitness)) {
        throw ("LabVIEWCLI port contract does not define bitness '{0}' for year '{1}' in {2}" -f $Bitness, $year, $contractInfo.ContractPath)
    }

    $expectedPort = 0
    if (-not [int]::TryParse([string]$yearNode.$Bitness, [ref]$expectedPort) -or $expectedPort -lt 1 -or $expectedPort -gt 65535) {
        throw ("LabVIEWCLI port contract value is invalid for year '{0}' bitness '{1}' in {2}" -f $year, $Bitness, $contractInfo.ContractPath)
    }

    $iniPath = Join-Path -Path (Split-Path -Path $LabVIEWExecutablePath -Parent) -ChildPath 'LabVIEW.ini'
    if (-not (Test-Path -Path $iniPath -PathType Leaf)) {
        throw ("LabVIEW.ini is required for strict port validation but was not found: {0}" -f $iniPath)
    }

    $remediationEnabled = $EnableRemediation.IsPresent
    if ($remediationEnabled) {
        Write-Warning ("LabVIEWCLI port contract remediation enabled. Ini path: {0}" -f $iniPath)
    }

    $settingsAdjusted = $false
    $enabledRaw = Get-LabVIEWIniValueStrict -IniPath $iniPath -Key 'server.tcp.enabled'
    if ([string]::IsNullOrWhiteSpace($enabledRaw) -and $remediationEnabled) {
        Set-LabVIEWIniValueStrict -IniPath $iniPath -Key 'server.tcp.enabled' -Value 'true'
        $enabledRaw = 'true'
        $settingsAdjusted = $true
        Write-Warning ("LabVIEW.ini was missing server.tcp.enabled; remediated to true in {0}" -f $iniPath)
    }
    if ([string]::IsNullOrWhiteSpace($enabledRaw)) {
        throw ("LabVIEW.ini is missing server.tcp.enabled in {0}" -f $iniPath)
    }

    $enabledNormalized = $enabledRaw.Trim().ToLowerInvariant()
    if (@('true', 't', '1', 'yes', 'y') -contains $enabledNormalized) {
        # valid enabled state
    } elseif (@('false', 'f', '0', 'no', 'n') -contains $enabledNormalized -and $remediationEnabled) {
        $previousEnabledRaw = $enabledRaw
        Set-LabVIEWIniValueStrict -IniPath $iniPath -Key 'server.tcp.enabled' -Value 'true'
        $settingsAdjusted = $true
        $enabledRaw = 'true'
        Write-Warning ("LabVIEW.ini had server.tcp.enabled={0}; remediated to true in {1}" -f $previousEnabledRaw, $iniPath)
    } elseif (@('false', 'f', '0', 'no', 'n') -contains $enabledNormalized) {
        throw ("LabVIEW.ini has server.tcp.enabled={0} in {1}; strict contract requires enabled." -f $enabledRaw, $iniPath)
    } elseif ($remediationEnabled) {
        $previousEnabledRaw = $enabledRaw
        Set-LabVIEWIniValueStrict -IniPath $iniPath -Key 'server.tcp.enabled' -Value 'true'
        $settingsAdjusted = $true
        $enabledRaw = 'true'
        Write-Warning ("LabVIEW.ini had invalid server.tcp.enabled='{0}'; remediated to true in {1}" -f $previousEnabledRaw, $iniPath)
    } else {
        throw ("LabVIEW.ini has invalid server.tcp.enabled='{0}' in {1}" -f $enabledRaw, $iniPath)
    }

    $portRaw = Get-LabVIEWIniValueStrict -IniPath $iniPath -Key 'server.tcp.port'
    if ([string]::IsNullOrWhiteSpace($portRaw) -and $remediationEnabled) {
        Set-LabVIEWIniValueStrict -IniPath $iniPath -Key 'server.tcp.port' -Value $expectedPort.ToString()
        $portRaw = $expectedPort.ToString()
        $settingsAdjusted = $true
        Write-Warning ("LabVIEW.ini was missing server.tcp.port; remediated to {0} in {1}" -f $expectedPort, $iniPath)
    }
    if ([string]::IsNullOrWhiteSpace($portRaw)) {
        throw ("LabVIEW.ini is missing server.tcp.port in {0}" -f $iniPath)
    }

    $actualPort = 0
    if ((-not [int]::TryParse($portRaw.Trim(), [ref]$actualPort) -or $actualPort -lt 1 -or $actualPort -gt 65535) -and $remediationEnabled) {
        Set-LabVIEWIniValueStrict -IniPath $iniPath -Key 'server.tcp.port' -Value $expectedPort.ToString()
        $actualPort = $expectedPort
        $settingsAdjusted = $true
        Write-Warning ("LabVIEW.ini had invalid server.tcp.port='{0}'; remediated to {1} in {2}" -f $portRaw, $expectedPort, $iniPath)
    } elseif (-not [int]::TryParse($portRaw.Trim(), [ref]$actualPort) -or $actualPort -lt 1 -or $actualPort -gt 65535) {
        throw ("LabVIEW.ini has invalid server.tcp.port='{0}' in {1}" -f $portRaw, $iniPath)
    }

    if ($actualPort -ne $expectedPort -and $remediationEnabled) {
        Set-LabVIEWIniValueStrict -IniPath $iniPath -Key 'server.tcp.port' -Value $expectedPort.ToString()
        $actualPort = $expectedPort
        $settingsAdjusted = $true
        Write-Warning ("LabVIEWCLI port contract mismatch for year {0} bitness {1}; remediated server.tcp.port to {2} in {3}" -f $year, $Bitness, $expectedPort, $iniPath)
    } elseif ($actualPort -ne $expectedPort) {
        throw ("LabVIEWCLI port contract mismatch for year {0} bitness {1}: expected {2} from {3}, found {4} in {5}" -f $year, $Bitness, $expectedPort, $contractInfo.ContractPath, $actualPort, $iniPath)
    }

    if ($settingsAdjusted) {
        Write-Host ("LabVIEWCLI contract remediation applied for year={0} bitness={1} in {2}" -f $year, $Bitness, $iniPath)
    }

    return [pscustomobject]@{
        PortNumber          = $expectedPort
        Source              = ('contract:{0} year:{1} bitness:{2}' -f $contractInfo.ContractPath, $year, $Bitness)
        ContractPath        = $contractInfo.ContractPath
        IniPath             = $iniPath
        LabVIEWYear         = $year
        Bitness             = $Bitness
        RemediationEnabled  = $remediationEnabled
        RemediationApplied  = $settingsAdjusted
    }
}
