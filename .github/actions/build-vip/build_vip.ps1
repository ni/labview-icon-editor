<#
.SYNOPSIS
    Updates a VIPB file's display information and builds the VI package.

.DESCRIPTION
    Resolves paths, merges version details into DisplayInformation JSON, and
    invokes VIPM CLI to build the final VI package.

.PARAMETER SupportedBitness
    LabVIEW bitness for the build ("32" or "64").

.PARAMETER RepoRoot
    Path to the repository root.

.PARAMETER VIPBPath
    Relative path to the VIPB file to update.

.PARAMETER LabVIEWVersion
    LabVIEW major version year (e.g., 2021).

.PARAMETER LabVIEWMinorRevision
    Minor revision number of LabVIEW (e.g., 0 for 21.0).

.PARAMETER Major
    Major version component for the package.

.PARAMETER Minor
    Minor version component for the package.

.PARAMETER Patch
    Patch version component for the package.

.PARAMETER Build
    Build number component for the package.

.PARAMETER Commit
    Commit identifier embedded in the package metadata.

.PARAMETER ReleaseNotesFile
    Path to a release notes file injected into the build.

.PARAMETER DisplayInformationJSON
    JSON string representing the VIPB display information to update.

.EXAMPLE
    .\build_vip.ps1 -SupportedBitness "64" -RepoRoot "C:\repo" -VIPBPath "Tooling\deployment\NI Icon editor.vipb" -Major 1 -Minor 0 -Patch 0 -Build 2 -Commit "abcd123" -ReleaseNotesFile "Tooling\deployment\release_notes.md" -DisplayInformationJSON '{"Package Version":{"major":1,"minor":0,"patch":0,"build":2}}'
#>

param (
    [string]$SupportedBitness,
    [string]$RepoRoot,
    [string]$VIPBPath,
    [string]$WorktreeRoot,
    [switch]$SkipWorktreeRootCheck,

    [string]$LabVIEWVersion,

    [ValidateRange(0, 99)]
    [int]$LabVIEWMinorRevision = 0,

    [int]$Major,
    [int]$Minor,
    [int]$Patch,
    [int]$Build,
    [string]$Commit,
    [string]$ReleaseNotesFile,

    [string]$DisplayInformationJSON,
    [string]$DisplayInformationJsonPath,

    [ValidateRange(60, 3600)]
    [int]$VipmTimeoutSeconds = 300
)

# 1) Resolve paths
try {
    $ResolvedRepoRoot = (Resolve-Path -Path $RepoRoot -ErrorAction Stop).Path
    $ResolvedVIPBPath = Join-Path -Path $ResolvedRepoRoot -ChildPath $VIPBPath -ErrorAction Stop
}
catch {
    $errorObject = [PSCustomObject]@{
        error      = "Error resolving paths. Ensure RepoRoot and VIPBPath are valid."
        exception  = $_.Exception.Message
        stackTrace = $_.Exception.StackTrace
    }
    $errorObject | ConvertTo-Json -Depth 10
    exit 1
}

# 1a) Worktree preflight (optional for local runs)
$preflightScript = Join-Path -Path $ResolvedRepoRoot -ChildPath 'Tooling\Invoke-Preflight.ps1'
if (Test-Path -Path $preflightScript) {
    . $preflightScript
    $scriptArgs = Convert-BoundParametersToArgumentList -BoundParameters $PSBoundParameters
    $relativeScript = if ($PSCommandPath) { Get-RepoRelativePath -RepoRoot $ResolvedRepoRoot -Path $PSCommandPath } else { $null }
    $preflight = Invoke-Preflight `
        -RepoRoot $ResolvedRepoRoot `
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
    $ResolvedRepoRoot = $preflight.RepoRoot
}

