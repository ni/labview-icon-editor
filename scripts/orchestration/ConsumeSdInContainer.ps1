[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [string]$Repo,
    [Parameter(Mandatory)]
    [string]$HandshakePath,
    [Parameter(Mandatory)]
    [string]$RunKey,
    [switch]$Force,
    [switch]$KeepLock
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$repoRoot = (Resolve-Path -LiteralPath $Repo).ProviderPath
if (-not (Test-Path -LiteralPath $HandshakePath)) { throw "Handshake JSON not found at $HandshakePath" }

$handshake = Get-Content -LiteralPath $HandshakePath | ConvertFrom-Json
function Get-RelativePath {
    param([string]$Base, [string]$Target)
    return [System.IO.Path]::GetRelativePath($Base, $Target)
}
$zipPath = Join-Path $repoRoot $handshake.zipRelPath
$pplPath = Join-Path $repoRoot $handshake.pplRelPath
foreach ($path in @($zipPath, $pplPath)) {
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { throw "Required artifact missing: $path" }
}

$zipHash = (Get-FileHash -LiteralPath $zipPath -Algorithm SHA256).Hash
if ($zipHash -ne $handshake.zipSha256) {
    Write-Host "[consume-sd] hash mismatch for zip: staged=$($handshake.zipSha256) computed=$zipHash"
    throw "Zip hash mismatch"
}
Write-Host "[consume-sd] zip $(Get-RelativePath -Base $repoRoot -Target $zipPath) sha256=$zipHash"

$pplHash = (Get-FileHash -LiteralPath $pplPath -Algorithm SHA256).Hash
if ($handshake.pplSha256 -and $pplHash -ne $handshake.pplSha256) {
    Write-Host "[consume-sd] hash mismatch for ppl: staged=$($handshake.pplSha256) computed=$pplHash"
    throw "PPL hash mismatch"
}
Write-Host "[consume-sd] ppl $(Get-RelativePath -Base $repoRoot -Target $pplPath) sha256=$pplHash"

Write-Host "[consume-sd] runKey=$RunKey lock=$($handshake.lockPath) ttl=$($handshake.lockTtlSec)s force=$Force keepLock=$KeepLock"

$orchExe = '/app/OrchestrationCli'
if (-not (Test-Path -LiteralPath $orchExe -PathType Leaf)) { throw "OrchestrationCli binary not found at $orchExe" }

$orchArgs = @(
    'local-sd',
    '--repo',
    $repoRoot,
    '--run-key',
    $RunKey,
    '--lock-path',
    $handshake.lockPath,
    '--lock-ttl-sec',
    $handshake.lockTtlSec,
    '--skip-local-sd-build'
)
if ($Force) { $orchArgs += '--force-lock' }
if ($KeepLock) { $ENV:ORCH_KEEP_LOCK = '1' }

Write-Host "[consume-sd] invoking OrchestrationCli local-sd $(if ($Force) {'(force)'} else { ''})"
& $orchExe @orchArgs
$exitCode = $LASTEXITCODE
if ($exitCode -ne 0) {
    Write-Host "[consume-sd] OrchestrationCli exited $exitCode"
}
exit $exitCode
