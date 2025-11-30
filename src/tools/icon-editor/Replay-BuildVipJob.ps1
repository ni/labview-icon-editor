#Requires -Version 7.0
<#
.SYNOPSIS
    Replays the GitHub Actions "Build VI Package" job locally.

.DESCRIPTION
    Fetches the job log (via gh) or accepts a pre-fetched log, extracts the
    display-information payload and version inputs, regenerates release notes,
    updates the VIPB metadata, and reruns the VI package build script. This
    allows rapid iteration without waiting for preceding CI stages.

.PARAMETER RunId
    The workflow run identifier to fetch. When supplied, the script queries
    GitHub for the job details and log content.

.PARAMETER LogPath
    Optional path to an existing job log. Use when you have already downloaded
    the log via 'gh run view ... --log'.

.PARAMETER JobName
    Name of the job to replay. Defaults to 'Build VI Package'.

.PARAMETER Workspace
    Local repository root mirroring ${{ github.workspace }}. Defaults to the
    current directory.

.PARAMETER ReleaseNotesPath
    Release notes file path (relative or absolute). Matches CI default of
    'Tooling/deployment/release_notes.md'.

.PARAMETER SkipReleaseNotes
    Skip regenerating release notes (assumes the file already exists).

.PARAMETER SkipVipbUpdate
    Skip calling Update-VipbDisplayInfo.ps1 (assumes VIPB already updated).

.PARAMETER SkipBuild
    Skip running build_vip.ps1 (helpful when debugging the metadata update only).

.PARAMETER CloseLabVIEW
    Invoke the Close_LabVIEW.ps1 helper after the build.

.PARAMETER DownloadArtifacts
    When supplied, downloads the run's artifacts (via gh run download) into a
    temporary directory and copies any lv_icon_*.lvlibp files into the expected
    resource/plugins folder.

.PARAMETER BuildToolchain
    Toolchain used to rebuild the VIP. Defaults to 'g-cli'; pass 'vipm' to route
    through the VIPM provider.

.PARAMETER BuildProvider
    Optional provider name forwarded to the selected toolchain (for example, a
    specific g-cli or VIPM backend).
#>

