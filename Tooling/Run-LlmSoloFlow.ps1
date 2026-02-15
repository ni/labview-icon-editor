#Requires -Version 7.0
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [ValidateSet('validate', 'integrate', 'release')]
    [string]$Mode,

    [string]$TargetBranch = '456-2020-migration',

    [string]$SourceBranch = '',

    [switch]$PublishPrerelease,

    [string]$ExpectedSha = '',

    [switch]$RunLocalParity,

    [ValidateRange(1, 20)]
    [int]$MaxParityAttempts = 3
)

$ErrorActionPreference = 'Stop'

function Resolve-RepoRoot {
    $gitRoot = & git rev-parse --show-toplevel 2>$null
    if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrWhiteSpace($gitRoot)) {
        throw 'Unable to resolve git repository root.'
    }
    return (Resolve-Path -Path $gitRoot.Trim() -ErrorAction Stop).Path
}

function Invoke-GitCommand {
    param(
        [Parameter(Mandatory = $true)]
        [string[]]$Arguments,

        [string]$Description = 'git command'
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

        [string]$Description = 'gh command'
    )

    $output = & gh @Arguments 2>&1
    if ($LASTEXITCODE -ne 0) {
        throw ("{0} failed: gh {1}`n{2}" -f $Description, ($Arguments -join ' '), ($output -join [Environment]::NewLine))
    }
    return @($output)
}

function Assert-GhReady {
    if (-not (Get-Command gh -ErrorAction SilentlyContinue)) {
        throw 'GitHub CLI (gh) is required for integrate/release modes.'
    }

    $null = Invoke-GhCommand -Arguments @('auth', 'status', '-h', 'github.com') -Description 'gh auth status'
}

function Resolve-CurrentBranch {
    $branch = (Invoke-GitCommand -Arguments @('rev-parse', '--abbrev-ref', 'HEAD') -Description 'Resolve current branch' | Select-Object -First 1).Trim()
    if ([string]::IsNullOrWhiteSpace($branch) -or $branch -eq 'HEAD') {
        throw 'Current branch is detached HEAD. Check out a branch before running.'
    }
    return $branch
}

function Assert-CleanWorktree {
    $statusLines = @(Invoke-GitCommand -Arguments @('status', '--porcelain') -Description 'Check working tree status')
    if ($statusLines.Count -gt 0) {
        throw "Working tree is not clean. Commit or stash changes before running '$Mode' mode."
    }
}

function Invoke-ValidationSuite {
    param(
        [Parameter(Mandatory = $true)]
        [string]$RepoRootPath
    )

    $results = New-Object System.Collections.Generic.List[object]
    $steps = @(
        [pscustomobject]@{
            Name   = 'Test-PathContract'
            Action = {
                param([string]$RootPath)
                $scriptPath = Join-Path $RootPath 'Tooling\Test-PathContract.ps1'
                & pwsh -NoProfile -File $scriptPath -WriteSummary
                if ($LASTEXITCODE -ne 0) {
                    throw "Script exited with code $LASTEXITCODE."
                }
            }
        },
        [pscustomobject]@{
            Name   = 'Test-CiPipelineSelectorDevModeContract'
            Action = {
                param([string]$RootPath)
                $scriptPath = Join-Path $RootPath 'Tooling\Test-CiPipelineSelectorDevModeContract.ps1'
                & pwsh -NoProfile -File $scriptPath -WriteSummary
                if ($LASTEXITCODE -ne 0) {
                    throw "Script exited with code $LASTEXITCODE."
                }
            }
        },
        [pscustomobject]@{
            Name   = 'Test-SoloMaintainerWorkflowContract'
            Action = {
                param([string]$RootPath)
                $scriptPath = Join-Path $RootPath 'Tooling\Test-SoloMaintainerWorkflowContract.ps1'
                & pwsh -NoProfile -File $scriptPath -WriteSummary
                if ($LASTEXITCODE -ne 0) {
                    throw "Script exited with code $LASTEXITCODE."
                }
            }
        },
        [pscustomobject]@{
            Name   = 'Pester PathContract.Tests.ps1'
            Action = {
                param([string]$RootPath)
                $testPath = Join-Path $RootPath 'Tooling\tests\PathContract.Tests.ps1'
                $testResult = Invoke-Pester -Path $testPath -PassThru -Output Detailed
                if ($null -eq $testResult -or $testResult.FailedCount -gt 0) {
                    throw 'Pester test run reported failures.'
                }
            }
        },
        [pscustomobject]@{
            Name   = 'Pester CiPipelineSelectorDevModeContract.Tests.ps1'
            Action = {
                param([string]$RootPath)
                $testPath = Join-Path $RootPath 'Tooling\tests\CiPipelineSelectorDevModeContract.Tests.ps1'
                $testResult = Invoke-Pester -Path $testPath -PassThru -Output Detailed
                if ($null -eq $testResult -or $testResult.FailedCount -gt 0) {
                    throw 'Pester test run reported failures.'
                }
            }
        },
        [pscustomobject]@{
            Name   = 'Pester SoloMaintainerWorkflowContract.Tests.ps1'
            Action = {
                param([string]$RootPath)
                $testPath = Join-Path $RootPath 'Tooling\tests\SoloMaintainerWorkflowContract.Tests.ps1'
                $testResult = Invoke-Pester -Path $testPath -PassThru -Output Detailed
                if ($null -eq $testResult -or $testResult.FailedCount -gt 0) {
                    throw 'Pester test run reported failures.'
                }
            }
        }
    )

    foreach ($step in $steps) {
        Write-Host ("[validate] {0}" -f $step.Name)
        try {
            & $step.Action $RepoRootPath
            $results.Add([pscustomobject]@{
                    name   = $step.Name
                    status = 'pass'
                    detail = ''
                }) | Out-Null
        } catch {
            $message = $_.Exception.Message
            $results.Add([pscustomobject]@{
                    name   = $step.Name
                    status = 'fail'
                    detail = $message
                }) | Out-Null
            throw ("Validation step failed: {0}. {1}" -f $step.Name, $message)
        }
    }

    return @($results.ToArray())
}

