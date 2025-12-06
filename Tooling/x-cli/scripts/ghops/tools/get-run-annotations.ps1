param(
    [Parameter(Mandatory = $false)]
    [string] $Repo,

    [Parameter(Mandatory = $true)]
    [long] $RunId,

    [Parameter(Mandatory = $false)]
    [string] $Out = "",

    # When set, also scrape job logs for error lines (in addition to annotations)
    [Parameter(Mandatory = $false)]
    [switch] $SearchLogs,

    # Optional job name to restrict log scraping (defaults to the whole run)
    [Parameter(Mandatory = $false)]
    [string] $Job = "",

    # Regex patterns to search in logs (joined with |)
    [Parameter(Mandatory = $false)]
    [string[]] $ErrorPatterns = @('##[error]', '\berror\b', 'yamllint', '✗'),

    # Maximum number of log hits to capture
    [Parameter(Mandatory = $false)]
    [int] $MaxLogHits = 100,

    # Optional: write full logs to this path
    [Parameter(Mandatory = $false)]
    [string] $OutLogs = "",

    # Optional: write normalized logs (temp prefixes removed) to this path
    [Parameter(Mandatory = $false)]
    [string] $OutLogsNormalized = "",

    # Regex for temp path normalization (replaced with empty string)
    [Parameter(Mandatory = $false)]
    [string] $TmpPathRegex = '\\.pytest_tmp/cwd\d+/',

    # Optional explicit organization (otherwise derived from -Repo/GITHUB_REPOSITORY)
    [Parameter(Mandatory = $false)]
    [string] $Org = "",

    [Parameter(Mandatory = $false)]
    [ValidateSet('auto', 'gh', 'rest')]
    [string] $Transport = 'auto',

    # Require gh; fail if unavailable (even if Transport=auto)
    [switch] $RequireGh,

    # Opt-out / opt-in token preflight (default: on)
    [switch] $PreflightToken,
    [switch] $NoPreflightToken,

    [switch] $Quiet,
    [switch] $Json
)

$ErrorActionPreference = 'Stop'

if ($Json -and -not $PSBoundParameters.ContainsKey('Quiet')) {
    $Quiet = $true
}

$doPreflight = $true
if ($NoPreflightToken.IsPresent) {
    $doPreflight = $false
} elseif ($PreflightToken.IsPresent) {
    $doPreflight = $true
}

function Write-Info([string] $msg) {
    if (-not $Quiet) { Write-Host $msg }
}

function Get-RepoOwner([string] $repo) {
    if ([string]::IsNullOrWhiteSpace($repo)) { return '' }
    if ($repo.Contains('/')) { return $repo.Split('/')[0] }
    return ''
}

function Get-EnvRepo() {
    if ([string]::IsNullOrWhiteSpace($Repo)) {
        $Repo = $env:GITHUB_REPOSITORY
    }
    if ([string]::IsNullOrWhiteSpace($Repo)) {
        throw "Repository not specified. Pass -Repo owner/name or set GITHUB_REPOSITORY."
    }
    return $Repo
}

if (-not $script:TokenAwarenessCache) { $script:TokenAwarenessCache = @{} }

function Invoke-TokenAwareness([string] $transport, [string] $repo, [string] $org) {
    $key = "{0}|{1}|{2}" -f $transport, $repo, $org
    if ($script:TokenAwarenessCache.ContainsKey($key)) { return $script:TokenAwarenessCache[$key] }
    $tokenScript = Join-Path $PSScriptRoot 'token-awareness.ps1'
    if (-not (Test-Path $tokenScript)) {
        $script:TokenAwarenessCache[$key] = $null
        return $null
    }
    $args = @{ Transport = $transport; Quiet = $true; Json = $true }
    if (-not [string]::IsNullOrWhiteSpace($repo)) { $args['Repo'] = $repo }
    if (-not [string]::IsNullOrWhiteSpace($org)) { $args['Org'] = $org }
    try {
        $output = & $tokenScript @args
    } catch {
        $script:TokenAwarenessCache[$key] = $null
        return $null
    }
    if ([string]::IsNullOrWhiteSpace($output)) {
        $script:TokenAwarenessCache[$key] = $null
        return $null
    }
    try {
        $info = $output | ConvertFrom-Json
    } catch {
        $info = $null
    }
    $script:TokenAwarenessCache[$key] = $info
    return $info
}

