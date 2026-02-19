#Requires -Version 7.0
<#
.SYNOPSIS
Dispatches deterministic prerelease publication for CI Pipeline.

.DESCRIPTION
Creates a temporary ci-run branch that points to an eligible merged PR merge commit
on develop, then dispatches .github/workflows/ci.yml with strict publish intent:
- publish_prerelease=true
- expected_sha=<target sha>
- strict_sha=true

By default, the helper resolves the latest merged PR targeting develop and uses its
merge commit SHA. You can override with -Sha.

.PARAMETER RepoRoot
Repository root path. Defaults to current directory.

.PARAMETER Repo
Repository in owner/name format. Defaults to Resolve-GitHubRepo.ps1 output.

.PARAMETER Sha
Target commit SHA (or rev-parse-compatible ref) to publish deterministically.
When omitted, the helper selects the latest merged PR merge commit on develop.

.PARAMETER ReleasePriority
Dispatch with force_gcli_lunit=true (release-priority profile).

.PARAMETER Wait
Wait for the dispatched workflow run to complete and return its final status.

.PARAMETER LookupAttempts
Number of polling attempts used to resolve the dispatched run id.

.PARAMETER LookupDelaySeconds
Delay between run-id polling attempts.

.PARAMETER KeepDispatchBranch
Keep the temporary remote ci-run branch after dispatch. Default is cleanup.

.PARAMETER DryRun
Print actions without pushing/dispatching/deleting remote refs.
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [string]$RepoRoot = '.',

    [Parameter(Mandatory = $false)]
    [string]$Repo = '',

    [Parameter(Mandatory = $false)]
    [string]$Sha = '',

    [switch]$ReleasePriority,

    [switch]$Wait,

    [ValidateRange(1, 60)]
    [int]$LookupAttempts = 12,

    [ValidateRange(1, 300)]
    [int]$LookupDelaySeconds = 5,

    [switch]$KeepDispatchBranch,

    [switch]$DryRun
)

$ErrorActionPreference = 'Stop'

function Invoke-GitCommand {
    param(
        [Parameter(Mandatory = $true)]
        [string[]]$Arguments,

        [Parameter(Mandatory = $true)]
        [string]$Description
    )

    $output = & git @Arguments 2>&1
    if ($LASTEXITCODE -ne 0) {
        throw ("{0} failed: git {1}`n{2}" -f $Description, ($Arguments -join ' '), ($output -join [Environment]::NewLine))
    }

    return @($output)
}

function Invoke-GhCommand {
    param(
        [Parameter(Mandatory = $true)]
        [string[]]$Arguments,

        [Parameter(Mandatory = $true)]
        [string]$Description
    )

    $output = & gh @Arguments 2>&1
    if ($LASTEXITCODE -ne 0) {
        throw ("{0} failed: gh {1}`n{2}" -f $Description, ($Arguments -join ' '), ($output -join [Environment]::NewLine))
    }

    return @($output)
}

function Get-RepoRootPath {
    param(
        [Parameter(Mandatory = $true)]
        [string]$PathInput
    )

    return (Resolve-Path -Path $PathInput -ErrorAction Stop).Path
}

function Get-RepositoryName {
    param(
        [Parameter(Mandatory = $true)]
        [string]$RepoRootPath,

        [Parameter(Mandatory = $false)]
        [string]$RepoOverride
    )

    if (-not [string]::IsNullOrWhiteSpace($RepoOverride)) {
        return $RepoOverride.Trim()
    }

    $resolverPath = Join-Path $RepoRootPath 'Tooling\Resolve-GitHubRepo.ps1'
    if (-not (Test-Path -LiteralPath $resolverPath -PathType Leaf)) {
        throw "Resolve-GitHubRepo.ps1 not found at $resolverPath"
    }

    $resolverOutput = @(& pwsh -NoProfile -File $resolverPath -RepoRoot $RepoRootPath)
    $resolverExitCode = if ($null -eq $LASTEXITCODE) { 0 } else { [int]$LASTEXITCODE }
    $resolved = if ($resolverOutput.Count -gt 0) { ([string]$resolverOutput[0]).Trim() } else { '' }

    if ($resolverExitCode -ne 0 -or [string]::IsNullOrWhiteSpace($resolved)) {
        throw 'Failed to resolve repository name from Resolve-GitHubRepo.ps1.'
    }

    return $resolved
}

