#Requires -Version 7.0
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Resolve-IconEditorRepoRoot {
  param([string]$StartPath = (Get-Location).Path)
  try {
    $root = git -C $StartPath rev-parse --show-toplevel 2>$null
    if ($root) {
      return (Resolve-Path -LiteralPath $root.Trim()).Path
    }
  } catch {
    # fall back to supplied path
  }
  return (Resolve-Path -LiteralPath $StartPath).Path
}

function Resolve-IconEditorRoot {
  param([string]$RepoRoot)
  if (-not $RepoRoot) {
    $RepoRoot = Resolve-IconEditorRepoRoot
  }

  $candidates = @(
    (Join-Path -Path $RepoRoot -ChildPath 'vendor/labview-icon-editor'),
    (Join-Path -Path $RepoRoot -ChildPath 'vendor/icon-editor')
  )

  foreach ($candidate in $candidates) {
    if (Test-Path -LiteralPath $candidate -PathType Container) {
      return (Resolve-Path -LiteralPath $candidate).Path
    }
  }

  $expected = $candidates -join ' or '
  throw "Icon editor root not found under $expected. Vendor the labview-icon-editor repository first."
}

function Resolve-IconEditorVendorToolsModulePath {
  param([string]$RepoRoot)

  if (-not $RepoRoot) {
    $RepoRoot = Resolve-IconEditorRepoRoot
  } else {
    $RepoRoot = (Resolve-Path -LiteralPath $RepoRoot).Path
  }

  $candidates = @(
    (Join-Path -Path $RepoRoot -ChildPath 'tools/VendorTools.psm1'),
    (Join-Path -Path $RepoRoot -ChildPath 'src/tools/VendorTools.psm1')
  )

  foreach ($candidate in $candidates) {
    if (Test-Path -LiteralPath $candidate -PathType Leaf) {
      return (Resolve-Path -LiteralPath $candidate).Path
    }
  }

  throw "VendorTools module not found under 'tools' or 'src/tools'. Checked: $($candidates -join ', ')"
}

function Get-LvAddonAllowedHosts {
  $hosts = New-Object System.Collections.Generic.List[string]
  $hosts.Add('github.com')
  if ($env:ICONEDITORLAB_GITHUB_HOSTS) {
    $extra = $env:ICONEDITORLAB_GITHUB_HOSTS -split '[,; ]+' | Where-Object { $_ }
    foreach ($entry in $extra) { $hosts.Add($entry) }
  }
  return $hosts | Where-Object { $_ } | ForEach-Object { $_.Trim().ToLowerInvariant() } | Where-Object { $_ } | Select-Object -Unique
}

function Get-LvAddonContributorLogin {
  param(
    [string]$IconEditorRoot,
    [string]$RepoRoot
  )

  if ($env:ICONEDITORLAB_GITHUB_LOGIN) {
    $envLogin = $env:ICONEDITORLAB_GITHUB_LOGIN.Trim()
    if ($envLogin) { return $envLogin }
  }

  $ghDisabled = $env:ICONEDITORLAB_DISABLE_GH_LOGIN -eq '1'
  if (-not $ghDisabled) {
    $gh = Get-Command gh -ErrorAction SilentlyContinue
    if ($gh) {
      try {
        $statusOutput = & $gh.Path auth status 2>&1
        if ($LASTEXITCODE -eq 0 -and $statusOutput) {
          foreach ($line in $statusOutput) {
            if ($line -match 'Logged in to [^ ]+ as ([^ ()]+)') {
              return $Matches[1]
            }
          }
        }
      } catch {}

      try {
        $loginOutput = & $gh.Path api user --jq '.login' 2>$null
        if ($LASTEXITCODE -eq 0 -and $loginOutput) {
          $login = $loginOutput.Trim()
          if ($login) { return $login }
        }
      } catch {}
    }
  }

  $remoteUrls = New-Object System.Collections.Generic.List[string]
  $repoRoot = $null
  if ($RepoRoot) {
    try { $repoRoot = (Resolve-Path -LiteralPath $RepoRoot).Path }
    catch { $repoRoot = $RepoRoot }
  } else {
    try { $repoRoot = Resolve-IconEditorRepoRoot } catch {}
  }

  if ($repoRoot) {
    try {
      $repoRemote = git -C $repoRoot remote get-url origin 2>$null
      if ($repoRemote) { $remoteUrls.Add($repoRemote) | Out-Null }
    } catch {}
  }

  if ($IconEditorRoot) {
    try {
      $iconRemote = git -C $IconEditorRoot remote get-url origin 2>$null
      if ($iconRemote) { $remoteUrls.Add($iconRemote) | Out-Null }
    } catch {}
  }

  $parsedOwners = New-Object System.Collections.Generic.List[string]
  foreach ($remoteUrl in $remoteUrls) {
    $owner = Get-GitHubOwnerFromUrl -Url $remoteUrl
    if ($owner) { $parsedOwners.Add($owner) | Out-Null }
  }

  foreach ($owner in $parsedOwners) {
    if ($owner -and $owner.ToLowerInvariant() -ne 'contributor') {
      return $owner
    }
  }

  foreach ($owner in $parsedOwners) {
    if ($owner) { return $owner }
  }

  return 'ni'
}

function ConvertTo-LvAddonContributorOriginUrl {
  param(
    [string]$OriginUrl,
    [string]$ContributorLogin
  )

  if (-not $OriginUrl -or -not $ContributorLogin) { return $null }

  $trimmed = $OriginUrl.Trim()
  if (-not $trimmed) { return $null }

  $pathPart = $null
  $hasGitSuffix = $false

  $uri = $null
  if ([Uri]::TryCreate($trimmed, [UriKind]::Absolute, [ref]$uri)) {
    $pathPart = $uri.AbsolutePath.Trim('/')
  } elseif ($trimmed -match '^[^@]+@[^:]+:(?<path>.+)$') {
    $pathPart = $Matches['path']
  } elseif ($trimmed -match 'github\.com[:/](?<path>.+)$') {
    $pathPart = $Matches['path']
  }

  if (-not $pathPart) { return $null }

  if ($pathPart.EndsWith('.git')) {
    $pathPart = $pathPart.Substring(0, $pathPart.Length - 4)
    $hasGitSuffix = $true
  }

  $segments = $pathPart.Split('/', [System.StringSplitOptions]::RemoveEmptyEntries)
  if ($segments.Length -lt 2) { return $null }

  $repo = $segments[$segments.Length - 1]
  if (-not $repo) { return $null }

  $suffix = if ($hasGitSuffix) { '.git' } else { '' }
  return "https://github.com/$ContributorLogin/$repo$suffix"
}

function Get-GitHubOwnerFromUrl {
  param([string]$Url)

  if (-not $Url) { return $null }
  $candidate = $Url.Trim()
  if (-not $candidate) { return $null }

  $pathPart = $null
  $uri = $null
  if ([Uri]::TryCreate($candidate, [UriKind]::Absolute, [ref]$uri)) {
    if ($uri.Host -like '*github.com') {
      $pathPart = $uri.AbsolutePath.Trim('/')
    }
  } elseif ($candidate -match '^[^@]+@github\.com:(?<path>.+)$') {
    $pathPart = $Matches['path']
  } elseif ($candidate -match 'github\.com[:/](?<path>.+)$') {
    $pathPart = $Matches['path']
  }

  if (-not $pathPart) { return $null }
  $segments = $pathPart.Split('/', [System.StringSplitOptions]::RemoveEmptyEntries)
  if ($segments.Length -lt 1) { return $null }

  $owner = $segments[0]
  if ($owner.EndsWith('.git')) {
    $owner = $owner.Substring(0, $owner.Length - 4)
  }

  return $owner
}

function Write-LvAddonRootSummary {
  param(
    [Parameter(Mandatory)][string]$IconEditorRoot,
    [string]$Source = 'resolved',
    [bool]$Strict,
    $LVAddonAnalysis,
    [string]$RepoRoot
  )

  $modeText = if ($Strict) { 'Strict' } else { 'Relaxed' }
  $origin = $null
  $host = $null
  $isLvAddon = $null
  if ($LVAddonAnalysis) {
    if ($LVAddonAnalysis.PSObject.Properties['OriginUrl']) { $origin = $LVAddonAnalysis.OriginUrl }
    if ($LVAddonAnalysis.PSObject.Properties['OriginHost']) { $host = $LVAddonAnalysis.OriginHost }
    if ($LVAddonAnalysis.PSObject.Properties['IsLVAddonLab']) { $isLvAddon = $LVAddonAnalysis.IsLVAddonLab }
  }

  $contributorLogin = Get-LvAddonContributorLogin -IconEditorRoot $IconEditorRoot -RepoRoot $RepoRoot
  $forkOrigin = ConvertTo-LvAddonContributorOriginUrl -OriginUrl $origin -ContributorLogin $contributorLogin
  if ($forkOrigin) {
    $origin = $forkOrigin
    $host = 'github.com'
  }

  $message = "[devscript] LvAddonRoot=""$IconEditorRoot"" Source=$Source"
  if ($Strict) { $message += " Mode=$modeText" }
  if ($origin) { $message += " Origin=$origin" }
  if ($host) { $message += " Host=$host" }
  if ($null -ne $isLvAddon) { $message += " IsLvAddonLab=$isLvAddon" }
  if ($contributorLogin) { $message += " Contributor=$contributorLogin" }
  Write-Host $message -ForegroundColor Cyan

  return [pscustomobject]@{
    Path = $IconEditorRoot
    Source = $Source
    Mode = $modeText
    Origin = $origin
    Host = $host
    IsLVAddonLab = $isLvAddon
    Contributor = $contributorLogin
  }
}

function Get-IconEditorAmbientTelemetryContext {
  $scopes = @('Script','Global')
  foreach ($scope in $scopes) {
    try {
      $variable = Get-Variable -Name telemetryContext -Scope $scope -ErrorAction Stop
      if ($null -ne $variable.Value) {
        return $variable.Value
      }
    } catch {
      # Ignore and continue to next scope.
    }
  }
  return $null
}

