Param(
  [Parameter(Mandatory=$true)][string]$Current,
  [string]$Discord,  # Discord webhook URL (empty/missing triggers DryRun fallback)
  [string]$HistoryDir = ".\telemetry\history",
  [string]$Manifest   = ".\telemetry\manifest.json",
  [int]$RetentionDays = 90,
  # Accept multiple switches; any of these indicates DRY-RUN
  [switch]$DryRun,
  [switch]$WhatIf,
  [switch]$ForceDryRun,
  # Optional posting strategies and diagnostics
  [switch]$PreferAttachment,
  [string]$AttachmentName = 'telemetry-summary.txt',
  [switch]$EmitChunkDiagnostics,
  # Optional PR comment markdown output
  [string]$CommentPath
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

if (-not (Test-Path -LiteralPath $Current)) {
  Write-Error "Telemetry summary not found: $Current"
}

$secretMissing = [string]::IsNullOrWhiteSpace($Discord)
if ($secretMissing) {
  Write-Warning "Discord webhook URL not set; falling back to dry-run. Set DISCORD_WEBHOOK_URL to enable posting."
}

New-Item -ItemType Directory -Force -Path $HistoryDir | Out-Null

function Read-Json([string]$p) {
  try { return (Get-Content -LiteralPath $p -Raw | ConvertFrom-Json) } catch { return $null }
}

$curr = Read-Json $Current
if ($null -eq $curr) { Write-Error "Current summary is not valid JSON: $Current" }

$prev = Get-ChildItem -LiteralPath $HistoryDir -Filter "summary-*.json" -File |
        Sort-Object LastWriteTimeUtc -Descending | Select-Object -First 1
$prevObj = $null
if ($prev) { $prevObj = Read-Json $prev.FullName }

function TryGet([object]$obj, [string]$name) {
  if ($null -eq $obj) { return $null }
  if (-not ($obj.PSObject.Properties.Name -contains $name)) { return $null }
  return $obj.$name
}

$currPass = TryGet $curr "pass"
$currFail = TryGet $curr "fail"
$currSkip = TryGet $curr "skipped"
$currDur  = TryGet $curr "duration_seconds"

$prevPass = TryGet $prevObj "pass"
$prevFail = TryGet $prevObj "fail"
$prevSkip = TryGet $prevObj "skipped"
$prevDur  = TryGet $prevObj "duration_seconds"

$baseline = ($null -eq $prevObj)
$manifestObj = if (Test-Path -LiteralPath $Manifest) { Read-Json $Manifest } else { $null }
$commit = if ($manifestObj) { $manifestObj.run.commit } else { $env:GITHUB_SHA }
$runId  = if ($manifestObj) { $manifestObj.run.run_id } else { $env:GITHUB_RUN_ID }

function HasProp([object]$obj, [string]$name) {
  return ($null -ne $obj) -and ($obj.PSObject.Properties.Name -contains $name)
}

function ToStr($v) { if ($null -eq $v) { return "n/a" } else { return [string]$v } }
function IsNumber($v) { return ($v -as [double]) -ne $null }
function DeltaStr([object]$curr, [object]$prev, [bool]$baseline) {
  if (-not $baseline -and (IsNumber $curr) -and (IsNumber $prev)) {
    $delta = ([double]$curr) - ([double]$prev)
    return " (Δ $delta)"
  }
  return ""
}

# Compose message using a List[string] for strictness/perf
$lines = New-Object 'System.Collections.Generic.List[string]'
$lines.Add(":white_check_mark: **X-CLI CI Summary**")
$runUrl = $null
if ($env:GITHUB_SERVER_URL -and $env:GITHUB_REPOSITORY -and $runId) {
  $runUrl = "$($env:GITHUB_SERVER_URL)/$($env:GITHUB_REPOSITORY)/actions/runs/$runId"
}
if ($runUrl) {
  $lines.Add("**run:** $runId   **commit:** $commit   **url:** $runUrl")
} else {
  $lines.Add("`run:` $runId   `commit:` $commit")
}
if ($baseline) { $lines.Add("**Baseline established.** No previous telemetry to compare.") }
else { $lines.Add("**Comparison vs previous:**") }

# Standard top-level metrics (with deltas when possible)
if (HasProp $curr 'total') {
  $prevTotal = if (HasProp $prevObj 'total') { $prevObj.total } else { $null }
  $lines.Add("- total: $(ToStr $curr.total)$(DeltaStr $curr.total $prevTotal $baseline)")
}
$lines.Add("- pass: $(ToStr $currPass)$(DeltaStr $currPass $prevPass $baseline)")
$lines.Add("- fail: $(ToStr $currFail)$(DeltaStr $currFail $prevFail $baseline)")
$lines.Add("- skipped: $(ToStr $currSkip)$(DeltaStr $currSkip $prevSkip $baseline)")
$durFmt = $null
if ($null -ne $currDur -and ($currDur -as [double]) -ne $null) {
  $durFmt = ('{0:0.0#}' -f [double]$currDur)
}
$durSuffix = if ($durFmt) { " (${durFmt}s)" } else { "" }
# Pretty delta formatting for duration (signed with seconds) to mirror Job Summary style
$durDeltaPretty = ""
if (-not $baseline -and (IsNumber $currDur) -and (IsNumber $prevDur)) {
  $dval = ([double]$currDur) - ([double]$prevDur)
  $dvalFmt = ('{0:0.0#}' -f [double]$dval)
  $durDeltaPretty = " (Δ ${dvalFmt}s)"
}
$lines.Add("- duration_seconds: $(ToStr $currDur)$durSuffix$durDeltaPretty")

# Helper to render "by_..." maps like by_category, by_suite, etc.
function RenderByMap([System.Collections.Generic.List[string]]$outLines, [string]$title, [object]$currMap, [object]$prevMap) {
  if ($null -eq $currMap) { return }
  $outLines.Add("")
  $outLines.Add("**${title}:**")
  $props = $currMap.PSObject.Properties | Sort-Object Name
  foreach ($p in $props) {
    $name = $p.Name
    $val  = $p.Value
    $prevVal = $null
    if ($null -ne $prevMap -and ($prevMap.PSObject.Properties.Name -contains $name)) {
      $prevVal = $prevMap.$name
    }
    if (IsNumber $val) {
      $outLines.Add("- ${name}: $(ToStr $val)$(DeltaStr $val $prevVal $baseline)")
    } elseif ($val -is [System.Collections.IDictionary] -or ($val.PSObject.Properties.Count -gt 0)) {
      $parts = @()
      if ($val.PSObject.Properties.Name -contains 'pass')    { $parts += "pass=$(ToStr $val.pass)" }
      if ($val.PSObject.Properties.Name -contains 'fail')    { $parts += "fail=$(ToStr $val.fail)" }
      if ($val.PSObject.Properties.Name -contains 'skipped') { $parts += "skipped=$(ToStr $val.skipped)" }
      if ($val.PSObject.Properties.Name -contains 'skip')    { $parts += "skip=$(ToStr $val.skip)" }
      if ($parts.Count -gt 0) {
        $outLines.Add("- ${name}: $($parts -join ", ")")
      } else {
        $jsonVal = ToStr ($val | ConvertTo-Json -Depth 3 -Compress)
        $outLines.Add("- ${name}: $jsonVal")
      }
    } else {
      $outLines.Add("- ${name}: $(ToStr $val)")
    }
  }
}

# Render known/likely maps
if (HasProp $curr 'by_category') {
  $prevMap = if (HasProp $prevObj 'by_category') { $prevObj.by_category } else { $null }
  RenderByMap $lines "By category" $curr.by_category $prevMap
}
foreach ($p in $curr.PSObject.Properties) {
  if ($p.Name -like 'by_*' -and $p.Name -ne 'by_category') {
    $title = ("By " + ($p.Name.Substring(3) -replace '_',' '))
    $prevMap = if ($prevObj -and ($prevObj.PSObject.Properties.Name -contains $p.Name)) { $prevObj.($p.Name) } else { $null }
    RenderByMap $lines $title $p.Value $prevMap
  }
}

$msg = [string]::Join("`n", $lines)

$forceDryRun = $DryRun.IsPresent `
  -or $WhatIf.IsPresent `
  -or $ForceDryRun.IsPresent `
  -or ($env:DRY_RUN -eq 'true' -or $env:DRY_RUN -eq '1') `
  -or $secretMissing
function Split-DiscordChunks([string]$text, [int]$limit = 2000) {
  $chunks = New-Object 'System.Collections.Generic.List[string]'
  $builder = New-Object System.Text.StringBuilder
  foreach ($line in ($text -split "`n")) {
    $lineWithNl = if ($builder.Length -eq 0) { $line } else { "`n$line" }
    if (($builder.Length + $lineWithNl.Length) -gt $limit) {
      $chunks.Add($builder.ToString())
      $builder.Clear() | Out-Null
      [void]$builder.Append($line)
    } else {
      [void]$builder.Append($lineWithNl)
    }
  }
  if ($builder.Length -gt 0) { $chunks.Add($builder.ToString()) }
  return ,$chunks.ToArray()
}
 
# Decide posting strategy and chunking info
$maxDiscordChars = 2000
$strategy = if ($PreferAttachment.IsPresent) { 'attachment' } elseif ($msg.Length -gt $maxDiscordChars) { 'chunk' } else { 'single' }
$chunksToSend = if ($strategy -eq 'chunk') { Split-DiscordChunks -text $msg -limit $maxDiscordChars } else { @($msg) }
$chunkTotal = if ($chunksToSend -is [System.Array]) { $chunksToSend.Length } else { 1 }
if ($forceDryRun) {
  Write-Warning "Dry-run: not posting to Discord. Message output below:"
  if ($strategy -eq 'attachment') {
    Write-Warning "Dry-run/attachment: would upload file $AttachmentName containing the full summary."
  } elseif ($msg.Length -gt 2000 -and $strategy -eq 'chunk') {
    $wouldChunks = Split-DiscordChunks -text $msg -limit 2000
    $wouldCnt = if ($wouldChunks -is [System.Array]) { $wouldChunks.Length } else { 1 }
    Write-Warning "Dry-run/chunking: message would be split into $wouldCnt chunk(s) for Discord."
  }
  Write-Output $msg
} else {
  if ($msg.Length -gt $maxDiscordChars -and $strategy -eq 'chunk') {
    Write-Warning "Discord content exceeds $maxDiscordChars characters ($($msg.Length)). Splitting into chunks."
  }
  if ($strategy -eq 'attachment') {
    # Post as a file attachment using multipart/form-data
    $payload = @{ content = "Telemetry summary attached ($AttachmentName)" } | ConvertTo-Json -Depth 3
    $bytes = [System.Text.Encoding]::UTF8.GetBytes($msg)
    $stream = New-Object System.IO.MemoryStream($bytes, $false)
    try {
      $client = [System.Net.Http.HttpClient]::new()
      $content = New-Object System.Net.Http.MultipartFormDataContent
      $jsonContent = New-Object System.Net.Http.StringContent($payload, [System.Text.Encoding]::UTF8, 'application/json')
      $content.Add($jsonContent, 'payload_json')
      $fileContent = New-Object System.Net.Http.StreamContent($stream)
      $fileContent.Headers.ContentType = [System.Net.Http.Headers.MediaTypeHeaderValue]::Parse('text/plain')
      $content.Add($fileContent, 'file', $AttachmentName)
      $response = $client.PostAsync($Discord, $content).GetAwaiter().GetResult()
      if (-not $response.IsSuccessStatusCode) {
        $respText = $response.Content.ReadAsStringAsync().GetAwaiter().GetResult()
        throw "Discord attachment post failed: $($response.StatusCode) $respText"
      }
      Write-Host "Posted summary to Discord as attachment ($AttachmentName)."
    } catch {
      Write-Warning "Failed to post attachment to Discord. $_"
      Write-Warning "Remediation: Verify webhook permissions for files; check network; consider falling back to chunked posts."
    } finally {
      if ($null -ne $stream) { $stream.Dispose() }
      if ($null -ne $client) { $client.Dispose() }
    }
  } else {
    $i = 0
    foreach ($chunk in $chunksToSend) {
      $i++
      $contentNote = if ($chunkTotal -gt 1) { "[part $i/$chunkTotal]`n$chunk" } else { $chunk }
      $body = @{ content = $contentNote } | ConvertTo-Json -Depth 3
      try {
        Invoke-RestMethod -Uri $Discord -Method Post -ContentType 'application/json' -Body $body -ErrorAction Stop
        Write-Host "Posted summary to Discord (chunk $i/$chunkTotal)."
      } catch {
        $status = $null
        $respText = $null
        try { $status = $_.Exception.Response.StatusCode.value__ } catch { }
        try {
          $stream2 = $_.Exception.Response.GetResponseStream()
          if ($stream2) {
            $reader2 = New-Object System.IO.StreamReader($stream2)
            $respText = $reader2.ReadToEnd()
          }
        } catch { }
        Write-Warning "Failed to post to Discord webhook. Status: $status. $_"
        if ($respText) { Write-Warning "Discord response: $respText" }
        Write-Warning "Remediation: Verify DISCORD_WEBHOOK_URL secret and workflow wiring; ensure runner has egress network; confirm webhook URL is valid and not revoked; use -DryRun to inspect message content and length."
        break
      }
    }
  }
}

$ts = (Get-Date).ToUniversalTime().ToString("yyyyMMddTHHmmssZ")
$dest = Join-Path -Path $HistoryDir -ChildPath ("summary-" + $ts + ".json")
Copy-Item -LiteralPath $Current -Destination $dest -Force
Write-Host "Saved current summary to $dest"

# Maintain a stable pointer to the latest summary for easy retrieval
$latest = Join-Path -Path $HistoryDir -ChildPath "summary-latest.json"
Copy-Item -LiteralPath $Current -Destination $latest -Force
Write-Host "Updated $latest with current summary"

# Emit a machine-readable diff for downstream analysis
$diff = [ordered]@{
  run_id   = $runId
  commit   = $commit
  ts       = $ts
  baseline = $baseline
  metrics  = [ordered]@{
    pass             = $currPass
    fail             = $currFail
    skipped          = $currSkip
    duration_seconds = $currDur
  }
}
if (-not $baseline) {
  $diff.metrics.prev_pass             = $prevPass
  $diff.metrics.prev_fail             = $prevFail
  $diff.metrics.prev_skipped          = $prevSkip
  $diff.metrics.prev_duration_seconds = $prevDur
  $diff.metrics.delta_pass             = if (IsNumber $currPass) { ([double]$currPass - [double]$prevPass) } else { $null }
  $diff.metrics.delta_fail             = if (IsNumber $currFail) { ([double]$currFail - [double]$prevFail) } else { $null }
  $diff.metrics.delta_skipped          = if (IsNumber $currSkip) { ([double]$currSkip - [double]$prevSkip) } else { $null }
  $diff.metrics.delta_duration_seconds = if (IsNumber $currDur)  { ([double]$currDur  - [double]$prevDur)  } else { $null }
}
$diffPath = Join-Path -Path $HistoryDir -ChildPath ("diff-" + $ts + ".json")
$diff | ConvertTo-Json -Depth 5 | Out-File -Encoding utf8NoBOM -FilePath $diffPath
Write-Host "Wrote diff to $diffPath"

# Maintain a stable pointer to the latest diff for easy retrieval
$diffLatest = Join-Path -Path $HistoryDir -ChildPath "diff-latest.json"
Copy-Item -LiteralPath $diffPath -Destination $diffLatest -Force
Write-Host "Updated $diffLatest with current diff"

# Prune history older than the retention period
$cutoff = (Get-Date).ToUniversalTime().AddDays(-$RetentionDays)
Get-ChildItem -LiteralPath $HistoryDir -Filter 'summary-*.json' -File |
  Where-Object { $_.LastWriteTimeUtc -lt $cutoff } |
  Remove-Item -Force -ErrorAction SilentlyContinue
Get-ChildItem -LiteralPath $HistoryDir -Filter 'diff-*.json' -File |
  Where-Object { $_.LastWriteTimeUtc -lt $cutoff } |
  Remove-Item -Force -ErrorAction SilentlyContinue
Write-Host "Pruned history older than $RetentionDays days"

# Emit chunk diagnostics for optional CI comments
$diag = [ordered]@{
  mode            = if ($forceDryRun) { 'dry-run' } else { 'post' }
  strategy        = $strategy
  chunks          = $chunkTotal
  message_length  = $msg.Length
  attachment      = ($strategy -eq 'attachment')
  attachment_name = if ($strategy -eq 'attachment') { $AttachmentName } else { $null }
  ts              = $ts
}
$diagJson = ($diag | ConvertTo-Json -Depth 4)
$diagPath = Join-Path -Path $HistoryDir -ChildPath ("chunk-diagnostics-" + $ts + ".json")
$diagJson | Out-File -Encoding utf8NoBOM -FilePath $diagPath
$diagLatest = Join-Path -Path $HistoryDir -ChildPath "chunk-diagnostics-latest.json"
Copy-Item -LiteralPath $diagPath -Destination $diagLatest -Force
Write-Host "Wrote chunk diagnostics to $diagPath"
if ($EmitChunkDiagnostics.IsPresent -or $env:CHUNK_DIAGNOSTICS -in @('1','true','True')) {
  Write-Host "CHUNK_DIAGNOSTICS: $diagJson"
}

# Optionally emit a PR-friendly comment.md to simplify CI comments
if ($CommentPath -and $CommentPath.Trim().Length -gt 0) {
  try {
    $commentDir = Split-Path -Parent -Path $CommentPath
    if ($commentDir -and -not (Test-Path -LiteralPath $commentDir)) {
      New-Item -ItemType Directory -Force -Path $commentDir | Out-Null
    }
    $md = New-Object System.Collections.Generic.List[string]
    $md.Add("# X-CLI CI Summary")
    $md.Add("")
    $md.Add('```')
    $md.Add($msg)
    $md.Add('```')
    if ($EmitChunkDiagnostics.IsPresent -or $env:CHUNK_DIAGNOSTICS -in @('1','true','True')) {
      $md.Add("")
      $md.Add("<details>")
      $md.Add("<summary>Chunk diagnostics</summary>")
      $md.Add("")
      $md.Add('```json')
      $md.Add($diagJson)
      $md.Add('```')
      $md.Add("</details>")
    }
    $mdText = [string]::Join("`n", $md)
    $mdText | Out-File -Encoding utf8NoBOM -FilePath $CommentPath
    Write-Host "Wrote PR comment markdown to $CommentPath"
  } catch {
    Write-Warning "Failed to write comment markdown to $CommentPath. $_"
  }
}
