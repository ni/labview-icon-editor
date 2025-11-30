#Requires -Version 7.0
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
$targetModule = Join-Path $repoRoot 'src' 'tools' 'icon-editor' 'IconEditorPackage.psm1'
if (-not (Test-Path -LiteralPath $targetModule -PathType Leaf)) {
    throw "IconEditorPackage module not found at '$targetModule'."
}

if ($env:ICON_EDITOR_LAB_SIMULATION -eq '1') {
    function Get-IconEditorPackageName {
        [CmdletBinding()]
        param([Parameter(Mandatory)][string]$VipbPath)
        return 'IconEditor_Test'
    }

    function Get-IconEditorPackagePath {
        [CmdletBinding()]
        param(
            [Parameter(Mandatory)][string]$VipbPath,
            [Parameter(Mandatory)][int]$Major,
            [Parameter(Mandatory)][int]$Minor,
            [Parameter(Mandatory)][int]$Patch,
            [Parameter(Mandatory)][int]$Build,
            [string]$WorkspaceRoot,
            [string]$OutputDirectory = '.github/builds/vip-stash'
        )

        if (-not $WorkspaceRoot) { $WorkspaceRoot = (Get-Location).Path }
        $outputRoot = if ([System.IO.Path]::IsPathRooted($OutputDirectory)) {
            [System.IO.Path]::GetFullPath($OutputDirectory)
        } else {
            [System.IO.Path]::GetFullPath((Join-Path $WorkspaceRoot $OutputDirectory))
        }
        if (-not (Test-Path -LiteralPath $outputRoot -PathType Container)) {
            New-Item -ItemType Directory -Path $outputRoot -Force | Out-Null
        }
        $name = Get-IconEditorPackageName -VipbPath $VipbPath
        return Join-Path $outputRoot ("{0}-{1}.{2}.{3}.{4}.vip" -f $name, $Major, $Minor, $Patch, $Build)
    }

    function Invoke-IconEditorProcess {
        [CmdletBinding()]
        param(
            [Parameter(Mandatory)][string]$Binary,
            [string[]]$Arguments,
            [string]$WorkingDirectory,
            [switch]$Quiet
        )

        return [pscustomobject]@{
            ExitCode = 0
            StdOut   = @()
            StdErr   = @()
            Duration = 0
            Warnings = @()
            LogPath  = $null
        }
    }

    function Confirm-IconEditorPackageArtifact {
        [CmdletBinding()]
        param([Parameter(Mandatory)][string]$PackagePath)

        $resolved = [System.IO.Path]::GetFullPath($PackagePath)
        if (-not (Test-Path -LiteralPath $resolved)) {
            New-Item -ItemType File -Path $resolved -Force | Out-Null
        }
        $info = Get-Item -LiteralPath $resolved
        return [pscustomobject]@{
            PackagePath      = $info.FullName
            Sha256           = $null
            SizeBytes        = $info.Length
            LastWriteTimeUtc = $info.LastWriteTimeUtc
        }
    }

    function Invoke-IconEditorVipBuild {
        [CmdletBinding()]
        param(
            [Parameter(Mandatory)][string]$VipbPath,
            [Parameter(Mandatory)][int]$Major,
            [Parameter(Mandatory)][int]$Minor,
            [Parameter(Mandatory)][int]$Patch,
            [Parameter(Mandatory)][int]$Build,
            [ValidateSet(32,64)][int]$SupportedBitness = 64,
            [int]$MinimumSupportedLVVersion = 2023,
            [ValidateSet(0,3)][int]$LabVIEWMinorRevision = 3,
            [Parameter(Mandatory)][string]$ReleaseNotesPath,
            [string]$WorkspaceRoot,
            [string]$OutputDirectory = '.github/builds/vip-stash',
            [ValidateSet('g-cli','vipm')][string]$Provider = 'g-cli',
            [string]$GCliProviderName,
            [string]$VipmProviderName,
            [int]$TimeoutSeconds = 300,
            [switch]$PreserveExisting,
            [switch]$Quiet
        )

        $packagePath = Get-IconEditorPackagePath -VipbPath $VipbPath -Major $Major -Minor $Minor -Patch $Patch -Build $Build -WorkspaceRoot $WorkspaceRoot -OutputDirectory $OutputDirectory
        "vip-package" | Set-Content -LiteralPath $packagePath -Encoding utf8
        return [pscustomobject]@{
            Output          = @()
            Warnings        = @()
            RemovedExisting = $false
            PackagePath     = $packagePath
            Provider        = 'simulation'
        }
    }

    function Get-IconEditorViServerSnapshot {
        [CmdletBinding()]
        param([string]$Path)
        return [pscustomobject]@{}
    }

    function Get-IconEditorViServerSnapshots {
        [CmdletBinding()]
        param([string]$IndexPath)
        return @()
    }

    Export-ModuleMember -Function `
        Get-IconEditorPackageName, `
        Get-IconEditorPackagePath, `
        Invoke-IconEditorProcess, `
        Confirm-IconEditorPackageArtifact, `
        Invoke-IconEditorVipBuild, `
        Get-IconEditorViServerSnapshot, `
        Get-IconEditorViServerSnapshots
    return
}

Import-Module -Name $targetModule -Force -Global | Out-Null