function Get-MergedDevelopPullRequestCandidateList {
    param(
        [Parameter(Mandatory = $true)]
        [string]$RepoName
    )

    $listPullRequestArgs = @(
        'pr', 'list',
        '--repo', $RepoName,
        '--state', 'merged',
        '--base', 'develop',
        '--limit', '100',
        '--json', 'number,mergeCommit,mergedAt,url,title'
    )

    $raw = Invoke-GhCommand -Arguments $listPullRequestArgs -Description 'List merged pull requests targeting develop'
    $json = ($raw -join [Environment]::NewLine).Trim()
    $items = if ([string]::IsNullOrWhiteSpace($json)) { @() } else { @($json | ConvertFrom-Json) }

    $candidates = foreach ($item in $items) {
        $mergeSha = [string]$item.mergeCommit.oid
        if ([string]::IsNullOrWhiteSpace($mergeSha)) {
            continue
        }

        $mergedAt = [datetimeoffset]::MinValue
        $mergedAtRaw = [string]$item.mergedAt
        if (-not [string]::IsNullOrWhiteSpace($mergedAtRaw)) {
            [void][datetimeoffset]::TryParse($mergedAtRaw, [ref]$mergedAt)
        }

        [pscustomobject]@{
            Number   = [int]$item.number
            Url      = [string]$item.url
            Title    = [string]$item.title
            MergedAt = $mergedAt
            MergeSha = $mergeSha.ToLowerInvariant()
        }
    }

    if (-not $candidates -or $candidates.Count -eq 0) {
        throw "No merged pull requests targeting develop were found in $RepoName."
    }

    return @($candidates | Sort-Object -Property MergedAt -Descending)
}

function Get-EligibleMergedDevelopPullRequestForSha {
    param(
        [Parameter(Mandatory = $true)]
        [string]$RepoName,

        [Parameter(Mandatory = $true)]
        [string]$TargetSha
    )

    $normalizedSha = $TargetSha.Trim().ToLowerInvariant()
    if ([string]::IsNullOrWhiteSpace($normalizedSha)) {
        throw 'Target SHA is empty.'
    }

    $commitArgs = @(
        'api',
        '-H', 'Accept: application/vnd.github+json',
        ("/repos/{0}/commits/{1}" -f $RepoName, $normalizedSha)
    )
    $commitRaw = Invoke-GhCommand -Arguments $commitArgs -Description 'Read commit metadata'
    $commitJson = ($commitRaw -join [Environment]::NewLine).Trim()
    if ([string]::IsNullOrWhiteSpace($commitJson)) {
        throw ("Commit metadata lookup returned no content for SHA {0}." -f $normalizedSha)
    }
    $commit = $commitJson | ConvertFrom-Json
    $parentCount = @($commit.parents).Count
    if ($parentCount -lt 2) {
        throw ("SHA {0} is not a merge commit (parent count: {1}). Deterministic publish requires a merged PR merge commit on develop." -f $normalizedSha, $parentCount)
    }

    $pullArgs = @(
        'api',
        '-H', 'Accept: application/vnd.github+json',
        ("/repos/{0}/commits/{1}/pulls" -f $RepoName, $normalizedSha)
    )
    $pullRaw = Invoke-GhCommand -Arguments $pullArgs -Description 'Resolve pull requests associated with SHA'
    $pullJson = ($pullRaw -join [Environment]::NewLine).Trim()
    $pulls = if ([string]::IsNullOrWhiteSpace($pullJson)) { @() } else { @($pullJson | ConvertFrom-Json) }

    $mergedDevelopPulls = @(
        $pulls | Where-Object {
            $mergedAtRaw = [string]$_.merged_at
            $baseRef = [string]$_.base.ref
            -not [string]::IsNullOrWhiteSpace($mergedAtRaw) -and $baseRef -eq 'develop'
        }
    )

    $matchingPulls = @(
        $mergedDevelopPulls | Where-Object {
            $mergeCommitSha = [string]$_.merge_commit_sha
            -not [string]::IsNullOrWhiteSpace($mergeCommitSha) -and $mergeCommitSha.ToLowerInvariant() -eq $normalizedSha
        }
    )

    if ($matchingPulls.Count -eq 0) {
        if ($mergedDevelopPulls.Count -gt 0) {
            throw ("SHA {0} is associated with merged develop PRs, but does not match their merge_commit_sha." -f $normalizedSha)
        }

        throw ("SHA {0} is not associated with any merged PR targeting develop." -f $normalizedSha)
    }

    $selected = $matchingPulls | Sort-Object -Property merged_at -Descending | Select-Object -First 1
    return [pscustomobject]@{
        Number   = [int]$selected.number
        Url      = [string]$selected.html_url
        MergeSha = ([string]$selected.merge_commit_sha).ToLowerInvariant()
        MergedAt = [string]$selected.merged_at
    }
}

