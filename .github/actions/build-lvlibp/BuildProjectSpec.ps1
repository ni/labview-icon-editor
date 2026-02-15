<#
.SYNOPSIS
    Builds a LabVIEW project specification using LabVIEWCLI.

.DESCRIPTION
    Mirrors container parity pre-steps on Windows hosts by running a staged
    LabVIEWCLI MassCompile and Icon Editor source synchronization before
    invoking a project build specification via LabVIEWCLI ExecuteBuildSpec.
    Supports packed library and source distribution build-spec contracts.
    Build-spec version values are stamped from semantic version inputs for
    packed-library builds, and the project file is restored from backup in
    all cases.

.PARAMETER LabVIEWVersion
    LabVIEW version year (e.g., 2021) or numeric version (e.g., 21.0).

.PARAMETER SupportedBitness
    Bitness of the LabVIEW environment ("32" or "64").

.PARAMETER RepoRoot
    Path to the repository root where the project file resides.

.PARAMETER ProjectSpecType
    Project spec contract to execute: PackedLibrary or SourceDistribution.

.PARAMETER BuildSpecName
    LabVIEW project build specification name.
    PackedLibrary defaults to "Editor Packed Library".
    SourceDistribution requires an explicit value.

.PARAMETER OutputRelativePath
    Output artifact path relative to RepoRoot.
    PackedLibrary defaults to "resource/plugins/lv_icon.lvlibp".
    SourceDistribution requires an explicit value.

.PARAMETER TargetName
    LabVIEW project target name. Defaults to "My Computer".

.PARAMETER Major
    Major version component for packed-library version stamping.

.PARAMETER Minor
    Minor version component for the PPL.

.PARAMETER Patch
    Patch version component for the PPL.

.PARAMETER Build
    Build number component for the PPL.

.PARAMETER Commit
    Commit hash or identifier recorded in the build.

.EXAMPLE
    .\BuildProjectSpec.ps1 -SupportedBitness "64" -RepoRoot "C:\labview-icon-editor" -ProjectSpecType PackedLibrary -Major 1 -Minor 0 -Patch 0 -Build 0 -Commit "Placeholder"
#>
param(
    [AllowNull()]
    [AllowEmptyString()]
    [string]$LabVIEWVersion = '',
    [ValidateSet('32', '64')]
    [string]$SupportedBitness,
    [string]$RepoRoot,
    [string]$WorktreeRoot,
    [switch]$SkipWorktreeRootCheck,
    [ValidateSet('PackedLibrary', 'SourceDistribution')]
    [string]$ProjectSpecType = 'PackedLibrary',
    [AllowNull()]
    [AllowEmptyString()]
    [string]$BuildSpecName = '',
    [AllowNull()]
    [AllowEmptyString()]
    [string]$OutputRelativePath = '',
    [AllowNull()]
    [AllowEmptyString()]
    [string]$TargetName = 'My Computer',
    [Int32]$Major,
    [Int32]$Minor,
    [Int32]$Patch,
    [Int32]$Build,
    [string]$Commit,
    [ValidateRange(0, 600000)]
    [int]$ConnectTimeoutMs = 0
)

$ErrorActionPreference = 'Stop'

Write-Output "Project spec version inputs: $Major.$Minor.$Patch.$Build"
Write-Output "Commit: $Commit"

function Resolve-ProjectSpecOptions {
    param(
        [Parameter(Mandatory = $true)]
        [ValidateSet('PackedLibrary', 'SourceDistribution')]
        [string]$SpecType,
        [AllowNull()]
        [AllowEmptyString()]
        [string]$SpecName,
        [AllowNull()]
        [AllowEmptyString()]
        [string]$RelativeOutputPath,
        [AllowNull()]
        [AllowEmptyString()]
        [string]$ResolvedTargetName
    )

    $targetNameValue = if ([string]::IsNullOrWhiteSpace($ResolvedTargetName)) { 'My Computer' } else { $ResolvedTargetName.Trim() }
    $specNameValue = if ([string]::IsNullOrWhiteSpace($SpecName)) { $null } else { $SpecName.Trim() }
    $outputPathValue = if ([string]::IsNullOrWhiteSpace($RelativeOutputPath)) { $null } else { $RelativeOutputPath.Trim() }

    if ($SpecType -eq 'PackedLibrary') {
        if ([string]::IsNullOrWhiteSpace($specNameValue)) {
            $specNameValue = 'Editor Packed Library'
        }
        if ([string]::IsNullOrWhiteSpace($outputPathValue)) {
            $outputPathValue = 'resource/plugins/lv_icon.lvlibp'
        }
    } else {
        if ([string]::IsNullOrWhiteSpace($specNameValue)) {
            throw "BuildSpecName is required when ProjectSpecType=SourceDistribution."
        }
        if ([string]::IsNullOrWhiteSpace($outputPathValue)) {
            throw "OutputRelativePath is required when ProjectSpecType=SourceDistribution."
        }
    }

    return [pscustomobject]@{
        ProjectSpecType = $SpecType
        BuildSpecName = $specNameValue
        OutputRelativePath = $outputPathValue
        TargetName = $targetNameValue
    }
}

