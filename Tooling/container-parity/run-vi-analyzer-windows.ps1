param(
    [string]$WorkspaceRoot = '',
    [string]$LabVIEWPath = '',
    [string]$LabVIEWVersion = '',
    [string]$LabVIEWBitness = '64',
    [string]$TasksPath = 'Tooling\vi-analyzer\tasks.json',
    [string]$ReportsRoot = 'builds\vi-analyzer\windows-container',
    [string]$StatusPath = 'builds\status\vi-analyzer-summary.parity.windows.json',
    [string]$SourceSyncManifestPath = ''
)

$ErrorActionPreference = 'Stop'

$pathContractScript = Join-Path -Path $PSScriptRoot -ChildPath '..\support\PathContract.ps1'
if (-not (Test-Path -LiteralPath $pathContractScript -PathType Leaf)) {
    throw "Path contract helper was not found: $pathContractScript"
}

$pathContractLines = Get-Content -LiteralPath $pathContractScript -ErrorAction Stop
for ($lineIndex = 0; $lineIndex -lt $pathContractLines.Count; $lineIndex++) {
    $lineText = [string]$pathContractLines[$lineIndex]
    if ($lineText -match '^\s*#\s*requires\s+-version\b') {
        $lineNumber = $lineIndex + 1
        $psVersion = if ($PSVersionTable -and $PSVersionTable.PSVersion) { [string]$PSVersionTable.PSVersion } else { '<unknown>' }
        throw ("Path contract shell compatibility failure: PathContract.ps1 contains a file-scope #Requires -Version directive on line {0}: '{1}'. Current shell version: {2}. This script runs in Windows PowerShell 5.1 inside NI Windows containers." -f $lineNumber, $lineText.Trim(), $psVersion)
    }
}

. $pathContractScript

function Test-EnabledValue {
    param(
        [AllowNull()]
        [string]$Value
    )

    if ([string]::IsNullOrWhiteSpace($Value)) {
        return $false
    }

    return $Value.Equals('1', [System.StringComparison]::OrdinalIgnoreCase) `
        -or $Value.Equals('true', [System.StringComparison]::OrdinalIgnoreCase) `
        -or $Value.Equals('yes', [System.StringComparison]::OrdinalIgnoreCase)
}