function Set-LvAddonRootTelemetry {
  param(
    [psobject]$TelemetryContext,
    [psobject]$Summary
  )

  if (-not $TelemetryContext -or -not $TelemetryContext.Telemetry -or -not $Summary) {
    return
  }

  Set-IconEditorTelemetryValue -Telemetry $TelemetryContext.Telemetry -PropertyName 'lvAddonRootPath' -Value $Summary.Path
  Set-IconEditorTelemetryValue -Telemetry $TelemetryContext.Telemetry -PropertyName 'lvAddonRootSource' -Value $Summary.Source
  Set-IconEditorTelemetryValue -Telemetry $TelemetryContext.Telemetry -PropertyName 'lvAddonRootMode' -Value $Summary.Mode
  if ($Summary.PSObject.Properties['Origin']) {
    Set-IconEditorTelemetryValue -Telemetry $TelemetryContext.Telemetry -PropertyName 'lvAddonRootOrigin' -Value $Summary.Origin
  }
  if ($Summary.PSObject.Properties['Host']) {
    Set-IconEditorTelemetryValue -Telemetry $TelemetryContext.Telemetry -PropertyName 'lvAddonRootHost' -Value $Summary.Host
  }
  if ($Summary.PSObject.Properties['IsLVAddonLab']) {
    Set-IconEditorTelemetryValue -Telemetry $TelemetryContext.Telemetry -PropertyName 'lvAddonRootIsLVAddonLab' -Value $Summary.IsLVAddonLab
  }
  if ($Summary.PSObject.Properties['Contributor']) {
    Set-IconEditorTelemetryValue -Telemetry $TelemetryContext.Telemetry -PropertyName 'lvAddonRootContributor' -Value $Summary.Contributor
  }
}

function Set-IconEditorTelemetryValue {
  param(
    [psobject]$Telemetry,
    [Parameter(Mandatory)][string]$PropertyName,
    $Value
  )

  if (-not $Telemetry -or -not $PropertyName) { return }
  if ($null -eq $Value) { return }

  $existing = $Telemetry.PSObject.Properties[$PropertyName]
  if ($existing) {
    $existing.Value = $Value
  } else {
    $Telemetry | Add-Member -NotePropertyName $PropertyName -NotePropertyValue $Value -Force
  }
}

function Get-IconEditorDevModeStatePath {
  param([string]$RepoRoot)
  if (-not $RepoRoot) {
    $RepoRoot = Resolve-IconEditorRepoRoot
  }
  return Join-Path $RepoRoot 'tests' 'results' '_agent' 'icon-editor' 'dev-mode-state.json'
}

function Get-IconEditorDevModeState {
  param([string]$RepoRoot)
  $statePath = Get-IconEditorDevModeStatePath -RepoRoot $RepoRoot
  if (-not (Test-Path -LiteralPath $statePath -PathType Leaf)) {
    return [pscustomobject]@{
      Active    = $null
      UpdatedAt = $null
      Source    = $null
      Path      = $statePath
    }
  }

  try {
    $state = Get-Content -LiteralPath $statePath -Raw | ConvertFrom-Json -ErrorAction Stop
  } catch {
    throw "Failed to parse icon editor dev-mode state file at '$statePath': $($_.Exception.Message)"
  }

  return [pscustomobject]@{
    Active    = $state.active
    UpdatedAt = $state.updatedAt
    Source    = $state.source
    Path      = $statePath
  }
}

function Set-IconEditorDevModeState {
  param(
    [Parameter(Mandatory)][bool]$Active,
    [string]$RepoRoot,
    [string]$Source
  )

  if (-not $RepoRoot) {
    $RepoRoot = Resolve-IconEditorRepoRoot
  } else {
    $RepoRoot = (Resolve-Path -LiteralPath $RepoRoot).Path
  }

  $statePath = Get-IconEditorDevModeStatePath -RepoRoot $RepoRoot
  $stateDir = Split-Path -Parent $statePath
  if (-not (Test-Path -LiteralPath $stateDir -PathType Container)) {
    New-Item -ItemType Directory -Path $stateDir -Force | Out-Null
  }

  $payload = [ordered]@{
    schema    = 'icon-editor/dev-mode-state@v1'
    updatedAt = (Get-Date).ToString('o')
    active    = [bool]$Active
    source    = $Source
  }

  $payload | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath $statePath -Encoding UTF8
  return Get-IconEditorDevModeState -RepoRoot $RepoRoot
}

function Invoke-IconEditorRogueCheck {
  param(
    [string]$RepoRoot,
    [string]$Stage,
    [switch]$FailOnRogue,
    [switch]$AutoClose
  )

  try {
    if (-not $RepoRoot) {
      $RepoRoot = Resolve-IconEditorRepoRoot
    } else {
      $RepoRoot = (Resolve-Path -LiteralPath $RepoRoot).Path
    }
  } catch {
    $RepoRoot = Resolve-IconEditorRepoRoot
  }

  $detectScript = Join-Path $RepoRoot 'tools' 'Detect-RogueLV.ps1'
  if (-not (Test-Path -LiteralPath $detectScript -PathType Leaf)) {
    return $null
  }

  $resultsDir = Join-Path $RepoRoot 'tests' 'results'
  if (-not (Test-Path -LiteralPath $resultsDir -PathType Container)) {
    try { New-Item -ItemType Directory -Force -Path $resultsDir | Out-Null } catch {}
  }

  $outputDir = Join-Path $resultsDir '_agent' 'icon-editor' 'rogue-lv'
  if (-not (Test-Path -LiteralPath $outputDir -PathType Container)) {
    try { New-Item -ItemType Directory -Force -Path $outputDir | Out-Null } catch {}
  }

  $safeStage = if ($Stage) { ($Stage -replace '[^a-zA-Z0-9_-]','-') } else { 'icon-editor' }
  if ([string]::IsNullOrWhiteSpace($safeStage)) { $safeStage = 'icon-editor' }
  $timestamp = Get-Date -Format 'yyyyMMddTHHmmssfff'
  $outputPath = Join-Path $outputDir ("rogue-lv-{0}-{1}.json" -f $safeStage.ToLowerInvariant(), $timestamp)

  $pwshExe = 'pwsh'
  try {
    $cmd = Get-Command -Name 'pwsh' -ErrorAction Stop
    if ($cmd -and $cmd.Source) {
      $pwshExe = $cmd.Source
    } elseif ($cmd -and $cmd.Path) {
      $pwshExe = $cmd.Path
    }
  } catch {}

  $args = @(
    '-NoLogo',
    '-NoProfile',
    '-File', $detectScript,
    '-ResultsDir', $resultsDir,
    '-OutputPath', $outputPath,
    '-LookBackSeconds', '300',
    '-RetryCount', '2',
    '-RetryDelaySeconds', '5'
  )
  if ($env:GITHUB_STEP_SUMMARY) {
    $args += '-AppendToStepSummary'
  }
  if ($FailOnRogue) {
    $args += '-FailOnRogue'
  }

  $exitCode = 0
  try {
    & $pwshExe @args | Out-Null
    $exitCode = $LASTEXITCODE
  } catch {
    Write-Warning ("Detect-RogueLV failed during stage '{0}': {1}" -f $Stage, $_.Exception.Message)
    return $null
  }

  if ($exitCode -ne 0 -and $AutoClose) {
    $closeScript = Join-Path $RepoRoot 'tools' 'Close-LabVIEW.ps1'
    if (Test-Path -LiteralPath $closeScript -PathType Leaf) {
      try {
        & $pwshExe -NoLogo -NoProfile -File $closeScript | Out-Null
      } catch {
        Write-Warning ("Automatic Close-LabVIEW attempt failed: {0}" -f $_.Exception.Message)
      }
    }
    try {
      & $pwshExe @args | Out-Null
      $exitCode = $LASTEXITCODE
    } catch {
      Write-Warning ("Detect-RogueLV retry failed during stage '{0}': {1}" -f $Stage, $_.Exception.Message)
    }
  }

  if ($exitCode -ne 0) {
    $message = "Rogue LabVIEW/LVCompare processes detected (stage '{0}'). See {1} for details." -f $Stage, $outputPath
    if ($FailOnRogue) {
      throw $message
    } else {
      Write-Warning $message
    }
  }

  return [pscustomobject]@{
    Stage    = $Stage
    ExitCode = $exitCode
    Path     = $outputPath
  }
}

function Write-DevModeScriptLog {
  param(
    [string]$RepoRoot,
    [string]$StageLabel,
    [string]$ScriptPath,
    [string[]]$ArgumentList,
    [object[]]$OutputLines,
    [int]$ExitCode
  )

  if (-not $RepoRoot) {
    $RepoRoot = Resolve-IconEditorRepoRoot
  }
  $resultsDir = Join-Path $RepoRoot 'tests' 'results'
  if (-not (Test-Path -LiteralPath $resultsDir -PathType Container)) {
    New-Item -ItemType Directory -Force -Path $resultsDir | Out-Null
  }
  $logDir = Join-Path $resultsDir '_agent' 'icon-editor' 'dev-mode-script'
  if (-not (Test-Path -LiteralPath $logDir -PathType Container)) {
    New-Item -ItemType Directory -Force -Path $logDir | Out-Null
  }

  $label = if ($StageLabel) { $StageLabel } else { [IO.Path]::GetFileNameWithoutExtension($ScriptPath) }
  if (-not $label) { $label = 'dev-mode-script' }
  $label = ($label -replace '[^\w\.\-]', '-').ToLowerInvariant()
  $timestamp = Get-Date -Format 'yyyyMMddTHHmmssfff'
  $logPath = Join-Path $logDir ("{0}-{1}.log" -f $label, $timestamp)

  $header = @(
    "# Dev-mode Script Log",
    "timestamp: $(Get-Date -Format 'o')",
    "stage: $label",
    "script: $ScriptPath",
    ("args: {0}" -f ([string]::Join(' ', $ArgumentList))),
    ("exitCode: {0}" -f $ExitCode),
    ''
  )
  $header | Set-Content -LiteralPath $logPath -Encoding utf8
  if ($OutputLines -and $OutputLines.Count -gt 0) {
    foreach ($line in $OutputLines) {
      Add-Content -LiteralPath $logPath -Value $line -Encoding utf8
    }
  }
  return $logPath
}

