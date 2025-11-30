param(
    [Parameter(Mandatory = $false)]
    [string] $Repo,

    [Parameter(Mandatory = $false)]
    [string] $Branch,

    [Parameter(Mandatory = $false)]
    [ValidateSet('auto','gh','rest')]
    [string] $Transport = 'auto',

    [switch] $RequireGh,
    [switch] $Quiet,
    [switch] $Json
)

$ErrorActionPreference = 'Stop'
if ($Json -and -not $PSBoundParameters.ContainsKey('Quiet')) { $Quiet = $true }
function Write-Info([string] $m) { if (-not $Quiet) { Write-Host $m } }

function Have-Gh { [bool](Get-Command gh -ErrorAction SilentlyContinue) }

$repoFull = $Repo
if ([string]::IsNullOrWhiteSpace($repoFull)) { $repoFull = $env:GITHUB_REPOSITORY }
if ([string]::IsNullOrWhiteSpace($repoFull)) { throw "Repository not specified. Pass -Repo owner/name or set GITHUB_REPOSITORY." }

$branchName = $Branch
if ([string]::IsNullOrWhiteSpace($branchName)) {
    try {
        $branchName = (& git rev-parse --abbrev-ref HEAD 2>$null).Trim()
    } catch { }
}
if ([string]::IsNullOrWhiteSpace($branchName)) {
    $ref = $env:GITHUB_REF
    if ($ref -and $ref.StartsWith('refs/heads/')) { $branchName = $ref.Substring(11) }
}
if ([string]::IsNullOrWhiteSpace($branchName)) { throw "Branch not specified. Pass -Branch or run inside a git checkout." }

$refName = "refs/heads/$branchName"

$transportMode = ($Transport ?? 'auto').ToLowerInvariant()
$ghAvailable = Have-Gh
$useGh = $ghAvailable
switch ($transportMode) {
    'gh' { if (-not $ghAvailable) { throw "Transport 'gh' requested but gh not found." }; $useGh = $true }
    'rest' { $useGh = $false }
}
if ($RequireGh -and -not $ghAvailable) { throw "-RequireGh specified but gh CLI not found." }

function Invoke-Gh([string] $path) { gh api $path 2>$null }
function Invoke-Rest([string] $uri) {
    $token = $env:GH_TOKEN; if ([string]::IsNullOrWhiteSpace($token)) { $token = $env:GITHUB_TOKEN }
    if ([string]::IsNullOrWhiteSpace($token)) { throw "REST transport requires GH_TOKEN or GITHUB_TOKEN." }
    $headers = @{ Authorization = "Bearer $token"; Accept = 'application/vnd.github+json'; 'User-Agent' = 'x-cli/branch-awareness' }
    Invoke-RestMethod -Method Get -Headers $headers -Uri $uri
}

function Get-RepoInfo([string] $repo) {
    if ($useGh) { (Invoke-Gh "repos/$repo") | ConvertFrom-Json }
    else { Invoke-Rest "https://api.github.com/repos/$repo" }
}

function Get-BranchProtection([string] $repo, [string] $branch) {
    $path = "repos/$repo/branches/$branch/protection"
    try {
        if ($useGh) { (Invoke-Gh $path) | ConvertFrom-Json }
        else { Invoke-Rest "https://api.github.com/$path" }
    } catch { $null }
}

function List-Rulesets([string] $repo) {
    $path = "repos/$repo/rulesets"
    if ($useGh) { (Invoke-Gh $path) | ConvertFrom-Json }
    else { Invoke-Rest "https://api.github.com/$path" }
}

function Get-RulesetDetail([string] $repo, [long] $id) {
    $path = "repos/$repo/rulesets/$id"
    if ($useGh) { (Invoke-Gh $path) | ConvertFrom-Json }
    else { Invoke-Rest "https://api.github.com/$path" }
}

$repoInfo = Get-RepoInfo -repo $repoFull
$defaultBranch = $repoInfo.default_branch
Write-Info "Repo: $repoFull | Branch: $branchName | Default: $defaultBranch"

$classic = Get-BranchProtection -repo $repoFull -branch $branchName
$classicChecks = @()
$strict = $false
if ($classic) {
    if ($classic.required_status_checks) {
        if ($classic.required_status_checks.contexts) { $classicChecks += $classic.required_status_checks.contexts }
        if ($classic.required_status_checks.strict) { $strict = [bool]$classic.required_status_checks.strict }
    }
    if ($classic.checks) {
        foreach ($c in $classic.checks) { if ($c.context) { $classicChecks += $c.context } }
    }
}
$classicChecks = @($classicChecks | Where-Object { $_ } | Select-Object -Unique)

$rulesets = @()
$matchedRules = @()
try {
    $rulesets = List-Rulesets -repo $repoFull
} catch {
    Write-Info "Failed to list rulesets: $($_.Exception.Message)"
    $rulesets = @()
}

foreach ($rs in $rulesets) {
    if ($rs.target -ne 'branch') { continue }
    $detail = Get-RulesetDetail -repo $repoFull -id $rs.id
    $include = @($detail.conditions.ref_name.include)
    $exclude = @($detail.conditions.ref_name.exclude)
    $checks = @()
    foreach ($rule in $detail.rules) {
        if ($rule.type -eq 'required_status_checks') {
            $rulesChecks = $rule.parameters.required_status_checks
            if ($rulesChecks) {
                $checks += ($rulesChecks | ForEach-Object { $_.context })
            }
        }
    }
    $checks = @($checks | Where-Object { $_ } | Select-Object -Unique)

    $matches = $false
    foreach ($pattern in $include) {
        if ([string]::IsNullOrWhiteSpace($pattern)) { continue }
        if ($pattern -eq '~DEFAULT_BRANCH') {
            if ($refName -eq "refs/heads/$defaultBranch") { $matches = $true; break }
        } elseif ($refName -like $pattern) {
            $matches = $true; break }
    }
    if ($matches) {
        foreach ($pattern in $exclude) {
            if ($refName -like $pattern) { $matches = $false; break }
        }
    }

    $matchedRules += [pscustomobject]@{
        id = $detail.id
        name = $detail.name
        enforcement = $detail.enforcement
        target = $detail.target
        include = $include
        exclude = $exclude
        required_checks = $checks
        matched = [bool]$matches
        url = $detail._links.html.href
    }
}

$effective = @($classicChecks)
foreach ($entry in $matchedRules) {
    if ($entry.matched) { $effective += $entry.required_checks }
}
$effective = @($effective | Where-Object { $_ } | Select-Object -Unique)

$result = [pscustomobject]@{
    repo = $repoFull
    branch = $branchName
    ref = $refName
    default_branch = $defaultBranch
    transport = if ($useGh) { 'gh' } else { 'rest' }
    classic = [pscustomobject]@{
        enabled = [bool]$classic
        strict = [bool]$strict
        required_checks = $classicChecks
    }
    rulesets = $matchedRules
    effective_required_checks = $effective
}

if ($Json) { $result | ConvertTo-Json -Depth 6 } else {
    Write-Info "Effective required checks: $($effective -join ', ')"
}

