param(
    [switch]$NoParallel,
    [int]$HeartbeatSec = 30  # per-step heartbeat (seconds); override via env QA_HEARTBEAT_SEC
)
$script:__qaNoParallelBound = $PSBoundParameters.ContainsKey('NoParallel')
# Default: run tests without parallelism unless explicitly enabled
if (-not $script:__qaNoParallelBound) {
    $NoParallel = $true
    try {
        $enable = $env:QA_ENABLE_PARALLEL
        if ($enable -and ($enable -match '^(1|true|yes|on)$')) { $NoParallel = $false }
    } catch {}
}
$root = Split-Path -Parent $MyInvocation.MyCommand.Path
$sln = Join-Path $root '..\XCli.sln'
$proj = Join-Path $root '..\src\XCli\XCli.csproj'
$stream = Join-Path $root 'stream-output.ps1'
# Ensure commands that expect x-cli root run with that as CWD
$repoRoot = Resolve-Path (Join-Path $root '..')
Push-Location $repoRoot
# Ensure all external commands stream output line-by-line for CI
# visibility by routing through the helper.
$telemetryFile = Join-Path $root '..\artifacts\qa-telemetry.jsonl'
New-Item -ItemType Directory -Force -Path (Split-Path $telemetryFile) | Out-Null
if (Test-Path $telemetryFile) { Remove-Item $telemetryFile }
New-Item -ItemType File -Path $telemetryFile -Force | Out-Null

$logDir = Join-Path $root '..\artifacts\logs'
New-Item -ItemType Directory -Force -Path $logDir | Out-Null

# Force UTF-8 for Python to avoid cp1252 output stalls on Windows consoles
$env:PYTHONUTF8 = '1'
$env:PYTHONIOENCODING = 'utf-8'

# Stabilize pytest temp/cache locations for idempotent local runs (esp. Windows)
try {
  $env:PYTEST_ADDOPTS = (($env:PYTEST_ADDOPTS + ' --basetemp=.pytest_tmp').Trim())
  # Prefer pytest's progress-style console output so users see live status
  $env:PYTEST_ADDOPTS = (($env:PYTEST_ADDOPTS + ' -o console_output_style=progress').Trim())
  $pytestTmp   = Join-Path $repoRoot '.pytest_tmp'
  $pytestCache = Join-Path $repoRoot '.pytest_cache'
  if (Test-Path $pytestTmp)   { Remove-Item -Recurse -Force -ErrorAction SilentlyContinue $pytestTmp }
  New-Item -ItemType Directory -Force -Path $pytestTmp | Out-Null
  # Best-effort: clear cache to avoid stale state between runs
  if (Test-Path $pytestCache) { Remove-Item -Recurse -Force -ErrorAction SilentlyContinue $pytestCache }
} catch {}