# 1b) Resolve LabVIEW version against .lvversion (fail-fast on mismatch)
$versionHelper = Join-Path $ResolvedRepoRoot 'Tooling\support\LabVIEWVersion.ps1'
if (Test-Path -Path $versionHelper) {
    . $versionHelper
    $repoInfo = Get-LabVIEWVersionInfo -RepoRoot $ResolvedRepoRoot
    $inputProvided = $PSBoundParameters.ContainsKey('LabVIEWVersion') -and -not [string]::IsNullOrWhiteSpace([string]$LabVIEWVersion)
    if ($inputProvided) {
        $inputInfo = Get-LabVIEWVersionInfo -VersionInput $LabVIEWVersion -RepoRoot $ResolvedRepoRoot
        $LabVIEWVersion = [int]$inputInfo.Year
    } else {
        $LabVIEWVersion = [int]$repoInfo.Year
        Write-Warning "LabVIEWVersion not provided; defaulting to .lvversion ($($repoInfo.Raw))."
    }

    if ($PSBoundParameters.ContainsKey('LabVIEWMinorRevision')) {
        if ([int]$LabVIEWMinorRevision -ne [int]$repoInfo.MinorRevision) {
            throw "LabVIEWMinorRevision '$LabVIEWMinorRevision' does not match .lvversion minor '$($repoInfo.MinorRevision)'."
        }
    } else {
        $LabVIEWMinorRevision = [int]$repoInfo.MinorRevision
    }
}

function Get-VipmTargetVersionLabel {
    param(
        [Parameter(Mandatory = $true)]
        [string]$LabVIEWNumericVersion,
        [Parameter(Mandatory = $true)]
        [ValidateSet('32', '64')]
        [string]$Bitness
    )

    if ($Bitness -eq '64') {
        return "$LabVIEWNumericVersion (64-bit)"
    }

    return $LabVIEWNumericVersion
}

function Get-VipmSettingsPath {
    if ([string]::IsNullOrWhiteSpace($env:ProgramData)) {
        throw 'ProgramData is not defined; cannot resolve VIPM settings file.'
    }

    return Join-Path -Path $env:ProgramData -ChildPath 'JKI\VIPM\Settings.ini'
}

function Get-VipmTargetsSectionInfo {
    param(
        [Parameter(Mandatory = $true)]
        [string[]]$Lines
    )

    $inTargets = $false
    $versions = @{}
    $portsLineIndex = -1
    $portsSize = 0
    $ports = @()
    $connectionTimeoutLineIndex = -1
    $connectionTimeoutValue = $null

    for ($index = 0; $index -lt $Lines.Count; $index++) {
        $line = [string]$Lines[$index]
        $sectionMatch = [regex]::Match($line, '^\s*\[(?<name>[^\]]+)\]\s*$')
        if ($sectionMatch.Success) {
            $sectionName = $sectionMatch.Groups['name'].Value.Trim()
            if ($sectionName -eq 'Targets') {
                $inTargets = $true
                continue
            }

            if ($inTargets) {
                break
            }
        }

        if (-not $inTargets) {
            continue
        }

        $versionMatch = [regex]::Match($line, '^\s*Versions\s+(?<idx>\d+)\s*=\s*"(?<value>.*)"\s*$')
        if ($versionMatch.Success) {
            $versions[[int]$versionMatch.Groups['idx'].Value] = $versionMatch.Groups['value'].Value
            continue
        }

        $portsMatch = [regex]::Match($line, '^\s*Ports\s*=\s*"(?<value><size\(s\)=\d+>.*)"\s*$')
        if ($portsMatch.Success) {
            $portsLineIndex = $index
            $portsRaw = $portsMatch.Groups['value'].Value
            $sizeMatch = [regex]::Match($portsRaw, '<size\(s\)=(?<n>\d+)>')
            if ($sizeMatch.Success) {
                $portsSize = [int]$sizeMatch.Groups['n'].Value
                $rest = $portsRaw.Substring($sizeMatch.Index + $sizeMatch.Length).Trim()
                if (-not [string]::IsNullOrWhiteSpace($rest)) {
                    $ports = @($rest -split '\s+')
                }
            }
            continue
        }

        $timeoutMatch = [regex]::Match($line, '^\s*Connection Timeout\s*=\s*"(?<value>\d+)"\s*$')
        if ($timeoutMatch.Success) {
            $connectionTimeoutLineIndex = $index
            $connectionTimeoutValue = [int]$timeoutMatch.Groups['value'].Value
        }
    }

    return [pscustomobject]@{
        Versions                   = $versions
        PortsLineIndex             = $portsLineIndex
        PortsSize                  = $portsSize
        Ports                      = @($ports)
        ConnectionTimeoutLineIndex = $connectionTimeoutLineIndex
        ConnectionTimeoutValue     = $connectionTimeoutValue
    }
}