[CmdletBinding(SupportsShouldProcess=$true, ConfirmImpact='Low', DefaultParameterSetName = 'Default')]
param(
    [Parameter(ParameterSetName = 'Run', Mandatory = $true)]
    [string]$RunId,

    [Parameter()]
    [string]$LogPath,

    [string]$JobName = 'Build VI Package',

    [string]$Workspace = (Get-Location).Path,

    [string]$ReleaseNotesPath = 'Tooling/deployment/release_notes.md',

    [switch]$SkipReleaseNotes,
    [switch]$SkipVipbUpdate,
    [switch]$SkipBuild,
    [switch]$CloseLabVIEW,
    [switch]$DownloadArtifacts,

    [ValidateSet('g-cli','vipm')]
    [string]$BuildToolchain = 'g-cli',

    [string]$BuildProvider
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$null = Import-Module Microsoft.PowerShell.Management -ErrorAction Stop
$null = Import-Module Microsoft.PowerShell.Utility -ErrorAction Stop
$PSModuleAutoLoadingPreference = 'None'
$PwshExecutable = (Get-Command pwsh).Source
$packedLibLabVIEWVersion = 2023
$packedLibLabVIEWMinorRevision = 3
$packagingLabVIEWVersion = 2026
$packagingLabVIEWMinorRevision = 0
$packagingSupportedBitness = 64

function Invoke-GitHubCli {
    param(
        [Parameter(Mandatory)][string[]]$Arguments,
        [switch]$Raw
    )

    $psi = New-Object System.Diagnostics.ProcessStartInfo
    $psi.FileName = 'gh'
    foreach ($arg in $Arguments) {
        [void]$psi.ArgumentList.Add($arg)
    }
    $psi.RedirectStandardOutput = $true
    $psi.RedirectStandardError = $true
    $psi.UseShellExecute = $false
    $process = [System.Diagnostics.Process]::Start($psi)
    $stdout = $process.StandardOutput.ReadToEnd()
    $stderr = $process.StandardError.ReadToEnd()
    $process.WaitForExit()

    if ($process.ExitCode -ne 0) {
        throw "gh $($Arguments -join ' ') failed: $stderr"
    }

    if ($Raw) { return $stdout }
    return ($stdout | ConvertFrom-Json)
}

function Invoke-ExternalPwsh {
    param([Parameter(Mandatory)][string[]]$Arguments)

    $psi = New-Object System.Diagnostics.ProcessStartInfo
    $psi.FileName = $PwshExecutable
    foreach ($arg in $Arguments) {
        [void]$psi.ArgumentList.Add($arg)
    }
    $psi.RedirectStandardOutput = $true
    $psi.RedirectStandardError = $true
    $psi.UseShellExecute = $false
    $proc = [System.Diagnostics.Process]::Start($psi)
    $stdout = $proc.StandardOutput.ReadToEnd()
    $stderr = $proc.StandardError.ReadToEnd()
    $proc.WaitForExit()

    [pscustomobject]@{
        ExitCode = $proc.ExitCode
        StdOut   = $stdout
        StdErr   = $stderr
    }
}

function Resolve-WorkspacePath {
    param([string]$Path)
    return (Resolve-Path -Path $Path -ErrorAction Stop).ProviderPath
}

$workspaceRoot = Resolve-WorkspacePath -Path $Workspace
$script:stagedArtifacts = New-Object System.Collections.Generic.List[string]
$script:removedPackage = $false
$script:buildOutput = $null
$script:buildWarnings = @()
$script:viServerSnapshots = @()
$script:packagePath = $null
$script:buildProviderName = $null
$script:buildToolchain = $BuildToolchain

$iconEditorModulePath = Join-Path $workspaceRoot 'tools\icon-editor\IconEditorPackage.psm1'
if (-not (Test-Path -LiteralPath $iconEditorModulePath -PathType Leaf)) {
    throw "IconEditor package module not found at '$iconEditorModulePath'."
}
Import-Module $iconEditorModulePath -Force

if ($IsWindows) {
    try {
        $script:viServerSnapshots = Get-IconEditorViServerSnapshots -Version 2021 -Bitness @(32, 64) -WorkspaceRoot $workspaceRoot
    } catch {
        Write-Verbose ("Unable to capture VI Server snapshot: {0}" -f $_.Exception.Message)
        $script:viServerSnapshots = @()
    }
}

if ($RunId) {
    Write-Verbose "Fetching job metadata for run $RunId"
    $runInfo = Invoke-GitHubCli -Arguments @('run', 'view', $RunId, '--json', 'jobs,headSha')
    $job = $runInfo.jobs | Where-Object { $_.name -eq $JobName }
    if (-not $job) {
        throw "Job '$JobName' not found in run $RunId."
    }

    $jobId = $null
    if ($job.PSObject.Properties['id']) {
        $jobId = $job.id
    } elseif ($job.PSObject.Properties['databaseId']) {
        $jobId = $job.databaseId
    }
    if (-not $jobId) {
        throw "Unable to determine job identifier for '$JobName' in run $RunId."
    }

    if (-not $LogPath) {
        $LogPath = Join-Path ([System.IO.Path]::GetTempPath()) "build-vi-package-$RunId.log"
    }

    Write-Verbose "Downloading job log to $LogPath"
    $logContent = Invoke-GitHubCli -Arguments @('run', 'view', $RunId, '--job', $jobId, '--log') -Raw
    Set-Content -LiteralPath $LogPath -Value $logContent -Encoding UTF8

    if ($DownloadArtifacts) {
        $artifactDest = Join-Path $workspaceRoot ".replay-artifacts-$RunId"
        if (Test-Path -LiteralPath $artifactDest) {
            Remove-Item -LiteralPath $artifactDest -Recurse -Force
        }
        New-Item -ItemType Directory -Path $artifactDest | Out-Null

        Write-Verbose "Downloading artifacts to $artifactDest"
        $downloadArgs = @('run', 'download', $RunId, '--dir', $artifactDest)
        Invoke-GitHubCli -Arguments $downloadArgs | Out-Null

        $pluginsTarget = Join-Path $workspaceRoot 'resource\plugins'
        foreach ($file in Get-ChildItem -Path $artifactDest -Recurse -Filter 'lv_icon_*.lvlibp' -File) {
            $destinationPath = Join-Path $pluginsTarget $file.Name
            if (Test-Path -LiteralPath $destinationPath) {
                $existing = Get-Item -LiteralPath $destinationPath
                if ($existing -is [System.IO.DirectoryInfo]) {
                    Remove-Item -LiteralPath $destinationPath -Recurse -Force
                }
            }
            Copy-Item -LiteralPath $file.FullName -Destination $destinationPath -Force
        }
    }
}

if (-not $LogPath) {
    throw "A log file is required. Provide -RunId or -LogPath."
}

if (-not (Test-Path -LiteralPath $LogPath -PathType Leaf)) {
    throw "Log file '$LogPath' does not exist."
}

$logLines = Get-Content -LiteralPath $LogPath

function Remove-AnsiEscapes {
    param([string]$Text)
    return ([regex]::Replace($Text, '\x1B\[[0-9;]*[A-Za-z]', ''))
}

$sanitizedLines = $logLines | ForEach-Object { Remove-AnsiEscapes $_ }
$jsonLine = $sanitizedLines | Where-Object { $_ -match 'DisplayInformationJSON' -or $_ -match 'display_information_json' } | Select-Object -Last 1
if (-not $jsonLine) {
    throw "Could not find the display-information payload in '$LogPath'."
}

$jsonMatch = [regex]::Match($jsonLine, "-DisplayInformationJSON\s+'(?<payload>\{.+\})'")
if (-not $jsonMatch.Success) {
    $jsonMatch = [regex]::Match($jsonLine, "display_information_json:\s+(?<payload>\{.+\})")
}
if (-not $jsonMatch.Success) {
    throw "Failed to parse display-information JSON from '$jsonLine'."
}

$displayInfo = $jsonMatch.Groups['payload'].Value | ConvertFrom-Json

$packageVersion = $displayInfo.'Package Version'
if (-not $packageVersion) {
    throw "DisplayInformation JSON did not contain 'Package Version'."
}

$intMajor = [int]$packageVersion.major
$intMinor = [int]$packageVersion.minor
$intPatch = [int]$packageVersion.patch
$intBuild = [int]$packageVersion.build

Push-Location $workspaceRoot
try {
    $vipbRelative = '.github/actions/build-vi-package/NI_Icon_editor.vipb'
    $vipbFullPath = Resolve-WorkspacePath -Path (Join-Path $workspaceRoot $vipbRelative)

    if ([System.IO.Path]::IsPathRooted($ReleaseNotesPath)) {
        $resolvedNotes = (Resolve-Path -Path $ReleaseNotesPath).ProviderPath
        if ($resolvedNotes.StartsWith($workspaceRoot, [System.StringComparison]::OrdinalIgnoreCase)) {
            $releaseNotesArgument = [System.IO.Path]::GetRelativePath($workspaceRoot, $resolvedNotes)
        } else {
            $releaseNotesArgument = $resolvedNotes
        }
        $releaseNotesFull = $resolvedNotes
    } else {
        $releaseNotesArgument = $ReleaseNotesPath
        $releaseNotesFull = Join-Path $workspaceRoot $ReleaseNotesPath
    }

    if (-not $SkipReleaseNotes) {
        Write-Host "Generating release notes at $releaseNotesFull"
        $releaseResult = Invoke-ExternalPwsh -Arguments @('-NoLogo','-NoProfile','-File','.github/actions/generate-release-notes/GenerateReleaseNotes.ps1','-OutputPath',$releaseNotesArgument)
        if ($releaseResult.ExitCode -ne 0) {
            throw "Release notes generation failed:`n$($releaseResult.StdOut)$($releaseResult.StdErr)"
        }
    }

    if (-not $SkipVipbUpdate) {
        Write-Host "Updating VIPB metadata via PowerShell helper"
        $updateResult = Invoke-ExternalPwsh -Arguments @(
            '-NoLogo','-NoProfile','-File','.github/actions/modify-vipb-display-info/Update-VipbDisplayInfo.ps1',
            '-SupportedBitness',"$packagingSupportedBitness",
            '-IconEditorRoot',(Get-Location).Path,
            '-VIPBPath',$vipbRelative,
            '-MinimumSupportedLVVersion',"$packedLibLabVIEWVersion",
            '-LabVIEWMinorRevision',"$packedLibLabVIEWMinorRevision",
            '-Major',$intMajor,
            '-Minor',$intMinor,
            '-Patch',$intPatch,
            '-Build',$intBuild,
            '-Commit',($RunId ?? 'local-replay'),
            '-ReleaseNotesFile',$releaseNotesArgument,
            '-DisplayInformationJSON',($displayInfo | ConvertTo-Json -Depth 5)
        )
        if ($updateResult.ExitCode -ne 0) {
            throw "VIPB update failed:`n$($updateResult.StdOut)$($updateResult.StdErr)"
        }
    }

    $buildResult = $null
    if (-not $SkipBuild) {
        Write-Host ("Running Invoke-IconEditorVipBuild via {0} toolchain to produce VI Package" -f $BuildToolchain)

        $buildParams = @{
            VipbPath                  = $vipbFullPath
            Major                     = $intMajor
            Minor                     = $intMinor
            Patch                     = $intPatch
            Build                     = $intBuild
            SupportedBitness          = $packagingSupportedBitness
            MinimumSupportedLVVersion = $packagingLabVIEWVersion
            LabVIEWMinorRevision      = $packagingLabVIEWMinorRevision
            ReleaseNotesPath          = $releaseNotesFull
            WorkspaceRoot             = $workspaceRoot
            Provider                  = $BuildToolchain
        }

        if ($BuildToolchain -eq 'g-cli' -and $BuildProvider) {
            $buildParams.GCliProviderName = $BuildProvider
        } elseif ($BuildToolchain -eq 'vipm' -and $BuildProvider) {
            $buildParams.VipmProviderName = $BuildProvider
        }

        $buildResult = Invoke-IconEditorVipBuild @buildParams

        $script:buildOutput = $buildResult.Output
        $script:buildWarnings = $buildResult.Warnings
        if ($buildResult.RemovedExisting) { $script:removedPackage = $true }
        if ($buildResult.PackagePath) { $script:packagePath = $buildResult.PackagePath }
        if ($buildResult.Provider) { $script:buildProviderName = $buildResult.Provider }
    }

    if ($CloseLabVIEW) {
        Write-Host ("Closing LabVIEW {0} ({1}-bit)" -f $packagingLabVIEWVersion, $packagingSupportedBitness)
        $closeResult = Invoke-ExternalPwsh -Arguments @(
            '-NoLogo','-NoProfile','-File','.github/actions/close-labview/Close_LabVIEW.ps1',
            '-MinimumSupportedLVVersion',"$packagingLabVIEWVersion",
            '-SupportedBitness',"$packagingSupportedBitness"
        )
        if ($closeResult.ExitCode -ne 0) {
            Write-Warning "close-labview script reported an error:`n$($closeResult.StdOut)$($closeResult.StdErr)"
        }
    }
}
finally {
    Pop-Location
}

$vipOutputDir = Join-Path $workspaceRoot '.github/builds/vip-stash'
Write-Host "Replay completed."
Write-Host " VIPB updated at $(Join-Path $workspaceRoot $vipbRelative)"
Write-Host " Release notes path: $releaseNotesFull"
Write-Host (" Build toolchain: {0}" -f $script:buildToolchain)
Write-Host (" Packed library LabVIEW version: {0}" -f $packedLibLabVIEWVersion)
Write-Host (" Packaging LabVIEW version: {0} ({1}-bit)" -f $packagingLabVIEWVersion, $packagingSupportedBitness)
if ($script:buildProviderName) {
    Write-Host (" Provider backend: {0}" -f $script:buildProviderName)
} elseif ($BuildProvider) {
    Write-Host (" Provider backend: {0}" -f $BuildProvider)
}
if ($stagedArtifacts.Count -gt 0) {
    Write-Host " Staged artifacts copied to resource/plugins:"
    $stagedArtifacts | ForEach-Object { Write-Host "   - $_" }
}
if ($script:removedPackage) {
    Write-Host " Removed previous .vip to avoid collisions."
}
if ($script:buildOutput) {
    if ($script:buildWarnings.Count -gt 0) {
        $warningSource = if ($script:buildToolchain) { $script:buildToolchain } else { 'packaging provider' }
        Write-Warning ("{0} emitted warnings during build:" -f $warningSource)
        $script:buildWarnings | ForEach-Object { Write-Warning "  $_" }

        if ($script:buildToolchain -eq 'g-cli') {
            $logHint = Join-Path $env:USERPROFILE 'Documents\LabVIEW Data\Logs'
            if (-not (Test-Path -LiteralPath $logHint -PathType Container)) {
                $logHint = '%USERPROFILE%\Documents\LabVIEW Data\Logs'
            }
            Write-Host " Hint: g-cli reported transient comms errors; if the build still completes you can proceed. Otherwise rerun or inspect LabVIEW logs at $logHint."
            if ($script:viServerSnapshots.Count -gt 0) {
                Write-Host " VI Server ports (LabVIEW.ini snapshot):"
                foreach ($snapshot in $script:viServerSnapshots) {
                    $label = "{0} {1}-bit" -f $snapshot.Version, $snapshot.Bitness
                    if ($snapshot.Status -ne 'ok') {
                        $detail = if ($snapshot.Message) { $snapshot.Message } else { 'Unavailable' }
                        Write-Host ("  - {0}: {1}" -f $label, $detail)
                    } else {
                        $portText = if ($snapshot.Port) { $snapshot.Port } else { 'unknown' }
                        $enabledText = if ($snapshot.Enabled) { $snapshot.Enabled } else { 'unknown' }
                        $iniRef = if ($snapshot.IniPath) { $snapshot.IniPath } else { 'n/a' }
                        Write-Host ("  - {0}: port={1}, enabled={2} (ini: {3})" -f $label, $portText, $enabledText, $iniRef)
                    }
                }
            }
        }
    }
    Write-Host " Build output (last 10 lines):"
    ($script:buildOutput -split "`r?`n" | Where-Object { $_ } | Select-Object -Last 10) | ForEach-Object { Write-Host "  $_" }
}

$finalPackagePath = $script:packagePath
if (-not $finalPackagePath) {
    $finalPackagePath = Get-IconEditorPackagePath -VipbPath $vipbFullPath -Major $intMajor -Minor $intMinor -Patch $intPatch -Build $intBuild -WorkspaceRoot $workspaceRoot
}

$vipBuildRequested = -not $SkipBuild.IsPresent

if ($finalPackagePath -and (Test-Path -LiteralPath $finalPackagePath)) {
    $pkgInfo = Get-Item -LiteralPath $finalPackagePath
    $sizeMB = [Math]::Round($pkgInfo.Length / 1MB, 2)
    Write-Host " Generated .vip located under $vipOutputDir ($sizeMB MB):"
    Write-Host "   $finalPackagePath"
} elseif ($vipBuildRequested) {
    throw "Expected VI package '$finalPackagePath' was not produced. Inspect build logs above."
} else {
    Write-Host "VIP build was skipped by request; no .vip artifact expected."
}

function Test-ValidLabel {
  param([Parameter(Mandatory)][string]$Label)
  if ($Label -notmatch '^[A-Za-z0-9._-]{1,64}$') { throw "Invalid label: $Label" }
}

function Invoke-WithTimeout {
  [CmdletBinding()]
  param(
    [Parameter(Mandatory)][scriptblock]$ScriptBlock,
    [Parameter()][int]$TimeoutSec = 600
  )
  $job = Start-Job -ScriptBlock $ScriptBlock
  if (-not (Wait-Job $job -Timeout $TimeoutSec)) {
    try { Stop-Job $job -Force } catch {}
    throw "Operation timed out in $TimeoutSec s"
  }
  Receive-Job $job -ErrorAction Stop
}
