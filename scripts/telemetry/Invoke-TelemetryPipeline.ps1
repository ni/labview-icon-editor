param(
    [Parameter(Mandatory=$true)][string]$Step,
    [Parameter(Mandatory=$true)][ValidateSet('pass','fail')][string]$Status,
    [string]$RepositoryPath = '.',
    [string]$EventsPath = 'artifacts/qa-telemetry.jsonl',
    [string]$SummaryPath = 'telemetry/summary.json',
    [string]$HistoryPath = 'telemetry/qa-summary-history.jsonl',
    [int]$DurationMs,
    [hashtable]$Meta = @{},
    [int]$MaxFailures = 0,
    [hashtable]$MaxFailuresPerStep = @{},
    [string]$Stage,
    [string]$Task,
    [string]$Runner,
    [string]$Bitness,
    [string]$LvVersion,
    [string]$Producer = 'Invoke-TelemetryPipeline',
    [string[]]$Artifacts = @(),
    [string]$SchemaEventsPath = 'Tooling/x-cli/docs/schemas/v2/telemetry.events.v2.schema.json',
    [string]$SchemaSummaryPath = 'Tooling/x-cli/docs/schemas/v1/telemetry.summary.v1.schema.json',
    [string]$MarkdownPath,
    [bool]$IncludeGitMeta = $true
)

$ErrorActionPreference = 'Stop'
$repoRoot = (Resolve-Path -LiteralPath $RepositoryPath).Path
$wrapper = Join-Path $repoRoot 'scripts/common/invoke-repo-cli.ps1'
if (-not (Test-Path -LiteralPath $wrapper -PathType Leaf)) {
    throw "invoke-repo-cli.ps1 not found at $wrapper"
}

function Get-GitMeta {
    try {
        $orig = Get-Location
        Set-Location $repoRoot
        $commit = (git rev-parse HEAD 2>$null).Trim()
        $branch = (git rev-parse --abbrev-ref HEAD 2>$null).Trim()
        $dirty = -not [string]::IsNullOrWhiteSpace((git status --porcelain 2>$null))
        return @{ commit = $commit; branch = $branch; dirty = $dirty }
    }
    catch { return $null }
    finally { Set-Location $orig }
}

function Invoke-XCli([string[]]$CliArgs) {
    $procArgs = @('-NoProfile','-File',$wrapper,'-CliName','XCli','-RepoRoot',$repoRoot,'-CliArgs') + $CliArgs
    & pwsh @procArgs
    if ($LASTEXITCODE -ne 0) {
        throw "x-cli exited with code $LASTEXITCODE for args: $($CliArgs -join ' ')"
    }
}

if ([string]::IsNullOrWhiteSpace($Step)) { throw 'Step is required' }
if ([string]::IsNullOrWhiteSpace($Status)) { throw 'Status is required' }

$metaBag = @{}
foreach ($k in $Meta.Keys) { $metaBag[$k] = [string]$Meta[$k] }
if ($Artifacts.Count -gt 0) { $metaBag['artifacts'] = ($Artifacts -join ';') }
if ($Stage) { $metaBag['stage'] = $Stage }
if ($Task) { $metaBag['task'] = $Task }
if ($Runner) { $metaBag['runner'] = $Runner }
if ($Bitness) { $metaBag['bitness'] = $Bitness }
if ($LvVersion) { $metaBag['lv_version'] = $LvVersion }
if ($Producer) { $metaBag['producer'] = $Producer }
if ($IncludeGitMeta) {
    $git = Get-GitMeta
    if ($git) {
        if ($git.commit) { $metaBag['git_commit'] = $git.commit }
        if ($git.branch) { $metaBag['git_branch'] = $git.branch }
        $metaBag['git_dirty'] = [string]$git.dirty
    }
}

$writeArgs = @('telemetry','write','--output',$EventsPath,'--step',$Step,'--status',$Status)
if ($DurationMs -gt 0) { $writeArgs += @('--duration-ms',[string]$DurationMs) }
foreach ($k in $metaBag.Keys) {
    $v = [string]$metaBag[$k]
    $writeArgs += @('--meta',"$k=$v")
}
Invoke-XCli -CliArgs $writeArgs

$summarizeArgs = @('telemetry','summarize','--in',$EventsPath,'--output',$SummaryPath)
if (-not [string]::IsNullOrWhiteSpace($HistoryPath)) {
    $summarizeArgs += @('--history',$HistoryPath)
}
Invoke-XCli -CliArgs $summarizeArgs

$validateArgs = @()
if ($SchemaEventsPath) {
    $validateArgs += ,@('telemetry','validate','--events',$EventsPath,'--schema',$SchemaEventsPath)
}
if ($SchemaSummaryPath) {
    $validateArgs += ,@('telemetry','validate','--summary',$SummaryPath,'--schema',$SchemaSummaryPath)
}
foreach ($va in $validateArgs) { Invoke-XCli -CliArgs $va }

$checkArgs = @('telemetry','check','--summary',$SummaryPath,'--max-failures',[string]$MaxFailures)
foreach ($k in $MaxFailuresPerStep.Keys) {
    $limit = [string]$MaxFailuresPerStep[$k]
    $checkArgs += @('--max-failures-step',"$k=$limit")
}
Invoke-XCli -CliArgs $checkArgs

if ($MarkdownPath) {
    $md = @()
    $md += "# Telemetry Summary"
    $md += "- Step: $Step"
    $md += "- Status: $Status"
    $md += "- Summary: $SummaryPath"
    $md += "- Events: $EventsPath"
    if ($Artifacts.Count -gt 0) { $md += "- Artifacts: $($Artifacts -join ', ')" }
    if ($metaBag.ContainsKey('git_commit')) { $md += "- Git: $($metaBag['git_commit']) ($($metaBag['git_branch'])) dirty=$($metaBag['git_dirty'])" }
    $md += ""
    $md += "## Failure gates"
    $md += "- MaxFailures: $MaxFailures"
    if ($MaxFailuresPerStep.Count -gt 0) {
        foreach ($k in $MaxFailuresPerStep.Keys) { $md += "- $k <= $($MaxFailuresPerStep[$k])" }
    }
    $mdDir = Split-Path -Parent (Resolve-Path -LiteralPath $MarkdownPath -ErrorAction SilentlyContinue)
    if (-not $mdDir) { $mdDir = Split-Path -Parent $MarkdownPath }
    if (-not [string]::IsNullOrWhiteSpace($mdDir)) { New-Item -ItemType Directory -Force -Path $mdDir | Out-Null }
    [System.IO.File]::WriteAllLines($MarkdownPath, $md)
}