function Set-VipmTargetSettingsFromContract {
    [CmdletBinding(SupportsShouldProcess = $true)]
    param(
        [Parameter(Mandatory = $true)]
        [string]$RepoRoot,
        [Parameter(Mandatory = $true)]
        [string]$VersionYear,
        [Parameter(Mandatory = $true)]
        [ValidateRange(0, 99)]
        [int]$MinorRevision,
        [Parameter(Mandatory = $true)]
        [ValidateSet('32', '64')]
        [string]$Bitness,
        [Parameter(Mandatory = $true)]
        [ValidateRange(60, 3600)]
        [int]$ConnectionTimeoutSeconds
    )

    $labviewExecutablePathHelper = Join-Path $RepoRoot 'Tooling\support\LabVIEWExecutablePath.ps1'
    if (-not (Test-Path -Path $labviewExecutablePathHelper -PathType Leaf)) {
        throw "LabVIEW executable resolver helper not found at $labviewExecutablePathHelper"
    }

    $portContractHelper = Join-Path $RepoRoot 'Tooling\support\LabVIEWCliPortContract.ps1'
    if (-not (Test-Path -Path $portContractHelper -PathType Leaf)) {
        throw "LabVIEW CLI port contract helper not found at $portContractHelper"
    }

    . $labviewExecutablePathHelper
    . $portContractHelper

    $numericVersion = "{0}.{1}" -f ([int]$VersionYear - 2000), $MinorRevision
    $targetVersionLabel = Get-VipmTargetVersionLabel -LabVIEWNumericVersion $numericVersion -Bitness $Bitness
    $settingsPath = Get-VipmSettingsPath
    if (-not (Test-Path -Path $settingsPath -PathType Leaf)) {
        throw "VIPM settings file not found at $settingsPath"
    }

    $lines = @(Get-Content -Path $settingsPath -ErrorAction Stop)
    $sectionInfo = Get-VipmTargetsSectionInfo -Lines $lines
    if ($sectionInfo.PortsLineIndex -lt 0) {
        throw "VIPM settings file '$settingsPath' does not define Targets.Ports."
    }
    if ($sectionInfo.ConnectionTimeoutLineIndex -lt 0) {
        throw "VIPM settings file '$settingsPath' does not define Targets.Connection Timeout."
    }
    if ($sectionInfo.Versions.Count -eq 0) {
        throw "VIPM settings file '$settingsPath' does not define Targets.Versions entries."
    }

    $targetIndex = $null
    foreach ($entry in $sectionInfo.Versions.GetEnumerator() | Sort-Object Key) {
        if ([string]::Equals([string]$entry.Value, $targetVersionLabel, [System.StringComparison]::OrdinalIgnoreCase)) {
            $targetIndex = [int]$entry.Key
            break
        }
    }
    if ($null -eq $targetIndex) {
        throw ("VIPM settings file '{0}' does not define target version '{1}' under [Targets]." -f $settingsPath, $targetVersionLabel)
    }

    $labviewExecutablePath = Resolve-LabVIEWExecutablePath -VersionYear $VersionYear -Bitness $Bitness
    $portResolution = Resolve-LabVIEWCliPortFromContract `
        -RepoRoot $RepoRoot `
        -LabVIEWVersion $numericVersion `
        -Bitness $Bitness `
        -LabVIEWExecutablePath $labviewExecutablePath
    $expectedPort = [int]$portResolution.PortNumber

    $ports = New-Object 'System.Collections.Generic.List[string]'
    foreach ($entry in @($sectionInfo.Ports)) {
        $ports.Add([string]$entry) | Out-Null
    }
    while ($ports.Count -lt [int]$sectionInfo.PortsSize) {
        $ports.Add('0') | Out-Null
    }
    while ($ports.Count -le $targetIndex) {
        $ports.Add('0') | Out-Null
    }

    $updated = $false
    $currentPort = [string]$ports[$targetIndex]
    if ($currentPort -ne $expectedPort.ToString()) {
        Write-Output ("Updating VIPM target port for '{0}' (index {1}) from {2} to {3}." -f $targetVersionLabel, $targetIndex, $currentPort, $expectedPort)
        $ports[$targetIndex] = $expectedPort.ToString()
        $updated = $true
    } else {
        Write-Output ("VIPM target port already matches contract for '{0}': {1}" -f $targetVersionLabel, $expectedPort)
    }

    $currentTimeout = [int]$sectionInfo.ConnectionTimeoutValue
    if ($currentTimeout -ne $ConnectionTimeoutSeconds) {
        Write-Output ("Updating VIPM Connection Timeout from {0} to {1} seconds." -f $currentTimeout, $ConnectionTimeoutSeconds)
        $lines[$sectionInfo.ConnectionTimeoutLineIndex] = ('Connection Timeout="{0}"' -f $ConnectionTimeoutSeconds)
        $updated = $true
    } else {
        Write-Output ("VIPM Connection Timeout already set to {0} seconds." -f $currentTimeout)
    }

    if ($updated -and $PSCmdlet.ShouldProcess($settingsPath, 'Synchronize VIPM target port and connection timeout with LabVIEW contract')) {
        $portsSize = $ports.Count
        $portsValue = if ($portsSize -gt 0) {
            "<size(s)=$portsSize> " + (($ports.ToArray()) -join ' ')
        } else {
            "<size(s)=0>"
        }
        $lines[$sectionInfo.PortsLineIndex] = ('Ports="{0}"' -f $portsValue)
        Set-Content -Path $settingsPath -Value $lines -Encoding utf8
        Write-Output ("VIPM settings synchronized to LabVIEW CLI contract: {0}" -f $settingsPath)
    }
}