function Invoke-LocalParity {
    param(
        [Parameter(Mandatory = $true)]
        [string]$RepoRootPath,

        [Parameter(Mandatory = $true)]
        [int]$Attempts
    )

    $parityScript = Join-Path $RepoRootPath 'Tooling\Run-CICompositeLocal-Auto.ps1'
    if (-not (Test-Path -LiteralPath $parityScript -PathType Leaf)) {
        throw "Run-CICompositeLocal-Auto.ps1 not found at $parityScript"
    }

    Write-Host ("[integrate] Running local parity loop (max attempts: {0})" -f $Attempts)
    & pwsh -NoProfile -File $parityScript -MaxAttempts $Attempts -UseWorktree:$false -SkipWorktreeRootCheck
    if ($LASTEXITCODE -ne 0) {
        throw "Local parity failed with exit code $LASTEXITCODE."
    }
}

function Resolve-RepositoryName {
    param(
        [Parameter(Mandatory = $true)]
        [string]$RepoRootPath
    )

    $resolverScript = Join-Path $RepoRootPath 'Tooling\Resolve-GitHubRepo.ps1'
    if (-not (Test-Path -LiteralPath $resolverScript -PathType Leaf)) {
        throw "Repository resolver script not found: $resolverScript"
    }

    $repoName = (& pwsh -NoProfile -File $resolverScript -RepoRoot $RepoRootPath | Select-Object -First 1).Trim()
    if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrWhiteSpace($repoName)) {
        throw 'Failed to resolve GitHub repository name.'
    }

    return $repoName
}

function Invoke-SourceBranchPush {
    param(
        [Parameter(Mandatory = $true)]
        [string]$BranchName
    )

    Write-Host ("[integrate] Pushing branch '{0}' to origin" -f $BranchName)
    $null = Invoke-GitCommand -Arguments @('push', 'origin', $BranchName) -Description 'Push source branch'
}

