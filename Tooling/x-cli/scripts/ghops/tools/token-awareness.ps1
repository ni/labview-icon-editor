param(
    [Parameter(Mandatory=$false)] [string] $Org = "",
    [Parameter(Mandatory=$false)] [string] $Repo = "",
    [Parameter(Mandatory=$false)] [ValidateSet('auto','gh','rest')] [string] $Transport = 'auto',
    [switch] $Quiet,
    [switch] $Json
)

$ErrorActionPreference = 'Stop'

function Write-Info([string] $msg) { if (-not $Quiet) { Write-Host $msg } }

function Have-Gh() { return [bool](Get-Command gh -ErrorAction SilentlyContinue) }

function Get-RepoOwner([string] $repo, [string] $org) {
    if (-not [string]::IsNullOrWhiteSpace($org)) { return $org }
    if ([string]::IsNullOrWhiteSpace($repo)) { $repo = $env:GITHUB_REPOSITORY }
    if (-not [string]::IsNullOrWhiteSpace($repo) -and $repo.Contains('/')) { return $repo.Split('/')[0] }
    return ''
}

function Get-RestHeaders() {
    $tok = $env:GH_TOKEN
    if ([string]::IsNullOrWhiteSpace($tok)) { $tok = $env:GITHUB_TOKEN }
    if ([string]::IsNullOrWhiteSpace($tok)) { return $null }
    return @{ Authorization = "Bearer $tok"; Accept = 'application/vnd.github+json'; 'User-Agent' = 'x-cli/token-awareness' }
}

function Get-UserHeadersGh() {
    # gh prints headers and body with -i; keep headers up to blank line
    $raw = & gh api -i '/user' 2>$null
    if (-not $raw) { return @{} }
    $lines = @($raw -split "`n")
    $hdr = @{}
    foreach ($l in $lines) {
        if ([string]::IsNullOrWhiteSpace($l)) { break }
        $idx = $l.IndexOf(':')
        if ($idx -gt 0) {
            $k = $l.Substring(0,$idx).Trim()
            $v = $l.Substring($idx+1).Trim()
            $hdr[$k] = $v
        }
    }
    return $hdr
}

function Get-UserHeadersRest() {
    $headers = Get-RestHeaders
    if ($null -eq $headers) { return $null }
    try {
        $resp = Invoke-WebRequest -Method Get -Headers $headers -Uri 'https://api.github.com/user'
        return $resp.Headers
    } catch {
        return $null
    }
}

function List-OrgsGh([int] $per = 100) {
    try {
        $raw = & gh api "/user/orgs?per_page=$per" --paginate --jq '.[].login' 2>$null
        if (-not $raw) { return @() }
        return @($raw -split "`n" | Where-Object { $_ })
    } catch { return @() }
}

function List-OrgsRest([int] $per = 100) {
    $headers = Get-RestHeaders
    if ($null -eq $headers) { return @() }
    $page = 1
    $items = @()
    while ($true) {
        try {
            $uri = "https://api.github.com/user/orgs?per_page=$per&page=$page"
            $resp = Invoke-RestMethod -Method Get -Headers $headers -Uri $uri
        } catch { break }
        if (-not $resp) { break }
        $logins = @($resp | ForEach-Object { $_.login }) | Where-Object { $_ }
        $items += $logins
        if ($logins.Count -lt $per) { break }
        $page++
        if ($page -gt 5) { break }
    }
    return @($items | Select-Object -Unique)
}

function Parse-Scopes($headers) {
    if ($null -eq $headers) { return @() }
    $key = 'X-OAuth-Scopes'
    $val = $headers[$key]
    if (-not $val) { return @() }
    return @($val -split ',' | ForEach-Object { $_.Trim() } | Where-Object { $_ })
}

try {
    $owner = Get-RepoOwner -repo $Repo -org $Org
    $hasGh = Have-Gh
    $useGh = switch ($Transport) { 'gh' { $true } 'rest' { $false } default { $hasGh } }

    $hdrs = if ($useGh) { Get-UserHeadersGh } else { Get-UserHeadersRest }
    $scopes = Parse-Scopes -headers $hdrs
    $hasReadOrg = [bool]($scopes | Where-Object { $_ -match ':org$' })
    $orgs = if ($useGh) { List-OrgsGh } else { List-OrgsRest }
    $canListOrgs = ($orgs.Count -gt 0)
    $orgVisible = $null
    if (-not [string]::IsNullOrWhiteSpace($owner)) {
        $orgVisible = ($orgs -contains $owner)
    }

    $result = [pscustomobject]@{
        transport       = if ($useGh) { 'gh' } else { 'rest' }
        scopes           = @($scopes)
        has_read_org     = [bool]$hasReadOrg
        can_list_orgs    = [bool]$canListOrgs
        org              = $owner
        org_visible      = $orgVisible
        notes            = @()
    }

    if (-not $useGh -and $null -eq (Get-RestHeaders)) {
        $result.notes += 'No token in GH_TOKEN/GITHUB_TOKEN; REST checks limited.'
    }

    if ($Json) {
        $result | ConvertTo-Json -Depth 5
    } else {
        Write-Info ("Transport: {0}" -f $result.transport)
        Write-Info ("Scopes: {0}" -f (($result.scopes -join ', ')))
        Write-Info ("has_read_org: {0} | can_list_orgs: {1}" -f $result.has_read_org, $result.can_list_orgs)
        if ($owner) { Write-Info ("Org '{0}' visible: {1}" -f $owner, $result.org_visible) }
    }
}
catch {
    $msg = $_.Exception.Message
    Write-Error "Token awareness failed: $msg"
    exit 1
}