function Have-Gh() {
    return [bool](Get-Command gh -ErrorAction SilentlyContinue)
}

$script:TransportMode = ($Transport ?? 'auto').ToLowerInvariant()
$script:HasGhCli = Have-Gh
if ($RequireGh -and -not $script:HasGhCli) {
    throw "-RequireGh specified but gh CLI not found on PATH."
}

switch ($script:TransportMode) {
    'gh' {
        if (-not $script:HasGhCli) { throw "Transport 'gh' requested but gh CLI not found on PATH." }
        $script:UseGh = $true
    }
    'rest' {
        $script:UseGh = $false
    }
    default {
        $script:UseGh = $script:HasGhCli
    }
}

function Ensure-Parent([string] $path) {
    if ([string]::IsNullOrWhiteSpace($path)) { return }
    $dir = Split-Path -Parent $path
    if (-not [string]::IsNullOrWhiteSpace($dir) -and -not (Test-Path $dir)) {
        New-Item -ItemType Directory -Force -Path $dir | Out-Null
    }
}

function Get-RestHeaders([switch] $AllowAnonymous) {
    $token = $env:GH_TOKEN
    if ([string]::IsNullOrEmpty($token)) { $token = $env:GITHUB_TOKEN }
    if ([string]::IsNullOrEmpty($token)) {
        if ($AllowAnonymous) { return @{} }
        throw "No GitHub token found (GH_TOKEN/GITHUB_TOKEN)."
    }
    return @{ Authorization = "Bearer $token"; Accept = 'application/vnd.github+json'; 'User-Agent' = 'x-cli/gh-annotations' }
}

function Get-Run([string] $repo, [long] $runId) {
    if ($script:UseGh) {
        $raw = & gh api "repos/$repo/actions/runs/$runId" 2>$null
        return $raw | ConvertFrom-Json
    }
    $headers = Get-RestHeaders
    $uri = "https://api.github.com/repos/$repo/actions/runs/$runId"
    return Invoke-RestMethod -Method Get -Headers $headers -Uri $uri
}

function Get-CheckRuns([string] $repo, [string] $sha) {
    if ($script:UseGh) {
        $raw = & gh api "repos/$repo/commits/$sha/check-runs?per_page=100" --paginate 2>$null
        if (-not $raw) { return @() }
        $runs = @()
        foreach ($chunk in ($raw -split "`n")) {
            if ([string]::IsNullOrWhiteSpace($chunk)) { continue }
            try {
                $obj = $chunk | ConvertFrom-Json
                if ($obj.check_runs) { $runs += @($obj.check_runs) }
            } catch { }
        }
        return @($runs)
    }
    $headers = Get-RestHeaders
    $uriBase = "https://api.github.com/repos/$repo/commits/$sha/check-runs?per_page=100"
    $page = 1
    $runs = @()
    while ($true) {
        $uri = "$uriBase&page=$page"
        try {
            $resp = Invoke-RestMethod -Method Get -Headers $headers -Uri $uri
        } catch {
            break
        }
        if (-not $resp.check_runs) { break }
        $runs += @($resp.check_runs)
        if ($resp.check_runs.Count -lt 100) { break }
        $page++
        if ($page -gt 5) { break }
    }
    return @($runs)
}

