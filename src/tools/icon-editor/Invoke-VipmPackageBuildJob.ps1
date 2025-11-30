#Requires -Version 7.0
<#
.SYNOPSIS
    Builds the Icon Editor VI package from the vendored VIPB specification.

.DESCRIPTION
    Uses a local log file (with DisplayInformationJSON) to determine the package
    version, regenerates release notes, updates the VIPB metadata, and invokes
    the IconEditor packaging helpers to produce a .vip via g-cli or vipm.
    This script is intended for direct builds; it does not talk to GitHub APIs.

.PARAMETER Workspace
    Local repository root mirroring ${{ github.workspace }}. Defaults to the
    current directory.

.PARAMETER ReleaseNotesPath
    Release notes file path (relative or absolute). Defaults to
    'Tooling/deployment/release_notes.md' under the workspace.

.PARAMETER LogPath
    Path to a log file containing a DisplayInformationJSON payload with
    "Package Version" information. Defaults to
    'configs/logs/vipm-build-sample.log' under the workspace when omitted.

.PARAMETER SkipReleaseNotes
    Skip regenerating release notes (assumes the file already exists).

.PARAMETER SkipVipbUpdate
    Skip calling Update-VipbDisplayInfo.ps1 (assumes VIPB already updated).

.PARAMETER SkipBuild
    Skip running the packaging provider (helpful for prepare-only workflows or
    environments without NI tooling). When set, the script will not require a
    .vip artifact to be produced.

.PARAMETER CloseLabVIEW
    Invoke the Close_LabVIEW.ps1 helper after the build.

.PARAMETER DownloadArtifacts
    Present for compatibility with previous replay flows; ignored by this
    build-focused script.

.PARAMETER BuildToolchain
    Toolchain used to build the VIP. Defaults to 'g-cli'; pass 'vipm' to route
    through the VIPM provider.

.PARAMETER BuildProvider
    Optional provider name forwarded to the selected toolchain (for example, a
    specific g-cli or VIPM backend).
#>

[CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'Low')]
param(
    [string]$RunId,

    [string]$LogPath = 'configs/logs/vipm-build-sample.log',

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

$packagingLabVIEWVersion = 2026
$packagingLabVIEWMinorRevision = 0
$packagingSupportedBitness = 64

function Invoke-ExternalPwsh {
    param([Parameter(Mandatory)][string[]]$Arguments)

    $pwshExecutable = (Get-Command pwsh).Source
    $psi = New-Object System.Diagnostics.ProcessStartInfo
    $psi.FileName = $pwshExecutable
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

    [pscustomobject]@{
        ExitCode = $process.ExitCode
        StdOut   = $stdout
        StdErr   = $stderr
    }
}

function Resolve-WorkspacePath {
    param([string]$Path)
    return (Resolve-Path -Path $Path -ErrorAction Stop).ProviderPath
}

function Get-PackageVersionFromLog {
    param([Parameter(Mandatory)][string]$LogFilePath)

    if (Test-Path -LiteralPath $LogFilePath -PathType Container) {
        throw "Log path '$LogFilePath' is a directory. Pass the full path to a log file (for example configs/logs/vipm-build-sample.log)."
    }
    if (-not (Test-Path -LiteralPath $LogFilePath -PathType Leaf)) {
        throw "Log file '$LogFilePath' does not exist. Pass the full path to a task log (e.g. configs/logs/vipm-build-sample.log)."
    }

    $logLines = Get-Content -LiteralPath $LogFilePath

    function Remove-AnsiEscapes {
        param([string]$Text)
        return ([regex]::Replace($Text, '\x1B\[[0-9;]*[A-Za-z]', ''))
    }

    $sanitizedLines = $logLines | ForEach-Object { Remove-AnsiEscapes $_ }
    $jsonLine = $sanitizedLines | Where-Object { $_ -match 'DisplayInformationJSON' -or $_ -match 'display_information_json' } | Select-Object -Last 1
    if (-not $jsonLine) {
        throw "Could not find the display-information payload in '$LogFilePath'."
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

    return [pscustomobject]@{
        DisplayInformation = $displayInfo
        Major              = [int]$packageVersion.major
        Minor              = [int]$packageVersion.minor
        Patch              = [int]$packageVersion.patch
        Build              = [int]$packageVersion.build
    }
}

$workspaceRoot = Resolve-WorkspacePath -Path $Workspace
$defaultLogRelative = 'configs\logs\vipm-build-sample.log'
$logPathProvided = $PSBoundParameters.ContainsKey('LogPath')

$iconEditorModulePath = Join-Path $workspaceRoot 'src\tools\icon-editor\IconEditorPackage.psm1'
if (-not (Test-Path -LiteralPath $iconEditorModulePath -PathType Leaf)) {
    throw "IconEditor package module not found at '$iconEditorModulePath'."
}
Import-Module $iconEditorModulePath -Force

Push-Location $workspaceRoot
try {
    $vipbRelative = '.github/actions/build-vi-package/NI_Icon_editor.vipb'
    $vipbFullPath = Resolve-WorkspacePath -Path (Join-Path $workspaceRoot $vipbRelative)

    if (-not $logPathProvided -or [string]::IsNullOrWhiteSpace($LogPath)) {
        $LogPath = $defaultLogRelative
    }

    $resolvedCandidate = $LogPath
    if (-not [System.IO.Path]::IsPathRooted($resolvedCandidate)) {
        $resolvedCandidate = Join-Path $workspaceRoot $resolvedCandidate
    }
    if (Test-Path -LiteralPath $resolvedCandidate -PathType Container) {
        $fallback = Join-Path $workspaceRoot $defaultLogRelative
        if (Test-Path -LiteralPath $fallback -PathType Leaf) {
            Write-Warning "LogPath '$LogPath' is a directory. Defaulting to '$fallback'."
            $LogPath = $fallback
        } else {
            throw "Log path '$resolvedCandidate' is a directory and the default log '$fallback' was not found."
        }
    }

    $resolvedLogPath = Resolve-WorkspacePath -Path $LogPath
    $versionInfo = Get-PackageVersionFromLog -LogFilePath $resolvedLogPath

    $intMajor = $versionInfo.Major
    $intMinor = $versionInfo.Minor
    $intPatch = $versionInfo.Patch
    $intBuild = $versionInfo.Build

    if ([System.IO.Path]::IsPathRooted($ReleaseNotesPath)) {
        $resolvedNotes = (Resolve-Path -Path $ReleaseNotesPath).ProviderPath
        $releaseNotesArgument = $resolvedNotes
        $releaseNotesFull = $resolvedNotes
    } else {
        $releaseNotesArgument = $ReleaseNotesPath
        $releaseNotesFull = Join-Path $workspaceRoot $ReleaseNotesPath
    }

    $releaseNotesScript = Join-Path $workspaceRoot '.github/actions/generate-release-notes/GenerateReleaseNotes.ps1'
    $releaseNotesHelper = Join-Path $workspaceRoot 'src\tools\icon-editor\Generate-ReleaseNotes.ps1'
    $customActionTest = Join-Path $workspaceRoot 'src\tools\icon-editor\Test-VipbCustomActions.ps1'
    if (Test-Path -LiteralPath $customActionTest -PathType Leaf) {
        try {
            & $customActionTest -VipbPath $vipbFullPath -Workspace $workspaceRoot
        } catch {
            throw "VIPB custom action guard failed: $($_.Exception.Message)"
        }
    }

    if (-not $SkipReleaseNotes) {
        if (Test-Path -LiteralPath $releaseNotesHelper -PathType Leaf) {
            Write-Host "Generating release notes at $releaseNotesFull"
            & $releaseNotesHelper -Workspace $workspaceRoot -OutputPath $releaseNotesArgument
        } else {
            Write-Warning "Release notes helper '$releaseNotesHelper' not found; skipping generation."
        }
    } else {
        $releaseNotesDir = Split-Path -Parent $releaseNotesFull
        if (-not (Test-Path -LiteralPath $releaseNotesDir -PathType Container)) {
            New-Item -ItemType Directory -Path $releaseNotesDir -Force | Out-Null
        }
        if (-not (Test-Path -LiteralPath $releaseNotesFull -PathType Leaf)) {
            New-Item -ItemType File -Path $releaseNotesFull -Force | Out-Null
        }
    }

    $updateScript = Join-Path $workspaceRoot '.github/actions/modify-vipb-display-info/Update-VipbDisplayInfo.ps1'
    if (-not $SkipVipbUpdate) {
        if (Test-Path -LiteralPath $updateScript -PathType Leaf) {
            Write-Host "Updating VIPB metadata via PowerShell helper"
            $displayInfoJson = $versionInfo.DisplayInformation | ConvertTo-Json -Depth 5

            $updateResult = Invoke-ExternalPwsh -Arguments @(
                '-NoLogo','-NoProfile',
                '-File',$updateScript,
                '-SupportedBitness',"$packagingSupportedBitness",
                '-IconEditorRoot',(Get-Location).Path,
                '-VIPBPath',$vipbRelative,
                '-MinimumSupportedLVVersion',"2023",
                '-LabVIEWMinorRevision',"3",
                '-Major',$intMajor,
                '-Minor',$intMinor,
                '-Patch',$intPatch,
                '-Build',$intBuild,
                '-Commit',($RunId ?? 'local-build'),
                '-ReleaseNotesFile',$releaseNotesArgument,
                '-DisplayInformationJSON',$displayInfoJson
            )
            if ($updateResult.ExitCode -ne 0) {
                throw "VIPB update failed:`n$($updateResult.StdOut)$($updateResult.StdErr)"
            }
        } else {
            Write-Warning "VIPB update script '$updateScript' not found; skipping metadata update."
        }
    }

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

        $packagePath = $buildResult.PackagePath
        if ($packagePath -and (Test-Path -LiteralPath $packagePath)) {
            $packageInfo = Get-Item -LiteralPath $packagePath
            $sizeMb = [Math]::Round($packageInfo.Length / 1MB, 2)
            Write-Host " Build succeeded. Package path:"
            Write-Host "   $packagePath"
            Write-Host (" Package size: {0} MB" -f $sizeMb)
            if ($buildResult.Provider) {
                Write-Host (" Provider backend: {0}" -f $buildResult.Provider)
            }
        } else {
            throw "Expected VI package '$packagePath' was not produced. Inspect build logs above."
        }
    } else {
        Write-Host "VIP build skipped by request (SkipBuild)."
    }

    if ($CloseLabVIEW) {
        Write-Host ("Closing LabVIEW {0} ({1}-bit)" -f $packagingLabVIEWVersion, $packagingSupportedBitness)
        $closeResult = Invoke-ExternalPwsh -Arguments @(
            '-NoLogo','-NoProfile',
            '-File','.github/actions/close-labview/Close_LabVIEW.ps1',
            '-MinimumSupportedLVVersion',"$packagingLabVIEWVersion",
            '-SupportedBitness',"$packagingSupportedBitness"
        )
        if ($closeResult.ExitCode -ne 0) {
            Write-Warning "close-labview script reported an error:`n$($closeResult.StdOut)$($closeResult.StdErr)"
        }
    }

    Write-Host "Build job completed."
}
finally {
    Pop-Location
}
