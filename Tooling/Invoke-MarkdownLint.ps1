#Requires -Version 7.0
<#
.SYNOPSIS
    Runs repository markdown linting with pinned markdownlint-cli2.

.DESCRIPTION
    Executes markdownlint-cli2 using repository-scoped globs from
    .markdownlint-cli2.jsonc and fails on findings.

.PARAMETER RepoRoot
    Repository root path. Defaults to the current git root.

.PARAMETER ConfigPath
    Path to markdownlint-cli2 config. Relative paths resolve from RepoRoot.

.PARAMETER WriteSummary
    Write a compact result summary to GITHUB_STEP_SUMMARY when available.

.PARAMETER SummaryPath
    Optional override for summary output path.
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [string]$RepoRoot,

    [Parameter(Mandatory = $false)]
    [string]$ConfigPath = '.markdownlint-cli2.jsonc',

    [switch]$WriteSummary,

    [Parameter(Mandatory = $false)]
    [string]$SummaryPath
)

$ErrorActionPreference = 'Stop'

function Resolve-RepoRoot {
    param([string]$PathOverride)

    if (-not [string]::IsNullOrWhiteSpace($PathOverride)) {
        return (Resolve-Path -Path $PathOverride -ErrorAction Stop).Path
    }

    if (Get-Command git -ErrorAction SilentlyContinue) {
        try {
            $gitRoot = git rev-parse --show-toplevel 2>$null
            if ($LASTEXITCODE -eq 0 -and -not [string]::IsNullOrWhiteSpace($gitRoot)) {
                return (Resolve-Path -Path $gitRoot.Trim() -ErrorAction Stop).Path
            }
        } catch {
            Write-Verbose ("git rev-parse failed: {0}" -f $_.Exception.Message)
        }
    }

    return (Resolve-Path -Path '.').Path
}

function Resolve-SummaryPath {
    param(
        [string]$OverridePath,
        [string]$ResolvedRepoRoot
    )

    if (-not [string]::IsNullOrWhiteSpace($OverridePath)) {
        return $OverridePath
    }

    if (-not [string]::IsNullOrWhiteSpace($env:LVIE_MARKDOWNLINT_SUMMARY_PATH)) {
        return $env:LVIE_MARKDOWNLINT_SUMMARY_PATH
    }

    if (-not [string]::IsNullOrWhiteSpace($env:GITHUB_STEP_SUMMARY)) {
        return $env:GITHUB_STEP_SUMMARY
    }

    if (-not [string]::IsNullOrWhiteSpace($ResolvedRepoRoot)) {
        return (Join-Path $ResolvedRepoRoot 'TestResults\markdownlint-summary.md')
    }

    return $null
}

function Write-Summary {
    param(
        [string]$Path,
        [string]$ConfigPathResolved,
        [int]$ExitCode
    )

    if ([string]::IsNullOrWhiteSpace($Path)) {
        return
    }

    $status = if ($ExitCode -eq 0) { 'pass' } else { 'fail' }
    $lines = @(
        '## Markdown Lint'
        ("- Status: {0}" -f $status)
        ('- Config: `{0}`' -f $ConfigPathResolved)
        '- Tool: `markdownlint-cli2@0.21.0`'
    )

    $directory = Split-Path -Parent $Path
    if (-not [string]::IsNullOrWhiteSpace($directory) -and -not (Test-Path -Path $directory -PathType Container)) {
        New-Item -Path $directory -ItemType Directory -Force | Out-Null
    }

    $lines | Out-File -FilePath $Path -Encoding utf8 -Append
}

$resolvedRepoRoot = Resolve-RepoRoot -PathOverride $RepoRoot
$resolvedConfigPath = if ([System.IO.Path]::IsPathRooted($ConfigPath)) {
    $ConfigPath
} else {
    Join-Path $resolvedRepoRoot $ConfigPath
}

if (-not (Test-Path -Path $resolvedConfigPath -PathType Leaf)) {
    throw ("markdownlint config not found: {0}" -f $resolvedConfigPath)
}

if (-not (Get-Command npx -ErrorAction SilentlyContinue)) {
    throw "npx was not found on PATH. Install Node.js/npm to run markdownlint."
}

Push-Location -Path $resolvedRepoRoot
try {
    Write-Host ("Running markdownlint with config: {0}" -f $resolvedConfigPath)
    & npx --yes markdownlint-cli2@0.21.0 --config $resolvedConfigPath
    $exitCode = if ($null -eq $LASTEXITCODE) { 0 } else { [int]$LASTEXITCODE }
} finally {
    Pop-Location
}

if ($WriteSummary) {
    $summary = Resolve-SummaryPath -OverridePath $SummaryPath -ResolvedRepoRoot $resolvedRepoRoot
    Write-Summary -Path $summary -ConfigPathResolved $resolvedConfigPath -ExitCode $exitCode
}

if ($exitCode -ne 0) {
    throw ("markdownlint failed with exit code {0}" -f $exitCode)
}

Write-Host 'markdownlint passed.'