function Run-Step {
    param(
        [string]$Name,
        [scriptblock]$Block
    )
    $start = [DateTimeOffset]::UtcNow.ToUnixTimeMilliseconds()
    Write-Host "==> [$Name] start $start"
    $logFile = Join-Path $logDir "$Name.log"
    # Resolve heartbeat interval (param <- env QA_HEARTBEAT_SEC) and start if > 0
    $hbInterval = $HeartbeatSec
    try {
        if ($env:QA_HEARTBEAT_SEC) {
            $tmp = 0; if ([int]::TryParse($env:QA_HEARTBEAT_SEC, [ref]$tmp)) { $hbInterval = $tmp }
        }
    } catch {}
    if ($hbInterval -lt 0) { $hbInterval = 0 }
    $hb = $null
    if ($hbInterval -gt 0) {
        # Clamp to sane bounds (5s..300s)
        if ($hbInterval -lt 5) { $hbInterval = 5 }
        if ($hbInterval -gt 300) { $hbInterval = 300 }
        # Start a lightweight heartbeat that appends to the step log to avoid perceived stalls
        $hb = Start-Job -ArgumentList $logFile, $hbInterval -ScriptBlock {
            param($lf, $interval)
            while ($true) {
                Start-Sleep -Seconds $interval
                $line = "[heartbeat] $(Get-Date -Format o) interval=${interval}s"
                try { Add-Content -Path $lf -Value $line -Encoding utf8 } catch {}
                Write-Host $line
            }
        }
    }
    try {
        & $Block 2>&1 | Tee-Object -FilePath $logFile
    } finally {
        try { if ($hb) { Stop-Job -Job $hb -Force -ErrorAction SilentlyContinue } } catch {}
        try { if ($hb) { Remove-Job -Job $hb -Force -ErrorAction SilentlyContinue } } catch {}
    }
    $exit = $LASTEXITCODE
    $end = [DateTimeOffset]::UtcNow.ToUnixTimeMilliseconds()
    $runtime = $end - $start
    Write-Host "<== [$Name] end $end (${runtime}ms) (exit $exit)"
    if ($exit -eq 0) {
        $status = 'pass'
    } else {
        $status = 'fail'
    }
    $obj = @{step=$Name; start=$start; end=$end; duration_ms=$runtime; status=$status}
    if ($exit -ne 0) { $obj.exit_code = $exit }
    # Prefer C# telemetry writer if available; fallback to PowerShell JSONL append
    $wrote = $false
    try {
        $xcli = Resolve-Path 'src/\XCli/\bin/\Release/\net8.0/\win-x64/\XCli.dll' -ErrorAction SilentlyContinue
        if ($xcli) {
            & $stream -Command dotnet -Args @($xcli.Path,'telemetry','write','--out',$telemetryFile.Replace('\\','/'),'--step',$Name,'--status',$status,'--duration-ms',[string]$runtime,'--start',[string]$start,'--end',[string]$end) | Out-Null
            if ($LASTEXITCODE -eq 0) { $wrote = $true }
        }
    } catch {}
    if (-not $wrote) {
        ($obj | ConvertTo-Json -Compress) | Out-File -FilePath $telemetryFile -Encoding utf8 -Append
    }
    if ($exit -ne 0) { exit $exit }
}

# Install .NET SDK and Python dependencies
Run-Step 'install-deps' {
    $bashOk = $false
    try {
        bash -lc "exit 0" 2>$null
        if ($LASTEXITCODE -eq 0) { $bashOk = $true }
    } catch {}
    if ($bashOk) {
        & $stream -Command bash -Args @("$root/install_dependencies.sh")
    } elseif (Test-Path (Join-Path $root 'install_dependencies.ps1')) {
        & $stream -Command pwsh -Args @('-File', (Join-Path $root 'install_dependencies.ps1'))
    } else {
        # Minimal inline fallback: install editable package and test tooling
        & $stream -Command python -Args @('-m','pip','install','-U','pip')
        & $stream -Command python -Args @('-m','pip','install','pytest','pytest-timeout','pytest-xdist','pytest-cov','coverage','pre-commit','ruamel.yaml')
    }
}

# Ensure telemetry modules expose agent feedback
Run-Step 'agent-feedback' { & $stream -Command python -Args @('-X','utf8',"$root\check_agent_feedback.py") }

# Ensure commit message follows template (HEAD commit). Non-blocking unless QA_STRICT_COMMIT_MSG=1
Run-Step 'commit-msg' {
    $authorEmail = (& git show -s --format=%ae HEAD)
    $configEmail = (& git config user.email)
    $headMsg = (& git show -s --format=%B HEAD)
    $isLocal = $false
    if ($LASTEXITCODE -eq 0) {
        try {
            if (-not [string]::IsNullOrWhiteSpace($authorEmail) -and -not [string]::IsNullOrWhiteSpace($configEmail)) {
                $isLocal = ($authorEmail.Trim().ToLowerInvariant() -eq $configEmail.Trim().ToLowerInvariant())
            }
        } catch {}
    }
    if (-not $isLocal) {
        Write-Host '::notice::Skipping commit-msg enforcement: HEAD author does not match local user.email'
        return
    }
    if ($LASTEXITCODE -eq 0 -and ($headMsg -join '').Trim()) {
        $tmp = Join-Path $repoRoot 'artifacts\HEAD_COMMIT_MSG.txt'
        New-Item -ItemType Directory -Force -Path (Split-Path $tmp) | Out-Null
        # Write UTF-8 without BOM to match parser expectations
        [System.IO.File]::WriteAllText($tmp, ($headMsg -join "`n"), (New-Object System.Text.UTF8Encoding($false)))
        & $stream -Command python -Args @('-X','utf8',"$root\check-commit-msg.py", $tmp)
        $rc = $LASTEXITCODE
        if ($rc -ne 0) {
            if ($env:QA_STRICT_COMMIT_MSG -eq '1') {
                exit $rc
            } else {
                Write-Host '::warning::commit-msg check failed (non-blocking). Set QA_STRICT_COMMIT_MSG=1 to enforce.'
                $global:LASTEXITCODE = 0
            }
        }
    } else {
        Write-Host "::notice::Skipping commit-msg check: unable to read HEAD commit message"
    }
}

