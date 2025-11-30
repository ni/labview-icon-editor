Param(
  [Parameter(Mandatory=$true)][string]$Repo,               # owner/name, e.g., LabVIEW-Community-CI-CD/gha-pr-comment-and-artifacts
  [Parameter(Mandatory=$true)][string]$PostMarketplaceSlug, # marketplace slug for the post action
  [Parameter(Mandatory=$true)][string]$ArtifactsMarketplaceSlug, # marketplace slug for the artifacts action
  [string]$Branch = 'main',
  [int]$MaxWaitSeconds = 12,
  [switch]$Quiet,
  [switch]$DryRun
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Ensure-GhAuth {
  try { & gh auth status 1>$null 2>$null } catch { throw "GitHub CLI not authenticated. Run: gh auth login" }
}

function Write-Readme([string]$repo) {
  $postCi = "https://github.com/$repo/actions/workflows/post-comment-or-artifact-ci.yml"
  $prCi   = "https://github.com/$repo/actions/workflows/action-pr-target-ci.yml"
  $relCi  = "https://github.com/$repo/actions/workflows/post-comment-or-artifact-release.yml"
  $releases = "https://github.com/$repo/releases"
  $readme = @(
    "# PR Comment + Artifacts Composites",
    "",
    "[![Action CI]($postCi/badge.svg)]($postCi) " +
    "[![PR Target CI]($prCi/badge.svg)]($prCi) " +
    "[![Release Workflow]($relCi/badge.svg)]($relCi) ",
    "",
    "[![Latest Release](https://img.shields.io/github/v/release/$repo?label=$([uri]::EscapeDataString('gha-pr-comment-and-artifacts')))]($releases) " +
    "[![Channel v1](https://img.shields.io/badge/channel-v1-blue)](https://github.com/$repo/releases/tag/v1)",
    "",
    "## Actions",
    "",
    "### Post PR Comment (label-gated)",
    "[![Marketplace – Post PR Comment](https://img.shields.io/badge/Marketplace-Post%20PR%20Comment-blue)](https://github.com/marketplace/actions/$PostMarketplaceSlug)",
    "",
    "Install",
    "```yaml",
    "- name: Post telemetry comment (label-gated)",
    "  uses: $repo/action-post@v1",
    "  with:",
    "    label: telemetry-chunk-diag",
    "    comment_path: telemetry/comment.md",
    "```",
    "",
    "### Load Artifacts Metadata",
    "[![Marketplace – Load Artifacts Metadata](https://img.shields.io/badge/Marketplace-Load%20Artifacts%20Metadata-blue)](https://github.com/marketplace/actions/$ArtifactsMarketplaceSlug)",
    "",
    "Install",
    "```yaml",
    "- name: Load artifacts metadata",
    "  id: meta",
    "  uses: $repo/action-artifacts@v1",
    "  with:",
    "    prefer_cache: true",
    "    output_path: telemetry/artifacts_meta.json",
    "```",
    "",
    "## Notes",
    "- Pin to `@v1` for the rolling major, or to an exact tag like `@v1.0.0`.",
    "- See each action directory for detailed usage and troubleshooting.",
    ""
  ) -join "`n"
  return $readme
}

if (-not $DryRun) { Ensure-GhAuth }

function Get-HttpProbe([string]$Url, [int]$MaxWait = 12) {
  $delay = 2
  $elapsed = 0
  $attempts = 0
  while ($true) {
    $attempts += 1
    $code = ""
    try {
      $resp = Invoke-WebRequest -Uri $Url -Method Head -TimeoutSec 8 -ErrorAction Stop
      $code = [string]$resp.StatusCode
    } catch { $code = "" }
    if ($code -eq '200') { return [ordered]@{ code = $code; attempts = $attempts; elapsed = $elapsed } }
    if ($elapsed -ge $MaxWait) { return [ordered]@{ code = $code; attempts = $attempts; elapsed = $elapsed } }
    Start-Sleep -Seconds $delay
    $elapsed += $delay
    $remaining = [Math]::Max(0, $MaxWait - $elapsed)
    if ($remaining -le 0) { return [ordered]@{ code = $code; attempts = $attempts; elapsed = $elapsed } }
    $delay = [Math]::Min($delay * 2, $remaining)
  }
}

$postUrl = "https://github.com/marketplace/actions/$PostMarketplaceSlug"
$artUrl  = "https://github.com/marketplace/actions/$ArtifactsMarketplaceSlug"
$postProbe = Get-HttpProbe -Url $postUrl -MaxWait $MaxWaitSeconds
$artProbe  = Get-HttpProbe -Url $artUrl  -MaxWait $MaxWaitSeconds
$postCode = $postProbe.code; $artCode = $artProbe.code
if (-not $Quiet) {
  Write-Host "Marketplace (post): HTTP $postCode attempts=$($postProbe.attempts) elapsed=${($postProbe.elapsed)}s"
  Write-Host "Marketplace (artifacts): HTTP $artCode attempts=$($artProbe.attempts) elapsed=${($artProbe.elapsed)}s"
}
if ($postCode -ne '200' -and -not $Quiet) { Write-Warning "Marketplace URL check (post): HTTP $postCode for $postUrl" }
if ($artCode  -ne '200' -and -not $Quiet) { Write-Warning "Marketplace URL check (artifacts): HTTP $artCode for $artUrl" }

if ($env:GITHUB_OUTPUT) {
  "post_http_code=$postCode" | Out-File -FilePath $env:GITHUB_OUTPUT -Append -Encoding utf8NoBOM
  "artifacts_http_code=$artCode" | Out-File -FilePath $env:GITHUB_OUTPUT -Append -Encoding utf8NoBOM
  "post_http_attempts=$($postProbe.attempts)" | Out-File -FilePath $env:GITHUB_OUTPUT -Append -Encoding utf8NoBOM
  "post_http_elapsed=$($postProbe.elapsed)"   | Out-File -FilePath $env:GITHUB_OUTPUT -Append -Encoding utf8NoBOM
  "artifacts_http_attempts=$($artProbe.attempts)" | Out-File -FilePath $env:GITHUB_OUTPUT -Append -Encoding utf8NoBOM
  "artifacts_http_elapsed=$($artProbe.elapsed)"   | Out-File -FilePath $env:GITHUB_OUTPUT -Append -Encoding utf8NoBOM
  $status = if (($postCode -eq '200') -and ($artCode -eq '200')) { 'ok' } else { 'warn' }
  $msg = "post=$postCode attempts=$($postProbe.attempts) elapsed=$($postProbe.elapsed)s; artifacts=$artCode attempts=$($artProbe.attempts) elapsed=$($artProbe.elapsed)s"
  "status=$status"  | Out-File -FilePath $env:GITHUB_OUTPUT -Append -Encoding utf8NoBOM
  "message=$msg"    | Out-File -FilePath $env:GITHUB_OUTPUT -Append -Encoding utf8NoBOM
}

# Append a brief summary to the GitHub job summary, if available
if ($env:GITHUB_STEP_SUMMARY) {
  $summary = @()
  $summary += "### Marketplace Probe"
  $summary += "status: $status"
  $summary += $msg
  $summaryText = [string]::Join("`n", $summary)
  $summaryText | Out-File -FilePath $env:GITHUB_STEP_SUMMARY -Append -Encoding utf8NoBOM
}

$tmp = Join-Path $env:TEMP ("actions-readme-" + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Force -Path $tmp | Out-Null

if (-not $DryRun) { gh repo clone $Repo $tmp -- -q }
$readmePath = Join-Path $tmp 'README.md'
$content = Write-Readme -repo $Repo
$content | Out-File -Encoding utf8NoBOM -FilePath $readmePath

if ($DryRun) {
  Write-Host "[dry-run] Would write README to: $readmePath"
  Write-Host ($content.Substring(0, [Math]::Min(300, $content.Length)) + '...')
  exit 0
}

Push-Location $tmp
try {
  git config user.name github-actions | Out-Null
  git config user.email github-actions@users.noreply.github.com | Out-Null
  git add README.md | Out-Null
  if (git diff --cached --quiet) {
    Write-Host "No README changes to commit."
  } else {
    git commit -m "docs: add badges and install snippets to README" | Out-Null
    git push origin HEAD:$Branch | Out-Null
    Write-Host "Updated README in $Repo ($Branch)."
  }
} finally {
  Pop-Location
}