function Get-DispatchBranchName {
    param(
        [Parameter(Mandatory = $true)]
        [string]$TargetSha
    )

    $shortSha = if ($TargetSha.Length -ge 8) { $TargetSha.Substring(0, 8) } else { $TargetSha }
    $stamp = (Get-Date).ToUniversalTime().ToString('yyyyMMdd-HHmmss')
    return ("ci-run-prerelease-{0}-{1}" -f $shortSha, $stamp)
}

function Get-DispatchedRun {
    param(
        [Parameter(Mandatory = $true)]
        [string]$RepoName,

        [Parameter(Mandatory = $true)]
        [string]$DispatchBranch,

        [Parameter(Mandatory = $true)]
        [string]$TargetSha,

        [Parameter(Mandatory = $true)]
        [int]$Attempts,

        [Parameter(Mandatory = $true)]
        [int]$DelaySeconds
    )

    $normalizedSha = $TargetSha.ToLowerInvariant()
    for ($attemptIndex = 1; $attemptIndex -le $Attempts; $attemptIndex++) {
        $listRunArgs = @(
            'run', 'list',
            '--repo', $RepoName,
            '--workflow', 'ci.yml',
            '--event', 'workflow_dispatch',
            '--branch', $DispatchBranch,
            '--json', 'databaseId,url,status,conclusion,headBranch,headSha,createdAt',
            '--limit', '20'
        )

        $raw = Invoke-GhCommand -Arguments $listRunArgs -Description 'List workflow_dispatch runs'
        $json = ($raw -join [Environment]::NewLine).Trim()
        $runs = if ([string]::IsNullOrWhiteSpace($json)) { @() } else { @($json | ConvertFrom-Json) }

        $match = $runs |
            Where-Object {
                ([string]$_.headBranch -eq $DispatchBranch) -and
                ([string]$_.headSha).ToLowerInvariant() -eq $normalizedSha
            } |
            Sort-Object -Property createdAt -Descending |
            Select-Object -First 1

        if ($match) {
            return [pscustomobject]@{
                RunId      = [int64]$match.databaseId
                Url        = [string]$match.url
                Status     = [string]$match.status
                Conclusion = [string]$match.conclusion
                CreatedAt  = [string]$match.createdAt
            }
        }

        if ($attemptIndex -lt $Attempts) {
            Start-Sleep -Seconds $DelaySeconds
        }
    }

    return $null
}

