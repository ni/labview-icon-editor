#Requires -Version 7.0

[CmdletBinding()]
param(
    [string]$RepoRoot,
    [string]$IconEditorRoot,
    [string]$RepoSlug = 'LabVIEW-Community-CI-CD/labview-icon-editor',
    [int]$MinimumSupportedLVVersion = 2023,
    [int]$PackageMinimumSupportedLVVersion = 2026,
    [int]$PackageSupportedBitness = 64,
    [switch]$SkipSync,
    [switch]$SkipVipcApply,
    [switch]$SkipBuild,
    [switch]$SkipRogueCheck,
    [switch]$SkipClose,
    [int]$Major = 1,
    [int]$Minor = 4,
    [int]$Patch = 1,
    [int]$Build,
    [string]$ResultsRoot,
    [switch]$VerboseOutput
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$null = Import-Module Microsoft.PowerShell.Management -ErrorAction Stop
$null = Import-Module Microsoft.PowerShell.Utility -ErrorAction Stop
$PSModuleAutoLoadingPreference = 'None'

function Invoke-Step {
    param(
        [Parameter(Mandatory)][string]$Name,
        [Parameter(Mandatory)][scriptblock]$Action
    )

    Write-Host ("==> {0}" -f $Name)
    & $Action
}

if (-not $RepoRoot) {
    $RepoRoot = (Microsoft.PowerShell.Management\Resolve-Path (Join-Path $PSScriptRoot '..\..\')).ProviderPath
}

if (-not $IconEditorRoot) {
    $IconEditorRoot = Join-Path $RepoRoot 'vendor\icon-editor'
}

$IconEditorRoot = (Microsoft.PowerShell.Management\Resolve-Path $IconEditorRoot -ErrorAction Stop).ProviderPath

if (-not $ResultsRoot) {
    $ResultsRoot = Join-Path $RepoRoot 'tests\results\_agent\icon-editor\vipm-cli-build'
}

if (-not $Build) {
    $Build = [int](Get-Date -Format 'yyMMdd')
}

function Ensure-VendorModule {
    param(
        [Parameter(Mandatory)][string]$FileName,
        [Parameter(Mandatory)][string]$Content
    )

    $toolsDir = Join-Path $IconEditorRoot 'tools'
    if (-not (Test-Path -LiteralPath $toolsDir -PathType Container)) {
        New-Item -ItemType Directory -Path $toolsDir -Force | Out-Null
    }
    $target = Join-Path $toolsDir $FileName
    Set-Content -LiteralPath $target -Value $Content -Encoding UTF8
}

$wrapperTemplate = @'
#Requires -Version 7.0

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = (Microsoft.PowerShell.Management\Resolve-Path (Join-Path $PSScriptRoot '..\..\..')).ProviderPath
$targetModule = Join-Path $repoRoot 'tools' '{0}'

if (-not (Test-Path -LiteralPath $targetModule -PathType Leaf)) {{
    throw "Unable to locate root {1} module at '$targetModule'."
}}

$imported = Import-Module $targetModule -Force -PassThru
if ($imported) {{
    Export-ModuleMember -Function $imported.ExportedFunctions.Keys -Alias $imported.ExportedAliases.Keys
}}
'@

$detectScript = Join-Path $RepoRoot 'tools\Detect-RogueLV.ps1'
$closeScript = Join-Path $IconEditorRoot '.github\actions\close-labview\Close_LabVIEW.ps1'

function Invoke-RogueCheckIfEnabled {
    if ($SkipRogueCheck) {
        Write-Host 'Skipping rogue detection.'
        return
    }
    if (Test-Path -LiteralPath $detectScript) {
        pwsh -NoLogo -NoProfile -File $detectScript -FailOnRogue
    } else {
        Write-Warning "Detect-RogueLV.ps1 not found at $detectScript – skipping."
    }
}

function Invoke-CloseLabVIEWBitness {
    param(
        [Parameter(Mandatory)][ValidateSet('32','64')][string]$Bitness,
        [int]$Version
    )

    if ($SkipClose) {
        Write-Host "Skipping forced close for $Bitness-bit."
        return
    }
    if (-not (Test-Path -LiteralPath $closeScript -PathType Leaf)) {
        Write-Warning "Close_LabVIEW.ps1 not found at $closeScript."
        return
    }
    $targetVersion = if ($Version) { $Version } else { $MinimumSupportedLVVersion }

    pwsh -NoLogo -NoProfile -File $closeScript `
        -MinimumSupportedLVVersion $targetVersion `
        -SupportedBitness $Bitness | Out-Null
    Invoke-RogueCheckIfEnabled
}

Invoke-Step -Name 'Detect rogue LabVIEW instances' -Action {
    Invoke-RogueCheckIfEnabled
}

Invoke-Step -Name 'Close LabVIEW 2023 (32/64-bit)' -Action {
    Invoke-CloseLabVIEWBitness -Bitness '32'
    Invoke-CloseLabVIEWBitness -Bitness '64'
}

Invoke-Step -Name 'Sync icon-editor vendor snapshot' -Action {
    if ($SkipSync) { Write-Host 'Skipping vendor sync.'; return }
    $syncScript = Join-Path $RepoRoot 'tools\icon-editor\Sync-IconEditorFork.ps1'
    if (-not (Test-Path -LiteralPath $syncScript -PathType Leaf)) {
        throw "Sync-IconEditorFork.ps1 not found at $syncScript."
    }
    pwsh -NoLogo -NoProfile -File $syncScript -RepoSlug $RepoSlug | Out-Null

    Ensure-VendorModule -FileName 'GCli.psm1' -Content ($wrapperTemplate -f 'GCli.psm1', 'GCli')
    Ensure-VendorModule -FileName 'Vipm.psm1' -Content ($wrapperTemplate -f 'Vipm.psm1', 'Vipm')
}

Invoke-Step -Name 'Apply runner dependencies via VIPM (32/64-bit)' -Action {
    if ($SkipVipcApply) { Write-Host 'Skipping VIPC application.'; return }
    $applyScript = Join-Path $IconEditorRoot '.github\actions\apply-vipc\ApplyVIPC.ps1'
    if (-not (Test-Path -LiteralPath $applyScript -PathType Leaf)) {
        throw "ApplyVIPC.ps1 not found at $applyScript."
    }

    $applyTargets = @(
        [pscustomobject]@{ Version = $MinimumSupportedLVVersion; VipVersion = $MinimumSupportedLVVersion; Bitness = '32' },
        [pscustomobject]@{ Version = $MinimumSupportedLVVersion; VipVersion = $MinimumSupportedLVVersion; Bitness = '64' }
    )

    $packagingTarget = [pscustomobject]@{
        Version    = $PackageMinimumSupportedLVVersion
        VipVersion = $PackageMinimumSupportedLVVersion
        Bitness    = [string]$PackageSupportedBitness
    }

    if (-not ($applyTargets | Where-Object {
        $_.Version -eq $packagingTarget.Version -and $_.Bitness -eq $packagingTarget.Bitness
    })) {
        $applyTargets += $packagingTarget
    }

    foreach ($target in $applyTargets | Sort-Object Version, Bitness -Unique) {
        pwsh -NoLogo -NoProfile -File $applyScript `
            -MinimumSupportedLVVersion $target.Version `
            -SupportedBitness $target.Bitness `
            -IconEditorRoot $IconEditorRoot `
            -VIP_LVVersion $target.VipVersion | Out-Null
        Invoke-CloseLabVIEWBitness -Bitness $target.Bitness -Version $target.Version
    }
}

$buildResult = $null
Invoke-Step -Name 'Run VIPM CLI build' -Action {
    if ($SkipBuild) { Write-Host 'Skipping build.'; return }
    $buildScript = Join-Path $RepoRoot 'tools\icon-editor\Invoke-IconEditorBuild.ps1'
    if (-not (Test-Path -LiteralPath $buildScript -PathType Leaf)) {
        throw "Invoke-IconEditorBuild.ps1 not found at $buildScript."
    }

    $buildArgs = @(
        '-IconEditorRoot', $IconEditorRoot,
        '-ResultsRoot', $ResultsRoot,
        '-BuildToolchain', 'vipm',
        '-MinimumSupportedLVVersion', $MinimumSupportedLVVersion,
        '-PackageMinimumSupportedLVVersion', $PackageMinimumSupportedLVVersion,
        '-PackageSupportedBitness', $PackageSupportedBitness,
        '-Major', $Major,
        '-Minor', $Minor,
        '-Patch', $Patch,
        '-Build', $Build
    )

    if ($VerboseOutput) { $buildArgs += '-Verbose' }

    pwsh -NoLogo -NoProfile -File $buildScript @buildArgs
}

Write-Host '==> Workflow complete.'

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