function Invoke-IconEditorDevModeScript {
  param(
    [Parameter(Mandatory)][string]$ScriptPath,
    [string[]]$ArgumentList,
    [string]$RepoRoot,
    [string]$IconEditorRoot,
    [string]$StageLabel
  )

  $provider = $env:ICONEDITORLAB_PROVIDER
  if (-not $provider) { $provider = 'Real' }

  if (-not $RepoRoot) {
    $RepoRoot = Resolve-IconEditorRepoRoot
  } else {
    $RepoRoot = (Resolve-Path -LiteralPath $RepoRoot).Path
  }

  if (-not $IconEditorRoot) {
    $IconEditorRoot = Resolve-IconEditorRoot -RepoRoot $RepoRoot
  } else {
    $IconEditorRoot = (Resolve-Path -LiteralPath $IconEditorRoot).Path
  }

  if (-not (Test-Path -LiteralPath $ScriptPath -PathType Leaf)) {
    throw "Icon editor dev-mode script not found at '$ScriptPath'."
  }

  if ($provider -ieq 'XCliSim') {
    return Invoke-IconEditorDevModeScriptWithXCli -ScriptPath $ScriptPath -ArgumentList $ArgumentList -RepoRoot $RepoRoot -IconEditorRoot $IconEditorRoot -StageLabel $StageLabel
  }

  $vendorToolsModule = Resolve-IconEditorVendorToolsModulePath -RepoRoot $RepoRoot
  Import-Module $vendorToolsModule -Force
  $scriptDirectory = Split-Path -Parent $ScriptPath
  $previousLocation = Get-Location

  $pwshCmd = Get-Command pwsh -ErrorAction Stop
  $args = if ($ArgumentList -and $ArgumentList.Count -gt 0) { $ArgumentList } else { @('-IconEditorRoot', $IconEditorRoot) }

  Set-Location -LiteralPath $scriptDirectory
  try {
    $scriptOutput = @()
    & $pwshCmd.Source -NoLogo -NoProfile -File $ScriptPath @args 2>&1 |
      Tee-Object -Variable scriptOutput | Out-Host
    $exitCode = $LASTEXITCODE
    $null = Write-DevModeScriptLog -RepoRoot $RepoRoot -StageLabel $StageLabel -ScriptPath $ScriptPath -ArgumentList $args -OutputLines $scriptOutput -ExitCode $exitCode
    if ($exitCode -ne 0) {
      $capturedText = ($scriptOutput | Out-String).Trim()
      $message = "Dev-mode script '$ScriptPath' exited with code $exitCode."
      if (-not [string]::IsNullOrWhiteSpace($capturedText)) {
        $message += [Environment]::NewLine + $capturedText
      }
      throw $message
    }
  }
  finally {
    Set-Location -LiteralPath $previousLocation.Path
  }
}

  function Invoke-IconEditorDevModeScriptWithXCli {
  param(
    [Parameter(Mandatory)][string]$ScriptPath,
    [string[]]$ArgumentList,
    [string]$RepoRoot,
    [string]$IconEditorRoot,
    [string]$StageLabel
  )

  $xCliProject = Join-Path $RepoRoot 'tools/x-cli-develop/src/XCli/XCli.csproj'
  if (-not (Test-Path -LiteralPath $xCliProject -PathType Leaf)) {
    throw "XCli project not found at '$xCliProject'. Set ICONEDITORLAB_PROVIDER=Real or vendor x-cli under tools/x-cli-develop."
  }

  $args = if ($ArgumentList -and $ArgumentList.Count -gt 0) { $ArgumentList } else { @('-IconEditorRoot', $IconEditorRoot) }

  $lvVersion = $null
  $bitness = $null
  for ($i = 0; $i -lt $args.Count; $i++) {
    if ($args[$i] -eq '-MinimumSupportedLVVersion' -and ($i + 1) -lt $args.Count) {
      $lvVersion = [string]$args[$i + 1]
      $i++
      continue
    }
    if ($args[$i] -eq '-SupportedBitness' -and ($i + 1) -lt $args.Count) {
      $bitness = [string]$args[$i + 1]
      $i++
      continue
    }
  }

    $argsJson = ConvertTo-Json -Depth 5 -InputObject $args

    $operationTag = if ($StageLabel) { $StageLabel } else { [IO.Path]::GetFileNameWithoutExtension($ScriptPath) }
    $runId = $env:ICONEDITORLAB_RUN_ID
    if (-not $runId) {
      $runId = [guid]::NewGuid().ToString('n')
    }

  $simulationScenario = if ($env:ICONEDITORLAB_SIM_SCENARIO) { $env:ICONEDITORLAB_SIM_SCENARIO } else { 'happy-path' }
  $subcommand = if ($StageLabel -like 'enable-*') { 'labview-devmode-enable' } else { 'labview-devmode-disable' }

    $dotnetCmd = Get-Command dotnet -ErrorAction Stop
    $payloadArgs = @($subcommand)
    $payloadArgs += @('--lvaddon-root', $IconEditorRoot)
    if ($lvVersion) { $payloadArgs += @('--lv-version', $lvVersion) }
    if ($bitness)   { $payloadArgs += @('--bitness', $bitness) }
    $payloadArgs += @(
      '--script', $ScriptPath,
      '--args-json', $argsJson,
      '--scenario', $simulationScenario,
      '--operation', $operationTag,
      '--run-id', $runId
    )

  $xCliRoot = Join-Path $RepoRoot 'tools/x-cli-develop'
  $xCliLogRoot = Join-Path $xCliRoot 'temp_telemetry'
  $previousDevModeRoot = $env:XCLI_DEV_MODE_ROOT
  $env:XCLI_DEV_MODE_ROOT = $xCliLogRoot

  $scriptOutput = @()
  try {
    & $dotnetCmd.Source 'run' '--project' $xCliProject '--' @payloadArgs 2>&1 |
      Tee-Object -Variable scriptOutput | Out-Host
    $exitCode = $LASTEXITCODE
    $null = Write-DevModeScriptLog -RepoRoot $RepoRoot -StageLabel $StageLabel -ScriptPath $ScriptPath -ArgumentList $args -OutputLines $scriptOutput -ExitCode $exitCode

    if ($exitCode -ne 0) {
      $capturedText = ($scriptOutput | Out-String).Trim()
      $message = "Dev-mode simulation via x-cli for script '$ScriptPath' exited with code $exitCode."
      if (-not [string]::IsNullOrWhiteSpace($capturedText)) {
        $message += [Environment]::NewLine + $capturedText
      }
      throw $message
    }
  }
  finally {
    if ($null -ne $previousDevModeRoot) {
      $env:XCLI_DEV_MODE_ROOT = $previousDevModeRoot
    } else {
      Remove-Item Env:XCLI_DEV_MODE_ROOT -ErrorAction SilentlyContinue
    }
  }
}

function ConvertTo-IntList {
  param(
    $Values,
    [int[]]$DefaultValues
  )

  $result = @()
  if ($Values) {
    foreach ($value in $Values) {
      if ($null -eq $value) { continue }
      if ($value -is [array]) {
        foreach ($inner in $value) {
          if ($null -ne $inner) { $result += [int]$inner }
        }
      } else {
        $result += [int]$value
      }
    }
  }

  if ($result.Count -eq 0) {
    $result = @()
    foreach ($default in $DefaultValues) {
      $result += [int]$default
    }
  }

  return $result
}

function Get-DefaultIconEditorDevModeTargets {
  param([string]$Operation)

  $normalized = if ($Operation) { $Operation.ToLowerInvariant() } else { 'compare' }
  switch ($normalized) {
    'buildpackage' {
      return [pscustomobject]@{
        Versions = @(2023)
        Bitness  = @(32, 64)
      }
    }
    default {
      return [pscustomobject]@{
        Versions = @(2025)
        Bitness  = @(64)
      }
    }
  }
}

function Get-IconEditorDevModePolicyPath {
  param([string]$RepoRoot)

  if (-not $RepoRoot) {
    $RepoRoot = Resolve-IconEditorRepoRoot
  } else {
    $RepoRoot = (Resolve-Path -LiteralPath $RepoRoot).Path
  }

  if ($env:ICON_EDITOR_DEV_MODE_POLICY_PATH) {
    return (Resolve-Path -LiteralPath $env:ICON_EDITOR_DEV_MODE_POLICY_PATH).Path
  }

  if ($env:ICON_EDITOR_DEV_MODE_POLICY_PATH) {
    try {
      return (Resolve-Path -LiteralPath $env:ICON_EDITOR_DEV_MODE_POLICY_PATH).Path
    } catch {
      # fall through to defaults
    }
  }

  $candidates = @(
    (Join-Path -Path $RepoRoot -ChildPath 'src/configs/labview-icon-editor/dev-mode-targets.json'),
    (Join-Path -Path $RepoRoot -ChildPath 'src/configs/icon-editor/dev-mode-targets.json'),
    (Join-Path -Path $RepoRoot -ChildPath 'configs/labview-icon-editor/dev-mode-targets.json'),
    (Join-Path -Path $RepoRoot -ChildPath 'configs/icon-editor/dev-mode-targets.json')
  )

  foreach ($candidate in $candidates) {
    if (Test-Path -LiteralPath $candidate -PathType Leaf) {
      return (Resolve-Path -LiteralPath $candidate).Path
    }
  }

  return $candidates[0]
}

function Get-IconEditorDevModePolicy {
  param(
    [string]$RepoRoot,
    [switch]$ThrowIfMissing
  )

  $policyPath = Get-IconEditorDevModePolicyPath -RepoRoot $RepoRoot
  if (-not (Test-Path -LiteralPath $policyPath -PathType Leaf)) {
    if ($ThrowIfMissing.IsPresent) {
      throw "Icon editor dev-mode policy not found at '$policyPath'."
    }
    return $null
  }

  try {
    $policyContent = Get-Content -LiteralPath $policyPath -Raw -Encoding UTF8
    $policy = $policyContent | ConvertFrom-Json -AsHashtable -Depth 5
  } catch {
    throw "Failed to parse icon editor dev-mode policy '$policyPath': $($_.Exception.Message)"
  }

  if (-not ($policy -and $policy.ContainsKey('operations'))) {
    if ($ThrowIfMissing.IsPresent) {
      throw "Icon editor dev-mode policy at '$policyPath' is missing the 'operations' node."
    }
    return $null
  }

  return [pscustomobject]@{
    Path       = (Resolve-Path -LiteralPath $policyPath).Path
    Schema     = $policy['schema']
    Operations = $policy['operations']
  }
}