function Remove-RemoteDispatchBranch {
    param(
        [Parameter(Mandatory = $true)]
        [string]$BranchName
    )

    try {
        $null = Invoke-GitCommand -Arguments @('push', 'origin', '--delete', $BranchName) -Description 'Delete temporary dispatch branch'
        return $true
    } catch {
        Write-Warning ("Unable to delete temporary dispatch branch '{0}': {1}" -f $BranchName, $_.Exception.Message)
        return $false
    }
}

if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
    throw 'git was not found on PATH.'
}
if (-not (Get-Command gh -ErrorAction SilentlyContinue)) {
    throw 'gh was not found on PATH.'
}

$repoRootPath = Get-RepoRootPath -PathInput $RepoRoot
Push-Location -Path $repoRootPath
try {
    $repositoryName = Get-RepositoryName -RepoRootPath $repoRootPath -RepoOverride $Repo
    Write-Host ("Repository: {0}" -f $repositoryName)

    $null = Invoke-GhCommand -Arguments @('auth', 'status', '-h', 'github.com') -Description 'Validate gh authentication'
    $null = Invoke-GitCommand -Arguments @('fetch', 'origin', 'develop', '--no-tags') -Description 'Fetch origin/develop'

    $selectedPullRequest = $null
    $targetSha = $null
    $eligiblePullRequest = $null
    if ([string]::IsNullOrWhiteSpace($Sha)) {
        $mergedPullRequests = Get-MergedDevelopPullRequestCandidateList -RepoName $repositoryName
        foreach ($candidatePullRequest in $mergedPullRequests) {
            $candidateSha = [string]$candidatePullRequest.MergeSha
            if ([string]::IsNullOrWhiteSpace($candidateSha)) {
                continue
            }

            try {
                $eligiblePullRequest = Get-EligibleMergedDevelopPullRequestForSha -RepoName $repositoryName -TargetSha $candidateSha
                $targetSha = $candidateSha
                $selectedPullRequest = $candidatePullRequest
                break
            } catch {
                $eligibilityError = $_.Exception.Message
                Write-Verbose ("Skipping merged PR #{0} ({1}) because it is not publish-eligible: {2}" -f $candidatePullRequest.Number, $candidateSha, $eligibilityError)
                continue
            }
        }

        if ([string]::IsNullOrWhiteSpace($targetSha) -or $null -eq $eligiblePullRequest) {
            throw "Unable to resolve an eligible merged develop merge commit for deterministic publish."
        }

        Write-Host ("Resolved latest eligible merged develop PR #{0}: {1}" -f $selectedPullRequest.Number, $selectedPullRequest.Url)
    } else {
        $targetSha = (Invoke-GitCommand -Arguments @('rev-parse', $Sha) -Description 'Resolve target SHA' | Select-Object -First 1).Trim().ToLowerInvariant()
        $eligiblePullRequest = Get-EligibleMergedDevelopPullRequestForSha -RepoName $repositoryName -TargetSha $targetSha
    }

    Write-Host ("Eligible merged develop PR #{0} for SHA {1}" -f $eligiblePullRequest.Number, $targetSha)

    $dispatchBranch = Get-DispatchBranchName -TargetSha $targetSha
    $pushRefSpec = ("{0}:refs/heads/{1}" -f $targetSha, $dispatchBranch)

    $dispatchArguments = @(
        'workflow', 'run', 'CI Pipeline',
        '--repo', $repositoryName,
        '--ref', $dispatchBranch,
        '-f', 'publish_prerelease=true',
        '-f', ("expected_sha={0}" -f $targetSha),
        '-f', 'strict_sha=true'
    )
    if ($ReleasePriority) {
        $dispatchArguments += @('-f', 'force_gcli_lunit=true')
    }

    if ($DryRun) {
        Write-Host ("[dry-run] git push origin {0}" -f $pushRefSpec)
        Write-Host ("[dry-run] gh {0}" -f ($dispatchArguments -join ' '))
        if (-not $KeepDispatchBranch) {
            Write-Host ("[dry-run] git push origin --delete {0}" -f $dispatchBranch)
        }
        return [pscustomobject]@{
            repo                   = $repositoryName
            sha                    = $targetSha
            merged_pr_number       = $eligiblePullRequest.Number
            merged_pr_url          = $eligiblePullRequest.Url
            dispatch_branch        = $dispatchBranch
            dispatched             = $false
            wait_requested         = [bool]$Wait
            release_priority_mode  = [bool]$ReleasePriority
            dry_run                = $true
            temp_branch_cleanup    = if ($KeepDispatchBranch) { 'skipped' } else { 'planned' }
        }
    }

    $dispatchBranchPushed = $false
    $cleanupResult = 'not-requested'
    $dispatchedRun = $null
    $watchStatus = 'not-requested'
    $watchConclusion = ''
    try {
        $null = Invoke-GitCommand -Arguments @('push', 'origin', $pushRefSpec) -Description 'Push temporary dispatch branch'
        $dispatchBranchPushed = $true

        $null = Invoke-GhCommand -Arguments $dispatchArguments -Description 'Dispatch CI Pipeline workflow'
        Write-Host ("Dispatched CI Pipeline for SHA {0} via ref {1}" -f $targetSha, $dispatchBranch)

        $dispatchedRun = Get-DispatchedRun `
            -RepoName $repositoryName `
            -DispatchBranch $dispatchBranch `
            -TargetSha $targetSha `
            -Attempts $LookupAttempts `
            -DelaySeconds $LookupDelaySeconds

        if ($dispatchedRun) {
            Write-Host ("Dispatched run: {0}" -f $dispatchedRun.Url)
        } else {
            Write-Warning 'Unable to resolve dispatched run id from workflow listing within lookup window.'
        }

        if ($Wait -and $dispatchedRun) {
            & gh run watch $dispatchedRun.RunId --repo $repositoryName --exit-status
            if ($LASTEXITCODE -ne 0) {
                throw ("Workflow run {0} completed with non-success status." -f $dispatchedRun.RunId)
            }

            $runViewArgs = @(
                'run', 'view', [string]$dispatchedRun.RunId,
                '--repo', $repositoryName,
                '--json', 'status,conclusion,url'
            )
            $runViewRaw = Invoke-GhCommand -Arguments $runViewArgs -Description 'Read dispatched run status'
            $runViewJson = ($runViewRaw -join [Environment]::NewLine).Trim()
            if (-not [string]::IsNullOrWhiteSpace($runViewJson)) {
                $runView = $runViewJson | ConvertFrom-Json
                $watchStatus = [string]$runView.status
                $watchConclusion = [string]$runView.conclusion
            } else {
                $watchStatus = 'unknown'
            }
        }
    } finally {
        if ($dispatchBranchPushed -and -not $KeepDispatchBranch) {
            $cleanupResult = if (Remove-RemoteDispatchBranch -BranchName $dispatchBranch) { 'deleted' } else { 'delete-failed' }
        } elseif ($dispatchBranchPushed -and $KeepDispatchBranch) {
            $cleanupResult = 'kept'
        } elseif (-not $dispatchBranchPushed) {
            $cleanupResult = 'not-created'
        }
    }

    return [pscustomobject]@{
        repo                   = $repositoryName
        sha                    = $targetSha
        merged_pr_number       = $eligiblePullRequest.Number
        merged_pr_url          = $eligiblePullRequest.Url
        dispatch_branch        = $dispatchBranch
        dispatched             = $true
        run_id                 = if ($dispatchedRun) { $dispatchedRun.RunId } else { $null }
        run_url                = if ($dispatchedRun) { $dispatchedRun.Url } else { '' }
        run_status             = if ($dispatchedRun) { $dispatchedRun.Status } else { '' }
        wait_requested         = [bool]$Wait
        wait_status            = $watchStatus
        wait_conclusion        = $watchConclusion
        release_priority_mode  = [bool]$ReleasePriority
        dry_run                = $false
        temp_branch_cleanup    = $cleanupResult
    }
} finally {
    Pop-Location
}