function Get-OrCreatePullRequest {
    param(
        [Parameter(Mandatory = $true)]
        [string]$RepoName,

        [Parameter(Mandatory = $true)]
        [string]$SourceBranchName,

        [Parameter(Mandatory = $true)]
        [string]$TargetBranchName
    )

    $listArgs = @(
        'pr', 'list',
        '--repo', $RepoName,
        '--head', $SourceBranchName,
        '--base', $TargetBranchName,
        '--state', 'open',
        '--json', 'number,url'
    )
    $existingRaw = Invoke-GhCommand -Arguments $listArgs -Description 'List existing pull requests'
    $existingJson = ($existingRaw -join [Environment]::NewLine).Trim()
    $existingList = if ([string]::IsNullOrWhiteSpace($existingJson)) { @() } else { @($existingJson | ConvertFrom-Json) }

    if ($existingList.Count -gt 0) {
        $existing = $existingList[0]
        return [pscustomobject]@{
            Number  = [int]$existing.number
            Url     = [string]$existing.url
            Created = $false
        }
    }

    $title = ("chore(solo): integrate {0} into {1}" -f $SourceBranchName, $TargetBranchName)
    $body = @(
        '## Solo Integration PR'
        ''
        '- Generated by `Tooling/Run-LlmSoloFlow.ps1`'
        '- Mode: `integrate`'
        ("- Source branch: {0}" -f $SourceBranchName)
        ("- Target branch: {0}" -f $TargetBranchName)
        ''
        'Validation gates:'
        '- `Test-PathContract.ps1`'
        '- `Test-CiPipelineSelectorDevModeContract.ps1`'
        '- `Test-SoloMaintainerWorkflowContract.ps1`'
        '- Pester contract suites under `Tooling/tests`'
    ) -join [Environment]::NewLine

    $createArgs = @(
        'pr', 'create',
        '--repo', $RepoName,
        '--head', $SourceBranchName,
        '--base', $TargetBranchName,
        '--title', $title,
        '--body', $body
    )
    $null = Invoke-GhCommand -Arguments $createArgs -Description 'Create pull request'

    $createdRaw = Invoke-GhCommand -Arguments $listArgs -Description 'Resolve created pull request'
    $createdJson = ($createdRaw -join [Environment]::NewLine).Trim()
    $createdList = if ([string]::IsNullOrWhiteSpace($createdJson)) { @() } else { @($createdJson | ConvertFrom-Json) }
    if ($createdList.Count -eq 0) {
        throw 'Pull request create reported success but no open PR was found.'
    }

    $created = $createdList[0]
    return [pscustomobject]@{
        Number  = [int]$created.number
        Url     = [string]$created.url
        Created = $true
    }
}

function Invoke-PublishWorkflowDispatch {
    param(
        [Parameter(Mandatory = $true)]
        [string]$RepoName,

        [Parameter(Mandatory = $true)]
        [string]$Sha
    )

    $dispatchArgs = @(
        'workflow', 'run', 'ci-composite.yml',
        '--repo', $RepoName,
        '-f', 'publish_prerelease=true',
        '-f', ("expected_sha={0}" -f $Sha),
        '-f', 'strict_sha=true'
    )
    $null = Invoke-GhCommand -Arguments $dispatchArgs -Description 'Dispatch ci-composite workflow'
}

function Resolve-DispatchedRun {
    param(
        [Parameter(Mandatory = $true)]
        [string]$RepoName,

        [Parameter(Mandatory = $true)]
        [string]$Sha
    )

    for ($attempt = 1; $attempt -le 6; $attempt++) {
        $listArgs = @(
            'run', 'list',
            '--repo', $RepoName,
            '--workflow', 'ci-composite.yml',
            '--event', 'workflow_dispatch',
            '--json', 'databaseId,headSha,url,status,createdAt',
            '--limit', '20'
        )
        $runsRaw = Invoke-GhCommand -Arguments $listArgs -Description 'List ci-composite workflow_dispatch runs'
        $runsJson = ($runsRaw -join [Environment]::NewLine).Trim()
        $runs = if ([string]::IsNullOrWhiteSpace($runsJson)) { @() } else { @($runsJson | ConvertFrom-Json) }
        $match = $runs | Where-Object { [string]$_.headSha -eq $Sha } | Select-Object -First 1
        if ($match) {
            return [pscustomobject]@{
                RunId = [int64]$match.databaseId
                Url   = [string]$match.url
                Status = [string]$match.status
            }
        }

        Start-Sleep -Seconds 5
    }

    return $null
}

function Get-RunArtifactName {
    param(
        [Parameter(Mandatory = $true)]
        [string]$RepoName,

        [Parameter(Mandatory = $true)]
        [int64]$RunId
    )

    try {
        $apiPath = "/repos/{0}/actions/runs/{1}/artifacts" -f $RepoName, $RunId
        $artifactsRaw = Invoke-GhCommand -Arguments @('api', $apiPath) -Description 'Read workflow run artifacts'
        $artifactsJson = ($artifactsRaw -join [Environment]::NewLine).Trim()
        if ([string]::IsNullOrWhiteSpace($artifactsJson)) {
            return @()
        }

        $payload = $artifactsJson | ConvertFrom-Json
        if ($null -eq $payload -or $null -eq $payload.artifacts) {
            return @()
        }

        return @($payload.artifacts | ForEach-Object { [string]$_.name } | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })
    } catch {
        Write-Warning ("Unable to resolve artifact names for run {0}: {1}" -f $RunId, $_.Exception.Message)
        return @()
    }
}

