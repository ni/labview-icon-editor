#Requires -Version 7.0
<#
.SYNOPSIS
    Orchestrates worktree selection/build and optionally runs local CI parity.

.DESCRIPTION
    Resolves repo/worktree roots, applies a worktree policy (strict/auto/relaxed),
    builds runner-cli in the selected worktree, and can invoke Run-CICompositeLocal.ps1.

.PARAMETER RepoRoot
    Optional repo root override. Defaults to git root or script location.

.PARAMETER WorktreeRoot
    Optional worktree root override. Defaults to LVIE_WORKTREE_ROOT or Ensure-WorktreeRoot.

.PARAMETER WorktreePolicy
    Strict | Auto | Relaxed. Defaults to Strict on CI, Auto for local runs.

.PARAMETER Ref
    Git ref for new worktree creation (Auto policy).

.PARAMETER ConfigPath
    Optional config path (defaults to Tooling/lvie.config.json when present).

.PARAMETER NoRepoNamePrefix
    Forwarded to New-CIWorktree.ps1 to omit repo name prefix.

.PARAMETER Run
    Invoke the run script after orchestration.

.PARAMETER RunScript
    Script to execute when Run is set. Default: Tooling/Run-CICompositeLocal.ps1

.PARAMETER RunArgs
    Arguments forwarded to the run script.
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [string]$RepoRoot,

    [Parameter(Mandatory = $false)]
    [string]$WorktreeRoot,

    [Parameter(Mandatory = $false)]
    [ValidateSet('Strict', 'Auto', 'Relaxed')]
    [string]$WorktreePolicy,

    [Parameter(Mandatory = $false)]
    [string]$Ref = 'HEAD',

    [Parameter(Mandatory = $false)]
    [string]$ConfigPath,

    [Parameter(Mandatory = $false)]
    [switch]$NoRepoNamePrefix,

    [Parameter(Mandatory = $false)]
    [switch]$Run,

    [Parameter(Mandatory = $false)]
    [string]$RunScript = 'Tooling/Run-CICompositeLocal.ps1',

    [Parameter(Mandatory = $false)]
    [string[]]$RunArgs = @()
)

$ErrorActionPreference = 'Stop'

function Resolve-RepoRoot {
    param([string]$BasePath)

    if (-not [string]::IsNullOrWhiteSpace($BasePath)) {
        return (Resolve-Path -Path $BasePath -ErrorAction Stop).Path
    }

    $scriptRoot = if ($PSScriptRoot) { $PSScriptRoot } else { Split-Path -Parent $PSCommandPath }
    $git = Get-Command git -ErrorAction SilentlyContinue
    if ($git) {
        try {
            $gitRoot = git -C $scriptRoot rev-parse --show-toplevel 2>$null
            if ($LASTEXITCODE -eq 0 -and -not [string]::IsNullOrWhiteSpace($gitRoot)) {
                return (Resolve-Path -Path $gitRoot.Trim() -ErrorAction Stop).Path
            }
        } catch {
            Write-Verbose ("git rev-parse failed: {0}" -f $_.Exception.Message)
        }
    }

    return (Resolve-Path -Path (Split-Path -Parent $scriptRoot) -ErrorAction Stop).Path
}

function Read-LvieConfig {
    param(
        [string]$RepoRootResolved,
        [string]$PathOverride
    )

    $path = $PathOverride
    if ([string]::IsNullOrWhiteSpace($path)) {
        $candidate = Join-Path $RepoRootResolved 'Tooling\lvie.config.json'
        if (Test-Path -Path $candidate) {
            $path = $candidate
        }
    }

    if ([string]::IsNullOrWhiteSpace($path)) {
        return $null
    }

    if (-not (Test-Path -Path $path)) {
        throw "Config file not found at $path"
    }

    try {
        return Get-Content -Raw -Path $path | ConvertFrom-Json -Depth 8
    } catch {
        throw ("Failed to parse config at {0}: {1}" -f $path, $_.Exception.Message)
    }
}

