[CmdletBinding()]
param(
    [string]$Repo = (Get-Location).ProviderPath,
    [string]$RunKey,
    [int]$LockTtlSec = 900,
    [switch]$ForceLock,
[ValidateSet('32','64')][string]$SupportedBitness = '64',
[int]$PackageLabVIEWVersion = 2025,
[ValidateSet('0','3')][string]$LabVIEWMinorRevision = '3',
[int]$Major = 0,
    [int]$Minor = 1,
    [int]$Patch = 0,
    [int]$Build = 0,
    [string]$OllamaEndpoint = 'http://localhost:11435',
    [string]$OllamaModel = 'llama3-8b-local',
    [string]$OllamaPrompt = 'local-sd/local-sd-ppl',
    [int]$PwshTimeoutSec = 7200,
    [switch]$SmokeOnly
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$repoRoot = (Resolve-Path -LiteralPath $Repo).ProviderPath
$resolvedRunKey = if ($RunKey) { $RunKey } else { "ollama-sd-ppl-$((Get-Date).ToString('yyyyMMdd-HHmmss'))" }

$logDir = Join-Path $repoRoot 'reports/logs'
New-Item -ItemType Directory -Path $logDir -Force | Out-Null
$logPath = Join-Path $logDir "ollama-host-$resolvedRunKey.log"
$simMode = [string]::Equals($env:OLLAMA_EXECUTOR_MODE, 'sim', 'OrdinalIgnoreCase')

function Ensure-DotnetOnPath {
    if (Get-Command dotnet -ErrorAction SilentlyContinue) { return }
    $homeDotnet = Join-Path $HOME '.dotnet'
    if (Test-Path -LiteralPath $homeDotnet) {
        $env:DOTNET_ROOT = $homeDotnet
        $env:PATH = "$homeDotnet;$homeDotnet\tools;$env:PATH"
    }
}

function Ensure-LockPath([string]$Path) {
    $dir = Split-Path -Parent $Path
    if ($dir -and -not (Test-Path -LiteralPath $dir)) {
        New-Item -ItemType Directory -Path $dir -Force | Out-Null
    }
    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
        New-Item -ItemType File -Path $Path -Force | Out-Null
    }
    return (Resolve-Path -LiteralPath $Path).Path
}

Ensure-DotnetOnPath
if (-not (Get-Command dotnet -ErrorAction SilentlyContinue)) {
    throw "dotnet SDK not found. Install .NET 8 or set DOTNET_ROOT/adjust PATH before running Run-Ollama-Host.ps1."
}

function Get-AppliedRequirements {
    $raw = $env:OLLAMA_REQUIREMENTS_APPLIED
    if ($raw) {
        return ($raw -split '[,\s]+' | Where-Object { $_ }) | Select-Object -Unique
    }
    return @('OEX-PARITY-001','OEX-PARITY-002','OEX-PARITY-003','OEX-PARITY-004')
}

$localScript = Join-Path $repoRoot 'scripts/orchestration/Run-LocalSd-Ppl.ps1'
if (-not (Test-Path -LiteralPath $localScript -PathType Leaf)) {
    throw "Local SD/PPL helper missing at $localScript"
}

function Rel([string]$Path) {
    return [System.IO.Path]::GetRelativePath($repoRoot, $Path)
}

function Invoke-WithTimeout {
    param(
        [string]$FilePath,
        [string[]]$Arguments,
        [int]$TimeoutSec
    )
    $psi = New-Object System.Diagnostics.ProcessStartInfo
    $psi.FileName = $FilePath
    $psi.Arguments = [string]::Join(' ', $Arguments)
    $psi.RedirectStandardOutput = $true
    $psi.RedirectStandardError = $true
    $psi.UseShellExecute = $false
    $psi.CreateNoWindow = $true
    $proc = New-Object System.Diagnostics.Process
    $proc.StartInfo = $psi
    $null = $proc.Start()
    if (-not $proc.WaitForExit($TimeoutSec * 1000)) {
        try { $proc.Kill() } catch {}
        return @{ ExitCode = 124; StdOut = ''; StdErr = "Timed out after $TimeoutSec seconds."; DurationMs = $TimeoutSec * 1000 }
    }
    $out = $proc.StandardOutput.ReadToEnd()
    $err = $proc.StandardError.ReadToEnd()
    return @{ ExitCode = $proc.ExitCode; StdOut = $out; StdErr = $err; DurationMs = 0 }
}

