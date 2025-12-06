param(
    [Parameter(Mandatory=$true)][string]$Step,
    [Parameter(Mandatory=$true)][string]$Command,
    [string[]]$CommandArgs = @(),
    [string]$RepositoryPath = '.',
    [string]$EventsPath = 'artifacts/qa-telemetry.jsonl',
    [string]$SummaryPath = 'telemetry/summary.json',
    [string]$HistoryPath = 'telemetry/qa-summary-history.jsonl',
    [int]$MaxFailures = 0,
    [hashtable]$MaxFailuresPerStep = @{},
    [hashtable]$Meta = @{},
    [string]$Stage,
    [string]$Task,
    [string]$Runner,
    [string]$Bitness,
    [string]$LvVersion,
    [string]$Producer = 'Run-Command-With-Telemetry',
    [string[]]$Artifacts = @(),
    [string]$SchemaEventsPath = 'Tooling/x-cli/docs/schemas/v2/telemetry.events.v2.schema.json',
    [string]$SchemaSummaryPath = 'Tooling/x-cli/docs/schemas/v1/telemetry.summary.v1.schema.json',
    [string]$MarkdownPath
)

$ErrorActionPreference = 'Stop'
$repoRoot = (Resolve-Path -LiteralPath $RepositoryPath).Path
$helper = Join-Path $repoRoot 'scripts/telemetry/Invoke-TelemetryPipeline.ps1'
if (-not (Test-Path -LiteralPath $helper -PathType Leaf)) {
    throw "Telemetry helper not found at $helper"
}

$status = 'fail'
$exitCode = 1
$stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
try {
    & $Command @CommandArgs
    $exitCode = $LASTEXITCODE
    if ($exitCode -eq 0) { $status = 'pass' }
}
catch {
    $status = 'fail'
    $exitCode = 1
}
finally {
    $stopwatch.Stop()
}

$metaBag = @{}
foreach ($k in $Meta.Keys) { $metaBag[$k] = [string]$Meta[$k] }
$metaBag['command'] = $Command
$metaBag['exitCode'] = [string]$exitCode
if ($CommandArgs.Count -gt 0) {
    $metaBag['args'] = ($CommandArgs -join ' ')
}

$telemetryArgs = @(
    '-NoProfile','-File',$helper,
    '-Step',$Step,
    '-Status',$status,
    '-RepositoryPath',$repoRoot,
    '-EventsPath',$EventsPath,
    '-SummaryPath',$SummaryPath,
    '-HistoryPath',$HistoryPath,
    '-DurationMs',[string]$stopwatch.ElapsedMilliseconds,
    '-MaxFailures',[string]$MaxFailures,
    '-Producer',$Producer,
    '-SchemaEventsPath',$SchemaEventsPath,
    '-SchemaSummaryPath',$SchemaSummaryPath
)
if ($MaxFailuresPerStep.Count -gt 0) {
    $telemetryArgs += @('-MaxFailuresPerStep',($MaxFailuresPerStep))
}
if ($metaBag.Count -gt 0) {
    $telemetryArgs += @('-Meta',($metaBag))
}
if ($Artifacts.Count -gt 0) { $telemetryArgs += @('-Artifacts',($Artifacts)) }
if ($Stage) { $telemetryArgs += @('-Stage',$Stage) }
if ($Task) { $telemetryArgs += @('-Task',$Task) }
if ($Runner) { $telemetryArgs += @('-Runner',$Runner) }
if ($Bitness) { $telemetryArgs += @('-Bitness',$Bitness) }
if ($LvVersion) { $telemetryArgs += @('-LvVersion',$LvVersion) }
if ($MarkdownPath) { $telemetryArgs += @('-MarkdownPath',$MarkdownPath) }

& pwsh @telemetryArgs
exit $exitCode