$projectSpec = Resolve-ProjectSpecOptions `
    -SpecType $ProjectSpecType `
    -SpecName $BuildSpecName `
    -RelativeOutputPath $OutputRelativePath `
    -ResolvedTargetName $TargetName

Write-Output ("ProjectSpecType: {0}" -f $projectSpec.ProjectSpecType)
Write-Output ("BuildSpecName: {0}" -f $projectSpec.BuildSpecName)
Write-Output ("OutputRelativePath: {0}" -f $projectSpec.OutputRelativePath)
Write-Output ("TargetName: {0}" -f $projectSpec.TargetName)

if ($ConnectTimeoutMs -gt 0) {
    Write-Host ("ConnectTimeoutMs ({0}) is ignored for LabVIEWCLI-based project-spec builds." -f $ConnectTimeoutMs)
}

$resolvedRepoRoot = $RepoRoot
if ($resolvedRepoRoot) {
    $resolvedRepoRoot = (Resolve-Path -Path $resolvedRepoRoot -ErrorAction Stop).Path
    $RepoRoot = $resolvedRepoRoot
    $preflightScript = Join-Path -Path $resolvedRepoRoot -ChildPath 'Tooling\Invoke-Preflight.ps1'
    if (Test-Path -Path $preflightScript) {
        . $preflightScript
        $scriptArgs = Convert-BoundParametersToArgumentList -BoundParameters $PSBoundParameters
        $relativeScript = if ($PSCommandPath) { Get-RepoRelativePath -RepoRoot $resolvedRepoRoot -Path $PSCommandPath } else { $null }
        $preflight = Invoke-Preflight `
            -RepoRoot $resolvedRepoRoot `
            -WorktreeRoot $WorktreeRoot `
            -LabVIEWVersion $LabVIEWVersion `
            -LabVIEWBitness $SupportedBitness `
            -SkipWorktreeRootCheck:$SkipWorktreeRootCheck `
            -AutoWorktree:$false `
            -ScriptPath $relativeScript `
            -ScriptArguments $scriptArgs
        if ($preflight.Reinvoked) {
            return
        }
        $resolvedRepoRoot = $preflight.RepoRoot
        $RepoRoot = $resolvedRepoRoot
    }
}

if ([string]::IsNullOrWhiteSpace($RepoRoot)) {
    throw "RepoRoot is required."
}

$projectPath = Join-Path -Path $RepoRoot -ChildPath 'lv_icon_editor.lvproj'
if (-not (Test-Path -Path $projectPath -PathType Leaf)) {
    throw "Project file not found at $projectPath"
}

$labviewYear = $LabVIEWVersion
if ($RepoRoot) {
    $versionHelper = Join-Path -Path $RepoRoot -ChildPath 'Tooling\support\LabVIEWVersion.ps1'
    if (Test-Path -Path $versionHelper) {
        . $versionHelper
        $versionInfo = Get-LabVIEWVersionInfo -VersionInput $LabVIEWVersion -RepoRoot $RepoRoot
        $labviewYear = $versionInfo.Year
    }
}
if ([string]::IsNullOrWhiteSpace($labviewYear)) {
    throw "LabVIEW version could not be resolved. Check .lvversion."
}

$labviewExeResolver = Join-Path -Path $RepoRoot -ChildPath 'Tooling\support\LabVIEWExecutablePath.ps1'
if (-not (Test-Path -Path $labviewExeResolver -PathType Leaf)) {
    throw "LabVIEW executable path resolver not found at $labviewExeResolver"
}
. $labviewExeResolver
$labviewExecutablePath = Resolve-LabVIEWExecutablePath -VersionYear $labviewYear -Bitness $SupportedBitness

