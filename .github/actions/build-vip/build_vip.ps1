<#
.SYNOPSIS
    Updates a VIPB file's display information and builds the VI package.

.DESCRIPTION
    Resolves paths, merges version details into DisplayInformation JSON, and
    calls g-cli to modify the VIPB file and create the final VI package.

.PARAMETER SupportedBitness
    LabVIEW bitness for the build ("32" or "64").

.PARAMETER RepoRoot
    Path to the repository root.

.PARAMETER VIPBPath
    Relative path to the VIPB file to update.

.PARAMETER LabVIEWVersion
    LabVIEW major version year (e.g., 2021).
    Alias: MinimumSupportedLVVersion.

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
    .\build_vip.ps1 -SupportedBitness "64" -RepoRoot "C:\repo" -VIPBPath "Tooling\deployment\NI Icon editor.vipb" -LabVIEWVersion 2021 -LabVIEWMinorRevision 0 -Major 1 -Minor 0 -Patch 0 -Build 2 -Commit "abcd123" -ReleaseNotesFile "Tooling\deployment\release_notes.md" -DisplayInformationJSON '{"Package Version":{"major":1,"minor":0,"patch":0,"build":2}}'
#>

param (
    [string]$SupportedBitness,
    [string]$RepoRoot,
    [string]$VIPBPath,
    [string]$WorktreeRoot,
    [switch]$SkipWorktreeRootCheck,

    [Alias('MinimumSupportedLVVersion')]
    [ValidateRange(2000, 2100)]
    [int]$LabVIEWVersion,

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

# Re-convert to a JSON string with a comfortable nesting depth
$UpdatedDisplayInformationJSON = $jsonObj | ConvertTo-Json -Depth 5

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

# 6) Construct reusable g-cli arguments
$gcliArgs = @(
    "--lv-ver", $LabVIEWVersion.ToString(),
    "--arch", $SupportedBitness,
    "--connect-timeout", "120000",
    "--kill",
    "--kill-timeout", "20000",
    "--verbose",
    "vipb", "--",
    "--buildspec", $ResolvedVIPBPath,
    "-v", "$Major.$Minor.$Patch.$Build",
    "--release-notes", $ResolvedReleaseNotesFile,
    "--timeout", $VipmTimeoutSeconds.ToString()
)

$prettyCommand = "g-cli " + ($gcliArgs -join ' ')
Write-Output "Base build command:"
Write-Output $prettyCommand

# 7) Execute the command once with log capture
$logFile = Join-Path -Path $LogDirectory -ChildPath "gcli-build.log"
Write-Host "Starting g-cli build. Logs: $logFile"

try {
    & g-cli @gcliArgs 2>&1 | Tee-Object -FilePath $logFile
}
catch {
    $_ | Out-String | Tee-Object -FilePath $logFile -Append | Out-Null
    $LASTEXITCODE = 1
}

if ($LASTEXITCODE -ne 0) {
    if (Test-Path $logFile) {
        Write-Host ("---- g-cli build log ({0}) ----" -f $logFile)
        Get-Content -Path $logFile | ForEach-Object { Write-Host $_ }
        Write-Host ("---- end g-cli build log ----")
    }
    else {
        Write-Host ("g-cli build log not found at {0}" -f $logFile)
    }

    $errorObject = [PSCustomObject]@{
        error    = "g-cli build failed."
        exitCode = $LASTEXITCODE
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