# Enforce ASCII-only H1 titles for changed SRS files
Run-Step 'srs-title-ascii' { & $stream -Command python -Args @('-X','utf8',(Join-Path $root 'check_srs_title_ascii.py')) }

# Verify changed SRS IDs are mapped in traceability and module maps
Run-Step 'verify-new-srs-mappings' { & $stream -Command python -Args @('-X','utf8',(Join-Path $root 'verify_new_srs_mappings.py')) }

# Ensure pre-commit hook IDs have doc links
Run-Step 'precommit-hook-links' { & $stream -Command python -Args @('-X','utf8',(Join-Path $root 'check_precommit_hook_links.py')) }

# Lint pre-commit templates (dry-run)
Run-Step 'precommit-template-dryrun' { & $stream -Command python -Args @('-X','utf8',(Join-Path $root 'sync_precommit_templates.py'), '--dry-run') }

# PowerShell script lint (PSScriptAnalyzer)
Run-Step 'pssa-install' {
    try {
        if (-not (Get-Module -ListAvailable -Name PSScriptAnalyzer)) {
            try { Set-PSRepository -Name 'PSGallery' -InstallationPolicy Trusted -ErrorAction Stop } catch {}
            Install-Module -Name PSScriptAnalyzer -Scope CurrentUser -Force -ErrorAction Stop | Out-Null
        }
        Import-Module PSScriptAnalyzer -ErrorAction Stop
    } catch {
        Write-Error "Failed to install/load PSScriptAnalyzer: $($_.Exception.Message)"
        throw
    }
}
Run-Step 'pssa-lint' {
    Import-Module PSScriptAnalyzer -ErrorAction Stop
    Invoke-ScriptAnalyzer -Path 'scripts' -Recurse -Severity Error -EnableExit
}

# Build both Release and Debug to prevent stale outputs
Run-Step 'build-release' { & $stream -Command dotnet -Args @('build', $sln, '-c', 'Release') }
Run-Step 'build-debug' { & $stream -Command dotnet -Args @('build', $sln, '-c', 'Debug') }

# Run Python tests with hang detection
$tests = Join-Path $root '..\tests'
# Quick discovery to emit an early count before running (helps during long collections)
Run-Step 'test-discover' {
    try {
        $args = @('-X','utf8','-m','pytest', $tests, '--collect-only','-q')
        if ($NoParallel) { $args += @('-p','no:xdist') }
        $out = & python @args 2>$null
        $cnt = ($out | Where-Object { $_ -and ($_ -notmatch '^=') } | Measure-Object -Line).Lines
        if (-not $cnt) { $cnt = 0 }
        Write-Host "pytest: discovered approx $cnt tests"
    } catch {
        Write-Host "pytest: discovery attempted (collect-only)"
    }
}
if ($NoParallel) {
    Run-Step 'test-python' { & $stream -Command python -Args @('-X','utf8','-m','pytest', $tests,'-vv','--timeout=300','--durations=20','--maxfail=1','--basetemp=.pytest_tmp','-p','no:xdist') }
} else {
    Run-Step 'test-python' { & $stream -Command python -Args @('-X','utf8','-m','pytest', $tests,'-vv','-n','auto','--dist','loadfile','--timeout=300','--durations=20','--maxfail=1','--basetemp=.pytest_tmp') }
}

