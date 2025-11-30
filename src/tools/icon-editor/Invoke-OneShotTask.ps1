Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$PSModuleAutoLoadingPreference = 'None'
#Requires -Version 7.0
[CmdletBinding()]
param(
  [ValidateSet('Fast','Robust')]
  [string]$Preset = 'Fast',
  [int]$MinimumSupportedLVVersion = 2021,
[int]$PackageMinimumSupportedLVVersion = 2023,
  [ValidateSet(32,64)][int]$PackageSupportedBitness = 64,
  [string]$GhTokenPath = 'C:\github_token.txt',
  [string]$RepoSlug = 'LabVIEW-Community-CI-CD/labview-icon-editor',
  [string]$ResultsRootValidate = 'tests/results/_agent/icon-editor/local-validate',
  [switch]$PublishArtifacts,
  [switch]$SkipUpload
)

<#
.SYNOPSIS
Runs the common VS Code icon-editor one-shot task from the CLI.

.DESCRIPTION
The VS Code tasks “IconEditor: One-shot (Fast path)” and
“IconEditor: Build + Unit Tests (One-shot, Robust)” both shell into
`tools/icon-editor/Run-OneShotBuildAndTests.ps1` with slightly different
arguments.  Iterating on those tasks outside the editor required copying
their command line or re-triggering the task palette each time.

This helper mirrors those task presets so you can do:

```
pwsh -File tools/icon-editor/Invoke-OneShotTask.ps1 -Preset Robust
```

and the script will invoke the same pipeline the VS Code task would have
run.  Artifact publishing flows (Stage → Validate → QA → Upload) are now
handled by dedicated helpers instead of the legacy `-PublishArtifacts` flag.
#>

function Resolve-RepoRoot {
  param([string]$Start = (Get-Location).Path)
  try {
    $resolved = git -C $Start rev-parse --show-toplevel 2>$null
    if ($LASTEXITCODE -eq 0 -and -not [string]::IsNullOrWhiteSpace($resolved)) {
      return $resolved.Trim()
    }
  } catch {}
  return (Resolve-Path -LiteralPath $Start).Path
}

$repoRoot = Resolve-RepoRoot
$oneShotScript = Join-Path $repoRoot 'tools/icon-editor/Run-OneShotBuildAndTests.ps1'
if (-not (Test-Path -LiteralPath $oneShotScript -PathType Leaf)) {
  throw "Unable to locate Run-OneShotBuildAndTests.ps1 at '$oneShotScript'."
}

$skipSyncValue = ''
$skipApplyValue = ''
$skipCloseValue = ''
switch ($Preset) {
  'Fast'   { $skipSyncValue = 'yes'; $skipApplyValue = 'yes' }
  'Robust' { }
}

$oneShotArgs = @(
  '-MinimumSupportedLVVersion', "$MinimumSupportedLVVersion",
  '-PackageMinimumSupportedLVVersion', "$PackageMinimumSupportedLVVersion",
  '-PackageSupportedBitness', "$PackageSupportedBitness",
  '-RepoSlug', $RepoSlug,
  '-ResultsRootValidate', $ResultsRootValidate,
  '-SkipSync', $skipSyncValue,
  '-SkipVipcApply', $skipApplyValue,
  '-SkipClose', $skipCloseValue
)
if ($GhTokenPath) {
  $oneShotArgs += @('-GhTokenPath', $GhTokenPath)
}

Write-Host ("[OneShot] Preset: {0} (LV {1} / Pkg {2}-{3}-bit)" -f $Preset, $MinimumSupportedLVVersion, $PackageMinimumSupportedLVVersion, $PackageSupportedBitness) -ForegroundColor Cyan
& pwsh -NoLogo -NoProfile -File $oneShotScript @oneShotArgs
$oneShotExit = $LASTEXITCODE
if ($oneShotExit -ne 0) {
  throw "Run-OneShotBuildAndTests.ps1 exited with $oneShotExit."
}

if ($PublishArtifacts -or $SkipUpload) {
  $stageFlow = @"
[OneShot] -PublishArtifacts/-SkipUpload have been retired.
Use the staged pipeline instead:
  1. tools/Stage-XCliArtifact.ps1
  2. tools/Test-XCliReleaseAsset.ps1
  3. tools/Promote-XCliArtifact.ps1
  4. tools/Upload-XCliArtifact.ps1
"@
  throw $stageFlow
}

function Test-ValidLabel {
  param([Parameter(Mandatory)][string]$Label)
  if ($Label -notmatch '^[A-Za-z0-9._-]{1,64}$') { throw "Invalid label: $Label" }
}

function Invoke-WithTimeout {
  [CmdletBinding()]
  param(
    [Parameter(Mandatory)][scriptblock]$ScriptBlock,
    [Parameter()][int]$TimeoutSec = 600
  )
  $job = Start-Job -ScriptBlock $ScriptBlock
  if (-not (Wait-Job $job -Timeout $TimeoutSec)) {
    try { Stop-Job $job -Force } catch {}
    throw "Operation timed out in $TimeoutSec s"
  }
  Receive-Job $job -ErrorAction Stop
}