function Get-LabVIEWIniValueStrict {
    param(
        [Parameter(Mandatory = $true)]
        [string]$IniPath,
        [Parameter(Mandatory = $true)]
        [string]$Key
    )

    foreach ($line in Get-Content -LiteralPath $IniPath -ErrorAction Stop) {
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

    $lines = @(Get-Content -LiteralPath $IniPath -ErrorAction Stop)
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

    Set-Content -LiteralPath $IniPath -Value $lines -Encoding ascii
}

function Resolve-LabVIEWContractYear {
    param(
        [Parameter(Mandatory = $true)]
        [string]$RepoRoot,
        [AllowNull()]
        [string]$VersionHint
    )

    $rawVersion = ''
    $rawSource = ''
    if (-not [string]::IsNullOrWhiteSpace($VersionHint)) {
        $rawVersion = $VersionHint.Trim()
        $rawSource = 'parameter:LabVIEWVersion'
    } elseif (-not [string]::IsNullOrWhiteSpace($env:CONTAINER_PARITY_LABVIEW_VERSION)) {
        $rawVersion = $env:CONTAINER_PARITY_LABVIEW_VERSION.Trim()
        $rawSource = '$env:CONTAINER_PARITY_LABVIEW_VERSION'
    } else {
        $lvversionPath = Join-Path $RepoRoot '.lvversion'
        if (-not (Test-Path -LiteralPath $lvversionPath -PathType Leaf)) {
            throw ".lvversion not found at $lvversionPath"
        }

        $rawVersion = (Get-Content -LiteralPath $lvversionPath -Raw -ErrorAction Stop).Trim()
        $rawSource = '.lvversion'
    }

    if ([string]::IsNullOrWhiteSpace($rawVersion)) {
        throw "LabVIEW version is empty and year cannot be resolved."
    }

    $majorToken = ($rawVersion -split '\.')[0]
    $parsed = 0
    if (-not [int]::TryParse($majorToken, [ref]$parsed)) {
        throw ("LabVIEW version '{0}' is invalid; expected numeric year or major.minor." -f $rawVersion)
    }

    $resolvedYear = ''
    if ($parsed -ge 2000) {
        $resolvedYear = [string]$parsed
    } elseif ($parsed -ge 0 -and $parsed -lt 100) {
        $resolvedYear = [string](2000 + $parsed)
    } else {
        throw ("LabVIEW version '{0}' cannot be mapped to a contract year." -f $rawVersion)
    }

    return [pscustomobject]@{
        Year       = $resolvedYear
        RawVersion = $rawVersion
        Source     = $rawSource
    }
}

function Resolve-LabVIEWContractBitness {
    param(
        [AllowNull()]
        [string]$BitnessHint,
        [AllowNull()]
        [string]$LabVIEWExecutablePath
    )

    $rawBitness = ''
    $rawSource = ''
    if (-not [string]::IsNullOrWhiteSpace($BitnessHint)) {
        $rawBitness = $BitnessHint.Trim()
        $rawSource = 'parameter:LabVIEWBitness'
    } elseif (-not [string]::IsNullOrWhiteSpace($env:CONTAINER_PARITY_LABVIEW_BITNESS)) {
        $rawBitness = $env:CONTAINER_PARITY_LABVIEW_BITNESS.Trim()
        $rawSource = '$env:CONTAINER_PARITY_LABVIEW_BITNESS'
    } elseif (-not [string]::IsNullOrWhiteSpace($LabVIEWExecutablePath)) {
        $normalizedPath = $LabVIEWExecutablePath.Trim()
        if ($normalizedPath -match '(?i)[\\/ ]Program Files \(x86\)[\\/]') {
            return [pscustomobject]@{
                Bitness    = '32'
                RawBitness = 'x86-path'
                Source     = 'inferred:LabVIEWExecutablePath'
            }
        }

        if ($normalizedPath -match '(?i)[\\/ ]Program Files[\\/]') {
            return [pscustomobject]@{
                Bitness    = '64'
                RawBitness = 'x64-path'
                Source     = 'inferred:LabVIEWExecutablePath'
            }
        }
    }

    if ([string]::IsNullOrWhiteSpace($rawBitness)) {
        throw 'LabVIEW bitness is empty and cannot be resolved. Pass -LabVIEWBitness or set CONTAINER_PARITY_LABVIEW_BITNESS.'
    }

    $normalized = $rawBitness.Trim().ToLowerInvariant()
    $resolved = if ($normalized -eq '32' -or $normalized -eq 'x86') {
        '32'
    } elseif ($normalized -eq '64' -or $normalized -eq 'x64') {
        '64'
    } else {
        throw ("LabVIEW bitness '{0}' is invalid; expected 32|64|x86|x64." -f $rawBitness)
    }

    return [pscustomobject]@{
        Bitness    = $resolved
        RawBitness = $rawBitness
        Source     = $rawSource
    }
}

function Resolve-LabVIEWCliPort {
    param(
        [string]$RepoRootPath,
        [string]$LabVIEWExecutablePath,
        [AllowNull()]
        [string]$LabVIEWContractBitness
    )

    $contractPath = Join-Path $RepoRootPath 'Tooling\labviewcli-port-contract.json'
    if (-not (Test-Path -LiteralPath $contractPath -PathType Leaf)) {
        throw "LabVIEW CLI port contract file not found at $contractPath"
    }

    $contractRaw = Get-Content -LiteralPath $contractPath -Raw -ErrorAction Stop
    if ([string]::IsNullOrWhiteSpace($contractRaw)) {
        throw "LabVIEW CLI port contract file is empty: $contractPath"
    }

    $contract = $contractRaw | ConvertFrom-Json -ErrorAction Stop
    if (-not ($contract.PSObject.Properties.Name -contains 'labview_cli_ports')) {
        throw "LabVIEW CLI port contract is missing 'labview_cli_ports': $contractPath"
    }

    $yearResolution = Resolve-LabVIEWContractYear -RepoRoot $RepoRootPath -VersionHint $LabVIEWVersion
    $year = [string]$yearResolution.Year
    Write-Output ("Resolved LabVIEW contract year: {0} (source: {1}, raw: {2})" -f $year, [string]$yearResolution.Source, [string]$yearResolution.RawVersion)
    $bitnessResolution = Resolve-LabVIEWContractBitness -BitnessHint $LabVIEWContractBitness -LabVIEWExecutablePath $LabVIEWExecutablePath
    $bitness = [string]$bitnessResolution.Bitness
    Write-Host ("Resolved LabVIEW contract bitness: {0} (source: {1}, raw: {2})" -f $bitness, [string]$bitnessResolution.Source, [string]$bitnessResolution.RawBitness)
    Write-Host ("Resolved LabVIEWCLI contract target: year={0} bitness={1}" -f $year, $bitness)

    if (-not ($contract.labview_cli_ports.PSObject.Properties.Name -contains $year)) {
        throw ("LabVIEW CLI port contract does not define year '{0}' in {1}" -f $year, $contractPath)
    }

    $yearNode = $contract.labview_cli_ports.$year
    if (-not ($yearNode.PSObject.Properties.Name -contains $bitness)) {
        throw ("LabVIEW CLI port contract does not define bitness '{0}' for year '{1}' in {2}" -f $bitness, $year, $contractPath)
    }

    $expectedPort = 0
    if (-not [int]::TryParse([string]$yearNode.$bitness, [ref]$expectedPort) -or $expectedPort -lt 1 -or $expectedPort -gt 65535) {
        throw ("LabVIEW CLI port contract value is invalid for year '{0}' bitness '{1}' in {2}" -f $year, $bitness, $contractPath)
    }

    if (-not (Test-Path -LiteralPath $LabVIEWExecutablePath -PathType Leaf)) {
        throw "LabVIEW executable was not found: $LabVIEWExecutablePath"
    }

    $iniPath = Join-Path (Split-Path -Path $LabVIEWExecutablePath -Parent) 'LabVIEW.ini'
    if (-not (Test-Path -LiteralPath $iniPath -PathType Leaf)) {
        throw "LabVIEW.ini is required for strict port validation but was not found: $iniPath"
    }

    $contractRemediationEnabled = Test-EnabledValue -Value $env:LVIE_REMEDIATE_LABVIEWCLI_PORT_CONTRACT
    if ($contractRemediationEnabled) {
        Write-Warning ("LabVIEWCLI port contract remediation enabled via LVIE_REMEDIATE_LABVIEWCLI_PORT_CONTRACT. Ini path: {0}" -f $iniPath)
    }

    $settingsAdjusted = $false
    $enabledRaw = Get-LabVIEWIniValueStrict -IniPath $iniPath -Key 'server.tcp.enabled'
    if ([string]::IsNullOrWhiteSpace($enabledRaw) -and $contractRemediationEnabled) {
        Set-LabVIEWIniValueStrict -IniPath $iniPath -Key 'server.tcp.enabled' -Value 'true'
        $enabledRaw = 'true'
        $settingsAdjusted = $true
        Write-Warning ("LabVIEW.ini was missing server.tcp.enabled; remediated to true in {0}" -f $iniPath)
    }
    if ([string]::IsNullOrWhiteSpace($enabledRaw)) {
        throw "LabVIEW.ini is missing server.tcp.enabled in $iniPath"
    }

    $enabledNormalized = $enabledRaw.Trim().ToLowerInvariant()
    if (@('true', 't', '1', 'yes', 'y') -contains $enabledNormalized) {
        # Valid enabled state.
    } elseif (@('false', 'f', '0', 'no', 'n') -contains $enabledNormalized -and $contractRemediationEnabled) {
        Set-LabVIEWIniValueStrict -IniPath $iniPath -Key 'server.tcp.enabled' -Value 'true'
        $settingsAdjusted = $true
        Write-Warning ("LabVIEW.ini had server.tcp.enabled={0}; remediated to true in {1}" -f $enabledRaw, $iniPath)
    } elseif (@('false', 'f', '0', 'no', 'n') -contains $enabledNormalized) {
        throw ("LabVIEW.ini has server.tcp.enabled={0} in {1}; strict contract requires enabled." -f $enabledRaw, $iniPath)
    } elseif ($contractRemediationEnabled) {
        Set-LabVIEWIniValueStrict -IniPath $iniPath -Key 'server.tcp.enabled' -Value 'true'
        $settingsAdjusted = $true
        Write-Warning ("LabVIEW.ini had invalid server.tcp.enabled='{0}'; remediated to true in {1}" -f $enabledRaw, $iniPath)
    } else {
        throw ("LabVIEW.ini has invalid server.tcp.enabled='{0}' in {1}" -f $enabledRaw, $iniPath)
    }

    $portRaw = Get-LabVIEWIniValueStrict -IniPath $iniPath -Key 'server.tcp.port'
    if ([string]::IsNullOrWhiteSpace($portRaw) -and $contractRemediationEnabled) {
        Set-LabVIEWIniValueStrict -IniPath $iniPath -Key 'server.tcp.port' -Value $expectedPort.ToString()
        $portRaw = $expectedPort.ToString()
        $settingsAdjusted = $true
        Write-Warning ("LabVIEW.ini was missing server.tcp.port; remediated to {0} in {1}" -f $expectedPort, $iniPath)
    }
    if ([string]::IsNullOrWhiteSpace($portRaw)) {
        throw "LabVIEW.ini is missing server.tcp.port in $iniPath"
    }

    $actualPort = 0
    if ((-not [int]::TryParse($portRaw.Trim(), [ref]$actualPort) -or $actualPort -lt 1 -or $actualPort -gt 65535) -and $contractRemediationEnabled) {
        Set-LabVIEWIniValueStrict -IniPath $iniPath -Key 'server.tcp.port' -Value $expectedPort.ToString()
        $actualPort = $expectedPort
        $settingsAdjusted = $true
        Write-Warning ("LabVIEW.ini had invalid server.tcp.port='{0}'; remediated to {1} in {2}" -f $portRaw, $expectedPort, $iniPath)
    } elseif (-not [int]::TryParse($portRaw.Trim(), [ref]$actualPort) -or $actualPort -lt 1 -or $actualPort -gt 65535) {
        throw ("LabVIEW.ini has invalid server.tcp.port='{0}' in {1}" -f $portRaw, $iniPath)
    }

    if ($actualPort -ne $expectedPort -and $contractRemediationEnabled) {
        Set-LabVIEWIniValueStrict -IniPath $iniPath -Key 'server.tcp.port' -Value $expectedPort.ToString()
        $actualPort = $expectedPort
        $settingsAdjusted = $true
        Write-Warning ("LabVIEWCLI port contract mismatch for year {0} bitness {1}; remediated server.tcp.port to {2} in {3}" -f $year, $bitness, $expectedPort, $iniPath)
    } elseif ($actualPort -ne $expectedPort) {
        throw ("LabVIEWCLI port contract mismatch for year {0} bitness {1}: expected {2} from {3}, found {4} in {5}" -f $year, $bitness, $expectedPort, $contractPath, $actualPort, $iniPath)
    }

    if ($settingsAdjusted) {
        Write-Host ("LabVIEWCLI contract remediation applied for year={0} bitness={1} in {2}" -f $year, $bitness, $iniPath)
    }

    return [pscustomobject]@{
        PortNumber   = $expectedPort
        Source       = ('contract:{0} year:{1} bitness:{2}' -f $contractPath, $year, $bitness)
        ContractPath = $contractPath
        IniPath      = $iniPath
        LabVIEWYear  = $year
        Bitness      = $bitness
    }
}

function Resolve-PathFromWorkspace {
    param(
        [string]$WorkspaceRootPath,
        [string]$CandidatePath
    )

    if ([string]::IsNullOrWhiteSpace($CandidatePath)) {
        throw 'Candidate path is required.'
    }

    if ([System.IO.Path]::IsPathRooted($CandidatePath)) {
        return [System.IO.Path]::GetFullPath($CandidatePath)
    }

    return [System.IO.Path]::GetFullPath((Join-Path $WorkspaceRootPath $CandidatePath))
}

function Get-FileSha256Hex {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path
    )

    return (Get-FileHash -LiteralPath $Path -Algorithm SHA256 -ErrorAction Stop).Hash.ToLowerInvariant()
}