# Run tests against Release build with hang detection
if ($NoParallel) {
    Run-Step 'test-release' { & $stream -Command dotnet -Args @('test', $sln, '-c', 'Release', '--no-build', '--logger:console;verbosity=minimal', '--logger:trx;LogFileName=test-results.trx', '--blame-hang', '--blame-hang-timeout', '5m', '--', 'RunConfiguration.DisableParallelization=true') }
} else {
    Run-Step 'test-release' { & $stream -Command dotnet -Args @('test', $sln, '-c', 'Release', '--no-build', '--logger:console;verbosity=minimal', '--logger:trx;LogFileName=test-results.trx', '--blame-hang', '--blame-hang-timeout', '5m') }
}
Run-Step 'summarize-tests' { & $stream -Command python -Args @('-X','utf8',"$root\summarize_dotnet_tests.py", (Join-Path $root '..')) }

# Publish single-file binaries for linux-x64 and win-x64
# FGC-REQ-DIST-001: cross-platform artifact publication
Run-Step 'publish' { & $stream -Command pwsh -Args @('-File', (Join-Path $root 'build.ps1')) }

# Smoke run '--help'
Run-Step 'smoke-help' { & $stream -Command dotnet -Args @('run', '--project', $proj, '--no-build', '--', '--help') }

# Summarize QA telemetry JSONL via CLI (C# standardization)
Run-Step 'qa-telemetry-summarize' {
    $xcliPath = Resolve-Path (Join-Path $repoRoot 'src\XCli\bin\Release\net8.0\win-x64\XCli.dll')
    & $stream -Command dotnet -Args @($xcliPath.Path, 'telemetry','summarize','--in','artifacts/qa-telemetry.jsonl','--out','telemetry/summary.json','--history','telemetry/qa-summary-history.jsonl')
}

# Optional schema validation (set QA_VALIDATE_SCHEMA=1)
Run-Step 'qa-telemetry-validate' {
    if ($env:QA_VALIDATE_SCHEMA -ne '1') {
        Write-Host 'Skipping telemetry validation: QA_VALIDATE_SCHEMA not set to 1'
        return
    }
    $xcliPath = Resolve-Path (Join-Path $repoRoot 'src\XCli\bin\Release\net8.0\win-x64\XCli.dll')
    $summarySchema = Join-Path $repoRoot 'docs\schemas\v1\telemetry.summary.v1.schema.json'
    $eventsSchema  = Join-Path $repoRoot 'docs\schemas\v1\telemetry.events.v1.schema.json'
    & $stream -Command dotnet -Args @($xcliPath.Path, 'telemetry','validate','--summary','telemetry/summary.json','--schema',$summarySchema)
    & $stream -Command dotnet -Args @($xcliPath.Path, 'telemetry','validate','--events','artifacts/qa-telemetry.jsonl','--schema',$eventsSchema)
}

# Optional gate on failures using MAX_QA_FAILURES env var
Run-Step 'qa-telemetry-check' {
    $max = $env:MAX_QA_FAILURES
    $perStep = $env:MAX_QA_FAILURES_STEP
    if ([string]::IsNullOrWhiteSpace($max)) {
        if ([string]::IsNullOrWhiteSpace($perStep)) {
            Write-Host 'Skipping telemetry check: MAX_QA_FAILURES / MAX_QA_FAILURES_STEP not set'
            return
        }
    }
    $xcliPath = Resolve-Path (Join-Path $repoRoot 'src\XCli\bin\Release\net8.0\win-x64\XCli.dll')
    $args = @($xcliPath.Path, 'telemetry','check','--summary','telemetry/summary.json')
    if (-not [string]::IsNullOrWhiteSpace($max)) { $args += @('--max-failures', $max) }
    if (-not [string]::IsNullOrWhiteSpace($perStep)) {
        foreach ($item in ($perStep -split ',')) {
            $kv = $item.Trim()
            if (-not [string]::IsNullOrWhiteSpace($kv) -and $kv.Contains('=')) {
                $args += @('--max-failures-step', $kv)
            }
        }
    }
    & $stream -Command dotnet -Args $args
}

# Restore original location
Pop-Location