if ($SmokeOnly) {
    $args = @(
        'run','--project','Tooling/dotnet/OrchestrationCli/OrchestrationCli.csproj','--',
        'ollama','--ollama-endpoint', $OllamaEndpoint, '--ollama-model', $OllamaModel, '--ollama-prompt', $OllamaPrompt
    )
    Write-Host "[ollama-host] smoke: invoking OrchestrationCli ollama endpoint=$OllamaEndpoint model=$OllamaModel prompt=\"$OllamaPrompt\""
    $result = Invoke-WithTimeout -FilePath 'dotnet' -Arguments $args -TimeoutSec $PwshTimeoutSec
    $result.StdOut | Tee-Object -FilePath $logPath
    if ($result.ExitCode -ne 0) {
        Write-Host "[ollama-host] smoke failed exit=$($result.ExitCode) err=$($result.StdErr)"
        exit $result.ExitCode
    }
    Write-Host "[ollama-host] smoke success (ollama call only)"
    exit 0
}

if ($simMode) {
    $messages = @()
    function LogSim([string]$msg) {
        $script:messages += $msg
        Write-Host $msg
    }

    $lockPath = Join-Path $repoRoot '.locks/orchestration.lock'
    $artifactsDir = Join-Path $repoRoot 'artifacts'
    $buildsArtifacts = Join-Path $repoRoot 'builds/artifacts'
    $isoRoot = Join-Path $repoRoot 'builds-isolated'
    $runDir = Join-Path $isoRoot $resolvedRunKey

    foreach ($dir in @($artifactsDir, $buildsArtifacts, $isoRoot)) {
        New-Item -ItemType Directory -Path $dir -Force | Out-Null
    }

    $zipPath = Join-Path $artifactsDir 'labview-icon-api.zip'
    $pplPath = Join-Path $artifactsDir 'labview-icon-api.ppl'

    "SIMULATION MODE - stub source distribution for $resolvedRunKey" | Set-Content -LiteralPath $zipPath -Encoding utf8
    "SIMULATION MODE - stub PPL for $resolvedRunKey" | Set-Content -LiteralPath $pplPath -Encoding utf8

    Copy-Item -LiteralPath $zipPath -Destination (Join-Path $buildsArtifacts (Split-Path $zipPath -Leaf)) -Force
    Copy-Item -LiteralPath $pplPath -Destination (Join-Path $buildsArtifacts (Split-Path $pplPath -Leaf)) -Force

    $zipHash = (Get-FileHash -LiteralPath $zipPath -Algorithm SHA256).Hash
    $pplHash = (Get-FileHash -LiteralPath $pplPath -Algorithm SHA256).Hash

    $appliedReqs = Get-AppliedRequirements
    $handshake = @{
        runKey     = $resolvedRunKey
        lockPath   = (Ensure-LockPath -Path $lockPath)
        lockTtlSec = $LockTtlSec
        forceLock  = $ForceLock.IsPresent
        zipRelPath = (Rel $zipPath)
        zipSha256  = $zipHash
        pplRelPath = (Rel $pplPath)
        pplSha256  = $pplHash
        timestampUtc = (Get-Date).ToUniversalTime().ToString('o')
        mode       = 'sim'
        requirements = $appliedReqs
        prereqBypassed = $true
    }

    $handshakePath = Join-Path $artifactsDir 'labview-icon-api-handshake.json'
    ConvertTo-Json $handshake -Depth 5 | Set-Content -LiteralPath $handshakePath -Encoding utf8

    New-Item -ItemType Directory -Path $runDir -Force | Out-Null
    Copy-Item -Path $artifactsDir -Destination $runDir -Recurse -Force

    $summaryPath = Join-Path $logDir "ollama-host-$resolvedRunKey.summary.json"
    $handshake | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath $summaryPath -Encoding utf8

    LogSim "[ollama-host][sim] runKey=$resolvedRunKey lock=$($handshake.lockPath) ttl=$($handshake.lockTtlSec)s mode=sim"
    LogSim "[ollama-host][sim][requirements] applied=$($appliedReqs -join ',')"
    LogSim "[artifact][labview-icon-api.zip] $($handshake.zipRelPath) ($zipHash)"
    LogSim "[artifact][labview-icon-api.ppl] $($handshake.pplRelPath) ($pplHash)"
    LogSim "[ollama-host][sim] handshake=$((Rel $handshakePath))"
    LogSim "[ollama-host][sim] staged=$((Rel $runDir))"
    LogSim "[ollama-host][sim] summary-json=$((Rel $summaryPath))"
    $messages | Set-Content -LiteralPath $logPath -Encoding utf8
    exit 0
}