function Get-AnnotationsForCheckRun($checkRun) {
    $annUrl = $checkRun.output.annotations_url
    if ([string]::IsNullOrWhiteSpace($annUrl)) { return @() }
    if ($checkRun.output.annotations_count -le 0) { return @() }

    if ($script:UseGh) {
        $lines = & gh api "$annUrl?per_page=50" --paginate --jq '.[]' 2>$null
        if (-not $lines) { return @() }
        $items = @()
        foreach ($line in $lines) {
            if ([string]::IsNullOrWhiteSpace($line)) { continue }
            try { $items += ($line | ConvertFrom-Json) } catch { }
        }
        return $items
    }
    $headers = Get-RestHeaders -AllowAnonymous
    # Minimal pagination (2 pages) to avoid complexity; large runs are rare.
    $u1 = "$annUrl?per_page=50&page=1"
    $u2 = "$annUrl?per_page=50&page=2"
    $a1 = @(); $a2 = @()
    try { $a1 = Invoke-RestMethod -Method Get -Headers $headers -Uri $u1 } catch { $a1 = @() }
    try { $a2 = Invoke-RestMethod -Method Get -Headers $headers -Uri $u2 } catch { $a2 = @() }
    return @($a1 + $a2)
}

function Get-RunJobsRest([string] $repo, [long] $runId) {
    $headers = Get-RestHeaders
    $jobs = @()
    $page = 1
    while ($true) {
        $uri = "https://api.github.com/repos/$repo/actions/runs/$runId/jobs?per_page=100&page=$page"
        try {
            $resp = Invoke-RestMethod -Method Get -Headers $headers -Uri $uri
        } catch {
            break
        }
        if ($resp.jobs) { $jobs += @($resp.jobs) }
        if (-not $resp.jobs -or $resp.jobs.Count -lt 100) { break }
        $page++
        if ($page -gt 5) { break }
    }
    return @($jobs)
}

function Get-RunLogsGh([string] $repo, [long] $runId, [string] $jobName) {
    if ([string]::IsNullOrWhiteSpace($jobName)) {
        $cmd = @('run','view',"$runId",'--repo',"$repo",'--log')
    } else {
        $cmd = @('run','view',"$runId",'--repo',"$repo",'--job',"$jobName",'--log')
    }
    try {
        $bytes = & gh @cmd 2>$null | Out-String
        return [string]$bytes
    } catch {
        return ""
    }
}

function Get-RunLogsRest([string] $repo, [long] $runId, [string] $jobName) {
    try {
        Add-Type -AssemblyName System.IO.Compression.FileSystem -ErrorAction SilentlyContinue
    } catch { }

    $headers = Get-RestHeaders
    $uri = "https://api.github.com/repos/$repo/actions/runs/$runId/logs"
    if (-not [string]::IsNullOrWhiteSpace($jobName)) {
        $job = Get-RunJobsRest -repo $repo -runId $runId | Where-Object { $_.name -ieq $jobName } | Select-Object -First 1
        if (-not $job) { return "" }
        $uri = "https://api.github.com/repos/$repo/actions/jobs/$($job.id)/logs"
    }

    $tmp = [System.IO.Path]::GetTempFileName()
    try {
        Invoke-WebRequest -Method Get -Headers $headers -Uri $uri -OutFile $tmp -ErrorAction Stop | Out-Null
    } catch {
        Remove-Item $tmp -ErrorAction SilentlyContinue
        return ""
    }

    try {
        $zip = [System.IO.Compression.ZipFile]::OpenRead($tmp)
        $builder = New-Object System.Text.StringBuilder
        foreach ($entry in $zip.Entries) {
            if ($entry.Length -le 0) { continue }
            $reader = New-Object System.IO.StreamReader($entry.Open())
            try {
                $builder.AppendLine($reader.ReadToEnd()) | Out-Null
            } finally {
                $reader.Dispose()
            }
        }
        $zip.Dispose()
        return $builder.ToString()
    } catch {
        return ""
    } finally {
        Remove-Item $tmp -ErrorAction SilentlyContinue
    }
}

function Get-RunLogs([string] $repo, [long] $runId, [string] $jobName) {
    if ($script:UseGh) {
        return Get-RunLogsGh -repo $repo -runId $runId -jobName $jobName
    }
    return Get-RunLogsRest -repo $repo -runId $runId -jobName $jobName
}

