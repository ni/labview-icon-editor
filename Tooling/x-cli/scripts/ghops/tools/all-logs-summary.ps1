<#
.SYNOPSIS
Summarize ghops all-logs.json for PR comments or dashboards.

.PARAMETER Input
Path to ghops-logs-all/all-logs.json (defaults to that path).

.PARAMETER Json
Emit a machine-readable JSON summary instead of Markdown text.
#>
[CmdletBinding()]
param(
  [Alias('Input')]
  [string]$AllLogs = 'ghops-logs-all/all-logs.json',
  [switch]$Json
)

$ErrorActionPreference = 'Stop'
if (-not (Test-Path -LiteralPath $AllLogs)) {
  Write-Error "Input not found: $AllLogs"; exit 1
}

$obj = Get-Content -LiteralPath $AllLogs -Raw | ConvertFrom-Json
if (-not $obj) { Write-Error 'Invalid JSON'; exit 1 }
if (-not $obj.schema -or $obj.schema -ne 'ghops.logs/v1') {
  Write-Warning "Unexpected schema '$($obj.schema)'; proceeding"
}

$entries = @($obj.entries)

if ($Json) {
  $summary = @{}
  foreach ($e in $entries) {
    $key = "$($e.origin)/$($e.name)"
    if (-not $summary.ContainsKey($key)) {
      $summary[$key] = [ordered]@{ count = 0; commands = 0; sample = @{} }
    }
    $summary[$key].count++
    $summary[$key].commands += @($e.commands).Count
    if ($summary[$key].sample.Count -eq 0) {
      $summary[$key].sample = [ordered]@{
        repo = $e.repo
        branch = $e.context.branch
        base = $e.context.base
        target = $e.context.target
        workflow = $e.context.workflow
        runId = $e.context.runId
        out = $e.context.out
        tag = $e.context.tag
        labels = $e.context.labels
      }
    }
  }
  $out = [ordered]@{
    meta = $obj.meta
    byTask = $summary
    totalEntries = $entries.Count
    totalCommands = ($entries | ForEach-Object { @($_.commands).Count } | Measure-Object -Sum).Sum
  }
  $out | ConvertTo-Json -Depth 6
  exit 0
}

# Markdown text summary
Write-Output ("ghops logs summary — repo {0} @ {1}" -f $obj.meta.repo, $obj.meta.sha)
$by = $entries | Group-Object origin, name
foreach ($g in $by) {
  $origin, $name = $g.Name -split ',\s*'
  $cmds = ($g.Group | ForEach-Object { @($_.commands).Count } | Measure-Object -Sum).Sum
  $ctx = $g.Group[0].context
  $extras = @()
  foreach ($k in 'branch','base','target','workflow','runId','out','tag') { if ($ctx.$k) { $extras += ("{0}={1}" -f $k,$ctx.$k) } }
  if ($ctx.labels) { $extras += ("labels=[{0}]" -f ($ctx.labels -join ',')) }
  $extraStr = if ($extras.Count -gt 0) { ' | ' + ($extras -join ' | ') } else { '' }
  Write-Output ("- {0}:{1} — {2} entries, {3} cmds{4}" -f $origin.Trim(), $name.Trim(), $g.Count, $cmds, $extraStr)
}