$labviewCliCommand = Get-Command LabVIEWCLI -ErrorAction SilentlyContinue
if (-not $labviewCliCommand) {
    throw "LabVIEWCLI is not available on PATH. Install/enable LabVIEWCLI before running BuildProjectSpec.ps1."
}

function ConvertTo-LabVIEWCliPortNumber {
    param(
        [AllowNull()]
        [AllowEmptyString()]
        [string]$RawValue,
        [string]$Source
    )

    if ([string]::IsNullOrWhiteSpace($RawValue)) {
        return $null
    }

    $parsed = 0
    if ([int]::TryParse($RawValue.Trim(), [ref]$parsed) -and $parsed -ge 1 -and $parsed -le 65535) {
        return [int]$parsed
    }

    Write-Warning ("Ignoring invalid LabVIEWCLI port '{0}' from {1}; expected 1-65535." -f $RawValue, $Source)
    return $null
}

function Get-LabVIEWIniValue {
    param(
        [Parameter(Mandatory = $true)]
        [string]$IniPath,
        [Parameter(Mandatory = $true)]
        [string]$Key
    )

    foreach ($line in Get-Content -Path $IniPath -ErrorAction SilentlyContinue) {
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
        if (-not $lineKey.Equals($Key, [System.StringComparison]::OrdinalIgnoreCase)) {
            continue
        }

        return $trimmed.Substring($separator + 1).Trim()
    }

    return $null
}

function Resolve-LabVIEWCliPort {
    param(
        [Parameter(Mandatory = $true)]
        [ValidateSet('32', '64')]
        [string]$Bitness,
        [Parameter(Mandatory = $true)]
        [string]$LabVIEWExecutablePath
    )

    $envCandidates = @(
        "LVIE_LABVIEWCLI_PORT_{0}" -f $Bitness,
        'LVIE_LABVIEWCLI_PORT',
        "LVIE_LUNIT_PORT_{0}" -f $Bitness,
        'LVIE_LUNIT_PORT'
    )

    foreach ($name in $envCandidates) {
        $value = [Environment]::GetEnvironmentVariable($name)
        $port = ConvertTo-LabVIEWCliPortNumber -RawValue $value -Source ('$env:{0}' -f $name)
        if ($null -ne $port) {
            return [pscustomobject]@{
                PortNumber = [int]$port
                Source = '$env:{0}' -f $name
            }
        }
    }

    $iniPath = Join-Path -Path (Split-Path -Path $LabVIEWExecutablePath -Parent) -ChildPath 'LabVIEW.ini'
    if (Test-Path -Path $iniPath -PathType Leaf) {
        $enabledRaw = Get-LabVIEWIniValue -IniPath $iniPath -Key 'server.tcp.enabled'
        if (-not [string]::IsNullOrWhiteSpace($enabledRaw)) {
            $normalizedEnabled = $enabledRaw.Trim().ToLowerInvariant()
            if (@('false', '0', 'off', 'no') -contains $normalizedEnabled) {
                throw ("VI server TCP is disabled in {0}. Enable server.tcp.enabled or set LVIE_LABVIEWCLI_PORT_{1}/LVIE_LABVIEWCLI_PORT." -f $iniPath, $Bitness)
            }
        }

        $iniPort = ConvertTo-LabVIEWCliPortNumber -RawValue (Get-LabVIEWIniValue -IniPath $iniPath -Key 'server.tcp.port') -Source ('{0} (server.tcp.port)' -f $iniPath)
        if ($null -ne $iniPort) {
            return [pscustomobject]@{
                PortNumber = [int]$iniPort
                Source = '{0} (server.tcp.port)' -f $iniPath
            }
        }
    }

    return [pscustomobject]@{
        PortNumber = 3363
        Source = 'default:3363'
    }
}