function Get-IconEditorDevModePolicyEntry {
  param(
    [Parameter(Mandatory)][string]$Operation,
    [string]$RepoRoot
  )

  $policy = Get-IconEditorDevModePolicy -RepoRoot $RepoRoot -ThrowIfMissing
  $operations = $policy.Operations
  if (-not $operations) {
    throw "Icon editor dev-mode policy at '$($policy.Path)' does not define any operations."
  }

  $entry = $null
  if ($operations.ContainsKey($Operation)) {
    $entry = $operations[$Operation]
    $operationKey = $Operation
  } else {
    foreach ($key in $operations.Keys) {
      if ($key -and ($key.ToString().ToLowerInvariant() -eq $Operation.ToLowerInvariant())) {
        $entry = $operations[$key]
        $operationKey = $key
        break
      }
    }
  }

  if (-not $entry) {
    throw "Operation '$Operation' is not defined in icon editor dev-mode policy '$($policy.Path)'."
  }

  $versions = @()
  if ($entry.versions) {
    foreach ($value in $entry.versions) {
      if ($null -ne $value) { $versions += [int]$value }
    }
  }

  $bitness = @()
  if ($entry.bitness) {
    foreach ($value in $entry.bitness) {
      if ($null -ne $value) { $bitness += [int]$value }
    }
  }

  return [pscustomobject]@{
    Operation = $operationKey
    Versions  = $versions
    Bitness   = $bitness
    Path      = $policy.Path
  }
}

function Test-IconEditorReliabilityOperation {
  param([string]$Operation)
  if (-not $Operation) { return $false }
  $normalized = $Operation.Trim()
  if ([string]::IsNullOrWhiteSpace($normalized)) { return $false }
  return ($normalized.ToLowerInvariant() -eq 'reliability')
}

function Enable-IconEditorDevelopmentMode {
  param(
    [string]$RepoRoot,
    [string]$IconEditorRoot,
    [int[]]$Versions,
    [int[]]$Bitness,
    [string]$Operation = 'Compare',
    [psobject]$TelemetryContext
  )

  if (-not $RepoRoot) {
    $RepoRoot = Resolve-IconEditorRepoRoot
  } else {
    $RepoRoot = (Resolve-Path -LiteralPath $RepoRoot).Path
  }

  if (-not $IconEditorRoot) {
    $IconEditorRoot = Resolve-IconEditorRoot -RepoRoot $RepoRoot
  } else {
    $IconEditorRoot = (Resolve-Path -LiteralPath $IconEditorRoot).Path
  }

  $vendorToolsModule = Resolve-IconEditorVendorToolsModulePath -RepoRoot $RepoRoot
  Import-Module $vendorToolsModule -Force
  $allowedHosts = Get-LvAddonAllowedHosts
  $enforceLvAddon = $false
  if ($env:GITHUB_ACTIONS -or $env:ICONEDITORLAB_ENFORCE_GITHUB_PATH -eq '1') {
    $enforceLvAddon = $true
  }
  $lvAddonAnalysis = Assert-LVAddonLabPath -Path $IconEditorRoot -Strict:$enforceLvAddon -AllowedHosts $allowedHosts
  $rootSource = if ($PSBoundParameters.ContainsKey('IconEditorRoot')) { 'parameter' } elseif ($env:ICONEDITOR_ROOT) { 'env' } else { 'resolved' }
  $iconEditorRootSummary = Write-LvAddonRootSummary -IconEditorRoot $IconEditorRoot -Source $rootSource -Strict:$enforceLvAddon -LVAddonAnalysis $lvAddonAnalysis -RepoRoot $RepoRoot
  $resolvedTelemetryContext = $null
  if ($PSBoundParameters.ContainsKey('TelemetryContext')) {
    $resolvedTelemetryContext = $TelemetryContext
  } else {
    $resolvedTelemetryContext = Get-IconEditorAmbientTelemetryContext
  }
  Set-LvAddonRootTelemetry -TelemetryContext $resolvedTelemetryContext -Summary $iconEditorRootSummary

  $preStage = if ($Operation) { "disable-{0}-pre" -f $Operation } else { 'disable-devmode-pre' }
  Invoke-IconEditorRogueCheck -RepoRoot $RepoRoot -Stage $preStage -FailOnRogue -AutoClose | Out-Null

  $actionsRoot = Join-Path $IconEditorRoot '.github' 'actions'
  $addTokenScript = Join-Path $actionsRoot 'add-token-to-labview' 'AddTokenToLabVIEW.ps1'
  $prepareScript  = Join-Path $actionsRoot 'prepare-labview-source' 'Prepare_LabVIEW_source.ps1'

  foreach ($required in @($addTokenScript, $prepareScript)) {
    if (-not (Test-Path -LiteralPath $required -PathType Leaf)) {
      throw "Icon editor dev-mode helper '$required' was not found."
    }
  }

  $targetsOverride = $null
  if (-not $PSBoundParameters.ContainsKey('Versions') -or -not $PSBoundParameters.ContainsKey('Bitness')) {
    try {
      $targetsOverride = Get-IconEditorDevModePolicyEntry -RepoRoot $RepoRoot -Operation $Operation
    } catch {
      $targetsOverride = $null
      if (-not $PSBoundParameters.ContainsKey('Versions') -and -not $PSBoundParameters.ContainsKey('Bitness')) {
        throw
      }
    }
  }

  $defaultTargets = Get-DefaultIconEditorDevModeTargets -Operation $Operation
  [array]$overrideVersions = @()
  [array]$overrideBitness  = @()
  if ($targetsOverride) {
    $overrideVersions = @($targetsOverride.Versions)
    $overrideBitness  = @($targetsOverride.Bitness)
  }
  [array]$effectiveVersions = if ($overrideVersions.Count -gt 0) { $overrideVersions } else { @($defaultTargets.Versions) }
  [array]$effectiveBitness  = if ($overrideBitness.Count -gt 0)  { $overrideBitness }  else { @($defaultTargets.Bitness) }

  [array]$versionList = ConvertTo-IntList -Values $Versions -DefaultValues $effectiveVersions
  [array]$bitnessList = ConvertTo-IntList -Values $Bitness -DefaultValues $effectiveBitness

  if ($versionList.Count -eq 0 -or $bitnessList.Count -eq 0) {
    throw "LabVIEW version/bitness selection resolved to an empty set for operation '$Operation'."
  }

  $strictReliability = Test-IconEditorReliabilityOperation -Operation $Operation
  if ($strictReliability) {
    Write-Host ("[dev-mode] Reliability policy active for operation '{0}'." -f $Operation) -ForegroundColor DarkGray
  }

  $pluginsPath = Join-Path $IconEditorRoot 'resource' 'plugins'
  if (Test-Path -LiteralPath $pluginsPath -PathType Container) {
    Get-ChildItem -LiteralPath $pluginsPath -Filter '*.lvlibp' -ErrorAction SilentlyContinue | Remove-Item -Force -ErrorAction SilentlyContinue
  }

  foreach ($versionValue in $versionList) {
    $versionText = [string]$versionValue
    foreach ($bitnessValue in $bitnessList) {
      $bitnessText = [string]$bitnessValue
      Invoke-LabVIEWPrelaunchGuard `
        -RepoRoot $RepoRoot `
        -Stage ("enable-addtoken-{0}-{1}" -f $versionText, $bitnessText) `
        -Versions @($versionValue) `
        -Bitness @($bitnessValue) `
        -IconEditorRoot $IconEditorRoot | Out-Null
      Invoke-IconEditorDevModeScript `
        -ScriptPath $addTokenScript `
        -ArgumentList @(
          '-MinimumSupportedLVVersion', $versionText,
          '-SupportedBitness',          $bitnessText,
          '-RelativePath',              $IconEditorRoot
        ) `
        -RepoRoot $RepoRoot `
        -IconEditorRoot $IconEditorRoot `
        -StageLabel ("enable-addtoken-{0}-{1}" -f $versionText, $bitnessText)

      Invoke-LabVIEWRogueSweep `
        -RepoRoot $RepoRoot `
        -Reason ("enable-addtoken-{0}-{1}" -f $versionText, $bitnessText) `
        -RequireClean:$strictReliability | Out-Null

      Invoke-LabVIEWPrelaunchGuard `
        -RepoRoot $RepoRoot `
        -Stage ("enable-prepare-{0}-{1}" -f $versionText, $bitnessText) `
        -Versions @($versionValue) `
        -Bitness @($bitnessValue) `
        -IconEditorRoot $IconEditorRoot | Out-Null
      Invoke-IconEditorDevModeScript `
        -ScriptPath $prepareScript `
        -ArgumentList @(
          '-MinimumSupportedLVVersion', $versionText,
          '-SupportedBitness',          $bitnessText,
          '-RelativePath',              $IconEditorRoot,
          '-LabVIEW_Project',         'lv_icon_editor',
          '-Build_Spec',              'Editor Packed Library'
        ) `
        -RepoRoot $RepoRoot `
        -IconEditorRoot $IconEditorRoot `
        -StageLabel ("enable-prepare-{0}-{1}" -f $versionText, $bitnessText)

      Invoke-LabVIEWRogueSweep `
        -RepoRoot $RepoRoot `
        -Reason ("enable-prepare-{0}-{1}" -f $versionText, $bitnessText) `
        -RequireClean:$strictReliability | Out-Null

      # Keep LabVIEW running after preparing source; closing is handled elsewhere when needed.
    }
  }

  $verification = Assert-IconEditorDevModeTokenState -RepoRoot $RepoRoot -IconEditorRoot $IconEditorRoot -Versions $versionList -Bitness $bitnessList -ExpectedActive $true
  $state = Set-IconEditorDevModeState -RepoRoot $RepoRoot -Active $true -Source ("Enable-IconEditorDevelopmentMode:{0}" -f $Operation)
  if ($verification) {
    $state | Add-Member -NotePropertyName Verification -NotePropertyValue $verification -Force
  }
  Close-IconEditorLabVIEW `
    -RepoRoot $RepoRoot `
    -IconEditorRoot $IconEditorRoot `
    -Versions $versionList `
    -Bitness $bitnessList `
    -FailOnRogue:$strictReliability
  Invoke-LabVIEWRogueSweep `
    -RepoRoot $RepoRoot `
    -Reason 'enable-close' `
    -RequireClean:$strictReliability | Out-Null
  $postStage = if ($Operation) { "devmode-{0}-post" -f $Operation } else { 'devmode-post' }
  Invoke-IconEditorRogueCheck -RepoRoot $RepoRoot -Stage $postStage -AutoClose -FailOnRogue:$strictReliability | Out-Null
  return $state
}

