[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$SourceRepoPath,
    [string]$Ref = 'HEAD',
    [ValidateSet('both','64','32')]
    [string]$SupportedBitness = 'both',
    [switch]$KeepWorktree
)

$ErrorActionPreference = 'Stop'

Write-Output '##vscode[notification type=info;title=Tests]Isolated worktree test run started'

$worker = Join-Path $PSScriptRoot 'worktree-test.ps1'
$forward = @{
    SourceRepoPath   = $SourceRepoPath
    Ref              = $Ref
    SupportedBitness = $SupportedBitness
}
if ($KeepWorktree) { $forward.KeepWorktree = $true }
if ($PSBoundParameters.ContainsKey('Verbose')) { $forward.Verbose = $true }

$code = 1
try {
    & $worker @forward
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
        Write-Output '##vscode[notification type=info;title=Tests]Isolated worktree test run succeeded'
    }
    else {
        Write-Output ("##vscode[notification type=error;title=Tests]Isolated worktree test run failed (exit {0})" -f $code)
    }
    exit $code
}
