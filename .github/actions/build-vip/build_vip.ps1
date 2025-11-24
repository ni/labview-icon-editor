<#
.SYNOPSIS
    Updates a VIPB file's display information and builds the VI package.

.DESCRIPTION
    Resolves paths, merges version details into DisplayInformation JSON, and
    calls vipm CLI to build the final VI package.

.PARAMETER SupportedBitness
    LabVIEW bitness for the build ("32" or "64").

.PARAMETER RepositoryPath
    Path to the repository root.

.PARAMETER VIPBPath
    Relative path to the VIPB file to update.

.PARAMETER Package_LabVIEW_Version
    Minimum LabVIEW version supported by the package.

.PARAMETER LabVIEWMinorRevision
    Minor revision number of LabVIEW (0 or 3).

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
    .\build_vip.ps1 -SupportedBitness "64" -RepositoryPath "C:\repo" -VIPBPath "Tooling\deployment\NI Icon editor.vipb" -Package_LabVIEW_Version 2021 -LabVIEWMinorRevision 3 -Major 1 -Minor 0 -Patch 0 -Build 2 -Commit "abcd123" -ReleaseNotesFile "Tooling\deployment\release_notes.md" -DisplayInformationJSON '{"Package Version":{"major":1,"minor":0,"patch":0,"build":2}}'
#>

param (
    [string]$SupportedBitness,
    [string]$RepositoryPath,
    [string]$VIPBPath,

    [Alias('MinimumSupportedLVVersion')]
    [int]$Package_LabVIEW_Version,

    [ValidateSet("0","3")]
    [string]$LabVIEWMinorRevision = "0",

    [int]$Major,
    [int]$Minor,
    [int]$Patch,
    [int]$Build,
    [string]$Commit,
    [string]$ReleaseNotesFile,

    [Parameter(Mandatory=$true)]
    [string]$DisplayInformationJSON
)

# 1) Resolve paths
try {
    $ResolvedRepositoryPath = Resolve-Path -Path $RepositoryPath -ErrorAction Stop
    if ([System.IO.Path]::IsPathRooted($VIPBPath)) {
        $ResolvedVIPBPath = Resolve-Path -Path $VIPBPath -ErrorAction Stop
    }
    else {
        $ResolvedVIPBPath = Join-Path -Path $ResolvedRepositoryPath -ChildPath $VIPBPath -ErrorAction Stop
    }
    Write-Verbose "RepositoryPath resolved to $ResolvedRepositoryPath"
    Write-Verbose "VIPBPath resolved to $ResolvedVIPBPath"
    if ($Commit) {
        Write-Verbose "Embedding commit metadata: $Commit" -Verbose:$VerbosePreference
    }
}
catch {
    $errorObject = [PSCustomObject]@{
        error      = "Error resolving paths. Ensure RepositoryPath and VIPBPath are valid."
        exception  = $_.Exception.Message
        stackTrace = $_.Exception.StackTrace
    }
    $errorObject | ConvertTo-Json -Depth 10
    exit 1
}