function Disable-IconEditorDevelopmentMode {
  param(
    [string]$RepoRoot,
    [string]$IconEditorRoot,
    [int[]]$Versions,
    [int[]]$Bitness,
    [string]$Operation = 'Compare',
    [psobject]$TelemetryContext
  )

  if (-not $RepoRoot) {
    $RepoRoot = Resolve-IconEditorRepoRoot
  } else {
    $RepoRoot = (Resolve-Path -LiteralPath $RepoRoot).Path
  }

  if (-not $IconEditorRoot) {
    $IconEditorRoot = Resolve-IconEditorRoot -RepoRoot $RepoRoot
  } else {
    $IconEditorRoot = (Resolve-Path -LiteralPath $IconEditorRoot).Path
  }

  $vendorToolsModule = Resolve-IconEditorVendorToolsModulePath -RepoRoot $RepoRoot
  Import-Module $vendorToolsModule -Force
  $allowedHosts = Get-LvAddonAllowedHosts
  $enforceLvAddon = $false
  if ($env:GITHUB_ACTIONS -or $env:ICONEDITORLAB_ENFORCE_GITHUB_PATH -eq '1') {
    $enforceLvAddon = $true
  }
  $lvAddonAnalysis = Assert-LVAddonLabPath -Path $IconEditorRoot -Strict:$enforceLvAddon -AllowedHosts $allowedHosts
  $rootSource = if ($PSBoundParameters.ContainsKey('IconEditorRoot')) { 'parameter' } elseif ($env:ICONEDITOR_ROOT) { 'env' } else { 'resolved' }
  $iconEditorRootSummary = Write-LvAddonRootSummary -IconEditorRoot $IconEditorRoot -Source $rootSource -Strict:$enforceLvAddon -LVAddonAnalysis $lvAddonAnalysis -RepoRoot $RepoRoot
  $resolvedTelemetryContext = $null
  if ($PSBoundParameters.ContainsKey('TelemetryContext')) {
    $resolvedTelemetryContext = $TelemetryContext
  } else {
    $resolvedTelemetryContext = Get-IconEditorAmbientTelemetryContext
  }
  Set-LvAddonRootTelemetry -TelemetryContext $resolvedTelemetryContext -Summary $iconEditorRootSummary

  $actionsRoot = Join-Path $IconEditorRoot '.github' 'actions'
  $restoreScript = Join-Path $actionsRoot 'restore-setup-lv-source' 'RestoreSetupLVSource.ps1'
  $closeScript   = Join-Path $actionsRoot 'close-labview' 'Close_LabVIEW.ps1'
  $resetHelper   = Join-Path $RepoRoot 'tools' 'icon-editor' 'Reset-IconEditorWorkspace.ps1'

  foreach ($required in @($restoreScript, $closeScript, $resetHelper)) {
    if (-not (Test-Path -LiteralPath $required -PathType Leaf)) {
      throw "Icon editor dev-mode helper '$required' was not found."
    }
  }

  $targetsOverride = $null
  if (-not $PSBoundParameters.ContainsKey('Versions') -or -not $PSBoundParameters.ContainsKey('Bitness')) {
    try {
      $targetsOverride = Get-IconEditorDevModePolicyEntry -RepoRoot $RepoRoot -Operation $Operation
    } catch {
      $targetsOverride = $null
    }
  }

  $defaultTargets = Get-DefaultIconEditorDevModeTargets -Operation $Operation
  [array]$overrideVersions = @()
  [array]$overrideBitness  = @()
  if ($targetsOverride) {
    $overrideVersions = @($targetsOverride.Versions)
    $overrideBitness  = @($targetsOverride.Bitness)
  }
  [array]$effectiveVersions = if ($overrideVersions.Count -gt 0) { $overrideVersions } else { @($defaultTargets.Versions) }
  [array]$effectiveBitness  = if ($overrideBitness.Count -gt 0)  { $overrideBitness }  else { @($defaultTargets.Bitness) }

  [array]$versionsList = ConvertTo-IntList -Values $Versions -DefaultValues $effectiveVersions
  [array]$bitnessList  = ConvertTo-IntList -Values $Bitness -DefaultValues $effectiveBitness

  if ($versionsList.Count -eq 0) {
    $versionsList = @($effectiveVersions | ForEach-Object { [int]$_ })
  }
  if ($bitnessList.Count -eq 0) {
    $bitnessList = @($effectiveBitness | ForEach-Object { [int]$_ })
  }

  if ($versionsList.Count -eq 0 -or $bitnessList.Count -eq 0) {
    throw "LabVIEW version/bitness selection resolved to an empty set for operation '$Operation'."
  }

  $strictReliability = Test-IconEditorReliabilityOperation -Operation $Operation
  if ($strictReliability) {
    Write-Host ("[dev-mode] Reliability policy active for disable operation '{0}'." -f $Operation) -ForegroundColor DarkGray
  }

  try {
    & $resetHelper `
      -RepoRoot $RepoRoot `
      -IconEditorRoot $IconEditorRoot `
      -Versions $versionsList `
      -Bitness $bitnessList | Out-Null
  } catch {
    throw "Reset-IconEditorWorkspace.ps1 failed: $($_.Exception.Message)"
  }

  $verification = Assert-IconEditorDevModeTokenState -RepoRoot $RepoRoot -IconEditorRoot $IconEditorRoot -Versions $versionsList -Bitness $bitnessList -ExpectedActive $false
  $state = Set-IconEditorDevModeState -RepoRoot $RepoRoot -Active $false -Source ("Disable-IconEditorDevelopmentMode:{0}" -f $Operation)
  if ($verification) {
    $state | Add-Member -NotePropertyName Verification -NotePropertyValue $verification -Force
  }
  Close-IconEditorLabVIEW `
    -RepoRoot $RepoRoot `
    -IconEditorRoot $IconEditorRoot `
    -Versions $versionsList `
    -Bitness $bitnessList `
    -FailOnRogue:$strictReliability
  Invoke-LabVIEWRogueSweep `
    -RepoRoot $RepoRoot `
    -Reason 'disable-close' `
    -RequireClean:$strictReliability | Out-Null
  $postStage = if ($Operation) { "disable-{0}-post" -f $Operation } else { 'disable-devmode-post' }
  Invoke-IconEditorRogueCheck -RepoRoot $RepoRoot -Stage $postStage -AutoClose -FailOnRogue:$strictReliability | Out-Null
  return $state
}

function Get-IconEditorDevModeLabVIEWTargets {
  param(
    [string]$RepoRoot,
    [string]$IconEditorRoot,
    [int[]]$Versions = @(2023),
    [int[]]$Bitness = @(32, 64)
  )

  if (-not $RepoRoot) {
    $RepoRoot = Resolve-IconEditorRepoRoot
  } else {
    $RepoRoot = (Resolve-Path -LiteralPath $RepoRoot).Path
  }

  if (-not $IconEditorRoot) {
    $IconEditorRoot = Resolve-IconEditorRoot -RepoRoot $RepoRoot
  } else {
    $IconEditorRoot = (Resolve-Path -LiteralPath $IconEditorRoot).Path
  }

  $vendorToolsModule = Resolve-IconEditorVendorToolsModulePath -RepoRoot $RepoRoot
  Import-Module $vendorToolsModule -Force

  $versionList = ConvertTo-IntList -Values $Versions -DefaultValues @(2023)
  $bitnessList = ConvertTo-IntList -Values $Bitness -DefaultValues @(32,64)

  $targets = New-Object System.Collections.Generic.List[object]
  foreach ($version in $versionList) {
    foreach ($bit in $bitnessList) {
      $exePath = Find-LabVIEWVersionExePath -Version $version -Bitness $bit
      $iniPath = $null
      $present = $false
      if ($exePath) {
        $present = $true
        $iniPath = Get-LabVIEWIniPath -LabVIEWExePath $exePath
      }
      $targets.Add([pscustomobject]@{
        Version = $version
        Bitness = $bit
        LabVIEWExePath = $exePath
        LabVIEWIniPath = $iniPath
        Present = [bool]$present
        IconEditorRoot = $IconEditorRoot
      }) | Out-Null
    }
  }

  return $targets.ToArray()
}

function Assert-IconEditorDevModeTokenState {
  param(
    [string]$RepoRoot,
    [string]$IconEditorRoot,
    [int[]]$Versions,
    [int[]]$Bitness,
    [bool]$ExpectedActive
  )

  $verification = Test-IconEditorDevelopmentMode -RepoRoot $RepoRoot -IconEditorRoot $IconEditorRoot -Versions $Versions -Bitness $Bitness
  if (-not $verification) { return $null }

  $presentEntries = @($verification.Entries | Where-Object { $_.Present -and $_.LabVIEWIniPath })
  if (-not $presentEntries -or $presentEntries.Count -eq 0) {
    Write-Verbose "Icon editor dev-mode verification: no LabVIEW targets present; skipping token check."
    return $verification
  }

  $violations = if ($ExpectedActive) {
    @($presentEntries | Where-Object { -not $_.ContainsIconEditorPath })
  } else {
    @($presentEntries | Where-Object { $_.ContainsIconEditorPath })
  }

  if ($violations -and $violations.Count -gt 0) {
    $expectation = if ($ExpectedActive) { 'include' } else { 'exclude' }
    $details = $violations | ForEach-Object {
      $iniPath = if ($_.LabVIEWIniPath) { $_.LabVIEWIniPath } else { '[ini path unavailable]' }
      $status = if ($_.ContainsIconEditorPath) { 'contains icon-editor path' } else { 'missing icon-editor path' }
      "LabVIEW {0} ({1}-bit) - {2} (ini: {3})" -f $_.Version, $_.Bitness, $status, $iniPath
    }
    $joined = [string]::Join('; ', $details)
    throw "Icon editor dev-mode verification failed: expected LabVIEW to $expectation the icon-editor path. Violations: $joined"
  }

  return $verification
}

