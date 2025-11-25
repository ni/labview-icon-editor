[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$SourceRepoPath,
    [Parameter(Mandatory = $true)]
    [string]$Ref,
    [Parameter(Mandatory = $true)]
    [string]$SupportedBitness,
    [Parameter(Mandatory = $true)]
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
    [string]$AuthorName
)

$ErrorActionPreference = 'Stop'

if (-not $IsWindows) {
    Write-Error 'Build (isolated worktree) requires Windows/PowerShell'
    exit 1
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