function Resolve-WorktreePolicy {
    param(
        [string]$PolicyOverride,
        [object]$Config
    )

    if (-not [string]::IsNullOrWhiteSpace($PolicyOverride)) {
        return $PolicyOverride
    }

    if (-not [string]::IsNullOrWhiteSpace($env:LVIE_WORKTREE_POLICY)) {
        return $env:LVIE_WORKTREE_POLICY
    }

    $isCi = $env:GITHUB_ACTIONS -eq 'true'
    if ($isCi) {
        return 'Strict'
    }

    if ($Config -and $Config.worktree -and -not [string]::IsNullOrWhiteSpace($Config.worktree.policy)) {
        return $Config.worktree.policy
    }

    return 'Auto'
}

function Resolve-WorktreeRoot {
    param(
        [string]$RootOverride,
        [object]$Config,
        [string]$RepoRootResolved
    )

    $root = $RootOverride
    if ([string]::IsNullOrWhiteSpace($root)) {
        $root = $env:LVIE_WORKTREE_ROOT
    }
    if ([string]::IsNullOrWhiteSpace($root) -and $Config -and $Config.worktree) {
        $root = $Config.worktree.root
    }

    if (-not [string]::IsNullOrWhiteSpace($root) -and -not [System.IO.Path]::IsPathRooted($root)) {
        $root = Join-Path $RepoRootResolved $root
    }

    if ([string]::IsNullOrWhiteSpace($root)) {
        return $null
    }

    $ensureScript = Join-Path $RepoRootResolved 'Tooling\Ensure-WorktreeRoot.ps1'
    if (-not (Test-Path -Path $ensureScript)) {
        throw "Ensure-WorktreeRoot.ps1 not found at $ensureScript"
    }

    return & $ensureScript -WorktreeRoot $root
}