function Select-LogHits([string] $text, [string[]] $patterns, [int] $max) {
    if ([string]::IsNullOrWhiteSpace($text)) { return @() }
    $pat = ($patterns -join '|')
    $opts = [System.Text.RegularExpressions.RegexOptions]::IgnoreCase
    $lines = $text -split "`n"
    $hits = New-Object System.Collections.Generic.List[object]
    $i = 0
    foreach ($line in $lines) {
        if ($i -ge $max) { break }
        if ([System.Text.RegularExpressions.Regex]::IsMatch($line, $pat, $opts)) {
            $hits.Add([PSCustomObject]@{ line = $line.TrimEnd("`r"); })
            $i++
        }
    }
    return $hits
}

try {
    $repo = Get-EnvRepo
    Write-Info "Repo: $repo | Run: $RunId"
    $targetOrg = if (-not [string]::IsNullOrWhiteSpace($Org)) { $Org } else { Get-RepoOwner $repo }
    $tokenAwareness = $null
    if ($doPreflight) {
        $transportLabel = if ($script:UseGh) { 'gh' } else { 'rest' }
        $tokenAwareness = Invoke-TokenAwareness -transport $transportLabel -repo $repo -org $targetOrg
        if (-not $script:UseGh) {
            if (-not $tokenAwareness) {
                throw "Token check failed: GH_TOKEN/GITHUB_TOKEN not set. Provide an org-scoped token or run gh auth login. See docs/ci/token-awareness.md."
            }
            $missingTokenNote = $false
            if ($tokenAwareness.notes) {
                $missingTokenNote = $tokenAwareness.notes | Where-Object { $_ -like '*No token*' }
                $missingTokenNote = [bool]$missingTokenNote
            }
            if ($missingTokenNote) {
                throw "Token check failed: GH_TOKEN/GITHUB_TOKEN not set. Provide an org-scoped token (read:org, repo, workflow) via GH_TOKEN. See docs/ci/token-awareness.md."
            }
            if ($targetOrg -and ($tokenAwareness.org_visible -eq $false)) {
                throw "Token cannot access org '$targetOrg'. Set GH_TOKEN to an org-scoped PAT (scopes: read:org, repo, workflow). See docs/ci/token-awareness.md."
            }
        } elseif ($tokenAwareness -and $targetOrg -and ($tokenAwareness.org_visible -eq $false) -and -not $Quiet) {
            Write-Info ("Token visibility note: org '{0}' not listed for current gh auth context." -f $targetOrg)
        }
    }
    $run = Get-Run -repo $repo -runId $RunId
    $sha = $run.head_sha
    if ([string]::IsNullOrWhiteSpace($sha)) { throw "Run $RunId missing head_sha (repo: $repo)." }
    Write-Info "head_sha: $sha"

    $checkRuns = Get-CheckRuns -repo $repo -sha $sha
    $all = @()
    foreach ($cr in $checkRuns) {
        $ann = Get-AnnotationsForCheckRun -checkRun $cr
        foreach ($a in $ann) {
            $all += [PSCustomObject]@{
                check_run_id   = $cr.id
                check_run_name = $cr.name
                path           = $a.path
                start_line     = $a.start_line
                end_line       = $a.end_line
                level          = $a.annotation_level
                title          = $a.title
                message        = $a.message
                raw_details    = $a.raw_details
            }
        }
    }

    # Level counts (error/warning/notice)
    $byLevel = @{}
    foreach ($it in $all) {
        $lvl = if ($it.level) { $it.level } else { 'unknown' }
        if (-not $byLevel.ContainsKey($lvl)) { $byLevel[$lvl] = 0 }
        $byLevel[$lvl]++
    }

    # Optional log scraping
    $logText = ""
    $logHits = @()
    $normalized = ""
    if ($SearchLogs -or @($all).Count -eq 0) {
        $transportLabel = if ($script:UseGh) { 'gh' } else { 'REST API' }
        Write-Info ("Fetching job logs ({0}) to supplement annotations..." -f $transportLabel)
        $logText = Get-RunLogs -repo $repo -runId $RunId -jobName $Job
        if (-not [string]::IsNullOrWhiteSpace($logText)) {
            if (-not [string]::IsNullOrWhiteSpace($OutLogs)) {
                Ensure-Parent $OutLogs
                Set-Content -NoNewline -Encoding UTF8 -Path $OutLogs -Value $logText
                Write-Info "Wrote logs: $OutLogs"
            }
            if (-not [string]::IsNullOrWhiteSpace($OutLogsNormalized) -and -not [string]::IsNullOrWhiteSpace($TmpPathRegex)) {
                $normalized = [System.Text.RegularExpressions.Regex]::Replace($logText, $TmpPathRegex, '')
                Ensure-Parent $OutLogsNormalized
                Set-Content -NoNewline -Encoding UTF8 -Path $OutLogsNormalized -Value $normalized
                Write-Info "Wrote normalized logs: $OutLogsNormalized"
            }
            $sourceForHits = if (-not [string]::IsNullOrWhiteSpace($normalized)) { $normalized } else { $logText }
            $logHits = Select-LogHits -text $sourceForHits -patterns $ErrorPatterns -max $MaxLogHits
        } else {
            Write-Info "Log download unavailable; skipping log search."
        }
    }

    $result = [PSCustomObject]@{
        repo                = $repo
        run_id              = $RunId
        run_html_url        = $run.html_url
        workflow_name       = $run.name
        head_sha            = $sha
        status              = $run.status
        conclusion          = $run.conclusion
        total_check_runs    = @($checkRuns).Count
        total_annotations   = @($all).Count
        transport           = if ($script:UseGh) { 'gh' } else { 'rest' }
        annotations_by_level= $byLevel
        annotations         = @($all)
        job                 = $Job
        out_logs            = $OutLogs
        out_logs_normalized = $OutLogsNormalized
        error_patterns      = @($ErrorPatterns)
        max_log_hits        = $MaxLogHits
        log_hits            = @($logHits)
        token_awareness     = $tokenAwareness
    }

    if (-not [string]::IsNullOrWhiteSpace($Out)) {
        $dir = Split-Path -Parent $Out
        if (-not [string]::IsNullOrWhiteSpace($dir) -and -not (Test-Path $dir)) {
            New-Item -ItemType Directory -Force -Path $dir | Out-Null
        }
        $result | ConvertTo-Json -Depth 6 | Set-Content -NoNewline -Encoding UTF8 -Path $Out
        Write-Info "Wrote annotations JSON: $Out"
    }

    if ($Json) {
        $result | ConvertTo-Json -Depth 6
    } else {
        Write-Info ("Check runs: {0} | Annotations: {1}" -f @($checkRuns).Count, @($all).Count)
        if ($byLevel.Keys.Count -gt 0 -and -not $Quiet) {
            $parts = @()
            foreach ($k in $byLevel.Keys) { $parts += ("{0}={1}" -f $k, $byLevel[$k]) }
            Write-Info ("Levels: {0}" -f ($parts -join ', '))
        }
        if (@($all).Count -gt 0 -and -not $Quiet) {
            $preview = $all | Select-Object -First 10
            foreach ($p in $preview) {
                Write-Host ("[{0}] {1}:{2} {3}" -f $p.check_run_name, $p.path, $p.start_line, $p.title)
            }
            if (@($all).Count -gt 10) { Write-Host "... (truncated)" }
        }
        if (@($all).Count -eq 0 -and $logHits.Count -gt 0 -and -not $Quiet) {
            Write-Info ("Log hits: {0} (showing first {1})" -f $logHits.Count, [Math]::Min($logHits.Count, [Math]::Min($MaxLogHits,10)))
            $c = 0
            foreach ($h in $logHits) {
                Write-Host ("log> {0}" -f $h.line)
                $c++
                if ($c -ge 10) { break }
            }
            if ($logHits.Count -gt 10) { Write-Host "... (truncated)" }
        }
    }
}
catch {
    $msg = $_.Exception.Message
    Write-Error "Failed to fetch run annotations: $msg"
    exit 1
}
