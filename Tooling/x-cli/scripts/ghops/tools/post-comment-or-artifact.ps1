Param(
  [Parameter(Mandatory=$true)][string]$LabelName,
  [Parameter(Mandatory=$true)][string]$CommentPath,
  [string]$Repo = $env:GITHUB_REPOSITORY,
  [int]$PrNumber,
  [string]$Token = $env:GITHUB_TOKEN,
  [string]$EventPath = $env:GITHUB_EVENT_PATH,
  [string]$OutputPath = $env:GITHUB_OUTPUT,
  [switch]$DryRun,
  [switch]$Json,
  [switch]$Quiet,
  # Optional org owner for token preflight
  [string]$Org = "",
  # Opt-out / opt-in token preflight (default: on)
  [switch]$PreflightToken,
  [switch]$NoPreflightToken
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

if ($Json -and -not $PSBoundParameters.ContainsKey('Quiet')) { $Quiet = $true }

function Write-Info([string] $msg) { if (-not $Quiet) { Write-Host $msg } }
function Write-Warn([string] $msg) { if (-not $Quiet) { Write-Warning $msg } }

function Set-Output([string]$name, [string]$value) {
  if (-not [string]::IsNullOrWhiteSpace($OutputPath)) {
    "$name=$value" | Out-File -FilePath $OutputPath -Append -Encoding utf8NoBOM
  } else {
    Write-Host "::notice::output $name=$value"
  }
}

if (-not (Test-Path -LiteralPath $CommentPath)) {
  Write-Warn "comment file not found: $CommentPath"
  Set-Output 'posted' 'false'
  Set-Output 'reason' 'comment-not-found'
  exit 0
}

if ([string]::IsNullOrWhiteSpace($Repo)) {
  Write-Warn 'GITHUB_REPOSITORY not set; provide -Repo owner/name.'
}

$labels = @()
if (-not $PrNumber -and (Test-Path -LiteralPath $EventPath)) {
  try {
    $event = Get-Content -LiteralPath $EventPath -Raw | ConvertFrom-Json
    if ($event.pull_request) {
      $PrNumber = [int]$event.pull_request.number
      if ($event.pull_request.labels) { $labels = @($event.pull_request.labels | ForEach-Object { $_.name }) }
    } elseif ($event.issue -and $event.issue.pull_request) {
      $PrNumber = [int]$event.issue.number
      if ($event.issue.labels) { $labels = @($event.issue.labels | ForEach-Object { $_.name }) }
    }
  } catch { Write-Warn "failed to parse event json: $_" }
}

$labelPresent = $false
if ($labels.Count -gt 0) {
  $labelPresent = ($labels -contains $LabelName)
}
$posted = $false
$reason = 'init'
Set-Output 'label_present' ($labelPresent.ToString().ToLowerInvariant())
if (-not $PrNumber) {
  Write-Warn 'PR number not resolved from event; provide -PrNumber to enable commenting.'
  $posted = $false; $reason = 'no-pr-number'
  Set-Output 'posted' 'false'
  Set-Output 'reason' $reason
  Set-Output 'comment_path' $CommentPath
  if ($Json.IsPresent) {
    $obj = [ordered]@{ repo=$Repo; pr_number=$PrNumber; label_name=$LabelName; label_present=$labelPresent; posted=$posted; reason=$reason; comment_path=$CommentPath; message_length= if (Test-Path -LiteralPath $CommentPath) { (Get-Content -LiteralPath $CommentPath -Raw).Length } else { 0 } }
    $obj | ConvertTo-Json -Depth 4 | Write-Output
  }
  exit 0
}

if (-not $labelPresent) {
  Write-Info "Label '$LabelName' not present on PR #$PrNumber; skipping comment."
  $posted = $false; $reason = 'label-missing'
  Set-Output 'posted' 'false'
  Set-Output 'reason' $reason
  Set-Output 'comment_path' $CommentPath
  if ($Json.IsPresent) {
    $obj = [ordered]@{ repo=$Repo; pr_number=$PrNumber; label_name=$LabelName; label_present=$labelPresent; posted=$posted; reason=$reason; comment_path=$CommentPath; message_length= if (Test-Path -LiteralPath $CommentPath) { (Get-Content -LiteralPath $CommentPath -Raw).Length } else { 0 } }
    $obj | ConvertTo-Json -Depth 4 | Write-Output
  }
  exit 0
}

$body = Get-Content -LiteralPath $CommentPath -Raw
if ($DryRun.IsPresent) {
  Write-Info "[dry-run] Would post comment to $Repo#${PrNumber} (len=$($body.Length))"
  $posted = $false; $reason = 'dry-run'
  Set-Output 'posted' 'false'
  Set-Output 'reason' $reason
  Set-Output 'comment_path' $CommentPath
  if ($Json.IsPresent) {
    $obj = [ordered]@{ repo=$Repo; pr_number=$PrNumber; label_name=$LabelName; label_present=$labelPresent; posted=$posted; reason=$reason; comment_path=$CommentPath; message_length=$body.Length }
    $obj | ConvertTo-Json -Depth 4 | Write-Output
  }
  exit 0
}

if ([string]::IsNullOrWhiteSpace($Token)) {
  Write-Warn 'GITHUB_TOKEN not available; cannot post comment.'
  $posted = $false; $reason = 'no-token'
  Set-Output 'posted' 'false'
  Set-Output 'reason' $reason
  Set-Output 'comment_path' $CommentPath
  if ($Json.IsPresent) {
    $obj = [ordered]@{ repo=$Repo; pr_number=$PrNumber; label_name=$LabelName; label_present=$labelPresent; posted=$posted; reason=$reason; comment_path=$CommentPath; message_length=$body.Length }
    $obj | ConvertTo-Json -Depth 4 | Write-Output
  }
  exit 0
}

# Optional token preflight (default on). If -Token is provided, validate it by temporarily exporting GH_TOKEN.
$doPreflight = $true
if ($NoPreflightToken.IsPresent) { $doPreflight = $false } elseif ($PreflightToken.IsPresent) { $doPreflight = $true }
if ($doPreflight) {
  try {
    $tokenScript = Join-Path $PSScriptRoot 'token-awareness.ps1'
    if (Test-Path $tokenScript) {
      $oldGh = $env:GH_TOKEN; $oldGt = $env:GITHUB_TOKEN
      try {
        if ($Token) { $env:GH_TOKEN = $Token; $env:GITHUB_TOKEN = $Token }
        $args = @{ Transport = 'rest'; Quiet = $true; Json = $true; Repo = $Repo }
        if (-not [string]::IsNullOrWhiteSpace($Org)) { $args['Org'] = $Org }
        $infoRaw = & $tokenScript @args
        if ($infoRaw) {
          $info = $infoRaw | ConvertFrom-Json
          $orgOwner = if (-not [string]::IsNullOrWhiteSpace($Org)) { $Org } elseif ($Repo -and $Repo.Contains('/')) { $Repo.Split('/')[0] } else { '' }
          $visible = $info.org_visible
          if ($orgOwner -and ($visible -eq $false)) {
            Write-Warn ("Token cannot access org '{0}'. Provide an org-scoped PAT (read:org, repo, workflow). See docs/ci/token-awareness.md." -f $orgOwner)
            $posted = $false; $reason = 'preflight-failed'
            Set-Output 'posted' 'false'
            Set-Output 'reason' $reason
            Set-Output 'comment_path' $CommentPath
            if ($Json.IsPresent) {
              $obj = [ordered]@{ repo=$Repo; pr_number=$PrNumber; label_name=$LabelName; label_present=$labelPresent; posted=$posted; reason=$reason; comment_path=$CommentPath; message_length=$body.Length; token_awareness=$info }
              $obj | ConvertTo-Json -Depth 6 | Write-Output
            }
            exit 0
          }
        }
      } finally {
        $env:GH_TOKEN = $oldGh; $env:GITHUB_TOKEN = $oldGt
      }
    }
  } catch {
    # non-fatal; continue
  }
}

try {
  $uri = "https://api.github.com/repos/$Repo/issues/$PrNumber/comments"
  $payload = @{ body = $body } | ConvertTo-Json -Depth 3
  $headers = @{ Authorization = "token $Token"; Accept = 'application/vnd.github+json'; 'User-Agent' = 'x-cli-ghops' }
  $resp = Invoke-RestMethod -Uri $uri -Method Post -Headers $headers -Body $payload -ContentType 'application/json' -ErrorAction Stop
  $posted = $true; $reason = 'ok'
  $commentUrl = $null
  if ($resp -and ($resp.PSObject.Properties.Name -contains 'html_url')) { $commentUrl = $resp.html_url }
  Write-Info "Posted PR comment to $Repo#$PrNumber"
  Set-Output 'posted' 'true'
  Set-Output 'reason' $reason
  Set-Output 'comment_path' $CommentPath
  if ($Json.IsPresent) {
    $obj = [ordered]@{ repo=$Repo; pr_number=$PrNumber; label_name=$LabelName; label_present=$labelPresent; posted=$posted; reason=$reason; comment_path=$CommentPath; message_length=$body.Length; url=$commentUrl }
    $obj | ConvertTo-Json -Depth 4 | Write-Output
  }
} catch {
  Write-Warn "Failed to post PR comment: $_"
  $posted = $false; $reason = 'post-error'
  Set-Output 'posted' 'false'
  Set-Output 'reason' $reason
  Set-Output 'comment_path' $CommentPath
  if ($Json.IsPresent) {
    $obj = [ordered]@{ repo=$Repo; pr_number=$PrNumber; label_name=$LabelName; label_present=$labelPresent; posted=$posted; reason=$reason; comment_path=$CommentPath; message_length=$body.Length }
    $obj | ConvertTo-Json -Depth 4 | Write-Output
  }
}