function Test-IconEditorDevelopmentMode {
  param(
    [string]$RepoRoot,
    [string]$IconEditorRoot,
    [int[]]$Versions = @(2023),
    [int[]]$Bitness = @(32, 64)
  )

  if (-not $RepoRoot) {
    $RepoRoot = Resolve-IconEditorRepoRoot
  } else {
    $RepoRoot = (Resolve-Path -LiteralPath $RepoRoot).Path
  }

  if (-not $IconEditorRoot) {
    $IconEditorRoot = Resolve-IconEditorRoot -RepoRoot $RepoRoot
  } else {
    $IconEditorRoot = (Resolve-Path -LiteralPath $IconEditorRoot).Path
  }

  $iconEditorRootLower = $IconEditorRoot.ToLowerInvariant().TrimEnd('\')
  $targets = Get-IconEditorDevModeLabVIEWTargets -RepoRoot $RepoRoot -IconEditorRoot $IconEditorRoot -Versions $Versions -Bitness $Bitness
  $results = New-Object System.Collections.Generic.List[object]

  foreach ($target in $targets) {
    $tokenValue = $null
    $containsIconEditor = $false
    if ($target.Present -and $target.LabVIEWIniPath -and (Test-Path -LiteralPath $target.LabVIEWIniPath -PathType Leaf)) {
      try {
        $tokenValue = Get-LabVIEWIniValue -Key 'LocalHost.LibraryPaths' -LabVIEWExePath $target.LabVIEWExePath -LabVIEWIniPath $target.LabVIEWIniPath
      } catch {
        $tokenValue = $null
      }
      if ($tokenValue) {
        $normalizedValue = ($tokenValue -replace '"', '').Split(';') | ForEach-Object {
          $_.Trim().TrimEnd('\').ToLowerInvariant()
        }
        foreach ($entry in $normalizedValue) {
          if ($entry -eq '') { continue }
          if ($entry -eq $iconEditorRootLower -or $entry.StartsWith($iconEditorRootLower)) {
            $containsIconEditor = $true
            break
          }
        }
      }
    }

    $results.Add([pscustomobject]@{
      Version = $target.Version
      Bitness = $target.Bitness
      LabVIEWExePath = $target.LabVIEWExePath
      LabVIEWIniPath = $target.LabVIEWIniPath
      Present = $target.Present
      TokenValue = $tokenValue
      ContainsIconEditorPath = $containsIconEditor
    }) | Out-Null
  }

  $presentEntries = @($results | Where-Object { $_.Present })
  $active = $null
  if ($presentEntries.Count -gt 0) {
    $active = $presentEntries | ForEach-Object { $_.ContainsIconEditorPath } | Where-Object { $_ } | Measure-Object | Select-Object -ExpandProperty Count
    $active = ($active -eq $presentEntries.Count)
  }

  return [pscustomobject]@{
    RepoRoot = $RepoRoot
    IconEditorRoot = $IconEditorRoot
    Active = $active
    Entries = $results
  }
}

function Close-IconEditorLabVIEW {
  param(
    [string]$RepoRoot,
    [string]$IconEditorRoot,
    [int[]]$Versions,
    [int[]]$Bitness,
    [int]$WaitTimeoutSeconds = 30,
    [switch]$FailOnRogue
  )

  $skipWait = $false
  $skipEnv = $env:ICON_EDITOR_SKIP_WAIT_FOR_LABVIEW_EXIT
  if ($skipEnv) {
    $value = $skipEnv.ToString().ToLowerInvariant()
    if ($value -in @('1','true','yes','on')) {
      $skipWait = $true
    }
  }

  if (-not $RepoRoot) {
    $RepoRoot = Resolve-IconEditorRepoRoot
  } else {
    $RepoRoot = (Resolve-Path -LiteralPath $RepoRoot).Path
  }

  if (-not $IconEditorRoot) {
    $IconEditorRoot = Resolve-IconEditorRoot -RepoRoot $RepoRoot
  } else {
    $IconEditorRoot = (Resolve-Path -LiteralPath $IconEditorRoot).Path
  }

  $actionsRoot = Join-Path $IconEditorRoot '.github' 'actions'
  $closeScript = Join-Path $actionsRoot 'close-labview' 'Close_LabVIEW.ps1'
  if (-not (Test-Path -LiteralPath $closeScript -PathType Leaf)) {
    Write-Verbose "Close-IconEditorLabVIEW: close script not found at '$closeScript'; skipping graceful shutdown."
    return
  }

  $vendorToolsModule = Resolve-IconEditorVendorToolsModulePath -RepoRoot $RepoRoot
  Import-Module $vendorToolsModule -Force

  $rawVersions = ConvertTo-IntList -Values $Versions -DefaultValues @(2023)
  $rawBitness  = ConvertTo-IntList -Values $Bitness -DefaultValues @(32, 64)
  $versionList = if ($rawVersions) { @($rawVersions) } else { @() }
  $bitnessList = if ($rawBitness) { @($rawBitness) } else { @() }
  $expectedExePaths = New-Object System.Collections.Generic.List[string]

  foreach ($version in $versionList) {
    foreach ($bit in $bitnessList) {
      $attemptArgs = @(
        '-MinimumSupportedLVVersion', [string]$version,
        '-SupportedBitness',          [string]$bit
      )

      $closeSucceeded = $false
      for ($attempt = 1; $attempt -le 2 -and -not $closeSucceeded; $attempt++) {
        try {
          Invoke-IconEditorDevModeScript `
            -ScriptPath $closeScript `
            -ArgumentList $attemptArgs `
            -RepoRoot $RepoRoot `
            -IconEditorRoot $IconEditorRoot
          $closeSucceeded = $true
        } catch {
          $message = $_.Exception.Message
          $transient = $message -match 'Timed out waiting for app to connect to g-cli' -or $message -match 'Failed to close LabVIEW with exit code 1'
          if ($transient -and $attempt -lt 2) {
            Write-Warning ("Close-IconEditorLabVIEW: retrying after g-cli timeout when closing LabVIEW {0} ({1}-bit)." -f $version, $bit)
            Start-Sleep -Seconds 2
            continue
          }
          if ($transient) {
            Write-Warning ("Close-IconEditorLabVIEW: ignoring repeated g-cli timeout when closing LabVIEW {0} ({1}-bit): {2}" -f $version, $bit, $message)
            $closeSucceeded = $true
          } else {
            throw
          }
        }
      }

      $exePath = Find-LabVIEWVersionExePath -Version $version -Bitness $bit
      if ($exePath) {
        $resolvedExe = $null
        try {
          $resolvedExe = (Resolve-Path -LiteralPath $exePath).Path.ToLowerInvariant()
        } catch {
          $resolvedExe = $exePath.ToLowerInvariant()
        }
        if ($resolvedExe -and -not $expectedExePaths.Contains($resolvedExe)) {
          [void]$expectedExePaths.Add($resolvedExe)
        }
      }
    }
  }

  $exeArray = if ($expectedExePaths.Count -gt 0) { $expectedExePaths.ToArray() } else { @() }

  if ($skipWait) {
    Write-Verbose "Close-IconEditorLabVIEW: skipping wait for LabVIEW exit (ICON_EDITOR_SKIP_WAIT_FOR_LABVIEW_EXIT=$skipEnv)."
    return
  }

$settleResult = Wait-IconEditorLabVIEWSettle -ExeCandidates $exeArray -TimeoutSeconds $WaitTimeoutSeconds -Stage 'close-labview'
  if (-not $settleResult.Succeeded) {
    throw "Timed out waiting for LabVIEW to exit after close sequence."
  }

  Invoke-IconEditorRogueCheck -RepoRoot $RepoRoot -Stage 'close-labview' -AutoClose -FailOnRogue:$FailOnRogue | Out-Null
}

function Wait-LabVIEWProcessExit {
  param(
    [string[]]$ExeCandidates,
    [int]$TimeoutSeconds = 30
  )

  $deadline = (Get-Date).AddSeconds($TimeoutSeconds)
  $normalizedCandidates = @()
  if ($ExeCandidates) {
    $normalizedCandidates = $ExeCandidates | Where-Object { $_ } | ForEach-Object { $_.ToLowerInvariant() }
  }

  while ($true) {
    $running = @(Get-Process LabVIEW -ErrorAction SilentlyContinue)
    if (-not $running -or $running.Count -eq 0) {
      return $true
    }

    if ($normalizedCandidates.Length -gt 0) {
      $matching = @()
      foreach ($proc in $running) {
        $procPath = $null
        try {
          $procPath = $proc.Path
        } catch {
          $procPath = $null
        }
        if (-not $procPath) {
          $matching += $proc
          continue
        }
        $procNormalized = $procPath.ToLowerInvariant()
        if ($normalizedCandidates -contains $procNormalized) {
          $matching += $proc
        }
      }
      if ($matching.Count -eq 0) {
        return $true
      }
    } else {
      if ($running.Count -eq 0) {
        return $true
      }
    }

    if ((Get-Date) -ge $deadline) {
      return $false
    }

    Start-Sleep -Milliseconds 500
  }
}

function Wait-IconEditorLabVIEWSettle {
  param(
    [string[]]$ExeCandidates,
    [int]$TimeoutSeconds = 30,
    [int]$ExtraSleepSeconds = 2,
    [string]$Stage = 'labview-settle'
  )

  $result = [ordered]@{
    stage = $Stage
    succeeded = $false
    durationSeconds = 0
    timeoutSeconds = $TimeoutSeconds
    extraSleepSeconds = $ExtraSleepSeconds
  }

  $watch = [System.Diagnostics.Stopwatch]::StartNew()
  $ok = Wait-LabVIEWProcessExit -ExeCandidates $ExeCandidates -TimeoutSeconds $TimeoutSeconds
  if (-not $ok) {
    $result.error = "Timed out waiting for LabVIEW processes to exit."
    $running = @(Get-Process LabVIEW -ErrorAction SilentlyContinue)
    if ($running -and $running.Count -gt 0) {
      $result.runningPids = ($running | Select-Object -ExpandProperty Id)
      Write-Warning ("{0}: still saw LabVIEW PIDs {1} after {2}s." -f $Stage, ($result.runningPids -join ','), $TimeoutSeconds)
    }
  } else {
    if ($ExtraSleepSeconds -gt 0) {
      Start-Sleep -Seconds $ExtraSleepSeconds
    }
    $result.succeeded = $true
  }

  $watch.Stop()
  $result.durationSeconds = [Math]::Round($watch.Elapsed.TotalSeconds, 2)
  $event = [pscustomobject]$result
  $listVar = Get-Variable -Name IconEditorLabVIEWSettleEvents -Scope Script -ErrorAction SilentlyContinue
  if (-not $listVar -or -not $listVar.Value) {
    $script:IconEditorLabVIEWSettleEvents = New-Object System.Collections.Generic.List[object]
    $listVar = Get-Variable -Name IconEditorLabVIEWSettleEvents -Scope Script -ErrorAction SilentlyContinue
  }
  if ($listVar -and $listVar.Value) {
    $listVar.Value.Add($event) | Out-Null
  }
  return $event
}

function Invoke-LabVIEWPrelaunchGuard {
  param(
    [string]$RepoRoot,
    [string]$Stage = 'labview-prelaunch',
    [int]$SettleTimeoutSeconds = 10,
    [int]$SettleSleepSeconds = 1,
    [int[]]$Versions,
    [int[]]$Bitness,
    [string]$IconEditorRoot
  )

  if (-not $RepoRoot) {
    $RepoRoot = Resolve-IconEditorRepoRoot
  } else {
    $RepoRoot = (Resolve-Path -LiteralPath $RepoRoot).Path
  }
  $resolvedIconEditorRoot = $IconEditorRoot
  if (-not $resolvedIconEditorRoot) {
    try {
      $resolvedIconEditorRoot = Resolve-IconEditorRoot -RepoRoot $RepoRoot
    } catch {
      $resolvedIconEditorRoot = $null
    }
  }

  Invoke-IconEditorRogueCheck -RepoRoot $RepoRoot -Stage $Stage -AutoClose | Out-Null
  $settleResult = Wait-IconEditorLabVIEWSettle -ExeCandidates @() -TimeoutSeconds $SettleTimeoutSeconds -ExtraSleepSeconds $SettleSleepSeconds -Stage ("{0}-settle" -f $Stage)
  if (-not $settleResult.Succeeded) {
    Write-Warning ("{0}: initial settle failed, attempting rogue cleanup and retry." -f $Stage)
    try {
      Invoke-IconEditorRogueCheck -RepoRoot $RepoRoot -Stage ("{0}-rogue-retry" -f $Stage) -AutoClose | Out-Null
    } catch {
      Write-Warning ("{0}: rogue cleanup retry encountered an error: {1}" -f $Stage, $_.Exception.Message)
    }
    if ($Versions -and $Bitness -and $resolvedIconEditorRoot) {
      try {
        Close-IconEditorLabVIEW -RepoRoot $RepoRoot -IconEditorRoot $resolvedIconEditorRoot -Versions $Versions -Bitness $Bitness | Out-Null
      } catch {
        Write-Warning ("{0}: Close-LabVIEW fallback reported: {1}" -f $Stage, $_.Exception.Message)
      }
    }
    $terminated = @()
    $pidsToKill = @()
    if ($settleResult.PSObject.Properties['runningPids'] -and $settleResult.runningPids) {
      $pidsToKill += $settleResult.runningPids
    }
    try {
      $liveLabVIEW = @(Get-Process -Name 'LabVIEW' -ErrorAction SilentlyContinue)
      if ($liveLabVIEW) {
        $pidsToKill += ($liveLabVIEW | Select-Object -ExpandProperty Id)
      }
    } catch {}
    $pidsToKill = $pidsToKill | Sort-Object -Unique
    foreach ($pid in $pidsToKill) {
      try {
        Stop-Process -Id $pid -Force -ErrorAction Stop
        $terminated += $pid
      } catch {
        Write-Warning ("{0}: failed to terminate LabVIEW PID {1}: {2}" -f $Stage, $pid, $_.Exception.Message)
      }
    }
    if ($terminated.Count -gt 0) {
      Write-Warning ("{0}: forcibly terminated LabVIEW PIDs {1} prior to settle retry." -f $Stage, ($terminated -join ','))
    }
    $retryTimeout = [Math]::Max($SettleTimeoutSeconds * 2, $SettleTimeoutSeconds + 10)
    $settleResult = Wait-IconEditorLabVIEWSettle -ExeCandidates @() -TimeoutSeconds $retryTimeout -ExtraSleepSeconds $SettleSleepSeconds -Stage ("{0}-settle-retry" -f $Stage)
    if (-not $settleResult.Succeeded) {
      throw "Pre-launch settle failed for stage '$Stage'."
    }
  }
  return $settleResult
}

function Get-IconEditorLabVIEWSettleEvents {
  param([switch]$Clear = $true)
  $listVar = Get-Variable -Name IconEditorLabVIEWSettleEvents -Scope Script -ErrorAction SilentlyContinue
  if (-not $listVar -or -not $listVar.Value) { return @() }
  $buffer = $listVar.Value
  $events = $buffer.ToArray()
  if ($Clear) { $buffer.Clear() }
  return $events
}

function Get-IconEditorSettleSummary {
  param([object[]]$Events)

  if (-not $Events -or $Events.Count -eq 0) { return $null }
  $flatEvents = @()
  foreach ($evt in $Events) {
    if (-not $evt) { continue }
    if ($evt -is [System.Array]) {
      foreach ($inner in $evt) {
        if ($inner) { $flatEvents += $inner }
      }
    } else {
      $flatEvents += $evt
    }
  }

  if ($flatEvents.Count -eq 0) { return $null }

  $succeeded = @($flatEvents | Where-Object { $_.Succeeded })
  $failed    = @($flatEvents | Where-Object { -not $_.Succeeded })
  $duration  = 0
  foreach ($evt in $flatEvents) {
    if ($evt.PSObject.Properties['durationSeconds']) {
      $duration += [double]$evt.durationSeconds
    }
  }

  $summary = [ordered]@{
    totalEvents          = $flatEvents.Count
    succeededEvents      = $succeeded.Count
    failedEvents         = $failed.Count
    totalDurationSeconds = [Math]::Round($duration, 2)
  }

  if ($failed.Count -gt 0) {
    $summary.failedStages = ($failed | ForEach-Object { $_.stage } | Where-Object { $_ } | Sort-Object -Unique)
    $summary.failedErrors = ($failed | ForEach-Object { $_.error } | Where-Object { $_ } | Sort-Object -Unique)
  }

  return $summary
}

  function Get-IconEditorVerificationSummary {
  param([psobject]$Verification)

  if (-not $Verification) { return $null }

  $entries = @()
  if ($Verification.PSObject.Properties['Entries']) {
    foreach ($entry in $Verification.Entries) {
      if ($entry) { $entries += $entry }
    }
  }

  $presentEntries = @($entries | Where-Object { $_.Present })
  $withIconEditor = @($presentEntries | Where-Object { $_.ContainsIconEditorPath })

  $summary = [ordered]@{
    presentCount            = $presentEntries.Count
    containsIconEditorCount = $withIconEditor.Count
    active                  = $Verification.Active
  }

  if ($presentEntries.Count -gt 0 -and $withIconEditor.Count -lt $presentEntries.Count) {
    $summary.missingTargets = $presentEntries |
      Where-Object { -not $_.ContainsIconEditorPath } |
      ForEach-Object {
        [ordered]@{
          version = $_.Version
          bitness = $_.Bitness
          labviewIniPath = $_.LabVIEWIniPath
        }
      }
  }

  return $summary
  }

  function Get-IconEditorDevModeOutcomeStatus {
    [CmdletBinding()]
    param(
      [Parameter(Mandatory)][string]$ErrorMessage
    )

    $defaultStatus = 'failed'
    if (-not $ErrorMessage) {
      return $defaultStatus
    }

    # Prefer explicit x-cli simulation hints when present.
    if ($ErrorMessage -match 'Dev-mode simulation via x-cli' -and $ErrorMessage -match 'exited with code\s+(\d+)') {
      $exitCode = 0
      if ([int]::TryParse($Matches[1], [ref]$exitCode)) {
        if ($exitCode -eq 2) {
          return 'degraded'
        }
      }
    }

    # Fallback: treat messages that explicitly call out partial/recoverable
    # failures as degraded.
    if ($ErrorMessage -match 'partial failure' -and $ErrorMessage -match 'recoverable') {
      return 'degraded'
    }

    return $defaultStatus
  }

  function Invoke-LabVIEWRogueSweep {
  param(
    [string]$RepoRoot,
    [string]$Reason = 'rogue-sweep',
    [int]$LookBackSeconds = 900,
    [switch]$RequireClean,
    [switch]$InvokeCloseOnDetection = $true
  )

  if (-not $RepoRoot) { return $null }
  $detectScript = Join-Path $RepoRoot 'tools' 'Detect-RogueLV.ps1'
  if (-not (Test-Path -LiteralPath $detectScript -PathType Leaf)) { return $null }

  $resultsDir = Join-Path $RepoRoot 'tests' 'results'
  if (-not (Test-Path -LiteralPath $resultsDir -PathType Container)) {
    New-Item -ItemType Directory -Force -Path $resultsDir | Out-Null
  }
  $rogueDir = Join-Path $resultsDir '_agent' 'icon-editor' 'rogue-lv'
  if (-not (Test-Path -LiteralPath $rogueDir -PathType Container)) {
    New-Item -ItemType Directory -Force -Path $rogueDir | Out-Null
  }

  $outputPath = Join-Path $rogueDir ("rogue-sweep-{0}.json" -f (Get-Date -Format 'yyyyMMddTHHmmssfff'))
  try {
    & $detectScript -ResultsDir $resultsDir -LookBackSeconds $LookBackSeconds -OutputPath $outputPath -Quiet | Out-Null
  } catch {
    Write-Warning ("{0}: rogue sweep failed ({1})." -f $Reason, $_.Exception.Message)
    return $null
  }

  if (-not (Test-Path -LiteralPath $outputPath -PathType Leaf)) { return $null }
  try {
    $payload = Get-Content -LiteralPath $outputPath -Raw | ConvertFrom-Json -ErrorAction Stop
  } catch {
    Write-Warning ("{0}: unable to parse rogue sweep output ({1})." -f $Reason, $_.Exception.Message)
    return $null
  }

  $rogueLabVIEW = @()
  $rogueLVCompare = @()
  if ($payload -and $payload.rogue) {
    if ($payload.rogue.labview) {
      foreach ($pid in $payload.rogue.labview) {
        if ($null -ne $pid) {
          try { $rogueLabVIEW += [int]$pid } catch {}
        }
      }
    }
    if ($payload.rogue.lvcompare) {
      foreach ($pid in $payload.rogue.lvcompare) {
        if ($null -ne $pid) {
          try { $rogueLVCompare += [int]$pid } catch {}
        }
      }
    }
  }

  if ($rogueLabVIEW.Count -gt 0) {
    Write-Warning ("{0}: terminating rogue LabVIEW PIDs {1}." -f $Reason, ($rogueLabVIEW -join ','))
    foreach ($pid in $rogueLabVIEW) {
      try {
        Stop-Process -Id $pid -Force -ErrorAction Stop
      } catch {
        Write-Warning ("{0}: failed to terminate PID {1}: {2}" -f $Reason, $pid, $_.Exception.Message)
      }
    }

    if ($InvokeCloseOnDetection) {
      $pwshExe = 'pwsh'
      try {
        $cmd = Get-Command -Name 'pwsh' -ErrorAction Stop
        if ($cmd -and $cmd.Source) {
          $pwshExe = $cmd.Source
        } elseif ($cmd -and $cmd.Path) {
          $pwshExe = $cmd.Path
        }
      } catch {}
      $closeScript = Join-Path $RepoRoot 'tools' 'Close-LabVIEW.ps1'
      if (Test-Path -LiteralPath $closeScript -PathType Leaf) {
        try {
          & $pwshExe -NoLogo -NoProfile -File $closeScript | Out-Null
        } catch {
          Write-Warning ("{0}: Close-LabVIEW retry failed ({1})." -f $Reason, $_.Exception.Message)
        }
      }
    }
  }

  if ($rogueLabVIEW.Count -gt 0 -and $RequireClean) {
    throw "Rogue LabVIEW processes detected during stage '{0}'. See {1} for details." -f $Reason, $outputPath
  }

  return [pscustomobject]@{
    reason = $Reason
    path = $outputPath
    rogueLabVIEW = $rogueLabVIEW
    rogueLVCompare = $rogueLVCompare
  }
}

  function Initialize-IconEditorDevModeTelemetry {
  param(
    [ValidateSet('enable','disable')][string]$Mode,
    [string]$RepoRoot,
    [string]$IconEditorRoot,
    [int[]]$Versions,
    [int[]]$Bitness,
    [string]$Operation,
    [string]$ResultsDir
  )

  if (-not $ResultsDir) {
    $ResultsDir = if ($RepoRoot) { Join-Path $RepoRoot 'tests' 'results' } else { 'tests/results' }
  }
  if (-not (Test-Path -LiteralPath $ResultsDir -PathType Container)) {
    try { New-Item -ItemType Directory -Force -Path $ResultsDir | Out-Null } catch {}
  }

  $devModeRunDir = Join-Path $ResultsDir '_agent' 'icon-editor' 'dev-mode-run'
  if (-not (Test-Path -LiteralPath $devModeRunDir -PathType Container)) {
    New-Item -ItemType Directory -Force -Path $devModeRunDir | Out-Null
  }

  $scriptStart = Get-Date
  $timestamp = Get-Date -Format 'yyyyMMddTHHmmssfff'
  $labelPrefix = if ($Mode -eq 'enable') { 'dev-mode-on-' } else { 'dev-mode-off-' }
  $telemetryLabel = "{0}{1}" -f $labelPrefix, $timestamp
  $telemetryPath = Join-Path $devModeRunDir ("dev-mode-run-$timestamp.json")
  $telemetryLatestPath = Join-Path $devModeRunDir 'latest-run.json'

  $agentWaitAvailable = $false
  if ($RepoRoot) {
    $agentWaitPath = Join-Path $RepoRoot 'tools' 'Agent-Wait.ps1'
    if (Test-Path -LiteralPath $agentWaitPath -PathType Leaf) {
      try {
        . $agentWaitPath
        $agentWaitAvailable = $true
      } catch {
        Write-Verbose ("Initialize-IconEditorDevModeTelemetry: failed to import Agent-Wait.ps1: {0}" -f $_.Exception.Message)
      }
    }
  }

    $context = [ordered]@{
      Mode = $Mode
    RepoRoot = $RepoRoot
    IconEditorRoot = $IconEditorRoot
    ResultsDir = $ResultsDir
    DevModeRunDir = $devModeRunDir
    TelemetryPath = $telemetryPath
    TelemetryLatestPath = $telemetryLatestPath
    TelemetryLabel = $telemetryLabel
    ScriptStart = $scriptStart
    TelemetrySaved = $false
    AgentWaitAvailable = $agentWaitAvailable
    Stages = New-Object System.Collections.Generic.List[object]
  }

    $provider = $env:ICONEDITORLAB_PROVIDER
    if (-not $provider) { $provider = 'Real' }
    $runId = $env:ICONEDITORLAB_RUN_ID
    if (-not $runId) { $runId = [guid]::NewGuid().ToString('n') }

    $context.Telemetry = [ordered]@{
      schema = 'icon-editor/dev-mode-run@v1'
      label = $telemetryLabel
      mode = $Mode
      operation = $Operation
      requestedVersions = $Versions
      requestedBitness = $Bitness
      repoRoot = $RepoRoot
      iconEditorRoot = $IconEditorRoot
      startedAt = $scriptStart.ToString('o')
      status = 'pending'
      provider = $provider
      runId    = $runId
    }

  return [pscustomobject]$context
}

function Invoke-IconEditorTelemetryStage {
  param(
    [Parameter(Mandatory)][psobject]$Context,
    [Parameter(Mandatory)][string]$Name,
    [Parameter(Mandatory)][ScriptBlock]$Action,
    [int]$ExpectedSeconds = 120
  )

  if (-not $Context) {
    throw "Invoke-IconEditorTelemetryStage requires a telemetry context."
  }

  $stage = [ordered]@{
    name = $Name
    startedAt = (Get-Date).ToString('o')
    status = 'pending'
  }
  $watch = [System.Diagnostics.Stopwatch]::StartNew()
  $waitId = "devmode-{0}-{1}" -f $Name, $Context.TelemetryLabel
  if ($Context.AgentWaitAvailable) {
    try {
      Start-AgentWait -Reason ("dev-mode:{0}" -f $Name) -ExpectedSeconds $ExpectedSeconds -ResultsDir $Context.ResultsDir -Id $waitId | Out-Null
    } catch {
      Write-Verbose ("Invoke-IconEditorTelemetryStage: failed to start wait tracking for {0}: {1}" -f $Name, $_.Exception.Message)
    }
  }

  try {
    $result = & $Action $stage
    if ($stage.status -eq 'pending') { $stage.status = 'ok' }
    return $result
  } catch {
    $stage.status = 'failed'
    $stage.error = $_.Exception.Message
    throw
  } finally {
    $watch.Stop()
    $stage.endedAt = (Get-Date).ToString('o')
    $stage.durationSeconds = [Math]::Round($watch.Elapsed.TotalSeconds, 2)
    if ($Context.AgentWaitAvailable) {
      try { End-AgentWait -ResultsDir $Context.ResultsDir -Id $waitId | Out-Null } catch {}
    }
    $null = $Context.Stages.Add($stage)
  }
}

function Complete-IconEditorDevModeTelemetry {
  param(
    [Parameter(Mandatory)][psobject]$Context,
    [string]$Status,
    [object]$State,
    [string]$Error
  )

  if (-not $Context) {
    throw "Complete-IconEditorDevModeTelemetry requires a telemetry context."
  }
  if ($Context.TelemetrySaved) { return }

  $completed = Get-Date
  if ($Status) { $Context.Telemetry.status = $Status }
  if ($State) {
    if ($State.PSObject.Properties['Path']) { $Context.Telemetry.statePath = $State.Path }
    if ($State.PSObject.Properties['UpdatedAt']) { $Context.Telemetry.updatedAt = $State.UpdatedAt }
    if ($State.PSObject.Properties['Verification']) {
      $Context.Telemetry.verification = $State.Verification
      $verificationSummary = Get-IconEditorVerificationSummary -Verification $State.Verification
      if ($verificationSummary) {
        $Context.Telemetry.verificationSummary = $verificationSummary
      }
    }
  }
  if ($Error) {
    $Context.Telemetry.error = $Error
    $lines = $Error -split "(`r`n|`n)"
    $primary = $lines | Where-Object {
      $_ -and (
        $_ -match 'Error:' -or
        $_ -match 'Rogue LabVIEW' -or
        $_ -match 'Timed out waiting for app to connect to g-cli'
      )
    } | Select-Object -First 1
    if (-not $primary) {
      $primary = $lines | Where-Object { -not [string]::IsNullOrWhiteSpace($_) } | Select-Object -First 1
    }
    if ($primary) {
      $Context.Telemetry.errorSummary = $primary.Trim()
    }
  }

  $Context.Telemetry.completedAt = $completed.ToString('o')
  $Context.Telemetry.durationSeconds = [Math]::Round(($completed - $Context.ScriptStart).TotalSeconds, 2)
  $Context.Telemetry.stages = $Context.Stages.ToArray()

  $allSettleEvents = @()
  foreach ($stageRecord in $Context.Telemetry.stages) {
    if ($stageRecord -and $stageRecord.PSObject.Properties['settleEvents']) {
      $allSettleEvents += $stageRecord.settleEvents
    }
  }
  if ($allSettleEvents.Count -gt 0) {
    $settleSummary = Get-IconEditorSettleSummary -Events $allSettleEvents
    if ($settleSummary) {
      $Context.Telemetry.settleSummary = $settleSummary
      if ($settleSummary.PSObject.Properties['totalDurationSeconds']) {
        $Context.Telemetry.settleSeconds = $settleSummary.totalDurationSeconds
      }
    }
  } elseif ($Context.Telemetry.PSObject.Properties['settleSeconds']) {
    $Context.Telemetry.PSObject.Properties.Remove('settleSeconds') | Out-Null
  }

  $json = $Context.Telemetry | ConvertTo-Json -Depth 7
  $json | Set-Content -LiteralPath $Context.TelemetryPath -Encoding utf8
  $json | Set-Content -LiteralPath $Context.TelemetryLatestPath -Encoding utf8
  $Context.TelemetrySaved = $true
}

  Export-ModuleMember -Function `
  Resolve-IconEditorRepoRoot, `
  Resolve-IconEditorRoot, `
  Get-IconEditorDevModeStatePath, `
  Get-IconEditorDevModeState, `
  Set-IconEditorDevModeState, `
  Invoke-IconEditorRogueCheck, `
  Invoke-IconEditorDevModeScript, `
  Enable-IconEditorDevelopmentMode, `
  Disable-IconEditorDevelopmentMode, `
  Get-IconEditorDevModePolicyPath, `
  Get-IconEditorDevModePolicy, `
  Get-IconEditorDevModePolicyEntry, `
  Get-IconEditorDevModeLabVIEWTargets, `
  Assert-IconEditorDevModeTokenState, `
  Test-IconEditorDevelopmentMode, `
  Wait-IconEditorLabVIEWSettle, `
  Invoke-LabVIEWPrelaunchGuard, `
  Get-IconEditorLabVIEWSettleEvents, `
  Get-IconEditorSettleSummary, `
  Get-IconEditorVerificationSummary, `
  Invoke-LabVIEWRogueSweep, `
  Initialize-IconEditorDevModeTelemetry, `
  Invoke-IconEditorTelemetryStage, `
    Complete-IconEditorDevModeTelemetry, `
    Get-IconEditorDevModeOutcomeStatus, `
  Get-LvAddonAllowedHosts, `
  Write-LvAddonRootSummary, `
  Resolve-IconEditorVendorToolsModulePath
if (-not (Get-Variable -Name IconEditorLabVIEWSettleEvents -Scope Script -ErrorAction SilentlyContinue)) {
  $script:IconEditorLabVIEWSettleEvents = New-Object System.Collections.Generic.List[object]
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
