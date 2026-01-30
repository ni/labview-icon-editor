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

.PARAMETER MinimumSupportedLVVersion
    LabVIEW major version (2021 only; 21.0).

.PARAMETER LabVIEWMinorRevision
    Minor revision number of LabVIEW (0 for 21.0).

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
    .\build_vip.ps1 -SupportedBitness "64" -RepoRoot "C:\repo" -VIPBPath "Tooling\deployment\NI Icon editor.vipb" -MinimumSupportedLVVersion 2021 -LabVIEWMinorRevision 0 -Major 1 -Minor 0 -Patch 0 -Build 2 -Commit "abcd123" -ReleaseNotesFile "Tooling\deployment\release_notes.md" -DisplayInformationJSON '{"Package Version":{"major":1,"minor":0,"patch":0,"build":2}}'
#>

param (
    [string]$SupportedBitness,
    [string]$RepoRoot,
    [string]$VIPBPath,

    [ValidateSet(2021)]
    [int]$MinimumSupportedLVVersion,

    [ValidateSet("0")]
    [string]$LabVIEWMinorRevision = "0",

    [int]$Major,
    [int]$Minor,
    [int]$Patch,
    [int]$Build,
    [string]$Commit,
    [string]$ReleaseNotesFile,

    [Parameter(Mandatory=$true)]
    [string]$DisplayInformationJSON,

    [ValidateRange(60, 3600)]
    [int]$VipmTimeoutSeconds = 300
)

# 1) Resolve paths
try {
    $ResolvedRepoRoot = Resolve-Path -Path $RepoRoot -ErrorAction Stop
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
$LogDirectory = Join-Path -Path $ResolvedRepoRoot -ChildPath "builds/logs"
New-Item -ItemType Directory -Path $LogDirectory -Force | Out-Null

# 3) Calculate the LabVIEW version string
$lvNumericMajor    = $MinimumSupportedLVVersion - 2000
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

# Re-convert to a JSON string with a comfortable nesting depth
$UpdatedDisplayInformationJSON = $jsonObj | ConvertTo-Json -Depth 5

# 5) Construct reusable g-cli arguments
$gcliArgs = @(
    "--lv-ver", $MinimumSupportedLVVersion.ToString(),
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

# 6) Execute the command once with log capture
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
