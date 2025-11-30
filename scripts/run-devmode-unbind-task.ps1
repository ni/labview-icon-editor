param(
    [string] $RepositoryPath = '.'
)

$repoRoot = Resolve-Path -Path $RepositoryPath -ErrorAction Stop
$binderScript = Join-Path $repoRoot 'scripts/task-devmode-bind.ps1'
if (-not (Test-Path $binderScript)) {
    throw "binder script not found: $binderScript"
}

$logDir = Join-Path $repoRoot 'reports/logs'
New-Item -ItemType Directory -Force -Path $logDir | Out-Null
$timestamp = (Get-Date).ToString('yyyyMMddHHmmss')
$logFile = Join-Path $logDir "devmode-unbind-task-$timestamp.log"

Start-Transcript -Path $logFile -Force
try {
    Write-Host "Running DevMode unbind task via $binderScript"
    pwsh -NoProfile -File $binderScript -RepositoryPath $repoRoot -Mode unbind -Bitness auto
}
finally {
    Stop-Transcript | Out-Null
}
