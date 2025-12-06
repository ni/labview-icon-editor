param(
    [string]$RepoRoot = '.',
    [string]$BaseBranch = 'main',
    [string]$WorkBranch = '',
    [switch]$RequireClean,
    [switch]$RunTests,
    [string]$BuildConfiguration = 'Debug',
    [string]$ForceSimulationSubcommands = 'srs',
    [switch]$PromptOnFetchFailure
)

$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'

$RepoRoot = (Resolve-Path $RepoRoot).Path
Push-Location $RepoRoot
try {
    if (-not (Test-Path -LiteralPath '.git')) { throw "Not a git repo: $RepoRoot" }

    $gitCmd = Get-Command git -ErrorAction SilentlyContinue
    if (-not $gitCmd) { throw 'git not found in PATH' }

    function Invoke-Git {
        param([string[]]$GitArgs)
        $out = & git -C $RepoRoot @GitArgs 2>&1
        return [pscustomobject]@{ Code = [int]($LASTEXITCODE ?? 0); Out = ($out -join "`n").TrimEnd(); Err = '' }
    }

    $issues = @()
    $results = @{ git = $gitCmd.Source }

    $status = Invoke-Git @('status','--porcelain')
    if ($RequireClean -and $status.Out.Length -gt 0) { $issues += 'Working tree not clean' }
    $results.status = $status.Out

    $head = Invoke-Git @('rev-parse','--abbrev-ref','HEAD')
    if ($head.Code -ne 0) {
        $issues += "Cannot read current branch (exit $($head.Code))"
        if ($head.Out) { $results.branchErr = $head.Out }
    }
    $currentBranch = $head.Out
    if ([string]::IsNullOrWhiteSpace($WorkBranch)) { $WorkBranch = $currentBranch }
    if ($currentBranch -eq 'HEAD') { $issues += 'Detached HEAD' }
    $results.branch = $WorkBranch

    $rebaseApply = Test-Path -LiteralPath '.git/rebase-apply'
    $rebaseMerge = Test-Path -LiteralPath '.git/rebase-merge'
    $mergeHead = Test-Path -LiteralPath '.git/MERGE_HEAD'
    if ($rebaseApply -or $rebaseMerge -or $mergeHead) { $issues += 'Rebase or merge in progress' }

    $fetch = Invoke-Git @('fetch','--all','--prune')
    $results.fetch = $fetch.Out
    $fetchIssue = $null
    if ($fetch.Code -ne 0) { $fetchIssue = "Fetch failed (exit $($fetch.Code))" }

    if ($fetchIssue -and $PromptOnFetchFailure -and [Environment]::UserInteractive) {
        Write-Warning "Fetch failed; retrying interactively so credential prompts can appear."
        $null = & git -C $RepoRoot fetch --all --prune
        $results.fetchRetryCode = [int]($LASTEXITCODE ?? 0)
        if ($LASTEXITCODE -eq 0) {
            $fetchIssue = $null
        }
    }

    if ($fetchIssue) { $issues += $fetchIssue }

    $baseRemote = Invoke-Git @('show-ref','--quiet',"refs/remotes/origin/$BaseBranch")
    if ($baseRemote.Code -ne 0) { $issues += "Missing origin/$BaseBranch" }
    $baseLocal = Invoke-Git @('show-ref','--quiet',"refs/heads/$BaseBranch")
    if ($baseLocal.Code -ne 0) { $issues += "Missing local $BaseBranch" }

    $upstream = Invoke-Git @('rev-parse','--abbrev-ref','--symbolic-full-name',"$WorkBranch@{u}")
    if ($upstream.Code -ne 0) {
        $issues += "No upstream for $WorkBranch"
    } else {
        $results.upstream = $upstream.Out
        $div = Invoke-Git @('rev-list','--left-right','--count',"$WorkBranch...$($upstream.Out)")
        if ($div.Code -eq 0) {
            $parts = $div.Out.Split(' ',[System.StringSplitOptions]::RemoveEmptyEntries)
            if ($parts.Count -eq 2) {
                $results.behindUpstream = [int]$parts[0]
                $results.aheadUpstream = [int]$parts[1]
                if ($results.behindUpstream -gt 0) { $issues += "$WorkBranch is behind upstream" }
            }
        }
    }

    $baseDiv = Invoke-Git @('rev-list','--left-right','--count',"origin/$BaseBranch...$WorkBranch")
    if ($baseDiv.Code -eq 0) {
        $parts = $baseDiv.Out.Split(' ',[System.StringSplitOptions]::RemoveEmptyEntries)
        if ($parts.Count -eq 2) {
            $results.behindBase = [int]$parts[0]
            $results.aheadBase = [int]$parts[1]
        }
    }

    if ($RunTests) {
        $testLog = Join-Path $RepoRoot "builds/tests/dotnet/git-check-$((Get-Date).ToString('yyyyMMdd-HHmmss')).log"
        $testCmd = @('pwsh','-NoProfile','-File','scripts/x-cli/run-dotnet-tests.ps1','-RepoRoot',$RepoRoot,'-BuildConfiguration',$BuildConfiguration,'-ForceSimulationSubcommands',$ForceSimulationSubcommands)
        Write-Host "==> tests" -ForegroundColor Cyan
        $null = & $testCmd[0] $testCmd[1..($testCmd.Length-1)] *>&1 | Tee-Object -FilePath $testLog -Append | Out-Host
        $results.testLog = $testLog
        $results.testExit = [int]($LASTEXITCODE ?? 0)
        if ($LASTEXITCODE -ne 0) { $issues += 'Tests failed' }
    }

    $results.issues = $issues
    $results | ConvertTo-Json -Depth 6 | Write-Output

    if ($issues.Count -gt 0) { exit 1 } else { exit 0 }
}
finally {
    Pop-Location -ErrorAction SilentlyContinue
}
