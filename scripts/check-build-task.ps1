# Validates the VSCode build task wiring for the single Build LVAddon task.
# Exits non-zero if the task is missing or does not include required flags or inputs.
[CmdletBinding()]
param(
    [string]$TasksPath = ".vscode/tasks.json"
)

$ErrorActionPreference = 'Stop'

if ([string]::IsNullOrWhiteSpace($TasksPath)) {
    $TasksPath = ".vscode/tasks.json"
}

try {
    $resolvedTasks = Resolve-Path -LiteralPath $TasksPath -ErrorAction Stop
    $TasksPath = $resolvedTasks.Path
}
catch {
    Write-Error "tasks.json not found at $TasksPath"
    exit 1
}

$json = Get-Content -LiteralPath $TasksPath -Raw | ConvertFrom-Json
$buildTask = $json.tasks | Where-Object { $_.label -eq "02 Build LVAddon (VI Package)" } | Select-Object -First 1

if (-not $buildTask) {
    Write-Error "Build task '02 Build LVAddon (VI Package)' not found in $TasksPath"
    exit 2
}

# Required substrings in the command
$command = ($buildTask.args -join ' ')
$required = @(
    "IntegrationEngineCli/IntegrationEngineCli.csproj",
    "--repo",
    "--ref",
    "--bitness",
    "--lvlibp-bitness",
    "--major",
    "--minor",
    "--patch",
    "--build",
    "--company",
    "--author"
)

$missing = $required | Where-Object { $command -notmatch [regex]::Escape($_) }
if ($missing) {
    Write-Error ("Build task command missing required flags: {0}" -f ($missing -join ', '))
    exit 3
}

if ($buildTask.windows -and $buildTask.windows.args) {
    $winCommand = ($buildTask.windows.args -join ' ')
    if ($winCommand -notmatch [regex]::Escape("--managed")) {
        Write-Error "Windows args are expected to include --managed for the Integration Engine managed orchestration."
        exit 4
    }
}

Write-Output "Build task wiring OK."
exit 0