function Get-NormalizedRelativePath {
    param(
        [Parameter(Mandatory = $true)]
        [string]$RootPath,
        [Parameter(Mandatory = $true)]
        [string]$Path
    )

    $rootFull = [System.IO.Path]::GetFullPath($RootPath).TrimEnd('\', '/')
    $pathFull = [System.IO.Path]::GetFullPath($Path)
    if (-not $pathFull.StartsWith($rootFull, [System.StringComparison]::OrdinalIgnoreCase)) {
        throw ("Path '{0}' is not under root '{1}'." -f $pathFull, $rootFull)
    }

    $relative = $pathFull.Substring($rootFull.Length).TrimStart('\', '/')
    return ($relative -replace '\\', '/')
}

function New-SourceSyncSnapshotEntry {
    param(
        [Parameter(Mandatory = $true)]
        [string]$SourceRoot,
        [Parameter(Mandatory = $true)]
        [string]$DestinationRoot
    )

    $entries = New-Object 'System.Collections.Generic.List[object]'
    if (-not (Test-Path -LiteralPath $SourceRoot -PathType Container)) {
        return $entries.ToArray()
    }

    $sourceFiles = @(
        Get-ChildItem -LiteralPath $SourceRoot -File -Recurse -Force -ErrorAction Stop |
            Sort-Object FullName
    )

    foreach ($sourceFile in $sourceFiles) {
        $relativePath = Get-NormalizedRelativePath -RootPath $SourceRoot -Path $sourceFile.FullName
        $relativeFsPath = $relativePath -replace '/', '\'
        $destinationPath = Join-Path $DestinationRoot $relativeFsPath
        $destinationExists = Test-Path -LiteralPath $destinationPath -PathType Leaf
        $beforeHash = if ($destinationExists) { Get-FileSha256Hex -Path $destinationPath } else { '' }
        $entries.Add([pscustomobject]@{
                relative_path  = $relativePath
                existed_before = $destinationExists
                before_hash    = $beforeHash
            }) | Out-Null
    }

    return $entries.ToArray()
}

function New-SourceSyncGroup {
    param(
        [Parameter(Mandatory = $true)]
        [string]$GroupId,
        [Parameter(Mandatory = $true)]
        [string]$SourceRoot,
        [Parameter(Mandatory = $true)]
        [string]$DestinationRoot,
        [object[]]$SnapshotEntries
    )

    $files = New-Object 'System.Collections.Generic.List[object]'
    $fileCount = 0
    $addedCount = 0
    $updatedCount = 0
    $unchangedCount = 0
    $missingAfterCount = 0
    $hashMismatchCount = 0

    foreach ($entry in @($SnapshotEntries)) {
        $relativePath = [string]$entry.relative_path
        if ([string]::IsNullOrWhiteSpace($relativePath)) {
            continue
        }

        $relativeFsPath = $relativePath -replace '/', '\'
        $sourcePath = Join-Path $SourceRoot $relativeFsPath
        if (-not (Test-Path -LiteralPath $sourcePath -PathType Leaf)) {
            continue
        }

        $destinationPath = Join-Path $DestinationRoot $relativeFsPath
        $sourceHash = Get-FileSha256Hex -Path $sourcePath
        $destinationExists = Test-Path -LiteralPath $destinationPath -PathType Leaf
        $destinationHash = if ($destinationExists) { Get-FileSha256Hex -Path $destinationPath } else { '' }
        $destinationSize = if ($destinationExists) { [int64](Get-Item -LiteralPath $destinationPath -ErrorAction Stop).Length } else { 0L }

        $classification = ''
        if (-not $destinationExists) {
            $classification = 'missing_after'
            $missingAfterCount++
        } elseif (-not [bool]$entry.existed_before) {
            $classification = 'added'
            $addedCount++
        } elseif ([string]$entry.before_hash -eq $sourceHash) {
            $classification = 'unchanged'
            $unchangedCount++
        } else {
            $classification = 'updated'
            $updatedCount++
        }

        $hashMatches = $destinationExists -and $destinationHash -eq $sourceHash
        if (-not $hashMatches) {
            $hashMismatchCount++
        }

        $fileCount++
        $files.Add([pscustomobject]@{
                relative_path      = $relativePath
                source_path        = $sourcePath
                destination_path   = $destinationPath
                classification     = $classification
                source_sha256      = $sourceHash
                destination_sha256 = $destinationHash
                source_size        = [int64](Get-Item -LiteralPath $sourcePath -ErrorAction Stop).Length
                destination_size   = $destinationSize
                hash_matches       = [bool]$hashMatches
            }) | Out-Null
    }

    return [pscustomobject]@{
        id                 = $GroupId
        source_root        = $SourceRoot
        destination_root   = $DestinationRoot
        file_count         = $fileCount
        added_count        = $addedCount
        updated_count      = $updatedCount
        unchanged_count    = $unchangedCount
        missing_after_count = $missingAfterCount
        hash_mismatch_count = $hashMismatchCount
        files              = $files.ToArray()
    }
}

function Write-SourceSyncManifest {
    param(
        [Parameter(Mandatory = $true)]
        [string]$ManifestPath,
        [Parameter(Mandatory = $true)]
        [string]$RepoRoot,
        [Parameter(Mandatory = $true)]
        [string]$LabVIEWRoot,
        [Parameter(Mandatory = $true)]
        [string]$Context,
        [Parameter(Mandatory = $true)]
        [object[]]$Groups
    )

    $gitSha = 'unknown'
    if (Get-Command git -ErrorAction SilentlyContinue) {
        $resolvedSha = (& git -C $RepoRoot rev-parse HEAD 2>$null)
        if (-not [string]::IsNullOrWhiteSpace($resolvedSha)) {
            $gitSha = $resolvedSha.Trim()
        }
    }

    $summary = [ordered]@{
        file_count          = (@($Groups) | Measure-Object -Property file_count -Sum).Sum
        added_count         = (@($Groups) | Measure-Object -Property added_count -Sum).Sum
        updated_count       = (@($Groups) | Measure-Object -Property updated_count -Sum).Sum
        unchanged_count     = (@($Groups) | Measure-Object -Property unchanged_count -Sum).Sum
        missing_after_count = (@($Groups) | Measure-Object -Property missing_after_count -Sum).Sum
        hash_mismatch_count = (@($Groups) | Measure-Object -Property hash_mismatch_count -Sum).Sum
    }

    foreach ($summaryKey in @('file_count', 'added_count', 'updated_count', 'unchanged_count', 'missing_after_count', 'hash_mismatch_count')) {
        if ($null -eq $summary[$summaryKey]) {
            $summary[$summaryKey] = 0
        }
    }

    $manifest = [ordered]@{
        schema_version = '1.0'
        manifest_kind  = 'source-sync'
        generated_utc  = (Get-Date).ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ssZ')
        git_sha        = $gitSha
        context        = $Context
        repo_root      = $RepoRoot
        labview_root   = $LabVIEWRoot
        groups         = @($Groups)
        summary        = [pscustomobject]$summary
    }

    $manifestParent = Split-Path -Path $ManifestPath -Parent
    if (-not [string]::IsNullOrWhiteSpace($manifestParent)) {
        New-Item -Path $manifestParent -ItemType Directory -Force | Out-Null
    }

    $manifest | ConvertTo-Json -Depth 12 | Set-Content -Path $ManifestPath -Encoding utf8
    return [pscustomobject]$manifest
}

function Sync-IconEditorSourcesForViAnalyzer {
    param(
        [Parameter(Mandatory = $true)]
        [string]$WorkspaceRootPath,
        [Parameter(Mandatory = $true)]
        [string]$LabVIEWExecutablePath,
        [Parameter(Mandatory = $true)]
        [string]$ManifestPath
    )

    if (-not (Test-Path -LiteralPath $WorkspaceRootPath -PathType Container)) {
        throw "Workspace root does not exist: $WorkspaceRootPath"
    }

    $labviewRoot = Split-Path -Path $LabVIEWExecutablePath -Parent
    if ([string]::IsNullOrWhiteSpace($labviewRoot) -or -not (Test-Path -LiteralPath $labviewRoot -PathType Container)) {
        throw "Unable to resolve LabVIEW install root from LabVIEW path: $LabVIEWExecutablePath"
    }

    $repoPlugins = Join-Path $WorkspaceRootPath 'resource\plugins'
    $repoIconApi = Join-Path $WorkspaceRootPath 'vi.lib\LabVIEW Icon API'
    $installPlugins = Join-Path $labviewRoot 'resource\plugins'
    $installIconApi = Join-Path $labviewRoot 'vi.lib\LabVIEW Icon API'
    $requiredPaths = @(
        (Join-Path $repoPlugins 'NIIconEditor'),
        (Join-Path $repoPlugins 'lv_IconEditor.lvlib'),
        (Join-Path $repoPlugins 'lv_icon.vi'),
        $repoIconApi
    )

    foreach ($path in $requiredPaths) {
        if (-not (Test-Path -LiteralPath $path)) {
            throw "Required Icon Editor source path is missing: $path"
        }
    }

    $pluginRootFiles = @('lv_IconEditor.lvlib', 'lv_icon.vi', 'lv_icon.vit', 'SAMPLE_lv_icon.vi')
    $pluginRootStage = Join-Path ([System.IO.Path]::GetTempPath()) ("lvie-source-sync-{0}" -f [Guid]::NewGuid().ToString('N'))
    New-Item -Path $pluginRootStage -ItemType Directory -Force | Out-Null

    try {
        foreach ($fileName in $pluginRootFiles) {
            $sourcePath = Join-Path $repoPlugins $fileName
            if (Test-Path -LiteralPath $sourcePath -PathType Leaf) {
                Copy-Item -LiteralPath $sourcePath -Destination $pluginRootStage -Force
            }
        }

        $snapshotPluginsDir = New-SourceSyncSnapshotEntry `
            -SourceRoot (Join-Path $repoPlugins 'NIIconEditor') `
            -DestinationRoot (Join-Path $installPlugins 'NIIconEditor')
        $snapshotPluginsRootFiles = New-SourceSyncSnapshotEntry `
            -SourceRoot $pluginRootStage `
            -DestinationRoot $installPlugins
        $snapshotIconApi = New-SourceSyncSnapshotEntry `
            -SourceRoot $repoIconApi `
            -DestinationRoot $installIconApi

        New-Item -Path $installPlugins -ItemType Directory -Force | Out-Null
        New-Item -Path $installIconApi -ItemType Directory -Force | Out-Null

        Copy-Item -LiteralPath (Join-Path $repoPlugins 'NIIconEditor') -Destination $installPlugins -Recurse -Force
        foreach ($fileName in $pluginRootFiles) {
            $sourcePath = Join-Path $repoPlugins $fileName
            if (Test-Path -LiteralPath $sourcePath -PathType Leaf) {
                Copy-Item -LiteralPath $sourcePath -Destination $installPlugins -Force
            }
        }
        Get-ChildItem -LiteralPath $repoIconApi -Force | Copy-Item -Destination $installIconApi -Recurse -Force

        $probe = Join-Path $installPlugins 'NIIconEditor\Miscellaneous\Classes Initialization.vi'
        if (-not (Test-Path -LiteralPath $probe -PathType Leaf)) {
            throw "Icon Editor source synchronization failed. Missing probe file: $probe"
        }

        $groups = @(
            (New-SourceSyncGroup `
                -GroupId 'resource-plugins-niiconeditor' `
                -SourceRoot (Join-Path $repoPlugins 'NIIconEditor') `
                -DestinationRoot (Join-Path $installPlugins 'NIIconEditor') `
                -SnapshotEntries $snapshotPluginsDir),
            (New-SourceSyncGroup `
                -GroupId 'resource-plugins-root-files' `
                -SourceRoot $pluginRootStage `
                -DestinationRoot $installPlugins `
                -SnapshotEntries $snapshotPluginsRootFiles),
            (New-SourceSyncGroup `
                -GroupId 'labview-icon-api' `
                -SourceRoot $repoIconApi `
                -DestinationRoot $installIconApi `
                -SnapshotEntries $snapshotIconApi)
        )

        $manifest = Write-SourceSyncManifest `
            -ManifestPath $ManifestPath `
            -RepoRoot $WorkspaceRootPath `
            -LabVIEWRoot $labviewRoot `
            -Context 'vi-analyzer-windows' `
            -Groups $groups

        Write-Output "Synchronized Icon Editor sources into LabVIEW install:"
        Write-Output "  resource\plugins -> $installPlugins"
        Write-Output "  vi.lib\LabVIEW Icon API -> $installIconApi"
        Write-Output "  source sync manifest -> $ManifestPath"
        return $manifest
    } finally {
        if (Test-Path -LiteralPath $pluginRootStage -PathType Container) {
            Remove-Item -LiteralPath $pluginRootStage -Recurse -Force -ErrorAction SilentlyContinue
        }
    }
}

function Get-LabVIEWCliTempLogPath {
    param(
        [string]$TempRoot = ([System.IO.Path]::GetTempPath())
    )

    return @(
        Get-ChildItem -LiteralPath $TempRoot -Filter 'lvtemporary_*.log' -File -ErrorAction SilentlyContinue |
            Sort-Object LastWriteTimeUtc -Descending |
            Select-Object -ExpandProperty FullName
    )
}

function Save-LabVIEWCliLog {
    param(
        [string]$LogRoot,
        [string]$OperationName,
        [string[]]$BeforeLogPaths
    )

    New-Item -Path $LogRoot -ItemType Directory -Force | Out-Null
    $timestamp = Get-Date -Format 'yyyyMMdd-HHmmss'
    $beforeSet = @{}
    foreach ($path in $BeforeLogPaths) {
        if (-not [string]::IsNullOrWhiteSpace($path)) {
            $beforeSet[$path] = $true
        }
    }

    $afterLogPaths = @(Get-LabVIEWCliTempLogPath)
    $newLogPaths = @()
    foreach ($source in $afterLogPaths) {
        if (-not $beforeSet.ContainsKey($source)) {
            $newLogPaths += $source
        }
    }

    if ($newLogPaths.Count -eq 0 -and $afterLogPaths.Count -gt 0) {
        $newLogPaths = @($afterLogPaths[0])
    }

    $copied = @()
    $index = 0
    foreach ($source in $newLogPaths) {
        if (-not (Test-Path -LiteralPath $source -PathType Leaf)) {
            continue
        }
        $index++
        $destination = Join-Path $LogRoot ("{0}-{1}-{2}.log" -f $OperationName.ToLowerInvariant(), $timestamp, $index)
        Copy-Item -LiteralPath $source -Destination $destination -Force
        $copied += $destination
        Write-Output "Captured LabVIEWCLI log: $destination"
    }

    return $copied
}

function Invoke-LabVIEWCliOperation {
    param(
        [string]$OperationName,
        [string[]]$Arguments,
        [string]$LogRoot
    )

    $beforeLogPaths = @(Get-LabVIEWCliTempLogPath)
    $outputLines = $null
    $exitCode = 0
    $previousErrorActionPreference = $ErrorActionPreference
    try {
        # LabVIEWCLI writes progress and operation details to stderr; keep collecting output
        # and rely on explicit exit-code/report checks instead of PowerShell error promotion.
        $ErrorActionPreference = 'Continue'
        $outputLines = & LabVIEWCLI @Arguments 2>&1
        $exitCode = if ($null -eq $LASTEXITCODE) { 0 } else { [int]$LASTEXITCODE }
    } finally {
        $ErrorActionPreference = $previousErrorActionPreference
    }
    $outputText = if ($null -eq $outputLines) {
        ''
    } else {
        @($outputLines | ForEach-Object { $_.ToString() }) -join [Environment]::NewLine
    }
    if (-not [string]::IsNullOrWhiteSpace($outputText)) {
        Write-Output $outputText
    }
    $copiedLogs = Save-LabVIEWCliLog -LogRoot $LogRoot -OperationName $OperationName -BeforeLogPaths $beforeLogPaths

    return [pscustomobject]@{
        ExitCode   = $exitCode
        CopiedLogs = $copiedLogs
        OutputText = $outputText
    }
}

function Get-CountFromText {
    param(
        [AllowNull()]
        [string]$Text,
        [string]$Pattern
    )

    if ([string]::IsNullOrWhiteSpace($Text)) {
        return $null
    }

    $match = [regex]::Match($Text, $Pattern, [System.Text.RegularExpressions.RegexOptions]::IgnoreCase -bor [System.Text.RegularExpressions.RegexOptions]::Multiline)
    if (-not $match.Success) {
        return $null
    }

    return [int]$match.Groups['n'].Value
}

function Get-ViAnalyzerCountSummary {
    param(
        [AllowNull()]
        [string]$ReportText
    )

    $counts = [ordered]@{
        passed          = Get-CountFromText -Text $ReportText -Pattern '^\s*Passed Tests\s+(?<n>\d+)\s*$'
        failed          = Get-CountFromText -Text $ReportText -Pattern '^\s*Failed Tests\s+(?<n>\d+)\s*$'
        skipped         = Get-CountFromText -Text $ReportText -Pattern '^\s*Skipped Tests\s+(?<n>\d+)\s*$'
        vi_unloadable   = Get-CountFromText -Text $ReportText -Pattern '^\s*VI not loadable\s+(?<n>\d+)\s*$'
        test_unloadable = Get-CountFromText -Text $ReportText -Pattern '^\s*Test not loadable\s+(?<n>\d+)\s*$'
        test_unrunnable = Get-CountFromText -Text $ReportText -Pattern '^\s*Test not runnable\s+(?<n>\d+)\s*$'
        test_error      = Get-CountFromText -Text $ReportText -Pattern '^\s*Test error out\s+(?<n>\d+)\s*$'
    }

    $analyzedTotal = 0
    foreach ($key in @('passed', 'failed', 'skipped', 'vi_unloadable', 'test_unloadable', 'test_unrunnable', 'test_error')) {
        $value = $counts[$key]
        if ($null -ne $value) {
            $analyzedTotal += [int]$value
        }
    }
    $counts['analyzed_total'] = $analyzedTotal
    return $counts
}

function Get-ViAnalyzerFailureItemList {
    param(
        [AllowNull()]
        [string]$ReportText
    )

    $items = New-Object 'System.Collections.Generic.List[object]'
    if ([string]::IsNullOrWhiteSpace($ReportText)) {
        return $items.ToArray()
    }

    $section = ''
    $currentDisplayName = ''
    $currentFilePath = ''
    $lines = $ReportText -split "`r?`n"
    foreach ($line in $lines) {
        $trimmed = $line.Trim()
        if ($trimmed -match '^\s*Failed Tests \(sorted by VI\)\s*$') {
            $section = 'failed_tests'
            $currentDisplayName = ''
            $currentFilePath = ''
            continue
        }

        if ($trimmed -match '^\s*Testing Errors\s*$') {
            $section = 'testing_errors'
            $currentDisplayName = ''
            $currentFilePath = ''
            continue
        }

        if ([string]::IsNullOrWhiteSpace($section)) {
            continue
        }

        if ([string]::IsNullOrWhiteSpace($trimmed)) {
            continue
        }

        if ($trimmed -eq '(none)') {
            continue
        }

        $viHeaderMatch = [regex]::Match($trimmed, '^(?<display>.+?)\s+\((?<path>.+)\)\s*$')
        if ($viHeaderMatch.Success -and $trimmed.IndexOf("`t") -lt 0) {
            $currentDisplayName = $viHeaderMatch.Groups['display'].Value.Trim()
            $currentFilePath = $viHeaderMatch.Groups['path'].Value.Trim()
            continue
        }

        $parts = $line -split "`t", 2
        if ($parts.Count -eq 2 -and -not [string]::IsNullOrWhiteSpace($parts[0]) -and -not [string]::IsNullOrWhiteSpace($parts[1])) {
            $items.Add([pscustomobject]@{
                    section         = $section
                    vi_display_name = $currentDisplayName
                    file_path       = $currentFilePath
                    check_name      = $parts[0].Trim()
                    message         = $parts[1].Trim()
                    raw_line        = $line.Trim()
                }) | Out-Null
        }
    }

    return $items.ToArray()
}

function Get-OrderedUniqueFilePathList {
    param([object[]]$Items)

    $ordered = New-Object 'System.Collections.Generic.List[string]'
    $seen = New-Object 'System.Collections.Generic.HashSet[string]'
    foreach ($item in @($Items)) {
        $path = ''
        if ($null -ne $item -and $item.PSObject.Properties.Name -contains 'file_path') {
            $path = [string]$item.file_path
        }

        if ([string]::IsNullOrWhiteSpace($path)) {
            continue
        }

        if ($seen.Add($path)) {
            $ordered.Add($path) | Out-Null
        }
    }

    return $ordered.ToArray()
}

$defaultDrive = if ([string]::IsNullOrWhiteSpace($env:SystemDrive)) { 'C:' } else { $env:SystemDrive }
$defaultRepoRoot = Join-Path -Path ("{0}\" -f $defaultDrive.TrimEnd('\')) -ChildPath 'workspace'

$repoRootResolution = Resolve-LvieRepoRoot `
    -LvieRepoRoot $env:LVIE_REPO_ROOT `
    -WorkspaceRoot $WorkspaceRoot `
    -RepoRoot $env:REPO_ROOT `
    -DefaultRepoRoot $defaultRepoRoot
$WorkspaceRoot = $repoRootResolution.Path

$tasksPathResolved = Resolve-PathFromWorkspace -WorkspaceRootPath $WorkspaceRoot -CandidatePath $TasksPath
$reportsRootResolved = Resolve-PathFromWorkspace -WorkspaceRootPath $WorkspaceRoot -CandidatePath $ReportsRoot
$statusPathResolved = Resolve-PathFromWorkspace -WorkspaceRootPath $WorkspaceRoot -CandidatePath $StatusPath
$sourceSyncManifestPathRaw = if (-not [string]::IsNullOrWhiteSpace($SourceSyncManifestPath)) {
    $SourceSyncManifestPath
} elseif (-not [string]::IsNullOrWhiteSpace($env:LVIE_SOURCE_SYNC_MANIFEST_PATH)) {
    $env:LVIE_SOURCE_SYNC_MANIFEST_PATH
} else {
    'builds\status\source-sync-manifest-vi-analyzer-windows.json'
}
$sourceSyncManifestPathResolved = Resolve-PathFromWorkspace -WorkspaceRootPath $WorkspaceRoot -CandidatePath $sourceSyncManifestPathRaw
$logRoot = Join-Path $WorkspaceRoot 'TestResults\container-parity\windows\vi-analyzer\logs'

New-Item -Path $reportsRootResolved -ItemType Directory -Force | Out-Null
New-Item -Path (Split-Path -Path $statusPathResolved -Parent) -ItemType Directory -Force | Out-Null
New-Item -Path $logRoot -ItemType Directory -Force | Out-Null

if (-not (Test-Path -LiteralPath $tasksPathResolved -PathType Leaf)) {
    throw "VI Analyzer task registry was not found: $tasksPathResolved"
}

$versionResolution = Resolve-LabVIEWContractYear -RepoRoot $WorkspaceRoot -VersionHint $LabVIEWVersion
if ([string]::IsNullOrWhiteSpace($LabVIEWPath)) {
    $LabVIEWPath = "C:\Program Files\National Instruments\LabVIEW $($versionResolution.Year)\LabVIEW.exe"
}

if (-not (Get-Command LabVIEWCLI -ErrorAction SilentlyContinue)) {
    throw "LabVIEWCLI is not available on PATH inside the container."
}

$portResolution = Resolve-LabVIEWCliPort `
    -RepoRootPath $WorkspaceRoot `
    -LabVIEWExecutablePath $LabVIEWPath `
    -LabVIEWContractBitness $LabVIEWBitness

Write-Host ("Resolved repo root: {0} (source: {1})" -f $WorkspaceRoot, $repoRootResolution.Source)
Write-Host ("Resolved VI Analyzer tasks path: {0}" -f $tasksPathResolved)
Write-Host ("Resolved VI Analyzer reports root: {0}" -f $reportsRootResolved)
Write-Host ("Resolved VI Analyzer status path: {0}" -f $statusPathResolved)
Write-Host ("Resolved VI Analyzer source sync manifest path: {0}" -f $sourceSyncManifestPathResolved)
Write-Host ("Using LabVIEW path: {0}" -f $LabVIEWPath)
Write-Host ("Using LabVIEWCLI port: {0}" -f $portResolution.PortNumber)

$tasksDoc = Get-Content -LiteralPath $tasksPathResolved -Raw -ErrorAction Stop | ConvertFrom-Json -ErrorAction Stop
$tasks = @($tasksDoc.tasks)
if ($tasks.Count -eq 0) {
    throw "VI Analyzer tasks file contains no tasks: $tasksPathResolved"
}

$sourceSyncManifest = $null
Write-Host "Synchronizing workspace Icon Editor sources into LabVIEW install before VI Analyzer."
$sourceSyncManifest = Sync-IconEditorSourcesForViAnalyzer `
    -WorkspaceRootPath $WorkspaceRoot `
    -LabVIEWExecutablePath $LabVIEWPath `
    -ManifestPath $sourceSyncManifestPathResolved

$taskResults = New-Object System.Collections.Generic.List[object]
$overallSuccess = $true

foreach ($task in $tasks) {
    $taskId = [string]$task.id
    $taskConfigPath = [string]$task.config_path
    if ([string]::IsNullOrWhiteSpace($taskId)) {
        throw "VI Analyzer task is missing required field 'id' in $tasksPathResolved"
    }
    if ([string]::IsNullOrWhiteSpace($taskConfigPath)) {
        throw "VI Analyzer task '$taskId' is missing required field 'config_path' in $tasksPathResolved"
    }

    $configPathResolved = Resolve-PathFromWorkspace -WorkspaceRootPath $WorkspaceRoot -CandidatePath $taskConfigPath
    if (-not (Test-Path -LiteralPath $configPathResolved -PathType Leaf)) {
        throw "VI Analyzer config not found for task '$taskId': $configPathResolved"
    }

    $safeTaskId = ($taskId -replace '[^A-Za-z0-9_.-]', '-')
    $reportPath = Join-Path $reportsRootResolved ("vi-analyzer-{0}.txt" -f $safeTaskId)
    if (Test-Path -LiteralPath $reportPath -PathType Leaf) {
        Remove-Item -LiteralPath $reportPath -Force -ErrorAction SilentlyContinue
    }

    Write-Host ""
    Write-Host ("=== VI Analyzer task: {0} ===" -f $taskId)
    $runResult = Invoke-LabVIEWCliOperation -OperationName ("RunVIAnalyzer-{0}" -f $safeTaskId) -LogRoot $logRoot -Arguments @(
        '-LogToConsole', 'TRUE',
        '-OperationName', 'RunVIAnalyzer',
        '-LabVIEWPath', $LabVIEWPath,
        '-PortNumber', $portResolution.PortNumber.ToString(),
        '-ConfigPath', $configPathResolved,
        '-ReportPath', $reportPath,
        '-ReportSaveType', 'ASCII',
        '-Headless'
    )

    $reportText = if (Test-Path -LiteralPath $reportPath -PathType Leaf) {
        Get-Content -LiteralPath $reportPath -Raw -ErrorAction Stop
    } else {
        ''
    }
    $counts = Get-ViAnalyzerCountSummary -ReportText $reportText
    $failureItems = @(Get-ViAnalyzerFailureItemList -ReportText $reportText)
    $failureFilePaths = @(Get-OrderedUniqueFilePathList -Items $failureItems)

    $failureReasons = New-Object System.Collections.Generic.List[string]
    if ($runResult.ExitCode -ne 0) {
        $failureReasons.Add(("Non-zero exit code: {0}" -f $runResult.ExitCode)) | Out-Null
    }
    if (-not (Test-Path -LiteralPath $reportPath -PathType Leaf)) {
        $failureReasons.Add('Report file missing.') | Out-Null
    }
    if ($null -eq $counts.analyzed_total -or [int]$counts.analyzed_total -le 0) {
        $failureReasons.Add('No tests were analyzed (analyzed_total = 0).') | Out-Null
    }
    foreach ($failKey in @('failed', 'vi_unloadable', 'test_unloadable', 'test_unrunnable', 'test_error')) {
        $value = $counts[$failKey]
        if ($null -ne $value -and [int]$value -gt 0) {
            $failureReasons.Add(("{0} count is {1}" -f $failKey, $value)) | Out-Null
        }
    }

    $taskSucceeded = $failureReasons.Count -eq 0
    if (-not $taskSucceeded) {
        $overallSuccess = $false
        Write-Host ("Task '{0}' failed with reason(s): {1}" -f $taskId, (@($failureReasons) -join '; '))
        if ($failureFilePaths.Count -gt 0) {
            Write-Host ("Task '{0}' failed file path(s): {1}" -f $taskId, ($failureFilePaths -join '; '))
            foreach ($filePath in $failureFilePaths) {
                Write-Host ("- File: {0}" -f $filePath)
                foreach ($item in @($failureItems | Where-Object { $_.file_path -eq $filePath })) {
                    Write-Host ("  - [{0}] {1}: {2}" -f $item.section, $item.check_name, $item.message)
                }
            }
        } else {
            Write-Host ("Task '{0}' produced no parsable file-level failure entries; see raw report: {1}" -f $taskId, $reportPath)
        }
    }

    $taskResults.Add([pscustomobject]@{
            id              = $taskId
            config_path     = $configPathResolved
            report_path     = $reportPath
            exit_code       = [int]$runResult.ExitCode
            succeeded       = $taskSucceeded
            counts          = [pscustomobject]$counts
            failure_reasons = @($failureReasons)
            failure_items   = @($failureItems)
            failure_file_paths = @($failureFilePaths)
        }) | Out-Null
}

$status = [ordered]@{
    generated_utc   = (Get-Date).ToUniversalTime().ToString('o')
    repo_root       = $WorkspaceRoot
    tasks_path      = $tasksPathResolved
    reports_root    = $reportsRootResolved
    source_sync_manifest_path = $sourceSyncManifestPathResolved
    overall_success = $overallSuccess
    task_count      = $taskResults.Count
    labview         = [ordered]@{
        raw             = [string]$versionResolution.RawVersion
        year            = [string]$portResolution.LabVIEWYear
        bitness         = [string]$portResolution.Bitness
        executable_path = $LabVIEWPath
    }
    port            = [ordered]@{
        number        = [int]$portResolution.PortNumber
        source        = [string]$portResolution.Source
        contract_path = [string]$portResolution.ContractPath
        ini_path      = [string]$portResolution.IniPath
    }
    container_contract = [ordered]@{
        raw         = $env:LVIE_CONTAINER_CONTRACT_RAW
        tag         = $env:LVIE_CONTAINER_CONTRACT_TAG
        image       = $env:LVIE_CONTAINER_CONTRACT_IMAGE
        os          = $env:LVIE_CONTAINER_CONTRACT_OS
        release_tag = $env:LVIE_CONTAINER_CONTRACT_RELEASE_TAG
    }
    source_sync     = [ordered]@{
        context = if ($null -ne $sourceSyncManifest -and $sourceSyncManifest.PSObject.Properties.Name -contains 'context') {
            [string]$sourceSyncManifest.context
        } else {
            'vi-analyzer-windows'
        }
        summary = if ($null -ne $sourceSyncManifest -and $sourceSyncManifest.PSObject.Properties.Name -contains 'summary') {
            $sourceSyncManifest.summary
        } else {
            $null
        }
    }
    task_results    = $taskResults
}

$status | ConvertTo-Json -Depth 8 | Set-Content -Path $statusPathResolved -Encoding utf8
Write-Host ("VI Analyzer status written: {0}" -f $statusPathResolved)

if (-not $overallSuccess) {
    $failedTasks = @($taskResults | Where-Object { -not $_.succeeded })
    $failedTaskIds = if ($failedTasks.Count -gt 0) {
        @($failedTasks | ForEach-Object { $_.id }) -join ', '
    } else {
        'unknown'
    }
    throw ("Windows-container VI Analyzer detected one or more task failures. Failed tasks: {0}. Status path: {1}" -f $failedTaskIds, $statusPathResolved)
}

Write-Host 'Windows-container VI Analyzer completed with no failures.'
