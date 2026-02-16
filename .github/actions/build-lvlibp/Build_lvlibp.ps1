<#
.SYNOPSIS
    Compatibility wrapper for packed-library project spec builds.

.DESCRIPTION
    Deprecated shim that forwards to BuildProjectSpec.ps1 using
    PackedLibrary defaults. This shim is retained for compatibility
    and will be removed after two release cycles.
#>
[CmdletBinding()]
param(
    [AllowNull()]
    [AllowEmptyString()]
    [string]$LabVIEWVersion = '',
    [ValidateSet('32', '64')]
    [string]$SupportedBitness,
    [string]$RepoRoot,
    [string]$WorktreeRoot,
    [switch]$SkipWorktreeRootCheck,
    [Int32]$Major,
    [Int32]$Minor,
    [Int32]$Patch,
    [Int32]$Build,
    [string]$Commit,
    [ValidateRange(0, 600000)]
    [int]$ConnectTimeoutMs = 0
)

$ErrorActionPreference = 'Stop'

Write-Warning 'Build_lvlibp.ps1 is deprecated and will be removed after two release cycles. Use BuildProjectSpec.ps1.'

$canonicalScript = Join-Path -Path $PSScriptRoot -ChildPath 'BuildProjectSpec.ps1'
if (-not (Test-Path -Path $canonicalScript -PathType Leaf)) {
    throw "BuildProjectSpec.ps1 was not found at $canonicalScript"
}

$invokeArgs = @{
    LabVIEWVersion = $LabVIEWVersion
    SupportedBitness = $SupportedBitness
    RepoRoot = $RepoRoot
    WorktreeRoot = $WorktreeRoot
    SkipWorktreeRootCheck = $SkipWorktreeRootCheck.IsPresent
    ProjectSpecType = 'PackedLibrary'
    BuildSpecName = 'Editor Packed Library'
    OutputRelativePath = 'resource/plugins/lv_icon.lvlibp'
    TargetName = 'My Computer'
    Major = $Major
    Minor = $Minor
    Patch = $Patch
    Build = $Build
    Commit = $Commit
    ConnectTimeoutMs = $ConnectTimeoutMs
}

& $canonicalScript @invokeArgs

if ($null -ne $LASTEXITCODE) {
    exit $LASTEXITCODE
}

exit 0
