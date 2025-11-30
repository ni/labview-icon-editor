Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$PSModuleAutoLoadingPreference = 'None'
[CmdletBinding(SupportsShouldProcess=$true, ConfirmImpact='Low')]
param(
  [Parameter()][ValidateSet('2021','2023','2025')][string]$LabVIEWVersion = '2023',
  [Parameter()][ValidateSet(32,64)][int]$Bitness = 64,
  [Parameter()][ValidateNotNullOrEmpty()][string]$Workspace = (Get-Location).Path,
  [Parameter()][int]$TimeoutSec = 600
)
#Requires -Version 7.0

param(
  [string]$RepoPath,
  [string]$BaseRef,
  [string]$HeadRef = 'HEAD',
  [int]$MaxCommits = 50,
  [string]$WorkspaceRoot,
  [string]$StageNamePrefix = 'commit',
  [switch]$SkipSync,
  [switch]$SkipValidate,
  [switch]$SkipLVCompare,
  [switch]$DryRun,
  [string]$LabVIEWExePath,
  [string]$SummaryPath,
  [string]$CachePath,
  [string]$EventsPath,
  [ValidateSet('quick','full')] [string]$Mode = 'full',
  [switch]$Quiet
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$InformationPreference = 'Continue'

function Resolve-RepoRoot {
  param([string]$StartPath = (Get-Location).Path)
  try {
    return (git -C $StartPath rev-parse --show-toplevel 2>$null).Trim()
  } catch {
    return $StartPath
  }
}

function Normalize-RepoPath {
  param([string]$Path)
  if ([string]::IsNullOrWhiteSpace($Path)) { return $null }
  $normalized = $Path.Replace('\', '/')
  while ($normalized.StartsWith('./')) { $normalized = $normalized.Substring(2) }
  if ($normalized.StartsWith('/')) { $normalized = $normalized.Substring(1) }
  return $normalized
}

function Ensure-Directory {
  param([string]$Path)
  if ([string]::IsNullOrWhiteSpace($Path)) { return $null }
  if (-not (Test-Path -LiteralPath $Path -PathType Container)) {
    New-Item -ItemType Directory -Path $Path -Force | Out-Null
  }
  try {
    return (Resolve-Path -LiteralPath $Path).Path
  } catch {
    return $Path
  }
}

function Get-ShortCommit {
  param([string]$Hash)
  if ([string]::IsNullOrWhiteSpace($Hash)) { return '(unknown)' }
  if ($Hash.Length -le 8) { return $Hash }
  return $Hash.Substring(0,8)
}

function Get-ParentCommit {
  param(
    [string]$RepoPath,
    [string]$Commit
  )
  if ([string]::IsNullOrWhiteSpace($Commit)) { return $null }
  $args = @('-C', $RepoPath, 'rev-parse', '--verify', "$Commit`^")
  $output = & git @args 2>$null
  if ($LASTEXITCODE -ne 0) { return $null }
  return ($output -split "`n")[0].Trim()
}

function Get-BlobHash {
  param(
    [string]$RepoPath,
    [string]$Commit,
    [string]$Path
  )
  if ([string]::IsNullOrWhiteSpace($Commit) -or [string]::IsNullOrWhiteSpace($Path)) { return $null }
  $args = @('-C', $RepoPath, 'rev-parse', "$Commit`:$Path")
  $output = & git @args 2>$null
  if ($LASTEXITCODE -ne 0) { return $null }
  return ($output -split "`n")[0].Trim()
}

function Get-BlobSize {
  param(
    [string]$RepoPath,
    [string]$BlobHash
  )
  if ([string]::IsNullOrWhiteSpace($BlobHash)) { return $null }
  $args = @('-C', $RepoPath, 'cat-file', '-s', $BlobHash)
  $output = & git @args 2>$null
  if ($LASTEXITCODE -ne 0) { return $null }
  try { return [int64]$output.Trim() } catch { return $null }
}

function Resolve-CompareDecision {
  param(
    [string]$Status,
    [string]$Path,
    [string]$OldPath,
    [string]$BaseHash,
    [string]$HeadHash
  )

  $normalizedPath = Normalize-RepoPath -Path ($Path ?? $OldPath)
  if (-not $Status) {
    return [pscustomobject]@{ Compare = $true; Reason = 'unknown status'; Path = $normalizedPath }
  }

  $statusCode = $Status.Substring(0,1).ToUpperInvariant()

  switch ($statusCode) {
    'D' {
      return [pscustomobject]@{ Compare = $false; Reason = 'deleted file'; Path = $normalizedPath }
    }
    'R' {
      $score = $Status.Substring(1)
      $pureRename = $false
      if ($score -and ($score -match '^\d+$')) {
        $pureRename = ([int]$score -eq 100)
      }
      if ($pureRename -and $BaseHash -and $HeadHash -and ($BaseHash -eq $HeadHash)) {
        return [pscustomobject]@{ Compare = $false; Reason = 'rename without content change'; Path = $normalizedPath }
      }
      if ($BaseHash -and $HeadHash -and ($BaseHash -eq $HeadHash)) {
        return [pscustomobject]@{ Compare = $false; Reason = 'content unchanged after rename'; Path = $normalizedPath }
      }
      return [pscustomobject]@{ Compare = $true; Reason = 'rename with modifications'; Path = $normalizedPath }
    }
    'C' {
      if ($BaseHash -and $HeadHash -and ($BaseHash -eq $HeadHash)) {
        return [pscustomobject]@{ Compare = $false; Reason = 'copy identical to source'; Path = $normalizedPath }
      }
      return [pscustomobject]@{ Compare = $true; Reason = 'copy with modifications'; Path = $normalizedPath }
    }
    default {
      if ($BaseHash -and $HeadHash -and ($BaseHash -eq $HeadHash)) {
        return [pscustomobject]@{ Compare = $false; Reason = 'content unchanged'; Path = $normalizedPath }
      }
      return [pscustomobject]@{ Compare = $true; Reason = 'modified'; Path = $normalizedPath }
    }
  }
}

function Read-ViDiffCache {
  param([string]$Path)
  $default = [ordered]@{
    schema  = 'icon-editor/vi-diff-cache@v1'
    entries = [ordered]@{}
  }
  if ([string]::IsNullOrWhiteSpace($Path) -or -not (Test-Path -LiteralPath $Path -PathType Leaf)) {
    return $default
  }
  try {
    $raw = Get-Content -LiteralPath $Path -Raw
    if ([string]::IsNullOrWhiteSpace($raw)) { return $default }
    $json = $raw | ConvertFrom-Json -Depth 6
    if (-not $json) { return $default }
    if (-not $json.PSObject.Properties['entries']) {
      $json | Add-Member -Name 'entries' -MemberType NoteProperty -Value ([ordered]@{}) -Force
    } elseif (-not ($json.entries -is [System.Collections.IDictionary])) {
      $dict = [ordered]@{}
      if ($json.entries -and $json.entries.PSObject) {
        foreach ($prop in $json.entries.PSObject.Properties) {
          $value = $prop.Value
          if ($value -and (-not $value.PSObject.Properties['commit'])) {
            $value | Add-Member -Name 'commit' -MemberType NoteProperty -Value $prop.Name -Force
          }
          $dict[$prop.Name] = $value
        }
      }
      $json.entries = $dict
    }
    return $json
  } catch {
    return $default
  }
}

function Write-ViDiffCache {
  param(
    [string]$Path,
    [pscustomobject]$Cache
  )
  if ([string]::IsNullOrWhiteSpace($Path) -or -not $Cache) { return }
  $dir = Split-Path -Parent $Path
  if ($dir) { Ensure-Directory $dir | Out-Null }
  $Cache | Add-Member -Name 'updatedAt' -MemberType NoteProperty -Value ((Get-Date).ToString('o')) -Force
  $Cache | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $Path -Encoding utf8
}

function Write-HeuristicEvent {
  param(
    [string]$Path,
    [hashtable]$Event
  )
  if ([string]::IsNullOrWhiteSpace($Path) -or -not $Event) { return }
  $dir = Split-Path -Parent $Path
  if ($dir) { Ensure-Directory $dir | Out-Null }
  if (-not $Event.ContainsKey('schema')) { $Event['schema'] = 'icon-editor/vi-diff-event@v1' }
  if (-not $Event.ContainsKey('timestamp')) { $Event['timestamp'] = (Get-Date).ToString('o') }
  Add-Content -LiteralPath $Path -Value ($Event | ConvertTo-Json -Depth 6 -Compress)
}

function Get-UniqueReasons {
  param([System.Collections.IEnumerable]$Items)
  $set = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
  if ($Items) {
    foreach ($item in $Items) {
      $reason = $null
      if ($item -and $item.PSObject -and $item.PSObject.Properties['reason']) {
        $reason = $item.reason
      } elseif ($item) {
        $reason = [string]$item
      }
      if (-not [string]::IsNullOrWhiteSpace($reason)) {
        $set.Add($reason) | Out-Null
      }
    }
  }
  return [System.Linq.Enumerable]::ToArray[System.String]($set)
}

function Load-HeuristicConfig {
  param(
    [string]$RepoRoot,
    [string]$DefaultRelativePath = 'configs/icon-editor/vi-diff-heuristics.json'
  )

  $configPath = Join-Path $RepoRoot $DefaultRelativePath
  $override = [System.Environment]::GetEnvironmentVariable('ICON_EDITOR_VI_DIFF_RULES')
  if (-not [string]::IsNullOrWhiteSpace($override)) {
    if ([System.IO.Path]::IsPathRooted($override)) {
      $configPath = $override
    } else {
      $configPath = [System.IO.Path]::GetFullPath((Join-Path $RepoRoot $override))
    }
  }

  if (-not (Test-Path -LiteralPath $configPath -PathType Leaf)) {
    return $null
  }

  try {
    return Get-Content -LiteralPath $configPath -Raw | ConvertFrom-Json -Depth 6
  } catch {
    Write-Warning ("Failed to parse heuristic rules '{0}': {1}" -f $configPath, $_.Exception.Message)
    return $null
  }
}

function Resolve-PrefixRule {
  param(
    [System.Collections.Generic.List[object]]$Rules,
    [string]$Path
  )
  if (-not $Rules -or $Rules.Count -eq 0 -or [string]::IsNullOrWhiteSpace($Path)) { return $null }
  $best = $null
  foreach ($rule in $Rules) {
    if ($Path.StartsWith($rule.prefix, [System.StringComparison]::OrdinalIgnoreCase)) {
      if (-not $best -or $rule.prefix.Length -gt $best.prefix.Length) {
        $best = $rule
      }
    }
  }
  return $best
}

$codeRepoRoot = Resolve-RepoRoot -StartPath $PSScriptRoot
$sweepScript = Join-Path $codeRepoRoot 'tools/icon-editor/Invoke-VIDiffSweep.ps1'
if (-not (Test-Path -LiteralPath $sweepScript -PathType Leaf)) {
  throw "Invoke-VIDiffSweep.ps1 not found at '$sweepScript'."
}

$modeNormalized = ($Mode ?? 'full').ToLowerInvariant()
if ($modeNormalized -ne 'quick' -and $modeNormalized -ne 'full') {
  throw "Unknown sweep mode '$Mode'. Supported values: quick, full."
}

if (-not $CachePath) {
  $CachePath = Join-Path $codeRepoRoot 'tests/results/_agent/icon-editor/vi-diff-cache.json'
}
if (-not [System.IO.Path]::IsPathRooted($CachePath)) {
  $CachePath = [System.IO.Path]::GetFullPath((Join-Path $codeRepoRoot $CachePath))
}
$cacheDir = Split-Path -Parent $CachePath
if ($cacheDir) { Ensure-Directory $cacheDir | Out-Null }
$cacheData = Read-ViDiffCache -Path $CachePath
$cacheEntries = if ($cacheData -and $cacheData.PSObject.Properties['entries'] -and $cacheData.entries -is [System.Collections.IDictionary]) {
  $cacheData.entries
} else {
  [ordered]@{}
}
$cacheStats = [ordered]@{ hits = 0; writes = 0 }
$cacheDirty = $false

if (-not $EventsPath) {
  $EventsPath = Join-Path $codeRepoRoot 'tests/results/_agent/icon-editor/vi-diff/compare-events.ndjson'
}
if (-not [System.IO.Path]::IsPathRooted($EventsPath)) {
  $EventsPath = [System.IO.Path]::GetFullPath((Join-Path $codeRepoRoot $EventsPath))
}
$eventsDir = Split-Path -Parent $EventsPath
if ($eventsDir) { Ensure-Directory $eventsDir | Out-Null }
$eventsPathResolved = $EventsPath

$heuristicConfig = Load-HeuristicConfig -RepoRoot $codeRepoRoot
$sizeThreshold = 0
if ($heuristicConfig -and $heuristicConfig.PSObject.Properties['sizeDeltaBytes']) {
  try { $sizeThreshold = [int]$heuristicConfig.sizeDeltaBytes } catch { $sizeThreshold = 0 }
}
$maxComparePerCommit = 0
if ($heuristicConfig -and $heuristicConfig.PSObject.Properties['maxComparePerCommit']) {
  try {
    $maxComparePerCommit = [int]$heuristicConfig.maxComparePerCommit
    if ($maxComparePerCommit -lt 0) { $maxComparePerCommit = 0 }
  } catch {
    $maxComparePerCommit = 0
  }
}
$prefixRules = [System.Collections.Generic.List[object]]::new()
if ($heuristicConfig -and $heuristicConfig.PSObject.Properties['prefixRules']) {
  foreach ($rule in @($heuristicConfig.prefixRules)) {
    if (-not $rule) { continue }
    $prefix = Normalize-RepoPath -Path $rule.prefix
    $action = if ($rule.PSObject.Properties['action']) { $rule.action.ToLowerInvariant() } else { $null }
    if ([string]::IsNullOrWhiteSpace($prefix) -or [string]::IsNullOrWhiteSpace($action)) { continue }
    $label = if ($rule.PSObject.Properties['label']) { [string]$rule.label } else { $prefix }
    $prefixRules.Add([pscustomobject]@{
        prefix = $prefix
        action = $action
        label  = $label
    }) | Out-Null
  }
}

$sweepWrapper = $null
Push-Location $codeRepoRoot
try {
  $sweepWrapper = & $sweepScript `
    -RepoPath $RepoPath `
    -BaseRef $BaseRef `
    -HeadRef $HeadRef `
    -MaxCommits $MaxCommits `
    -SkipSync:$SkipSync `
    -Quiet:$Quiet
}
finally {
  Pop-Location
}

if (-not $sweepWrapper) {
  throw 'Invoke-VIDiffSweep.ps1 returned no data.'
}

$candidates = $sweepWrapper.candidates
if (-not $candidates) {
  throw 'Invoke-VIDiffSweep.ps1 did not return candidate metadata.'
}

$repoResolved = $candidates.repoPath
$commitResults = New-Object System.Collections.Generic.List[object]
$compareExecutedCount = 0

if (-not $repoResolved) {
  throw 'Failed to resolve repository for sweep.'
}

$commitList = if ($candidates.PSObject.Properties['commits'] -and $candidates.commits) { $candidates.commits } else { @() }

foreach ($commit in $commitList) {
  $commitHash = $commit.commit
  $parentCommit = Get-ParentCommit -RepoPath $repoResolved -Commit $commitHash

  $cacheEntry = $null
  $cacheModeLabel = $null
  $cacheHit = $false
  $comparePaths = [System.Collections.Generic.List[string]]::new()
  $skipped = [System.Collections.Generic.List[object]]::new()
  $ranCompare = $false
  $decision = 'skip'
  $reasons = @()
  $compareResult = $null

  if ($commitHash -and $cacheEntries -is [System.Collections.IDictionary] -and $cacheEntries.Contains($commitHash)) {
    $candidate = $cacheEntries[$commitHash]
    if ($candidate) {
      $cacheEntry = $candidate
      if ($candidate.PSObject.Properties['mode']) { $cacheModeLabel = [string]$candidate.mode }
      $entryDecision = if ($candidate.PSObject.Properties['decision']) { [string]$candidate.decision } else { $null }
      $entryRanCompare = $false
      if ($candidate.PSObject.Properties['ranCompare']) {
        try { $entryRanCompare = [bool]$candidate.ranCompare } catch { $entryRanCompare = $false }
      }
      $usable = $false
      if ($modeNormalized -eq 'full') {
        if ($entryDecision -eq 'skip' -or $entryRanCompare) { $usable = $true }
      } else {
        $usable = $true
      }

      if ($usable) {
        $cacheHit = $true
        $cacheStats.hits++
        if ($candidate.PSObject.Properties['comparePaths']) {
          foreach ($path in @($candidate.comparePaths | Where-Object { $_ })) { $comparePaths.Add($path) | Out-Null }
        }
        if ($candidate.PSObject.Properties['skipped']) {
          foreach ($item in @($candidate.skipped)) {
            if ($item -and $item.PSObject -and $item.PSObject.Properties['path']) {
              $skipped.Add([pscustomobject]@{ path = $item.path; reason = $item.reason }) | Out-Null
            }
          }
        }
        if ($candidate.PSObject.Properties['reasons']) {
          $reasons = @($candidate.reasons | Where-Object { $_ })
        }
        if ($entryDecision) {
          $decision = $entryDecision
        } elseif ($comparePaths.Count -gt 0) {
          $decision = 'compare'
        }
        $ranCompare = $entryRanCompare
      }
    }
  }

  if (-not $cacheHit) {
    $fileInfos = [System.Collections.Generic.List[object]]::new()
    foreach ($file in ($commit.files ?? @())) {
      $normalizedPath = Normalize-RepoPath -Path $file.path
      $basePath = if ($file.oldPath) { $file.oldPath } else { $file.path }

      $baseHash = if ($parentCommit) { Get-BlobHash -RepoPath $repoResolved -Commit $parentCommit -Path $basePath } else { $null }
      $headHash = Get-BlobHash -RepoPath $repoResolved -Commit $commitHash -Path $file.path

      $decisionNode = Resolve-CompareDecision -Status $file.status -Path $file.path -OldPath $file.oldPath -BaseHash $baseHash -HeadHash $headHash
      $shouldCompare = $decisionNode.Compare
      $forceCompare = $false
      $reasonList = [System.Collections.Generic.List[string]]::new()
      if (-not $shouldCompare -and $decisionNode.Reason) { $reasonList.Add($decisionNode.Reason) | Out-Null }

      $prefixRule = Resolve-PrefixRule -Rules $prefixRules -Path $normalizedPath
      if ($prefixRule) {
        switch ($prefixRule.action) {
          'skip' {
            $shouldCompare = $false
            $reasonList.Add("prefix-skip:$($prefixRule.label)") | Out-Null
          }
          'compare' {
            $forceCompare = $true
            $shouldCompare = $true
            $reasonList.Add("prefix-compare:$($prefixRule.label)") | Out-Null
          }
        }
      }

      if ($shouldCompare -and -not $forceCompare -and $sizeThreshold -gt 0) {
        $baseSize = Get-BlobSize -RepoPath $repoResolved -BlobHash $baseHash
        $headSize = Get-BlobSize -RepoPath $repoResolved -BlobHash $headHash
        if ($baseSize -ne $null -and $headSize -ne $null) {
          $delta = [Math]::Abs($headSize - $baseSize)
          if ($delta -le $sizeThreshold) {
            $shouldCompare = $false
            $reasonList.Add('small-delta') | Out-Null
          }
        }
      }

      if ($shouldCompare -and $modeNormalized -eq 'quick') {
        $shouldCompare = $false
        $reasonList.Add('quick-mode') | Out-Null
      }

      if ($shouldCompare) {
        $comparePaths.Add($normalizedPath) | Out-Null
      } else {
        $reasonText = if ($reasonList.Count -gt 0) { ($reasonList.ToArray() -join ', ') } elseif ($decisionNode.Reason) { $decisionNode.Reason } else { 'heuristic-skip' }
        $skipped.Add([pscustomobject]@{
            path   = $normalizedPath
            reason = $reasonText
          }) | Out-Null
      }
    }

    $decision = if ($comparePaths.Count -gt 0) { 'compare' } else { 'skip' }

    $throttleApplied = $false
    if ($maxComparePerCommit -gt 0 -and $comparePaths.Count -gt $maxComparePerCommit) {
      $throttleApplied = $true
      $kept = [System.Collections.Generic.List[string]]::new()
      for ($index = 0; $index -lt $comparePaths.Count; $index++) {
        $path = $comparePaths[$index]
        if ($index -lt $maxComparePerCommit) {
          $kept.Add($path) | Out-Null
        } else {
          $skipped.Add([pscustomobject]@{
              path   = $path
              reason = 'compare-throttle'
            }) | Out-Null
        }
      }
      $comparePaths = $kept
      if ($comparePaths.Count -eq 0) {
        $decision = 'skip'
      }
    }

    $reasonSeed = @()
    if ($decision -eq 'compare') {
      $reasonSeed += 'requires-compare'
    } else {
      $reasonSeed += Get-UniqueReasons -Items $skipped
    }
    if ($throttleApplied) {
      $reasonSeed += ("compare-throttle:{0}" -f $maxComparePerCommit)
    }
    if ($DryRun.IsPresent) {
      $reasonSeed += 'dry-run'
    }

    $shouldRunCompare = ($modeNormalized -eq 'full') -and (-not $DryRun.IsPresent) -and ($comparePaths.Count -gt 0)

    if ($shouldRunCompare) {
      $shortCommit = Get-ShortCommit -Hash $commitHash
      $stageName = "{0}-{1}" -f $StageNamePrefix, $shortCommit
      $commitScript = Join-Path $codeRepoRoot 'tools/icon-editor/Invoke-VIComparisonFromCommit.ps1'
      if (-not (Test-Path -LiteralPath $commitScript -PathType Leaf)) {
        throw "Invoke-VIComparisonFromCommit.ps1 not found at '$commitScript'."
      }
      $compareParams = @{
        Commit        = $commitHash
        RepoPath      = $repoResolved
        WorkspaceRoot = $WorkspaceRoot
        StageName     = $stageName
        IncludePaths  = $comparePaths.ToArray()
        LabVIEWExePath= $LabVIEWExePath
        SkipSync      = $true
      }
      if ($SkipValidate.IsPresent) { $compareParams['SkipValidate'] = $true }
      if ($SkipLVCompare.IsPresent) { $compareParams['SkipLVCompare'] = $true }
      $compareResult = & $commitScript @compareParams
      $ranCompare = $true
      $compareExecutedCount++
      $reasonSeed += 'compare-executed'
    }

    $reasons = Get-UniqueReasons -Items $reasonSeed
    $reasons = @($reasons | Where-Object { $_ })

    $cachedSkipped = @()
    foreach ($item in $skipped) {
      $cachedSkipped += [ordered]@{
        path   = $item.path
        reason = $item.reason
      }
    }

    $cacheEntry = [ordered]@{
      commit       = $commitHash
      mode         = $modeNormalized
      ranCompare   = $ranCompare
      decision     = $decision
      comparePaths = $comparePaths.ToArray()
      skipped      = $cachedSkipped
      reasons      = $reasons
      timestamp    = (Get-Date).ToString('o')
      headRef      = $candidates.headRef
    }

    $cacheEntries[$commitHash] = $cacheEntry
    if ($cacheData -and $cacheData.PSObject.Properties['entries']) {
      $cacheData.entries = $cacheEntries
    }
    $cacheStats.writes++
    $cacheDirty = $true
  } else {
    if (-not $reasons -or $reasons.Count -eq 0) {
      if ($decision -eq 'compare') {
        $reasons = @('requires-compare')
      } else {
        $reasons = Get-UniqueReasons -Items $skipped
        $reasons = @($reasons | Where-Object { $_ })
      }
    }
  }

  if (-not $Quiet) {
    $shortCommit = Get-ShortCommit -Hash $commitHash
    if ($cacheHit) {
      $cacheLabel = if ($cacheModeLabel) { $cacheModeLabel } else { 'cache' }
      Write-Information ("Commit {0}: cache hit ({1}) decision={2} compareCount={3}" -f $shortCommit, $cacheLabel, $decision, $comparePaths.Count)
    } elseif ($comparePaths.Count -eq 0) {
      $skipReasons = Get-UniqueReasons -Items $skipped
      $reasonText = if ($skipReasons -and $skipReasons.Count -gt 0) { $skipReasons -join ', ' } else { 'no compare candidates' }
      Write-Information ("Commit {0}: all VI changes skipped ({1})" -f $shortCommit, $reasonText)
    } elseif ($modeNormalized -eq 'quick' -or $DryRun.IsPresent) {
      Write-Information ("Commit {0}: triage identified {1} file(s) (compare deferred; mode={2})" -f $shortCommit, $comparePaths.Count, $modeNormalized)
    } else {
      Write-Information ("Commit {0}: comparing {1} file(s)" -f $shortCommit, $comparePaths.Count)
    }
  }

  $compareArray = $comparePaths.ToArray()
  $skippedArray = $skipped.ToArray()

  $commitResult = [ordered]@{
    commit       = $commitHash
    author       = $commit.author
    authorDate   = $commit.authorDate
    subject      = $commit.subject
    decision     = $decision
    mode         = $modeNormalized
    cacheHit     = $cacheHit
    comparePaths = $compareArray
    skipped      = $skippedArray
    reasons      = $reasons
    ranCompare   = $ranCompare
  }
  if ($cacheModeLabel) { $commitResult['cacheMode'] = $cacheModeLabel }
  if ($cacheEntry -and $cacheEntry.PSObject.Properties['timestamp']) { $commitResult['cacheTimestamp'] = $cacheEntry.timestamp }
  if ($compareResult -and $compareResult.PSObject.Properties['stageSummary']) { $commitResult['stageSummary'] = $compareResult.stageSummary }
  $commitResults.Add([pscustomobject]$commitResult) | Out-Null

  $eventPayload = [ordered]@{
    type         = 'heuristic-decision'
    mode         = $modeNormalized
    commit       = $commitHash
    decision     = $decision
    cacheHit     = $cacheHit
    ranCompare   = $ranCompare
    compareCount = $compareArray.Length
  }
  if ($compareArray.Length -gt 0) { $eventPayload['comparePaths'] = $compareArray }
  if ($skippedArray.Length -gt 0) {
    $eventPayload['skipped'] = ($skippedArray | Select-Object -First 10 | ForEach-Object { [ordered]@{ path = $_.path; reason = $_.reason } })
  }
  if ($reasons -and $reasons.Count -gt 0) { $eventPayload['reasons'] = $reasons }
  if ($cacheModeLabel) { $eventPayload['cacheMode'] = $cacheModeLabel }
  Write-HeuristicEvent -Path $eventsPathResolved -Event $eventPayload
}

if ($cacheDirty) {
  Write-ViDiffCache -Path $CachePath -Cache $cacheData
}
$result = [ordered]@{
  repoPath        = $repoResolved
  baseRef         = $candidates.baseRef
  headRef         = $candidates.headRef
  mode            = $modeNormalized
  cache           = [ordered]@{
    path   = $CachePath
    hits   = $cacheStats.hits
    writes = $cacheStats.writes
  }
  eventsPath      = $eventsPathResolved
  totalCommits    = $commitResults.Count
  comparedCommits = $compareExecutedCount
  commits         = $commitResults.ToArray()
  candidates      = $candidates
  outputPath      = $sweepWrapper.outputPath
}
if ($sweepWrapper.PSObject.Properties['metadata']) {
  $result['metadata'] = $sweepWrapper.metadata
}

if ($SummaryPath) {
  $summaryDir = Split-Path -Parent $SummaryPath
  if ($summaryDir -and -not (Test-Path -LiteralPath $summaryDir -PathType Container)) {
    [void](New-Item -ItemType Directory -Path $summaryDir -Force)
  }
  $result | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $SummaryPath -Encoding utf8
}

return [pscustomobject]$result

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