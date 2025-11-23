[CmdletBinding()]
param(
    [string]$WorkflowFile = ".github/workflows/ci.yml",
    [string]$RepositoryPath,
    [switch]$Quiet,
    [switch]$ReturnRunId
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

function Write-Info($msg) { if (-not $Quiet) { Write-Host $msg } }

# Resolve repo path and SHA
$repo = if ($RepositoryPath) { $RepositoryPath } else { (Get-Location).ProviderPath }
try { $repo = (Resolve-Path -LiteralPath $repo -ErrorAction Stop).ProviderPath } catch {}

if (-not (Get-Command git -ErrorAction SilentlyContinue)) { throw "git not found on PATH." }

try {
    $sha = git -C $repo rev-parse HEAD 2>$null
    if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrWhiteSpace($sha)) { throw "Unable to resolve HEAD SHA." }
    $sha = $sha.Trim()
} catch {
    throw "Unable to resolve HEAD SHA: $($_.Exception.Message)"
}

Write-Info "Checking CI gate for commit: $sha"

if (-not (Get-Command gh -ErrorAction SilentlyContinue)) {
    throw "GitHub CLI (gh) not found. Install gh and ensure GH_TOKEN/GITHUB_TOKEN is available."
}

$authHint = "Run: gh auth login -> GitHub.com -> HTTPS -> Login with a web browser, copy code, press Enter to open https://github.com/login/device."

# Ensure gh has a token; prefer GH_TOKEN, fall back to GITHUB_TOKEN
if (-not $env:GH_TOKEN -and $env:GITHUB_TOKEN) {
    $env:GH_TOKEN = $env:GITHUB_TOKEN
}

try {
    gh auth status -h github.com 2>$null | Out-Null
}
catch {
    throw "gh auth status failed. Login with 'gh auth login' (GitHub.com -> HTTPS -> web browser) or set GH_TOKEN/GITHUB_TOKEN with repo access. $authHint"
}

# Determine repo owner/name
try {
    $remoteUrl = git -C $repo remote get-url origin 2>$null
    if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrWhiteSpace($remoteUrl)) { throw "No origin remote found." }
    $remoteUrl = $remoteUrl.Trim()
    if ($remoteUrl -match 'github\.com[:/](?<owner>[^/]+)/(?<name>[^/.]+)') {
        $owner = $Matches['owner']
        $name  = $Matches['name']
    } else {
        throw "Unable to parse owner/repo from origin URL: $remoteUrl"
    }
    # Normalize to the canonical repo name (handles GitHub renames/redirects).
    $canonical = gh api "/repos/$owner/$name" -q '.full_name' 2>$null
    if ($LASTEXITCODE -eq 0 -and $canonical -and $canonical -match '^(?<cOwner>[^/]+)/(?<cName>[^/]+)$') {
        $owner = $Matches['cOwner']
        $name  = $Matches['cName']
    }
} catch {
    throw "Unable to determine repository owner/name: $($_.Exception.Message)"
}

$workflowPath = if ([System.IO.Path]::IsPathRooted($WorkflowFile)) { $WorkflowFile } else { (Join-Path $repo $WorkflowFile) }
if (-not (Test-Path -LiteralPath $workflowPath)) {
    throw "Workflow file not found: $workflowPath"
}

$workflowName = [System.IO.Path]::GetFileName($workflowPath)

# Query workflow runs for this SHA
Write-Info "Querying GitHub Actions for workflow '$workflowName' on $owner/$name..."
# The workflow-runs endpoint does not support head_sha; pull a page of runs and filter locally.
# Explicitly force GET when passing query params; gh switches to POST if a field is present.
$json = gh api -X GET "/repos/$owner/$name/actions/workflows/$workflowName/runs" -f per_page=50 2>$null
if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrWhiteSpace($json)) {
    throw "Unable to query workflow runs via gh api. Ensure GH_TOKEN/GITHUB_TOKEN is set and gh is authenticated. $authHint"
}

try {
    $data = $json | ConvertFrom-Json
} catch {
    throw "Failed to parse gh api response: $($_.Exception.Message)"
}

$runs = @($data.workflow_runs | Where-Object { $_.head_sha -eq $sha })
if (-not $runs -or $runs.Count -eq 0) {
    throw "No runs found for workflow '$workflowName' at commit $sha."
}

$run = $runs | Sort-Object created_at -Descending | Select-Object -First 1
Write-Info ("Found workflow run: id={0}, status={1}, conclusion={2}, event={3}" -f $run.id, $run.status, $run.conclusion, $run.event)

if ($run.status -ne 'completed' -or $run.conclusion -ne 'success') {
    throw ("CI gate failed: latest run for {0} is status={1}, conclusion={2} (run id {3}). Wait for a successful run before proceeding." -f $sha, $run.status, $run.conclusion, $run.id)
}

Write-Info "CI gate passed for commit $sha."
if ($ReturnRunId) {
    Write-Output $run.id
}
exit 0