# 2) Create release notes if needed and resolve the paths
if (-not (Test-Path $ReleaseNotesFile)) {
    Write-Information "Release notes file '$ReleaseNotesFile' does not exist. Creating it..." -InformationAction Continue
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
$LogDirectory = Join-Path -Path $ResolvedRepositoryPath -ChildPath "builds/logs"
New-Item -ItemType Directory -Path $LogDirectory -Force | Out-Null

# 3) Resolve LabVIEW version from VIPB to ensure determinism, overriding any inbound value
$versionScriptCandidates = @(
    (Join-Path $ResolvedRepositoryPath 'scripts/get-package-lv-version.ps1'),
    (Join-Path $ResolvedRepositoryPath '.github/scripts/get-package-lv-version.ps1'),
    (Join-Path $PSScriptRoot '..\..\scripts\get-package-lv-version.ps1')
) | Where-Object { Test-Path $_ }

if (-not $versionScriptCandidates) {
    $errorObject = [PSCustomObject]@{
        error = "Unable to locate get-package-lv-version.ps1 relative to repository or action path."
        repo  = $ResolvedRepositoryPath
        action= $PSScriptRoot
    }
    $errorObject | ConvertTo-Json -Depth 6
    exit 1
}

$versionScript = $versionScriptCandidates | Select-Object -First 1
$Package_LabVIEW_Version = & $versionScript -RepositoryPath $RepositoryPath

# Calculate the LabVIEW version string
$lvNumericMajor    = $Package_LabVIEW_Version - 2000
$lvNumericVersion  = "$($lvNumericMajor).$LabVIEWMinorRevision"
if ($SupportedBitness -eq "64") {
    $VIP_LVVersion_A = "$lvNumericVersion (64-bit)"
}
else {
    $VIP_LVVersion_A = $lvNumericVersion
}
Write-Output "Building VI Package for LabVIEW $VIP_LVVersion_A..."

# 4) Parse and update the DisplayInformationJSON
try {
    $jsonObj = $DisplayInformationJSON | ConvertFrom-Json
}
catch {
    $errorObject = [PSCustomObject]@{
        error      = "Failed to parse DisplayInformationJSON into valid JSON."
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

# 5) Execute vipm build with retries and log capture
$vipmCli = Get-Command vipm -ErrorAction SilentlyContinue
if (-not $vipmCli) {
    Write-Error "vipm CLI is not available on PATH; cannot build the VI package."
    exit 1
}

$vipmArgs = @(
    "build",
    $ResolvedVIPBPath,
    "--labview-version", $Package_LabVIEW_Version.ToString(),
    "--labview-bitness", $SupportedBitness
)

$prettyCommand = "vipm " + ($vipmArgs -join ' ')
Write-Output "Base build command:"
Write-Output $prettyCommand

$logFile = Join-Path -Path $LogDirectory -ChildPath "vipm-build-attempt-1.log"
Write-Information "Starting vipm build. Log: $logFile" -InformationAction Continue

try {
    & vipm @vipmArgs 2>&1 | Tee-Object -FilePath $logFile
}
catch {
    $_ | Out-String | Tee-Object -FilePath $logFile -Append | Out-Null
    $LASTEXITCODE = 1
}

if ($LASTEXITCODE -ne 0) {
    if (Test-Path $logFile) {
        Write-Information ("---- vipm build log ({0}) ----" -f $logFile) -InformationAction Continue
        Get-Content -Path $logFile | ForEach-Object { Write-Information $_ -InformationAction Continue }
        Write-Information ("---- end vipm build log ({0}) ----" -f $logFile) -InformationAction Continue
    }
    else {
        Write-Warning ("vipm build log not found at {0}" -f $logFile)
    }

    $errorObject = [PSCustomObject]@{
        error    = "vipm build failed."
        exitCode = $LASTEXITCODE
        logs     = @($logFile)
    }
    $errorObject | ConvertTo-Json -Depth 10
    exit 1
}

# Move or confirm the produced VIP is under builds/VI Package for downstream steps
$outputDir = Join-Path -Path $ResolvedRepositoryPath -ChildPath "builds/VI Package"
New-Item -ItemType Directory -Path $outputDir -Force | Out-Null
$vipbDir = Split-Path -Parent $ResolvedVIPBPath

$vipProduced = Get-ChildItem -Path $outputDir -Filter *.vip -File -ErrorAction SilentlyContinue | Sort-Object LastWriteTime -Descending | Select-Object -First 1
if (-not $vipProduced) {
    $vipProduced = Get-ChildItem -Path $vipbDir -Filter *.vip -File -ErrorAction SilentlyContinue | Sort-Object LastWriteTime -Descending | Select-Object -First 1
    if ($vipProduced) {
        $destPath = Join-Path -Path $outputDir -ChildPath $vipProduced.Name
        Move-Item -LiteralPath $vipProduced.FullName -Destination $destPath -Force
        Write-Information ("Moved built VIP to {0}" -f $destPath) -InformationAction Continue
    }
}
elseif ($vipProduced) {
    Write-Information ("Built VIP already present at {0}" -f $vipProduced.FullName) -InformationAction Continue
}

if (-not $vipProduced) {
    Write-Warning "vipm build succeeded but no .vip was found; downstream locate step may fail."
}

Write-Information "Successfully built VI package: $ResolvedVIPBPath" -InformationAction Continue
