# Legacy validator CI helper (archived)

param(
  [string]$WorkflowPath = '.github/workflows/knowledge-validate.yml',
  [string]$Branch       = 'cp/14-15-validator-nozips',
  [int]   $Pr           = 718,
  [string]$ZipPath      = '',
  [string]$ArtifactRoot = '',
  [switch]$WhatIf,
  [switch]$NoComment,
  [int]$MaxWaitSeconds  = 600,
  [int]$PollSeconds     = 5,
  [int]$PreviewLines    = 10,
  [Nullable[int]]$RunIdOverride = $null,
  [string]$RunUrlOverride = '',
  [string]$SummaryPath = ''
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
if ($PSVersionTable.PSVersion.Major -ge 7) {
  $PSNativeCommandUseErrorActionPreference = $true
}

function Invoke-GhOrThrow {
  param(
    [string[]]$Command,
    [string]$Context
  )

  $cmdText = 'gh ' + ($Command -join ' ')

  if ($WhatIf) {
    Write-Output "WHATIF: $cmdText ($Context)"
    return
  }

  $output = & gh @Command
  $exit = $LASTEXITCODE
  if ($exit -ne 0) {
    $msg = "$cmdText failed with exit code $exit" + $(if ($Context) { " [$Context]" } else { '' })
    throw $msg
  }

  return $output
}

function Find-First {
  param(
    [string]$Root,
    [string]$Name
  )

  Get-ChildItem -Path $Root -Recurse -File -ErrorAction SilentlyContinue |
    Where-Object { $_.Name -eq $Name } |
    Select-Object -First 1
}

if (-not $RunIdOverride) {
  if ($WhatIf -and -not $ArtifactRoot) {
    throw "WhatIf requires -ArtifactRoot or -RunIdOverride to avoid live gh calls."
  }

  Write-Output "Dispatching $WorkflowPath on --ref $Branch (zip_path='$ZipPath') ..."
  Invoke-GhOrThrow -Command @('workflow','run',$WorkflowPath,'--ref',$Branch,'-f',"zip_path=$ZipPath") -Context 'dispatch'

  Write-Output "Waiting for workflow_dispatch run on $Branch ..."
  $target = $null
  $maxPolls = [Math]::Ceiling($MaxWaitSeconds / [Math]::Max(1, $PollSeconds))
  for ($i = 0; $i -lt $maxPolls; $i++) {
    if ($WhatIf) { break }
    $runsJson = Invoke-GhOrThrow -Command @('run','list','--workflow',$WorkflowPath,'--json','databaseId,headBranch,event,status,conclusion,url,createdAt','-L','50') -Context 'run list'
    $runs = if ($runsJson) { $runsJson | ConvertFrom-Json } else { @() }
    $target = $runs |
      Where-Object { $_.headBranch -eq $Branch -and $_.event -eq 'workflow_dispatch' } |
      Sort-Object createdAt |
      Select-Object -Last 1
    Write-Verbose ("Poll {0}/{1}: status={2}" -f ($i + 1), $maxPolls, $(if ($target) { $target.status } else { 'none' }))
    if ($target -and $target.status -eq 'completed') { break }
    Start-Sleep -Seconds ([Math]::Max(1, $PollSeconds))
  }

  if (-not $WhatIf -and -not $target) {
    throw "No workflow_dispatch run found for $WorkflowPath on branch $Branch after $MaxWaitSeconds seconds."
  }

  $runId  = if ($WhatIf) { -1 } else { $target.databaseId }
  $runUrl = if ($WhatIf) { '(whatif)' } else { $target.url }
  Write-Output ("Run {0} completed: {1}" -f $runId, $(if ($WhatIf) { 'SKIPPED' } else { $target.conclusion }))
  Write-Output ("Run URL: {0}" -f $runUrl)
} else {
  $runId  = $RunIdOverride
  $runUrl = if ($RunUrlOverride) { $RunUrlOverride } else { "(not provided)" }
  Write-Output ("Using provided RunId: {0}" -f $runId)
  if ($RunUrlOverride) { Write-Output ("Run URL: {0}" -f $RunUrlOverride) }
}

$outDir = if ($ArtifactRoot) { $ArtifactRoot } else { '_kv' }
if (-not $ArtifactRoot) {
  New-Item -ItemType Directory -Force -Path $outDir | Out-Null
  Invoke-GhOrThrow -Command @('run','download',$runId,'-D',$outDir) -Context "download run=$runId"
} else {
  Write-Output ("Using existing artifacts at {0}" -f $ArtifactRoot)
}

$logFile  = Find-First -Root $outDir -Name 'validator.log'
$jsonFile = Find-First -Root $outDir -Name 'validator.json'

if (-not $logFile -or -not $jsonFile) {
  Write-Output "Artifact check: missing required files."
  Write-Output ("Listing files under {0}" -f $outDir)
  Get-ChildItem -Path $outDir -File | Select-Object Name,Length | Format-Table -AutoSize
  throw "Missing artifacts: log=$($null -ne $logFile), json=$($null -ne $jsonFile)"
}
$log    = Get-Content -Raw -Path $logFile.FullName
$jsonTx = Get-Content -Raw -Path $jsonFile.FullName

$patterns = @('^(?i)Root:','^Manifest:','^Crosswalks:','^Glossary DoD:','^Edition Appendix:','^Policies PDFs:','^OVERALL:')
$okOrder = $true
$pos = -1
foreach ($p in $patterns) {
  $match = [regex]::Match($log, $p, [System.Text.RegularExpressions.RegexOptions]::Multiline)
  if (-not $match.Success -or $match.Index -le $pos) {
    $okOrder = $false
    break
  }
  $pos = $match.Index
}

$okMarker = [regex]::IsMatch($log, '^--JARVIS-VALIDATOR-JSON--$', [System.Text.RegularExpressions.RegexOptions]::Multiline)

$okKeys = $false
$j = $null
try {
  $j = $jsonTx | ConvertFrom-Json
  $req = 'overall','roles','crosswalks','glossary_DoD','appendix_found','appendix_path','policies_pdf_note'
  $okKeys = ($req | ForEach-Object { $j.PSObject.Properties.Name -contains $_ }) -notcontains $false
} catch {
  $okKeys = $false
}

$overall = if ($j) { $j.overall } else { '(n/a)' }
$files   = if ($j) { ($j.crosswalks.files | Measure-Object).Count } else { 0 }
$parsed  = if ($j) { $j.crosswalks.parsed_ok } else { 0 }
$rows    = if ($j) { $j.crosswalks.rows_ok } else { 0 }
$appx    = if ($j) { if ($j.appendix_path) { $j.appendix_path } else { 'n/a' } } else { 'n/a' }

$orderStatus  = if ($okOrder) { 'OK' } else { 'FAIL' }
$markerStatus = if ($okMarker) { 'OK' } else { 'MISSING' }
$jsonStatus   = if ($okKeys) { 'OK' } else { 'MISSING' }

Write-Output ("Shape: ORDER={0} MARKER={1} JSON={2}" -f $orderStatus, $markerStatus, $jsonStatus)
$logPath  = if ($logFile)  { $logFile.FullName }  else { '(none)' }
$jsonPath = if ($jsonFile) { $jsonFile.FullName } else { '(none)' }
Write-Output ("Artifacts: {0}, {1}" -f $logPath, $jsonPath)

$shape = if ($okOrder -and $okMarker -and $okKeys) { 'OK' } else { 'CHECK FAIL' }
$bodyLines = @(
  '**Knowledge Validate - Advisory Check (post-merge)**',
  "- Run: [$runId]($runUrl)",
  "- Result: **$overall**",
  "- Order + marker + JSON keys: **$shape**",
  "- Crosswalks: files=**$files**, parsed_ok=**$parsed**, rows_ok=**$rows**",
  "- Appendix: **$appx**",
  '- Artifacts: validator.log / validator.json'
)
$body = $bodyLines -join [Environment]::NewLine
if (-not $NoComment -and -not $WhatIf) {
  Invoke-GhOrThrow -Command @('pr','comment',$Pr,'--body',$body) -Context "pr=$Pr"
} else {
  Write-Output "NoComment/WhatIf set; skipping PR comment"
}

function Write-BlockComment {
  param(
    [string]$Title,
    [string]$Content,
    [string]$Language
  )

  $bytes = [System.Text.Encoding]::UTF8.GetByteCount($Content)
  $snippet = if ($bytes -lt 60000) { $Content } else { ([regex]::Split($Content, '\\r?\\n') | Select-Object -First 200) -join [Environment]::NewLine }
  $commentBody = @(
    "**$Title**",
    ('```' + $Language),
    $snippet,
    '```'
  ) -join [Environment]::NewLine
  if (-not $NoComment -and -not $WhatIf) {
    Invoke-GhOrThrow -Command @('pr','comment',$Pr,'--body',$commentBody) -Context "pr=$Pr"
  } else {
    Write-Output "NoComment/WhatIf set; skipping PR comment for '$Title'"
  }
}

if ($jsonTx) {
  Write-BlockComment -Title 'validator.json (full or first 200 lines)' -Content $jsonTx -Language 'json'
}

if ($log) {
  Write-BlockComment -Title 'validator.log (full or first 200 lines)' -Content $log -Language ''
}

Write-Output ''
Write-Output 'Summary:'
Write-Output ("Run URL: {0}" -f $runUrl)
Write-Output ("Shape checks: ORDER={0}, MARKER={1}, JSON KEYS={2}" -f $orderStatus, $markerStatus, $jsonStatus)

if ($log) {
  $first10 = ([regex]::Split($log, '\r?\n') | Select-Object -First $PreviewLines) -join [Environment]::NewLine
  Write-Output ("First {0} lines of validator.log:" -f $PreviewLines)
  Write-Output $first10
}

if ($SummaryPath) {
  $summary = [pscustomobject]@{
    runId     = $runId
    runUrl    = $runUrl
    overall   = $overall
    shape     = $shape
    order     = $orderStatus
    marker    = $markerStatus
    json      = $jsonStatus
    files     = $files
    parsed    = $parsed
    rows      = $rows
    appendix  = $appx
    logPath   = $logFile.FullName
    jsonPath  = $jsonFile.FullName
  }
  $summary | ConvertTo-Json -Depth 5 | Set-Content -Path $SummaryPath -Encoding UTF8
  Write-Output ("Wrote summary JSON to {0}" -f $SummaryPath)
}
