param(
  [string]$RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")),
  [string]$ContextsDir = $null,
  [string]$SectionTitle = 'Markdown Templates Rendered',
  [switch]$VerboseLog
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Resolve-PythonExe {
  try {
    & python3 --version *> $null
    return 'python3'
  } catch { }
  try {
    & py -3 --version *> $null
    return 'py -3'
  } catch { }
  try {
    & python --version *> $null
    return 'python'
  } catch { }
  throw "Python not found (python3/py/python). Install Python in CI."
}

function Write-Log($msg){ if ($VerboseLog) { Write-Host $msg } }

$root = (Resolve-Path $RepoRoot).Path
if (-not $ContextsDir) { $ContextsDir = Join-Path $root 'docs/templates/markdown/contexts' }
$contextsDirPath = (Resolve-Path $ContextsDir -ErrorAction SilentlyContinue)?.Path
$tplRoot = Join-Path $root 'docs/templates/markdown'

if (-not (Test-Path $tplRoot)) {
  Write-Host "No templates folder found: $tplRoot"
  exit 0
}

$python = Resolve-PythonExe
Write-Log "Using Python: $python"

$templates = Get-ChildItem $tplRoot -Recurse -File -Filter *.tpl.md
if (-not $templates) {
  Write-Host "No .tpl.md templates found under $tplRoot"
  exit 0
}

$results = @()
foreach ($tpl in $templates) {
  $tplPath = $tpl.FullName
  $dir = Split-Path -Parent $tplPath
  $name = Split-Path -Leaf $tplPath
  # Remove .tpl.md
  $prefix = $name -replace "\.tpl\.md$",""
  $outPath = Join-Path $dir ($prefix + '.example.md')
  $metaPath = Join-Path $dir ($prefix + '.meta.json')
  # Build context candidates using robust path combine (avoids Join-Path arg pitfalls)
  $ctxCandidates = @()
  $ctxCandidates += [System.IO.Path]::Combine($dir, "$prefix.context.json")
  $ctxCandidates += [System.IO.Path]::Combine($dir, "$prefix.context.yaml")
  $ctxCandidates += [System.IO.Path]::Combine($dir, "$prefix.context.yml")
  $ctxPath = $null
  foreach ($c in $ctxCandidates) { if (Test-Path $c) { $ctxPath = $c; break } }
  if (-not $ctxPath -and $contextsDirPath) {
    $def = Join-Path $contextsDirPath 'default.json'
    if (Test-Path $def) { $ctxPath = $def }
  }

  $args = @('scripts/md_emit.py','--template', (Resolve-Path $tplPath).Path, '--out', $outPath, '--meta-out', $metaPath)
  if ($ctxPath) { $args += @('--context', $ctxPath) }
  Write-Log ("Render: {0} -> {1} (ctx: {2})" -f $tplPath, $outPath, ($ctxPath ?? '<none>'))
  $status = 'ok'
  $errMsg = $null
  try {
    & $python @args | Write-Host
    if ($LASTEXITCODE -ne 0) { $status = 'error'; $errMsg = "exit $LASTEXITCODE" }
  } catch {
    $status = 'error'
    $errMsg = $_.Exception.Message
    Write-Warning "Failed to render '$name': $errMsg"
  }
  $item = [ordered]@{ template = [string]$tplPath; context = [string]($ctxPath ?? ''); output = [string]$outPath; status = $status; error = [string]($errMsg ?? '') }
  # Tag group for easier triage (snippets vs general templates)
  $tplRel = $tplPath.Replace($root + [System.IO.Path]::DirectorySeparatorChar, '')
  if ($tplRel -match "(^|\\|/)docs(\\|/)templates(\\|/)markdown(\\|/)snippets(\\|/)") {
    $item.group = 'snippets'
  } else {
    $item.group = 'templates'
  }
  if (Test-Path $metaPath) {
    try {
      $meta = Get-Content $metaPath -Raw | ConvertFrom-Json
      if ($meta.placeholdersUsed) { $item.placeholdersUsed = @($meta.placeholdersUsed) }
      if ($meta.placeholdersMissing) { $item.placeholdersMissing = @($meta.placeholdersMissing) }
    } catch {
      Write-Warning "Failed to read meta for '$name': $($_.Exception.Message)"
    }
  }
  $results += $item
}

$artifactDir = Join-Path $root 'artifacts/md-templates'
New-Item -ItemType Directory -Force -Path $artifactDir | Out-Null
$manifestPath = Join-Path $artifactDir 'manifest.json'
($results | ConvertTo-Json -Depth 4) | Out-File -FilePath $manifestPath -Encoding utf8
Write-Host "Manifest: $manifestPath"

if ($env:GITHUB_STEP_SUMMARY) {
  $sb = New-Object System.Text.StringBuilder
  [void]$sb.AppendLine("### $SectionTitle")
  foreach ($r in $results) {
    $line = "- ``{0}`` → ``{1}`` (ctx: ``{2}``) [{3}]" -f $r.template, $r.output, ($r.context -replace [regex]::Escape($root), '.'), $r.status
    [void]$sb.AppendLine($line)
  }
  $sb.ToString() | Out-File -FilePath $env:GITHUB_STEP_SUMMARY -Append -Encoding utf8
}

exit 0
