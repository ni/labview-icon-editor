<#
.SYNOPSIS
    Single entry point for Integration Engine workflows that build and package the LabVIEW Icon Editor without passing nested script paths.

.DESCRIPTION
    Wraps existing build/dev/packaging scripts so callers can run a single command such as:
        pwsh -File scripts/ie.ps1 build-worktree -Ref HEAD -SupportedBitness 64 -LvlibpBitness both
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory)][ValidateSet(
        'build-worktree',
        'build-pipeline',
        'build-lvlibp',
        'build-vip',
        'build-source-distribution',
        'apply-vipc',
        'dev-set',
        'dev-bind',
        'dev-revert',
        'dev-force-clean'
    )]
    [string]$Command,

    # Common inputs
    [string]$RepositoryPath,
    [string]$Ref = 'HEAD',
    [ValidateSet('32','64')]
    [string]$SupportedBitness = '64',
    [ValidateSet('both','64','32')]
    [string]$LvlibpBitness = 'both',
    [int]$Major = 0,
    [int]$Minor = 1,
    [int]$Patch = 0,
    [int]$Build = 0,
    [string]$Commit = 'manual',
    [string]$CompanyName = 'LabVIEW-Community-CI-CD',
    [string]$AuthorName = 'Local Developer',
    [int]$LabVIEWMinorRevision = 3,
    [string]$PackageLabVIEWVersion = '2021',
    [switch]$RunBothBitnessSeparately,

    # VIP/VIPB inputs
    [string]$VipcPath = 'runner_dependencies.vipc',
    [string]$VipbPath = 'Tooling/deployment/seed.vipb',
    [ValidateSet('32','64','both')]
    [string]$Bitness = '64',
    [string]$BuildMode = 'vip+lvlibp',
    [switch]$Simulate,
    [switch]$SkipCIGate,

    # Dev-mode inputs
    [ValidateSet('both','64','32')]
    [string]$DevModeBitness = 'both',
    [switch]$ForceBind,
    [string]$VipbPathForDevMode,
    [switch]$SkipConfirm
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

function Resolve-RepoRoot {
    param([string]$BasePath)
    if (-not [string]::IsNullOrWhiteSpace($BasePath)) {
        return (Resolve-Path -LiteralPath $BasePath -ErrorAction Stop).Path
    }
    $fromScript = Split-Path -Parent $PSScriptRoot
    try {
        return (Resolve-Path -LiteralPath $fromScript -ErrorAction Stop).Path
    }
    catch {
        throw "Unable to resolve repository root from '$BasePath' or script location."
    }
}

function Resolve-Script {
    param(
        [Parameter(Mandatory)][string]$RepoRoot,
        [Parameter(Mandatory)][string]$RelativePath
    )
    $full = Join-Path -Path $RepoRoot -ChildPath $RelativePath
    if (-not (Test-Path -LiteralPath $full)) {
        throw "Expected script not found at $full"
    }
    return $full
}

function Invoke-Script {
    param(
        [Parameter(Mandatory)][string]$Path,
        [hashtable]$ArgumentMap
    )

    $render = if ($ArgumentMap) {
        ($ArgumentMap.GetEnumerator() | ForEach-Object { "-$($_.Key) $($_.Value)" }) -join ' '
    } else { '' }
    Write-Information ("Executing: {0} {1}" -f $Path, $render) -InformationAction Continue

    if ($ArgumentMap) {
        & $Path @ArgumentMap
    }
    else {
        & $Path
    }

    if ($LASTEXITCODE -ne 0) {
        throw ("{0} failed with exit code {1}" -f (Split-Path -Leaf $Path), $LASTEXITCODE)
    }
}

$repoRoot = Resolve-RepoRoot -BasePath $RepositoryPath