function Invoke-CloseLabVIEWSafely {
    param(
        [string]$Version,
        [string]$Bitness
    )

    $closeScript = Join-Path -Path $RepoRoot -ChildPath '.github\actions\close-labview\Close_LabVIEW.ps1'
    if (Test-Path -Path $closeScript) {
        try {
            & $closeScript -LabVIEWVersion $Version -SupportedBitness $Bitness | Out-Null
        } catch {
            Write-Warning ("Close_LabVIEW.ps1 failed: {0}" -f $_.Exception.Message)
        }
    } else {
        Write-Warning ("Close_LabVIEW.ps1 not found at {0}. Skipping close attempt." -f $closeScript)
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

function Copy-LabVIEWCliLogs {
    param(
        [string[]]$BeforePaths,
        [string]$LogRoot,
        [string]$OperationName = 'executebuildspec'
    )

    New-Item -Path $LogRoot -ItemType Directory -Force | Out-Null
    $beforeSet = @{}
    foreach ($path in $BeforePaths) {
        if (-not [string]::IsNullOrWhiteSpace($path)) {
            $beforeSet[$path] = $true
        }
    }

    $afterPaths = @(Get-LabVIEWCliTempLogPath)
    $newPaths = @()
    foreach ($path in $afterPaths) {
        if (-not $beforeSet.ContainsKey($path)) {
            $newPaths += $path
        }
    }
    if ($newPaths.Count -eq 0 -and $afterPaths.Count -gt 0) {
        $newPaths = @($afterPaths[0])
    }

    $timestamp = Get-Date -Format 'yyyyMMdd-HHmmss'
    $copiedPaths = @()
    $index = 0
    foreach ($sourcePath in $newPaths) {
        if (-not (Test-Path -LiteralPath $sourcePath -PathType Leaf)) {
            continue
        }

        $index++
        $destination = Join-Path -Path $LogRoot -ChildPath ("labviewcli-{0}-{1}-{2}.log" -f $OperationName.ToLowerInvariant(), $timestamp, $index)
        Copy-Item -LiteralPath $sourcePath -Destination $destination -Force
        $copiedPaths += $destination
        Write-Host ("Captured LabVIEWCLI log: {0}" -f $destination)
    }

    return @($copiedPaths)
}

function Set-BuildSpecVersionProperty {
    param(
        [Parameter(Mandatory = $true)]
        [System.Xml.XmlDocument]$ProjectXml,
        [Parameter(Mandatory = $true)]
        [System.Xml.XmlElement]$BuildSpecNode,
        [Parameter(Mandatory = $true)]
        [string]$PropertySuffix,
        [Parameter(Mandatory = $true)]
        [int]$Value
    )

    $propertyName = "Bld_version.{0}" -f $PropertySuffix
    $propertyNode = $BuildSpecNode.SelectSingleNode("Property[@Name='$propertyName']")
    if ($null -eq $propertyNode) {
        $propertyNode = $ProjectXml.CreateElement('Property')
        $null = $propertyNode.SetAttribute('Name', $propertyName)
        $null = $propertyNode.SetAttribute('Type', 'Int')
        $null = $BuildSpecNode.AppendChild($propertyNode)
    }

    $propertyNode.InnerText = [string]$Value
}

function Set-BuildSpecVersionValues {
    param(
        [Parameter(Mandatory = $true)]
        [string]$ProjectPath,
        [Parameter(Mandatory = $true)]
        [string]$BuildSpecName,
        [Parameter(Mandatory = $true)]
        [int]$Major,
        [Parameter(Mandatory = $true)]
        [int]$Minor,
        [Parameter(Mandatory = $true)]
        [int]$Patch,
        [Parameter(Mandatory = $true)]
        [int]$Build
    )

    $projectXml = New-Object System.Xml.XmlDocument
    $projectXml.PreserveWhitespace = $true
    $projectXml.Load($ProjectPath)

    $buildSpecNode = $null
    foreach ($candidate in @($projectXml.SelectNodes('//Item[@Name]'))) {
        if (($candidate -is [System.Xml.XmlElement]) -and $candidate.GetAttribute('Name').Equals($BuildSpecName, [System.StringComparison]::OrdinalIgnoreCase)) {
            $buildSpecNode = $candidate
            break
        }
    }
    if ($null -eq $buildSpecNode) {
        throw ("Build specification '{0}' was not found in {1}" -f $BuildSpecName, $ProjectPath)
    }

    if (-not ($buildSpecNode -is [System.Xml.XmlElement])) {
        throw ("Build specification node for '{0}' is not an XML element." -f $BuildSpecName)
    }

    Set-BuildSpecVersionProperty -ProjectXml $projectXml -BuildSpecNode $buildSpecNode -PropertySuffix 'major' -Value $Major
    Set-BuildSpecVersionProperty -ProjectXml $projectXml -BuildSpecNode $buildSpecNode -PropertySuffix 'minor' -Value $Minor
    Set-BuildSpecVersionProperty -ProjectXml $projectXml -BuildSpecNode $buildSpecNode -PropertySuffix 'patch' -Value $Patch
    Set-BuildSpecVersionProperty -ProjectXml $projectXml -BuildSpecNode $buildSpecNode -PropertySuffix 'build' -Value $Build

    $projectXml.Save($ProjectPath)
}

function Resolve-TargetDirectoryForMassCompile {
    param(
        [Parameter(Mandatory = $true)]
        [string]$RepoRootPath
    )

    $targetDirRelativePath = if ([string]::IsNullOrWhiteSpace($env:TARGET_DIR_REL)) {
        'Test\Templates'
    } else {
        $env:TARGET_DIR_REL
    }

    if (-not [string]::IsNullOrWhiteSpace($env:TARGET_DIR)) {
        return [pscustomobject]@{
            Path   = $env:TARGET_DIR
            Source = '$env:TARGET_DIR'
        }
    }

    return [pscustomobject]@{
        Path   = Join-Path -Path $RepoRootPath -ChildPath $targetDirRelativePath
        Source = '$env:TARGET_DIR_REL'
    }
}

function Get-ExcludedTemplateList {
    $excludeRaw = $env:CONTAINER_PARITY_EXCLUDE_FILES
    if ([string]::IsNullOrWhiteSpace($excludeRaw)) {
        $excludeRaw = 'Polymorphic Template.vi'
    }

    return @(
        $excludeRaw.Split(';', [System.StringSplitOptions]::RemoveEmptyEntries) |
            ForEach-Object { $_.Trim() } |
            Where-Object { -not [string]::IsNullOrWhiteSpace($_) }
    )
}

function Sync-IconEditorSourcesForBuildSpec {
    param(
        [Parameter(Mandatory = $true)]
        [string]$RepoRootPath,
        [Parameter(Mandatory = $true)]
        [string]$LabVIEWExecutablePath
    )

    if (-not (Test-Path -LiteralPath $RepoRootPath -PathType Container)) {
        throw "Workspace root does not exist: $RepoRootPath"
    }

    $labviewRoot = Split-Path -Path $LabVIEWExecutablePath -Parent
    if ([string]::IsNullOrWhiteSpace($labviewRoot) -or -not (Test-Path -LiteralPath $labviewRoot -PathType Container)) {
        throw "Unable to resolve LabVIEW install root from LabVIEW path: $LabVIEWExecutablePath"
    }

    $repoPlugins = Join-Path -Path $RepoRootPath -ChildPath 'resource\plugins'
    $repoIconApi = Join-Path -Path $RepoRootPath -ChildPath 'vi.lib\LabVIEW Icon API'
    $requiredPaths = @(
        (Join-Path -Path $repoPlugins -ChildPath 'NIIconEditor'),
        (Join-Path -Path $repoPlugins -ChildPath 'lv_IconEditor.lvlib'),
        (Join-Path -Path $repoPlugins -ChildPath 'lv_icon.vi'),
        $repoIconApi
    )

    foreach ($requiredPath in $requiredPaths) {
        if (-not (Test-Path -LiteralPath $requiredPath)) {
            throw "Required Icon Editor source path is missing: $requiredPath"
        }
    }

    $installPlugins = Join-Path -Path $labviewRoot -ChildPath 'resource\plugins'
    $installIconApi = Join-Path -Path $labviewRoot -ChildPath 'vi.lib\LabVIEW Icon API'
    New-Item -Path $installPlugins -ItemType Directory -Force | Out-Null
    New-Item -Path $installIconApi -ItemType Directory -Force | Out-Null

    Copy-Item -LiteralPath (Join-Path -Path $repoPlugins -ChildPath 'NIIconEditor') -Destination $installPlugins -Recurse -Force

    foreach ($fileName in @('lv_IconEditor.lvlib', 'lv_icon.vi', 'lv_icon.vit', 'SAMPLE_lv_icon.vi')) {
        $sourcePath = Join-Path -Path $repoPlugins -ChildPath $fileName
        if (Test-Path -LiteralPath $sourcePath -PathType Leaf) {
            Copy-Item -LiteralPath $sourcePath -Destination $installPlugins -Force
        }
    }

    Get-ChildItem -LiteralPath $repoIconApi -Force | Copy-Item -Destination $installIconApi -Recurse -Force

    $probe = Join-Path -Path $installPlugins -ChildPath 'NIIconEditor\Miscellaneous\Classes Initialization.vi'
    if (-not (Test-Path -LiteralPath $probe -PathType Leaf)) {
        throw "Icon Editor source synchronization failed. Missing probe file: $probe"
    }

    Write-Output "Synchronized Icon Editor sources into LabVIEW install:"
    Write-Output "  resource\plugins -> $installPlugins"
    Write-Output "  vi.lib\LabVIEW Icon API -> $installIconApi"
}

function Invoke-LabVIEWCliOperation {
    param(
        [Parameter(Mandatory = $true)]
        [string]$OperationName,
        [Parameter(Mandatory = $true)]
        [string[]]$Arguments,
        [Parameter(Mandatory = $true)]
        [string]$LogRoot
    )

    $beforeLogs = @(Get-LabVIEWCliTempLogPath)

    Write-Output "Executing the following command:"
    Write-Output ("LabVIEWCLI {0}" -f ($Arguments -join ' '))
    $outputLines = & $labviewCliCommand.Source @Arguments 2>&1
    $exitCode = if ($null -eq $LASTEXITCODE) { 0 } else { [int]$LASTEXITCODE }

    foreach ($line in @($outputLines)) {
        if ($null -ne $line) {
            Write-Host $line
        }
    }

    $capturedLogs = Copy-LabVIEWCliLogs -BeforePaths $beforeLogs -LogRoot $LogRoot -OperationName $OperationName
    if ($capturedLogs.Count -eq 0) {
        Write-Warning ("No LabVIEWCLI temporary logs were discovered to copy for operation '{0}'." -f $OperationName)
    }

    return [pscustomobject]@{
        ExitCode = $exitCode
    }
}

$logsDir = Join-Path -Path $RepoRoot -ChildPath 'builds\logs'
New-Item -Path $logsDir -ItemType Directory -Force | Out-Null

$outputPath = Join-Path -Path $RepoRoot -ChildPath $projectSpec.OutputRelativePath
$backupPath = Join-Path -Path ([System.IO.Path]::GetTempPath()) -ChildPath ("lv_icon_editor.lvproj.{0}.bak" -f ([Guid]::NewGuid().ToString('N')))
$backupPathForMessage = $backupPath
Copy-Item -Path $projectPath -Destination $backupPath -Force

$buildError = $null
$restoreError = $null
$stagingDir = $null

try {
    if ($projectSpec.ProjectSpecType -eq 'PackedLibrary') {
        Set-BuildSpecVersionValues -ProjectPath $projectPath -BuildSpecName $projectSpec.BuildSpecName -Major $Major -Minor $Minor -Patch $Patch -Build $Build
    }

    $targetDirInfo = Resolve-TargetDirectoryForMassCompile -RepoRootPath $RepoRoot
    if (-not (Test-Path -LiteralPath $targetDirInfo.Path -PathType Container)) {
        throw "Target directory does not exist: $($targetDirInfo.Path)"
    }

    $excludeTemplates = @(Get-ExcludedTemplateList)
    $stagingDir = Join-Path ([System.IO.Path]::GetTempPath()) ("lvie-parity-{0}" -f [Guid]::NewGuid().ToString('N'))
    New-Item -Path $stagingDir -ItemType Directory -Force | Out-Null
    Copy-Item -Path (Join-Path $targetDirInfo.Path '*') -Destination $stagingDir -Recurse -Force

    foreach ($relativePath in $excludeTemplates) {
        $candidate = Join-Path -Path $stagingDir -ChildPath $relativePath
        if (Test-Path -LiteralPath $candidate) {
            Write-Output "Excluding template from parity compile: $relativePath"
            Remove-Item -LiteralPath $candidate -Recurse -Force
        }
    }

    $portResolution = Resolve-LabVIEWCliPort -Bitness $SupportedBitness -LabVIEWExecutablePath $labviewExecutablePath
    Write-Host ("Using LabVIEWCLI PortNumber: {0} (source: {1})" -f $portResolution.PortNumber, $portResolution.Source)
    Write-Output ("Resolved target directory: {0} (source: {1})" -f $targetDirInfo.Path, $targetDirInfo.Source)
    Write-Output ("Excluded templates: {0}" -f ($excludeTemplates -join '; '))
    Write-Output ("Staging directory: {0}" -f $stagingDir)

    Write-Output "Running LabVIEWCLI MassCompile in headless mode."
    $massCompileArgs = @(
        '-LogToConsole', 'TRUE',
        '-OperationName', 'MassCompile',
        '-DirectoryToCompile', $stagingDir,
        '-LabVIEWPath', $labviewExecutablePath,
        '-PortNumber', $portResolution.PortNumber.ToString(),
        '-Headless'
    )
    $massCompileResult = Invoke-LabVIEWCliOperation -OperationName 'masscompile' -Arguments $massCompileArgs -LogRoot $logsDir
    if ($massCompileResult.ExitCode -ne 0) {
        throw "LabVIEWCLI MassCompile failed with exit code $($massCompileResult.ExitCode)."
    }
    Write-Output "MassCompile completed successfully."

    Write-Output "Synchronizing workspace Icon Editor sources into LabVIEW install before build-spec execution."
    Sync-IconEditorSourcesForBuildSpec -RepoRootPath $RepoRoot -LabVIEWExecutablePath $labviewExecutablePath

    if (Test-Path -Path $outputPath -PathType Leaf) {
        Remove-Item -Path $outputPath -Force
    }

    $buildStartUtc = (Get-Date).ToUniversalTime()
    Write-Output ("Running LabVIEWCLI ExecuteBuildSpec in headless mode for {0}." -f $projectSpec.ProjectSpecType)
    $labviewCliArgs = @(
        '-LogToConsole', 'TRUE',
        '-OperationName', 'ExecuteBuildSpec',
        '-ProjectPath', $projectPath,
        '-BuildSpecName', $projectSpec.BuildSpecName,
        '-TargetName', $projectSpec.TargetName,
        '-LabVIEWPath', $labviewExecutablePath,
        '-PortNumber', $portResolution.PortNumber.ToString(),
        '-Headless'
    )

    $buildSpecResult = Invoke-LabVIEWCliOperation -OperationName 'executebuildspec' -Arguments $labviewCliArgs -LogRoot $logsDir
    if ($buildSpecResult.ExitCode -ne 0) {
        throw "LabVIEWCLI ExecuteBuildSpec failed with exit code $($buildSpecResult.ExitCode)."
    }

    if (-not (Test-Path -Path $outputPath -PathType Leaf)) {
        throw "Build specification output not found at expected path: $outputPath"
    }

    $outputItem = Get-Item -Path $outputPath -ErrorAction Stop
    if ($outputItem.LastWriteTimeUtc -lt $buildStartUtc) {
        throw ("Build specification output is stale and was not updated by this run: {0}" -f $outputItem.FullName)
    }

    Write-Host ("Build succeeded: {0} ({1} bytes)." -f $outputItem.FullName, $outputItem.Length)
}
catch {
    $buildError = $_
}
finally {
    if (-not [string]::IsNullOrWhiteSpace($stagingDir) -and (Test-Path -LiteralPath $stagingDir -PathType Container)) {
        Remove-Item -LiteralPath $stagingDir -Recurse -Force -ErrorAction SilentlyContinue
    }

    try {
        if (-not (Test-Path -Path $backupPathForMessage -PathType Leaf)) {
            throw "Project backup was not found at '$backupPathForMessage'."
        }

        Copy-Item -Path $backupPathForMessage -Destination $projectPath -Force
        Remove-Item -Path $backupPathForMessage -Force -ErrorAction SilentlyContinue
        Write-Host ("Restored project file from backup: {0}" -f $backupPathForMessage)
    }
    catch {
        $restoreError = $_
    }

    try {
        Invoke-CloseLabVIEWSafely -Version $labviewYear -Bitness $SupportedBitness
    }
    catch {
        Write-Warning ("Close LabVIEW cleanup failed: {0}" -f $_.Exception.Message)
    }
}

if ($restoreError) {
    $restoreMessage = @(
        ("Failed to restore project file '{0}' from backup '{1}'." -f $projectPath, $backupPathForMessage)
        ("Manual recovery command: Copy-Item -LiteralPath '{0}' -Destination '{1}' -Force" -f $backupPathForMessage, $projectPath)
    ) -join ' '

    if ($buildError) {
        throw ("{0} {1}" -f $buildError.Exception.Message, $restoreMessage)
    }

    throw $restoreMessage
}

if ($buildError) {
    throw $buildError
}

exit 0

