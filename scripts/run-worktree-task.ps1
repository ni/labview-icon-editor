[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$SourceRepoPath,
    [Parameter(Mandatory = $true)]
    [string]$Ref,
    [Parameter(Mandatory = $true)]
    [ValidateSet('both','64','32')]
    [string]$SupportedBitness,
    [Parameter(Mandatory = $true)]
    [ValidateSet('both','64','32')]
    [string]$LvlibpBitness,
    [Parameter(Mandatory = $true)]
    [int]$Major,
    [Parameter(Mandatory = $true)]
    [int]$Minor,
    [Parameter(Mandatory = $true)]
    [int]$Patch,
    [Parameter(Mandatory = $true)]
    [int]$Build,
    [Parameter(Mandatory = $true)]
    [string]$CompanyName,
    [Parameter(Mandatory = $true)]
    [string]$AuthorName,
    [switch]$RunBothBitnessSeparately
)

$ErrorActionPreference = 'Stop'

if (-not $IsWindows) {
    Write-Error 'Build (isolated worktree) requires Windows/PowerShell'
    exit 1
}

# Resolve repository root robustly (covers cases where known folders move when OneDrive is enabled/disabled).
$resolverPath = Join-Path $PSScriptRoot 'common/resolve-repo-root.ps1'
if (-not (Test-Path -LiteralPath $resolverPath -PathType Leaf)) {
    Write-Error "Repo resolver not found at $resolverPath"
    exit 1
}
. $resolverPath
$resolvedRepo = Resolve-RepoRoot -StartPaths @($SourceRepoPath, $PSScriptRoot, (Get-Location).Path)
if (-not $resolvedRepo) {
    Write-Error "Unable to resolve repository root from '$SourceRepoPath' or the current script location."
    exit 1
}
$SourceRepoPath = $resolvedRepo

if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
    Write-Warning "git not found on PATH; falling back to in-place orchestrator build (no worktree isolation)."
    $dotnet = Get-Command dotnet -ErrorAction SilentlyContinue
    if (-not $dotnet) {
        Write-Error "dotnet CLI not found; cannot run fallback build without git."
        exit 1
    }

    $resolver = Join-Path $PSScriptRoot 'common/resolve-repo-cli.ps1'
    if (-not (Test-Path -LiteralPath $resolver -PathType Leaf)) {
        Write-Error "CLI resolver not found at $resolver; cannot run fallback build without git."
        exit 1
    }
    $prov = & $resolver -CliName 'OrchestrationCli' -RepoPath $SourceRepoPath -SourceRepoPath $SourceRepoPath -PrintProvenance:$false
    $cliArgs = @(
        "package-build",
        "--repo", $SourceRepoPath,
        "--ref", $Ref,
        "--bitness", $SupportedBitness,
        "--lvlibp-bitness", $LvlibpBitness,
        "--major", $Major,
        "--minor", $Minor,
        "--patch", $Patch,
        "--build", $Build,
        "--company", $CompanyName,
        "--author", $AuthorName,
        "--labview-minor", "3"
    )
    if ($IsWindows) { $cliArgs += "--managed" }

    Write-Host ("{0} {1}" -f $prov.Command[0], ($prov.Command[1..($prov.Command.Count-1)] + $cliArgs -join ' '))
    & $prov.Command[0] @($prov.Command[1..($prov.Command.Count-1)]) @cliArgs
    exit $LASTEXITCODE
}

Write-Output '##vscode[notification type=info;title=Build]Isolated worktree build started'

$worktree = Join-Path $PSScriptRoot 'worktree-build.ps1'
$forward = @{
    SourceRepoPath   = $SourceRepoPath
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

if ($RunBothBitnessSeparately) {
    $forward.RunBothBitnessSeparately = $true
}

if ($PSBoundParameters.ContainsKey('Verbose')) {
    $forward.Verbose = $true
}

$code = 1
try {
    & $worktree @forward
    $code = $LASTEXITCODE
}
catch {
    Write-Output "Inner launch failed: $($_.Exception.Message)"
    if ($_.ScriptStackTrace) {
        Write-Output ("Stack: {0}" -f $_.ScriptStackTrace)
    }
    if ($_.InvocationInfo) {
        Write-Output ("At {0}:{1}" -f $_.InvocationInfo.ScriptName, $_.InvocationInfo.ScriptLineNumber)
    }
    $code = 1
}
finally {
    if ($code -eq 0) {
        Write-Output '##vscode[notification type=info;title=Build]Isolated worktree build succeeded'
    }
    else {
        Write-Output ("##vscode[notification type=error;title=Build]Isolated worktree build failed (exit {0})" -f $code)
    }
    exit $code
}
