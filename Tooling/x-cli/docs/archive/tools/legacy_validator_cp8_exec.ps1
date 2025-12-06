# Legacy validator CI helper (archived)

param(
  [string]$WorkflowPath = '.github/workflows/knowledge-validate.yml',
  [string]$Branch       = 'cp/14-15-validator-nozips',
  [int]   $Pr           = 718,
  [string]$ZipPath      = ''   # leave blank for root mode
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# --- Preconditions ---
gh auth status -h github.com | Out-Null
if (-not (Test-Path -LiteralPath $WorkflowPath)) {
  throw "Workflow not found: $WorkflowPath"
}

# --- Dispatch manual run (workflow_dispatch) on the target branch ---
Write-Host "Dispatching $WorkflowPath on --ref $Branch (zip_path='$ZipPath') ..."
gh workflow run "$WorkflowPath" --ref "$Branch" -f zip_path="$ZipPath" | Out-Null

# --- Poll newest workflow_dispatch run on that branch until completion ---
Write-Host "Waiting for workflow_dispatch run on $Branch ..."
$target = $null
for ($i=0; $i -lt 120; $i++) {
  $runs = gh run list --workflow "$WorkflowPath" `
          --json databaseId,headBranch,event,status,conclusion,url,createdAt -L 50 `
          | ConvertFrom-Json
  $target = $runs | Where-Object { $_.headBranch -eq $Branch -and $_.event -eq 'workflow_dispatch' } `
                   | Sort-Object createdAt | Select-Object -Last 1
  if ($null -ne $target -and $target.status -eq 'completed') { break }
  Start-Sleep -Seconds 5
}
if ($null -eq $target) { throw "No workflow_dispatch run found for $WorkflowPath on branch $Branch." }

$runId  = $target.databaseId
$runUrl = $target.url
Write-Host ("Run {0} completed: {1}" -f $runId, $target.conclusion)
Write-Host ("Run URL: {0}" -f $runUrl)

# --- Download artifacts (try all; then fall back to logs if not found) ---
$outDir = '_kv'
New-Item -ItemType Directory -Force -Path $outDir | Out-Null

$artifactOk = $true
try {
  # Download ALL artifacts for the run into _kv
  gh run download $runId -D $outDir | Out-Null
} catch {
  $artifactOk = $false
}

# Find validator.log / validator.json inside _kv (any subfolder)
function Find-First([string]$root, [string]$name) {
  Get-ChildItem -Path $root -Recurse -File -ErrorAction SilentlyContinue `
    | Where-Object { $_.Name -eq $name } | Select-Object -First 1
}
$logFile  = Find-First -root $outDir -name 'validator.log'
$jsonFile = Find-First -root $outDir -name 'validator.json'

if (-not $logFile -or -not $jsonFile) {
  Write-Warning "Expected artifacts missing. Falling back to capture run logs."
  # Save raw run log
  $runLogPath = Join-Path $outDir 'run.log'
  gh run view $runId --log | Set-Content -Encoding UTF8 -Path $runLogPath

  # Extract validator segment → write validator.log and validator.json
  $raw = Get-Content -Raw -Path $runLogPath
  # Try to locate marker and backtrack a bit to include the ordered lines
  $marker = '--JARVIS-VALIDATOR-JSON--'
  $idx = $raw.IndexOf($marker)
  if ($idx -ge 0) {
    $jsonText = $raw.Substring($idx + $marker.Length)
    $jsonOut  = Join-Path $outDir 'validator.json'
    $jsonText | Set-Content -Encoding UTF8 -Path $jsonOut

    # For validator.log, try to capture from the first "Root:" before marker to marker
    $pre = $raw.Substring(0, $idx)
    $rootMatch = [regex]::Matches($pre, '(^|\r?\n)Root:\s.*', 'Multiline')
    if ($rootMatch.Count -gt 0) {
      $start = $rootMatch[$rootMatch.Count-1].Index
      $orderedBlock = $pre.Substring($start, $idx - $start).Trim()
    } else {
      $orderedBlock = $pre.Trim()
    }
    $logOut = Join-Path $outDir 'validator.log'
    $orderedBlock + "`r`n" + $marker | Set-Content -Encoding UTF8 -Path $logOut

    $logFile  = Get-Item -LiteralPath $logOut
    $jsonFile = Get-Item -LiteralPath $jsonOut
  } else {
    Write-Warning "Marker not found in job logs; cannot fabricate validator.json."
  }
}

# --- Shape checks (order + marker + JSON keys) ---
$log    = if ($logFile)  { Get-Content -Raw -Path $logFile.FullName }  else { '' }
$jsonTx = if ($jsonFile) { Get-Content -Raw -Path $jsonFile.FullName } else { '' }

$patterns = '^Root:','^Manifest:','^Crosswalks:','^Glossary DoD:','^Edition Appendix:','^Policies PDFs:','^OVERALL:'
$okOrder = $true; $pos = -1
foreach ($p in $patterns) {
  $m = [regex]::Match($log, $p, [System.Text.RegularExpressions.RegexOptions]::Multiline)
  if (-not $m.Success -or $m.Index -le $pos) { $okOrder = $false; break } else { $pos = $m.Index }
}
$okMarker = [regex]::IsMatch($log, '^--JARVIS-VALIDATOR-JSON--$', [System.Text.RegularExpressions.RegexOptions]::Multiline)

$okKeys = $false; $j = $null
try {
  $j = $jsonTx | ConvertFrom-Json
  $req = 'overall','roles','crosswalks','glossary_DoD','appendix_found','appendix_path','policies_pdf_note'
  $okKeys = ($req | ForEach-Object { $j.PSObject.Properties.Name -contains $_ }) -notcontains $false
} catch { $okKeys = $false }

$overall = if ($j) { $j.overall } else { '(n/a)' }
$files   = if ($j) { ($j.crosswalks.files | Measure-Object).Count } else { 0 }
$parsed  = if ($j) { $j.crosswalks.parsed_ok } else { 0 }
$rows    = if ($j) { $j.crosswalks.rows_ok } else { 0 }
$appx    = if ($j) { if ($j.appendix_path) { $j.appendix_path } else { '—' } } else { '—' }

Write-Host ("Shape: ORDER={0} MARKER={1} JSON={2}" -f ($okOrder?'OK':'FAIL'), ($okMarker?'OK':'MISSING'), ($okKeys?'OK':'MISSING'))
Write-Host ("Artifacts: {0}, {1}" -f ($(if($logFile){$logFile.FullName}else{'(none)'}), $(if($jsonFile){$jsonFile.FullName}else{'(none)'}))

# --- Post PR comment (concise summary) ---
$shape = if ($okOrder -and $okMarker -and $okKeys) { 'OK' } else { 'CHECK FAIL' }
$body = @"
**Knowledge Validate — Advisory Check (post‑merge)**
- Run: [$runId]($runUrl)
- Result: **$overall**
- Order + marker + JSON keys: **$shape**
- Crosswalks: files=**$files**, parsed_ok=**$parsed**, rows_ok=**$rows**
- Appendix: **$appx**
- Artifacts: validator.log / validator.json
"@
gh pr comment $Pr --body "$body"

# --- Embed artifacts (size guard ~60 KB each) ---
function Post-Block([string]$title, [string]$content, [string]$lang) {
  $bytes = [System.Text.Encoding]::UTF8.GetByteCount($content)
  $snippet = if ($bytes -lt 60000) { $content } else { ($content -split "`r?`n") | Select-Object -First 200 -Join "`n" }
  $cb = "**$title**`n```$lang`n$snippet`n```"
  gh pr comment $Pr --body $cb
}
if ($jsonTx) { Post-Block -title 'validator.json (full or first 200 lines)' -content $jsonTx -lang 'json' }
if ($log)    { Post-Block -title 'validator.log (full or first 200 lines)'  -content $log    -lang '' }

# --- Final console summary ---
Write-Host ""
Write-Host "Summary:"
Write-Host ("- Run URL: {0}" -f $runUrl)
Write-Host ("- Shape checks: ORDER={0}, MARKER={1}, JSON KEYS={2}" `
            -f ($(if($okOrder){'OK'}else{'FAIL'}), $(if($okMarker){'OK'}else{'MISSING'}), $(if($okKeys){'OK'}else{'MISSING'})))
if ($log) {
  $first10 = ($log -split "`r?`n") | Select-Object -First 10 -Join "`n"
  Write-Host "- First 10 lines of validator.log:"
  Write-Host $first10
}