function Write-SoloReleaseEvidence {
    param(
        [Parameter(Mandatory = $true)]
        [string]$RepoRootPath,

        [Parameter(Mandatory = $true)]
        [object]$Evidence
    )

    $statusDir = Join-Path $RepoRootPath 'builds\status'
    New-Item -Path $statusDir -ItemType Directory -Force | Out-Null
    $statusPath = Join-Path $statusDir 'solo-release-evidence.json'
    $Evidence | ConvertTo-Json -Depth 10 | Out-File -FilePath $statusPath -Encoding utf8
    return $statusPath
}

$repoRoot = Resolve-RepoRoot
Push-Location $repoRoot
try {
    $resolvedSourceBranch = if ([string]::IsNullOrWhiteSpace($SourceBranch)) { Resolve-CurrentBranch } else { $SourceBranch.Trim() }
    $currentBranch = Resolve-CurrentBranch
    if ($currentBranch -ne $resolvedSourceBranch) {
        throw ("Current branch '{0}' does not match SourceBranch '{1}'. Check out the source branch before running." -f $currentBranch, $resolvedSourceBranch)
    }

    $runParity = if ($Mode -eq 'validate') {
        $false
    } elseif ($PSBoundParameters.ContainsKey('RunLocalParity')) {
        [bool]$RunLocalParity
    } else {
        $true
    }

    Write-Host ("Mode: {0}" -f $Mode)
    Write-Host ("Source branch: {0}" -f $resolvedSourceBranch)
    Write-Host ("Target branch: {0}" -f $TargetBranch)
    Write-Host ("Run local parity: {0}" -f $runParity)

    $validationResults = Invoke-ValidationSuite -RepoRootPath $repoRoot

    if ($Mode -eq 'validate') {
        Write-Host 'Validation mode completed successfully.'
        return
    }

    Assert-CleanWorktree
    if ($runParity) {
        Invoke-LocalParity -RepoRootPath $repoRoot -Attempts $MaxParityAttempts
    }

    Assert-GhReady
    $repoName = Resolve-RepositoryName -RepoRootPath $repoRoot
    Invoke-SourceBranchPush -BranchName $resolvedSourceBranch
    $pullRequest = Get-OrCreatePullRequest -RepoName $repoName -SourceBranchName $resolvedSourceBranch -TargetBranchName $TargetBranch
    Write-Host ("Pull request ({0}): {1}" -f $pullRequest.Number, $pullRequest.Url)

    if ($Mode -eq 'integrate') {
        Write-Host 'Integrate mode completed successfully.'
        return
    }

    $currentSha = (Invoke-GitCommand -Arguments @('rev-parse', 'HEAD') -Description 'Resolve HEAD SHA' | Select-Object -First 1).Trim()
    $evidence = [ordered]@{
        source_sha        = $currentSha
        source_branch     = $resolvedSourceBranch
        target_branch     = $TargetBranch
        repository        = $repoName
        pull_request_url  = $pullRequest.Url
        guard_results     = $validationResults
        ci_run_urls       = @()
        artifact_names    = @()
        publish_requested = [bool]$PublishPrerelease
        publish_decision  = 'not-requested'
        expected_sha      = if ([string]::IsNullOrWhiteSpace($ExpectedSha)) { '' } else { $ExpectedSha.Trim() }
        generated_utc     = (Get-Date).ToUniversalTime().ToString('o')
    }

    if (-not $PublishPrerelease) {
        $evidencePath = Write-SoloReleaseEvidence -RepoRootPath $repoRoot -Evidence $evidence
        Write-Host ("Release mode completed without dispatch. Evidence: {0}" -f $evidencePath)
        return
    }

    if ([string]::IsNullOrWhiteSpace($ExpectedSha)) {
        throw 'ExpectedSha is required when PublishPrerelease is set.'
    }

    if ($ExpectedSha.Trim().ToLowerInvariant() -ne $currentSha.ToLowerInvariant()) {
        throw ("ExpectedSha '{0}' does not match current HEAD '{1}'." -f $ExpectedSha.Trim(), $currentSha)
    }

    Invoke-PublishWorkflowDispatch -RepoName $repoName -Sha $currentSha
    $dispatchedRun = Resolve-DispatchedRun -RepoName $repoName -Sha $currentSha
    if ($dispatchedRun) {
        $evidence.ci_run_urls = @($dispatchedRun.Url)
        $evidence.artifact_names = @(Get-RunArtifactName -RepoName $repoName -RunId $dispatchedRun.RunId)
    }
    $evidence.publish_decision = 'dispatch-requested'

    $evidencePath = Write-SoloReleaseEvidence -RepoRootPath $repoRoot -Evidence $evidence
    Write-Host ("Release dispatch completed. Evidence: {0}" -f $evidencePath)
} finally {
    Pop-Location
}
