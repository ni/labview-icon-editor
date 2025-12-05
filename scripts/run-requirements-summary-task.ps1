param(
    [string] $Csv = 'docs/requirements/requirements.csv',
    [string] $Summary = 'reports/requirements-summary.md',
    [string] $Html = 'reports/requirements-summary.html',
    [string] $HighPrioritySummary = 'reports/requirements-summary-high.md'
)

$repoRoot = Resolve-Path -Path '.' -ErrorAction Stop
$invokeCli = Join-Path $repoRoot 'scripts/common/invoke-repo-cli.ps1'
$csvPath = Resolve-Path -Path $Csv -ErrorAction Stop
$summaryPath = Join-Path $repoRoot $Summary
$htmlPath = Join-Path $repoRoot $Html
$highSummaryPath = Join-Path $repoRoot $HighPrioritySummary

if (-not (Test-Path -LiteralPath $invokeCli -PathType Leaf)) {
    throw "invoke-repo-cli helper not found at $invokeCli"
}

function Invoke-Summarizer {
    param(
        [string[]] $Args
    )

    $output = & $invokeCli -CliName 'RequirementsSummarizer' -RepoRoot $repoRoot -Args $Args 2>&1
    $exitCode = $LASTEXITCODE

    $output | ForEach-Object { Write-Host $_ }

    if ($exitCode -ne 0) {
        throw "RequirementsSummarizer failed with exit code $exitCode"
    }
}

$logDir = Join-Path $repoRoot 'reports/logs'
New-Item -ItemType Directory -Force -Path $logDir | Out-Null
$logFile = Join-Path $logDir ("requirements-summary-task-$((Get-Date).ToString('yyyyMMddHHmmss')).log")

Start-Transcript -Path $logFile -Force
try {
    Write-Host "Generating requirements summary (full) from $csvPath"
    Invoke-Summarizer -Args @(
        '--csv', $csvPath,
        '--summary-output', $summaryPath,
        '--html-output', $htmlPath,
        '--summary-full',
        '--details'
    )

    Write-Host "Generating high-priority filtered summary"
    Invoke-Summarizer -Args @(
        '--csv', $csvPath,
        '--summary-output', $highSummaryPath,
        '--filter-priority', 'High',
        '--sort', 'Priority',
        '--summary-full',
        '--details'
    )
}
finally {
    Stop-Transcript | Out-Null
}