function Test-IsUnderRoot {
    param(
        [string]$Path,
        [string]$Root
    )

    if ([string]::IsNullOrWhiteSpace($Path) -or [string]::IsNullOrWhiteSpace($Root)) {
        return $false
    }

    $pathFull = [System.IO.Path]::GetFullPath($Path)
    $rootFull = [System.IO.Path]::GetFullPath($Root)
    if (-not $rootFull.EndsWith('\')) {
        $rootFull = $rootFull + '\'
    }

    return $pathFull.StartsWith($rootFull, [System.StringComparison]::OrdinalIgnoreCase)
}

function Get-RunnerCliRuntime {
    $arch = [System.Runtime.InteropServices.RuntimeInformation]::OSArchitecture
    if ($IsWindows) { return 'win-x64' }
    if ($IsLinux) {
        if ($arch -eq 'Arm64') { return 'linux-arm64' }
        return 'linux-x64'
    }
    if ($IsMacOS) {
        if ($arch -eq 'Arm64') { return 'osx-arm64' }
        return 'osx-x64'
    }
    return 'win-x64'
}

function Get-RunnerCliFileName {
    param([string]$Runtime)
    if ($Runtime -like 'win-*') { return 'runner-cli.exe' }
    return 'runner-cli'
}

function Initialize-RunnerCli {
    param(
        [string]$RepoRootResolved
    )

    $ensureCli = Join-Path $RepoRootResolved 'Tooling\Ensure-RunnerCli.ps1'
    if (-not (Test-Path -Path $ensureCli)) {
        Write-Warning "Ensure-RunnerCli.ps1 not found at $ensureCli; skipping runner-cli build."
        return $null
    }

    $runtime = Get-RunnerCliRuntime
    $cliFile = Get-RunnerCliFileName -Runtime $runtime
    $preferred = Join-Path $RepoRootResolved "Tooling\runner-cli\publish\$runtime\$cliFile"

    try {
        return & $ensureCli -RepoRoot $RepoRootResolved -RunnerCliPath $preferred -SkipDownload
    } catch {
        if ($env:LVIE_REQUIRE_RUNNER_CLI -eq '1') {
            throw
        }
        Write-Warning ("runner-cli build failed: {0}" -f $_.Exception.Message)
        return $null
    }
}

function Resolve-RunScriptPath {
    param(
        [string]$RepoRootResolved,
        [string]$RunScriptValue
    )

    if ([string]::IsNullOrWhiteSpace($RunScriptValue)) {
        return $null
    }

    if ([System.IO.Path]::IsPathRooted($RunScriptValue)) {
        return $RunScriptValue
    }

    return Join-Path $RepoRootResolved $RunScriptValue
}

$repoRootResolved = Resolve-RepoRoot -BasePath $RepoRoot
$config = Read-LvieConfig -RepoRootResolved $repoRootResolved -PathOverride $ConfigPath
$policy = Resolve-WorktreePolicy -PolicyOverride $WorktreePolicy -Config $config
$root = $null

if ($policy -eq 'Strict' -or $policy -eq 'Auto') {
    $root = Resolve-WorktreeRoot -RootOverride $WorktreeRoot -Config $config -RepoRootResolved $repoRootResolved
}

$targetRepoRoot = $repoRootResolved

if ($policy -eq 'Strict') {
    if (-not (Test-IsUnderRoot -Path $repoRootResolved -Root $root)) {
        throw ("RepoRoot '{0}' is not under worktree root '{1}'. Set LVIE_WORKTREE_ROOT or run from a worktree." -f $repoRootResolved, $root)
    }
}

if ($policy -eq 'Auto') {
    if (-not (Test-IsUnderRoot -Path $repoRootResolved -Root $root)) {
        $worktreeScript = Join-Path $repoRootResolved 'Tooling\New-CIWorktree.ps1'
        if (-not (Test-Path -Path $worktreeScript)) {
            throw "New-CIWorktree.ps1 not found at $worktreeScript"
        }
        Write-Host ("RepoRoot is outside worktree root. Creating worktree under {0}..." -f $root)
        $targetRepoRoot = & $worktreeScript -Ref $Ref -WorktreeRoot $root -NoRepoNamePrefix:$NoRepoNamePrefix
    }
}

if ($policy -eq 'Relaxed' -and $root -and -not (Test-IsUnderRoot -Path $repoRootResolved -Root $root)) {
    Write-Warning ("RepoRoot '{0}' is not under worktree root '{1}'. Continuing (Relaxed policy)." -f $repoRootResolved, $root)
}

    $runnerCli = Initialize-RunnerCli -RepoRootResolved $targetRepoRoot

Write-Host ("Worktree policy: {0}" -f $policy)
if ($root) {
    Write-Host ("Worktree root: {0}" -f $root)
}
Write-Host ("Repo root: {0}" -f $targetRepoRoot)
if ($runnerCli -and $runnerCli.Path) {
    Write-Host ("Runner CLI: {0}" -f $runnerCli.Path)
}

$shouldRun = $Run.IsPresent -or ($RunArgs.Count -gt 0)
if ($shouldRun) {
    $scriptPath = Resolve-RunScriptPath -RepoRootResolved $targetRepoRoot -RunScriptValue $RunScript
    if (-not $scriptPath -or -not (Test-Path -Path $scriptPath)) {
        throw "Run script not found at $scriptPath"
    }

    if ($root) {
        $env:LVIE_WORKTREE_ROOT = $root
    }

    $argsToUse = @()
    if ($RunArgs) {
        $argsToUse += $RunArgs
    }
    if ($scriptPath -like '*Run-CICompositeLocal.ps1' -and ($argsToUse -notcontains '-Orchestrated')) {
        $argsToUse += '-Orchestrated'
    }

    Write-Host ("Invoking: pwsh -NoProfile -File {0} {1}" -f $scriptPath, ($argsToUse -join ' '))
    & pwsh -NoProfile -File $scriptPath @argsToUse
    if ($LASTEXITCODE -ne 0 -and $LASTEXITCODE -ne $null) {
        exit $LASTEXITCODE
    }
}

return [pscustomobject]@{
    Policy        = $policy
    WorktreeRoot  = $root
    RepoRoot      = $targetRepoRoot
    RunnerCliPath = if ($runnerCli) { $runnerCli.Path } else { $null }
    ConfigPath    = if ($ConfigPath) { $ConfigPath } else { (Join-Path $repoRootResolved 'Tooling\lvie.config.json') }
}