# 1b) Ensure VI Package output directory exists to avoid VIPM prompts
$artifactRoot = $env:LVIE_ARTIFACT_ROOT
$vipOutputDir = if ([string]::IsNullOrWhiteSpace($artifactRoot)) {
    Join-Path -Path $ResolvedRepoRoot -ChildPath "builds/VI Package"
} else {
    Join-Path -Path $artifactRoot -ChildPath "builds/VI Package"
}
New-Item -ItemType Directory -Path $vipOutputDir -Force | Out-Null

# 1c) Resolve VIPB output folder + package name to pre-clean existing VIP
$vipbOutputDir = $null
$packageFileName = $null
try {
    $vipbXml = [xml](Get-Content -Raw -Path $ResolvedVIPBPath)
    $general = $vipbXml.VI_Package_Builder_Settings.Library_General_Settings
    if ($general) {
        $packageFileName = $general.Package_File_Name
        $outputFolder = $general.Library_Output_Folder
        if (-not [string]::IsNullOrWhiteSpace($outputFolder)) {
            $vipbRoot = Split-Path -Path $ResolvedVIPBPath -Parent
            $vipbOutputDir = if ([System.IO.Path]::IsPathRooted($outputFolder)) {
                $outputFolder
            } else {
                Join-Path -Path $vipbRoot -ChildPath $outputFolder
            }
            $vipbOutputDir = [System.IO.Path]::GetFullPath($vipbOutputDir)
        }
    }
} catch {
    Write-Warning ("Failed to parse VIPB output folder: {0}" -f $_.Exception.Message)
}

# 2) Create release notes if needed and resolve the paths
if (-not (Test-Path $ReleaseNotesFile)) {
    Write-Host "Release notes file '$ReleaseNotesFile' does not exist. Creating it..."
    New-Item -ItemType File -Path $ReleaseNotesFile -Force | Out-Null
}

try {
    $ResolvedReleaseNotesFile = Resolve-Path -Path $ReleaseNotesFile -ErrorAction Stop
}
catch {
    $errorObject = [PSCustomObject]@{
        error      = "Error resolving ReleaseNotesFile. Ensure the path exists and is accessible."
        exception  = $_.Exception.Message
        stackTrace = $_.Exception.StackTrace
    }
    $errorObject | ConvertTo-Json -Depth 10
    exit 1
}

# 3a) Ensure build log directory exists for troubleshooting
$LogDirectory = if ([string]::IsNullOrWhiteSpace($artifactRoot)) {
    Join-Path -Path $ResolvedRepoRoot -ChildPath "builds/logs"
} else {
    Join-Path -Path $artifactRoot -ChildPath "builds/logs"
}
New-Item -ItemType Directory -Path $LogDirectory -Force | Out-Null

