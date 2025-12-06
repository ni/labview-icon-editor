[CmdletBinding()]
param(
    [string]$RepoPath = '.',
    [int]$Loops = 4,
    [switch]$WaitForHeadRun,
    [bool]$DownloadLogs = $true,
    [string]$LogDir = 'artifacts/ci-logs',
    [string]$TestCommand = 'pwsh -NoProfile -File scripts/test/Test.ps1 -RepositoryPath . -SupportedBitness 64',
    [int]$SleepSeconds = 30,
    [string]$PatchCommand,
    [string]$PatchWorkDir,
    [bool]$PatchEachLoop = $false,
    [string[]]$ExtraArgs
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$repo = (Resolve-Path -LiteralPath $RepoPath).Path
$cliProj = Join-Path $repo 'Tooling/dotnet/CiRefineCli/CiRefineCli.csproj'
if (-not (Test-Path -LiteralPath $cliProj -PathType Leaf)) {
    throw "CiRefineCli project not found at $cliProj"
}

$logRoot = Join-Path $repo $LogDir
if (-not (Test-Path -LiteralPath $logRoot)) {
    New-Item -ItemType Directory -Path $logRoot -Force | Out-Null
}

for ($i = 1; $i -le $Loops; $i++) {
    Write-Host "[loop $i/$Loops] Running CiRefineCli..." -ForegroundColor Cyan
    $jsonPath = Join-Path $logRoot ("summary-loop-$i.json")
    $parsedExtra = @()
    $trimChars = @('''','"','`',' ')
    if ($ExtraArgs) {
        foreach ($item in $ExtraArgs) {
            if ($item -match "," -and $item -match "--") {
                # Split comma-delimited fallback (handles a single quoted blob)
                $parsedExtra += ($item -split ",") | ForEach-Object { $_.Trim($trimChars) } | Where-Object { $_ }
            }
            else {
                $parsedExtra += $item.Trim($trimChars)
            }
        }
    }

    $cliArgs = @(
        '--repo-path', $repo,
        '--json-output', $jsonPath,
        '--log-dir', $LogDir,
        '--force'
    )
    if ($WaitForHeadRun) { $cliArgs += '--wait-for-head-run' }
    if ($DownloadLogs) { $cliArgs += '--download-logs' }
    if ($TestCommand) { $cliArgs += @('--test-cmd', $TestCommand) }
    if ($parsedExtra) { $cliArgs += $parsedExtra }

    $dotnetCmd = @('run', '--project', $cliProj, '--') + $cliArgs
    Write-Host "dotnet $($dotnetCmd -join ' ')" -ForegroundColor DarkGray
    & dotnet @dotnetCmd
    $exit = $LASTEXITCODE
    $shouldPatch = $PatchCommand -and ($PatchEachLoop -or $exit -ne 0)
    if ($shouldPatch) {
        $workDir = if ($PatchWorkDir) { $PatchWorkDir } else { $repo }
        Write-Host "[loop $i] Running patch command in '$workDir': $PatchCommand" -ForegroundColor Yellow
        $prev = @{ REFINE_LOOP = $env:REFINE_LOOP; REFINE_EXIT_CODE = $env:REFINE_EXIT_CODE; REFINE_SUMMARY_PATH = $env:REFINE_SUMMARY_PATH; REFINE_LOG_DIR = $env:REFINE_LOG_DIR }
        $env:REFINE_LOOP = $i
        $env:REFINE_EXIT_CODE = $exit
        $env:REFINE_SUMMARY_PATH = $jsonPath
        $env:REFINE_LOG_DIR = $logRoot
        Push-Location $workDir
        try {
            & pwsh -NoProfile -Command $PatchCommand
            $patchExit = $LASTEXITCODE
            if ($patchExit -ne 0) {
                Write-Warning "[loop $i] Patch command exited with $patchExit"
            }
        }
        finally {
            Pop-Location
            $env:REFINE_LOOP = $prev.REFINE_LOOP
            $env:REFINE_EXIT_CODE = $prev.REFINE_EXIT_CODE
            $env:REFINE_SUMMARY_PATH = $prev.REFINE_SUMMARY_PATH
            $env:REFINE_LOG_DIR = $prev.REFINE_LOG_DIR
        }
    }

    if ($exit -eq 0) {
        Write-Host "[loop $i] Completed successfully." -ForegroundColor Green
        break
    }

    Write-Warning "[loop $i] CiRefineCli exited with $exit; continuing after $SleepSeconds seconds."
    Start-Sleep -Seconds $SleepSeconds
}
