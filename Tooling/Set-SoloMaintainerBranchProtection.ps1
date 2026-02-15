#Requires -Version 7.0
[CmdletBinding()]
param(
    [string]$Branch = '456-2020-migration',
    [string]$Repo = '',
    [switch]$DryRun
)

$ErrorActionPreference = 'Stop'

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

if (-not (Get-Command gh -ErrorAction SilentlyContinue)) {
    throw 'GitHub CLI (gh) is required.'
}

$repoRoot = (& git rev-parse --show-toplevel 2>$null | Select-Object -First 1).Trim()
if ([string]::IsNullOrWhiteSpace($repoRoot)) {
    throw 'Unable to resolve repository root.'
}

$resolverScript = Join-Path $repoRoot 'Tooling\Resolve-GitHubRepo.ps1'
if (-not (Test-Path -LiteralPath $resolverScript -PathType Leaf)) {
    throw "Missing repository resolver script: $resolverScript"
}

$resolvedRepo = if ([string]::IsNullOrWhiteSpace($Repo)) {
    (& pwsh -NoProfile -File $resolverScript -RepoRoot $repoRoot | Select-Object -First 1).Trim()
} else {
    $Repo.Trim()
}
if ([string]::IsNullOrWhiteSpace($resolvedRepo)) {
    throw 'Unable to resolve repository name.'
}

$requiredContexts = @(
    'CI Pipeline (Composite) / Pipeline Contract',
    'CI Pipeline (No Smoke) / Pipeline Contract'
)

$branchPayload = [ordered]@{
    required_status_checks           = [ordered]@{
        strict   = $true
        contexts = $requiredContexts
    }
    enforce_admins                   = $false
    required_pull_request_reviews    = [ordered]@{
        dismiss_stale_reviews           = $false
        require_code_owner_reviews      = $false
        required_approving_review_count = 0
    }
    restrictions                     = $null
    required_linear_history          = $false
    allow_force_pushes               = $false
    allow_deletions                  = $false
    block_creations                  = $false
    required_conversation_resolution = $false
    lock_branch                      = $false
    allow_fork_syncing               = $false
}

$repoPayload = [ordered]@{
    allow_merge_commit = $true
    allow_rebase_merge = $false
}

$branchPayloadJson = $branchPayload | ConvertTo-Json -Depth 10
$repoPayloadJson = $repoPayload | ConvertTo-Json -Depth 5

if ($DryRun) {
    Write-Host ("Repository: {0}" -f $resolvedRepo)
    Write-Host ("Branch: {0}" -f $Branch)
    Write-Host 'Branch protection payload:'
    Write-Host $branchPayloadJson
    Write-Host 'Repository merge strategy payload:'
    Write-Host $repoPayloadJson
    return
}

$tempDir = Join-Path ([System.IO.Path]::GetTempPath()) ("lvie-solo-protection-{0}" -f [guid]::NewGuid().ToString('N'))
New-Item -Path $tempDir -ItemType Directory -Force | Out-Null
try {
    $branchPayloadPath = Join-Path $tempDir 'branch-protection.json'
    $repoPayloadPath = Join-Path $tempDir 'repo-merge-policy.json'
    $branchPayloadJson | Out-File -FilePath $branchPayloadPath -Encoding utf8
    $repoPayloadJson | Out-File -FilePath $repoPayloadPath -Encoding utf8

    $null = Invoke-GhCommand -Arguments @(
        'api',
        '--method', 'PUT',
        '-H', 'Accept: application/vnd.github+json',
        "/repos/$resolvedRepo/branches/$Branch/protection",
        '--input', $branchPayloadPath
    ) -Description 'Set branch protection'

    $null = Invoke-GhCommand -Arguments @(
        'api',
        '--method', 'PATCH',
        '-H', 'Accept: application/vnd.github+json',
        "/repos/$resolvedRepo",
        '--input', $repoPayloadPath
    ) -Description 'Set repository merge strategy'

    Write-Host ("Updated solo-maintainer branch protection for {0}:{1}" -f $resolvedRepo, $Branch)
} finally {
    if (Test-Path -LiteralPath $tempDir -PathType Container) {
        Remove-Item -LiteralPath $tempDir -Recurse -Force -ErrorAction SilentlyContinue
    }
}