# 3) Calculate the LabVIEW version string
$lvNumericMajor    = $LabVIEWVersion - 2000
$lvNumericVersion  = "$($lvNumericMajor).$LabVIEWMinorRevision"
if ($SupportedBitness -eq "64") {
    $VIP_LVVersion_A = "$lvNumericVersion (64-bit)"
}
else {
    $VIP_LVVersion_A = $lvNumericVersion
}
Write-Output "Building VI Package for LabVIEW $VIP_LVVersion_A..."

# 4) Resolve and parse DisplayInformation JSON
$resolvedDisplayJson = $DisplayInformationJSON
if ([string]::IsNullOrWhiteSpace($resolvedDisplayJson) -and -not [string]::IsNullOrWhiteSpace($DisplayInformationJsonPath)) {
    if (-not (Test-Path -Path $DisplayInformationJsonPath)) {
        $errorObject = [PSCustomObject]@{
            error      = "DisplayInformationJsonPath '$DisplayInformationJsonPath' does not exist."
        }
        $errorObject | ConvertTo-Json -Depth 10
        exit 1
    }
    $resolvedDisplayJson = Get-Content -Raw -Path $DisplayInformationJsonPath
}
if ([string]::IsNullOrWhiteSpace($resolvedDisplayJson) -and -not [string]::IsNullOrWhiteSpace($env:DISPLAY_INFORMATION_JSON)) {
    $resolvedDisplayJson = $env:DISPLAY_INFORMATION_JSON
}
if ([string]::IsNullOrWhiteSpace($resolvedDisplayJson)) {
    $errorObject = [PSCustomObject]@{
        error = "DisplayInformationJSON was not provided. Pass -DisplayInformationJSON, -DisplayInformationJsonPath, or set DISPLAY_INFORMATION_JSON."
    }
    $errorObject | ConvertTo-Json -Depth 10
    exit 1
}

try {
    $jsonObj = $resolvedDisplayJson | ConvertFrom-Json
}
catch {
    $errorObject = [PSCustomObject]@{
        error      = "Failed to parse DisplayInformation JSON."
        exception  = $_.Exception.Message
        stackTrace = $_.Exception.StackTrace
    }
    $errorObject | ConvertTo-Json -Depth 10
    exit 1
}

# If "Package Version" doesn't exist, create it as a subobject
if (-not $jsonObj.'Package Version') {
    $jsonObj | Add-Member -MemberType NoteProperty -Name 'Package Version' -Value ([PSCustomObject]@{
        major = $Major
        minor = $Minor
        patch = $Patch
        build = $Build
    })
}
else {
    # "Package Version" exists, so just overwrite its fields
    $jsonObj.'Package Version'.major = $Major
    $jsonObj.'Package Version'.minor = $Minor
    $jsonObj.'Package Version'.patch = $Patch
    $jsonObj.'Package Version'.build = $Build
}

# 5a) Pre-clean existing VIP in the configured output folder to avoid VIPM error 10
$vipBaseName = if (-not [string]::IsNullOrWhiteSpace($packageFileName)) {
    $packageFileName
} else {
    [System.IO.Path]::GetFileNameWithoutExtension($ResolvedVIPBPath)
}
$vipVersion = "$Major.$Minor.$Patch.$Build"
$vipName = "{0}-{1}.vip" -f $vipBaseName, $vipVersion
$outputDirToClean = if (-not [string]::IsNullOrWhiteSpace($vipbOutputDir)) { $vipbOutputDir } else { $vipOutputDir }
if (-not (Test-Path -Path $outputDirToClean)) {
    New-Item -ItemType Directory -Path $outputDirToClean -Force | Out-Null
}
$vipFullPath = Join-Path -Path $outputDirToClean -ChildPath $vipName
if (Test-Path -Path $vipFullPath) {
    Write-Host ("Removing existing VIP to avoid overwrite error: {0}" -f $vipFullPath)
    Remove-Item -Path $vipFullPath -Force -ErrorAction SilentlyContinue
}

# 6) Construct reusable VIPM CLI arguments
$vipmCommand = Get-Command vipm -ErrorAction SilentlyContinue
if (-not $vipmCommand) {
    $errorObject = [PSCustomObject]@{
        error = "VIPM CLI is not available on PATH."
    }
    $errorObject | ConvertTo-Json -Depth 10
    exit 1
}

