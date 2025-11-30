param(
    [string] $RepositoryPath = '.'
)

$repoRoot = Resolve-Path -Path $RepositoryPath -ErrorAction Stop
$clearScript = Join-Path $repoRoot 'scripts/clear-labview-librarypaths-all.ps1'
if (-not (Test-Path $clearScript)) {
    throw "clear script not found: $clearScript"
}

$logDir = Join-Path $repoRoot 'reports/logs'
New-Item -ItemType Directory -Force -Path $logDir | Out-Null
$timestamp = (Get-Date).ToString('yyyyMMddHHmmss')
$logFile = Join-Path $logDir "devmode-clear-all-task-$timestamp.log"

Start-Transcript -Path $logFile -Force
try {
    Write-Host "Running DevMode clear/unbind all via $clearScript"
    pwsh -NoProfile -File $clearScript
}
finally {
    Stop-Transcript | Out-Null
}