$cmd = @(
    '-NoProfile', '-ExecutionPolicy', 'Bypass',
    '-File', $localScript,
    '-Repo', $repoRoot,
    '-RunKey', $resolvedRunKey,
    '-LockTtlSec', $LockTtlSec,
    '-SupportedBitness', $SupportedBitness,
    '-PackageLabVIEWVersion', $PackageLabVIEWVersion,
    '-Major', $Major, '-Minor', $Minor, '-Patch', $Patch, '-Build', $Build
)
if ($ForceLock) { $cmd += '-ForceLock' }

Write-Host "[ollama-host] starting local-sd-ppl runKey=$resolvedRunKey ttl=${LockTtlSec}s force=$($ForceLock.IsPresent) log=$(Rel $logPath) endpoint=$OllamaEndpoint model=$OllamaModel prompt=\"$OllamaPrompt\" timeout=${PwshTimeoutSec}s"
$result = Invoke-WithTimeout -FilePath 'pwsh' -Arguments $cmd -TimeoutSec $PwshTimeoutSec
$output = $result.StdOut + $result.StdErr
$output | Tee-Object -FilePath $logPath
$exitCode = $result.ExitCode
if ($exitCode -ne 0) {
    $details = [ordered]@{
        detection_point = 'orchestration'
        endpoint        = $OllamaEndpoint
        model           = $OllamaModel
        prompt          = $OllamaPrompt
        exitCode        = $exitCode
        error           = $result.StdErr
    }
    $detailsJson = $details | ConvertTo-Json -Depth 4
    $detailsPath = Join-Path $logDir "ollama-host-$resolvedRunKey.fail.json"
    $detailsJson | Set-Content -LiteralPath $detailsPath -Encoding utf8
    Write-Host "[ollama-host] fail: exit=$exitCode detection_point=orchestration details=$(Rel $detailsPath)"
    exit $exitCode
}

$handshakePath = Join-Path $repoRoot 'artifacts/labview-icon-api-handshake.json'
if (-not (Test-Path -LiteralPath $handshakePath -PathType Leaf)) {
    throw "Handshake JSON not found at $handshakePath"
}
$handshake = Get-Content -LiteralPath $handshakePath | ConvertFrom-Json

$zipPath = Join-Path $repoRoot $handshake.zipRelPath
$pplPath = if ($handshake.pplRelPath) { Join-Path $repoRoot $handshake.pplRelPath } else { $null }

$summary = [ordered]@{
    runKey     = $resolvedRunKey
    handshake  = Rel $handshakePath
    lock       = $handshake.lockPath
    zip        = @{
        path   = Rel $zipPath
        sha256 = $handshake.zipSha256
    }
    ppl        = if ($pplPath) { @{ path = Rel $pplPath; sha256 = $handshake.pplSha256 } } else { $null }
    staged     = @{
        artifacts = 'artifacts/'
        runScoped = Rel (Join-Path $repoRoot ("builds-isolated/$resolvedRunKey"))
    }
    ollama = @{
        endpoint = $OllamaEndpoint
        model    = $OllamaModel
        prompt   = $OllamaPrompt
    }
}

$summaryJson = $summary | ConvertTo-Json -Depth 5
$summaryPath = Join-Path $logDir "ollama-host-$resolvedRunKey.summary.json"
$summaryJson | Set-Content -LiteralPath $summaryPath -Encoding utf8

$summaryLines = @(
    "[ollama-host] runKey=$($summary.runKey)",
    "[ollama-host] handshake=$($summary.handshake)",
    "[ollama-host] zip=$($summary.zip.path) sha256=$($summary.zip.sha256)",
    $(if ($summary.ppl) { "[ollama-host] ppl=$($summary.ppl.path) sha256=$($summary.ppl.sha256)" } else { "[ollama-host] ppl=<not-produced>" }),
    "[ollama-host] runScoped=$($summary.staged.runScoped)",
    "[ollama-host] summary-json=$(Rel $summaryPath)"
)
$summaryLines | Tee-Object -FilePath $logPath -Append | ForEach-Object { Write-Host $_ }

Write-Host "[ollama-host] next: use the runKey + hashes in the Windows Ollama container prompt (ORCH-020B) after this host run completes."