$vipmArgs = @(
    '--labview-version', $LabVIEWVersion.ToString(),
    '--labview-bitness', $SupportedBitness,
    'build',
    $ResolvedVIPBPath
)

$prettyCommand = "{0} {1}" -f $vipmCommand.Source, ($vipmArgs -join ' ')
Write-Output "Base build command:"
Write-Output $prettyCommand
Write-Output ("Release notes source: {0}" -f $ResolvedReleaseNotesFile)
Write-Output ("Build metadata: version={0}.{1}.{2}.{3} commit={4}" -f $Major, $Minor, $Patch, $Build, $Commit)

# 6a) Keep VIPM target connection settings aligned with strict LabVIEWCLI contract.
Set-VipmTargetSettingsFromContract `
    -RepoRoot $ResolvedRepoRoot `
    -VersionYear $LabVIEWVersion.ToString() `
    -MinorRevision $LabVIEWMinorRevision `
    -Bitness $SupportedBitness `
    -ConnectionTimeoutSeconds $VipmTimeoutSeconds

# 7) Execute the command once with log capture
$logFile = Join-Path -Path $LogDirectory -ChildPath "vipm-build.log"
Write-Host "Starting VIPM CLI build. Logs: $logFile"

$runnerHelper = Join-Path -Path $ResolvedRepoRoot -ChildPath 'Tooling\support\GcliRunner.ps1'
if (-not (Test-Path -Path $runnerHelper -PathType Leaf)) {
    $errorObject = [PSCustomObject]@{
        error = "Command runner helper not found at $runnerHelper."
    }
    $errorObject | ConvertTo-Json -Depth 10
    exit 1
}

. $runnerHelper

$timeoutMs = [int]([Math]::Min([long]$VipmTimeoutSeconds * 1000, 2147483647))
$commandResult = Invoke-GCliCommand -ExecutablePath $vipmCommand.Source -Arguments $vipmArgs -TimeoutMs $timeoutMs
$combinedOutput = @()
if ($commandResult.OutputLines) {
    $combinedOutput += @($commandResult.OutputLines)
}
if ($commandResult.ErrorLines) {
    $combinedOutput += @($commandResult.ErrorLines)
}
if ($combinedOutput.Count -gt 0) {
    $combinedOutput | Set-Content -Path $logFile -Encoding utf8
} else {
    '' | Set-Content -Path $logFile -Encoding utf8
}

$effectiveExitCode = if ($commandResult.TimedOut) { 124 } else { [int]$commandResult.ExitCode }
if ($commandResult.TimedOut) {
    $timeoutLine = ("Timeout waiting on VIPM after {0} seconds." -f $VipmTimeoutSeconds)
    Add-Content -Path $logFile -Value $timeoutLine
    Write-Warning $timeoutLine
}

if ($effectiveExitCode -ne 0) {
    if (Test-Path $logFile) {
        Write-Host ("---- VIPM CLI build log ({0}) ----" -f $logFile)
        Get-Content -Path $logFile | ForEach-Object { Write-Host $_ }
        Write-Host ("---- end VIPM CLI build log ----")
    }
    else {
        Write-Host ("VIPM CLI build log not found at {0}" -f $logFile)
    }

    $errorObject = [PSCustomObject]@{
        error    = if ($commandResult.TimedOut) { "VIPM CLI build timed out." } else { "VIPM CLI build failed." }
        exitCode = $effectiveExitCode
        log      = $logFile
    }
    $errorObject | ConvertTo-Json -Depth 10
    exit 1
}

Write-Host "Successfully built VI package: $ResolvedVIPBPath"

if (-not [string]::IsNullOrWhiteSpace($artifactRoot)) {
    try {
        $vipCandidates = Get-ChildItem -Path $ResolvedRepoRoot -Recurse -Filter *.vip -ErrorAction SilentlyContinue
        $latestVip = $vipCandidates | Sort-Object -Property LastWriteTime -Descending | Select-Object -First 1
        if ($latestVip) {
            $targetPath = Join-Path $vipOutputDir $latestVip.Name
            Copy-Item -Path $latestVip.FullName -Destination $targetPath -Force
            Write-Host ("Copied .vip to artifact root: {0}" -f $targetPath)
        }
    } catch {
        Write-Warning ("Failed to copy .vip to artifact root: {0}" -f $_.Exception.Message)
    }
}