switch ($Command) {
    'build-worktree' {
        $scriptPath = Resolve-Script -RepoRoot $repoRoot -RelativePath "scripts/run-worktree-task.ps1"
        $args = @{
            SourceRepoPath   = $repoRoot
            Ref              = $Ref
            SupportedBitness = $SupportedBitness
            LvlibpBitness    = $LvlibpBitness
            Major            = $Major
            Minor            = $Minor
            Patch            = $Patch
            Build            = $Build
            CompanyName      = $CompanyName
            AuthorName       = $AuthorName
        }
        if ($RunBothBitnessSeparately) { $args.RunBothBitnessSeparately = $true }
        Invoke-Script -Path $scriptPath -ArgumentMap $args
    }

    'build-pipeline' {
        $scriptPath = Resolve-Script -RepoRoot $repoRoot -RelativePath "scripts/run-build-or-package.ps1"
        $args = @{
            BuildMode            = $BuildMode
            WorkspacePath        = $repoRoot
            LabVIEWMinorRevision = $LabVIEWMinorRevision
            CompanyName          = $CompanyName
            AuthorName           = $AuthorName
            LvlibpBitness        = $LvlibpBitness
            VipbPath             = $VipbPath
        }
        if ($Simulate) { $args.Simulate = $true }
        Invoke-Script -Path $scriptPath -ArgumentMap $args
    }

    'build-lvlibp' {
        $scriptPath = Resolve-Script -RepoRoot $repoRoot -RelativePath "scripts/run-build-lvlibp-task.ps1"
        $args = @{
            RepositoryPath = $repoRoot
            SupportedBitness = $SupportedBitness
            Major = $Major
            Minor = $Minor
            Patch = $Patch
            Build = $Build
            Commit = $Commit
        }
        Invoke-Script -Path $scriptPath -ArgumentMap $args
    }

    'build-vip' {
        $scriptPath = Resolve-Script -RepoRoot $repoRoot -RelativePath "scripts/task-build-vip.ps1"
        $args = @{
            RepositoryPath = $repoRoot
            Bitness        = $Bitness
        }
        if ($SkipCIGate) { $args.SkipCIGate = $true }
        Invoke-Script -Path $scriptPath -ArgumentMap $args
    }

    'build-source-distribution' {
        $scriptPath = Resolve-Script -RepoRoot $repoRoot -RelativePath "scripts/build-source-distribution/Build_Source_Distribution.ps1"
        $args = @{
            RepositoryPath = $repoRoot
        }
        Invoke-Script -Path $scriptPath -ArgumentMap $args
    }

    'apply-vipc' {
        $scriptPath = Resolve-Script -RepoRoot $repoRoot -RelativePath "scripts/apply-vipc/ApplyVIPC.ps1"
        $args = @{
            Package_LabVIEW_Version = $PackageLabVIEWVersion
            SupportedBitness        = $SupportedBitness
            RepositoryPath          = $repoRoot
            VIPCPath                = $VipcPath
        }
        Invoke-Script -Path $scriptPath -ArgumentMap $args
    }

    'missing-in-project' {
        $scriptPath = Resolve-Script -RepoRoot $repoRoot -RelativePath "scripts/missing-in-project/Invoke-MissingInProjectCLI.ps1"
        $args = @{
            LVVersion   = $PackageLabVIEWVersion
            Arch        = $SupportedBitness
            ProjectFile = (Join-Path $repoRoot 'lv_icon_editor.lvproj')
        }
        Invoke-Script -Path $scriptPath -ArgumentMap $args
    }

    'dev-set' {
        $scriptPath = Resolve-Script -RepoRoot $repoRoot -RelativePath "scripts/set-development-mode/run-dev-mode.ps1"
        $args = @{
            SupportedBitness = $SupportedBitness
        }
        Invoke-Script -Path $scriptPath -ArgumentMap $args
    }

    'dev-bind' {
        $scriptPath = Resolve-Script -RepoRoot $repoRoot -RelativePath "scripts/bind-development-mode/BindDevelopmentMode.ps1"
        $args = @{
            RepositoryPath = $repoRoot
            Mode           = 'bind'
            Bitness        = $DevModeBitness
        }
        if ($ForceBind) { $args.Force = $true }
        Invoke-Script -Path $scriptPath -ArgumentMap $args
    }

    'dev-revert' {
        $scriptPath = Resolve-Script -RepoRoot $repoRoot -RelativePath "scripts/revert-development-mode/run-dev-mode.ps1"
        $args = @{
            SupportedBitness = $SupportedBitness
        }
        Invoke-Script -Path $scriptPath -ArgumentMap $args
    }

    'dev-force-clean' {
        $scriptPath = Resolve-Script -RepoRoot $repoRoot -RelativePath "scripts/dev-mode-force-clean.ps1"
        $args = @{
            RepositoryPath = $repoRoot
        }
        if ($VipbPathForDevMode) { $args.VipbPath = $VipbPathForDevMode }
        if ($SkipConfirm) { $args.SkipConfirm = $true }
        Invoke-Script -Path $scriptPath -ArgumentMap $args
    }

    default {
        throw "Unsupported command '$Command'"
    }
}
