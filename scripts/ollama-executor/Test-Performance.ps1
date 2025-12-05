<#
.SYNOPSIS
  Performance benchmark suite for Ollama executor.

.DESCRIPTION
  Measures and reports performance metrics including throughput, latency, memory usage,
  and artifact creation time. Compares against baselines to detect regressions.

.PARAMETER Baseline
  Path to baseline performance data file. If not provided, creates new baseline.

.PARAMETER OutputReport
  Path to save performance report (default: reports/performance-benchmark.json)

.EXAMPLE
  # Create baseline
  pwsh -NoProfile -File scripts/ollama-executor/Test-Performance.ps1

  # Compare against baseline
  pwsh -NoProfile -File scripts/ollama-executor/Test-Performance.ps1 -Baseline baseline.json
#>

[CmdletBinding()]
param(
    [string]$Baseline = "",
    [string]$OutputReport = "reports/performance-benchmark.json"
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

Write-Host "=== Ollama Executor Performance Benchmark Suite ===" -ForegroundColor Cyan
Write-Host ""

# Cache OS detection for performance (avoid repeated checks)
$script:cachedIsWindows = if ($null -ne $IsWindows) { $IsWindows } else { $false }
$script:cachedIsLinux = if ($null -ne $IsLinux) { $IsLinux } else { $false }
$script:cachedIsMacOS = if ($null -ne $IsMacOS) { $IsMacOS } else { $false }

# Ensure reports directory exists
$reportDir = Split-Path $OutputReport -Parent
if ($reportDir -and -not (Test-Path $reportDir)) {
    New-Item -ItemType Directory -Path $reportDir -Force | Out-Null
}

$results = @{
    timestamp = Get-Date -Format 'o'
    environment = @{
        os = if ($script:cachedIsWindows) { "Windows" } elseif ($script:cachedIsLinux) { "Linux" } elseif ($script:cachedIsMacOS) { "macOS" } else { "Unknown" }
        pwsh_version = $PSVersionTable.PSVersion.ToString()
        processor_count = [Environment]::ProcessorCount
    }
    benchmarks = @{}
}

function Measure-Benchmark {
    param(
        [string]$Name,
        [scriptblock]$ScriptBlock,
        [int]$Iterations = 1
    )
    
    Write-Host "Running benchmark: $Name ($Iterations iterations)" -ForegroundColor Yellow
    
    $measurements = @()
    $memoryBefore = [GC]::GetTotalMemory($true)
    
    for ($i = 0; $i -lt $Iterations; $i++) {
        $sw = [Diagnostics.Stopwatch]::StartNew()
        $result = & $ScriptBlock
        $sw.Stop()
        
        $measurements += @{
            iteration = $i + 1
            duration_ms = $sw.ElapsedMilliseconds
            result = $result
        }
    }
    
    $memoryAfter = [GC]::GetTotalMemory($false)
    $memoryDelta = $memoryAfter - $memoryBefore
    
    $durations = $measurements | ForEach-Object { $_.duration_ms }
    $avgDuration = ($durations | Measure-Object -Average).Average
    $minDuration = ($durations | Measure-Object -Minimum).Minimum
    $maxDuration = ($durations | Measure-Object -Maximum).Maximum
    
    $benchmark = @{
        name = $Name
        iterations = $Iterations
        avg_duration_ms = [math]::Round($avgDuration, 2)
        min_duration_ms = $minDuration
        max_duration_ms = $maxDuration
        memory_delta_bytes = $memoryDelta
        measurements = $measurements
    }
    
    Write-Host "  Avg: $($benchmark.avg_duration_ms)ms, Min: $($benchmark.min_duration_ms)ms, Max: $($benchmark.max_duration_ms)ms" -ForegroundColor Gray
    Write-Host "  Memory delta: $([math]::Round($memoryDelta / 1MB, 2))MB" -ForegroundColor Gray
    
    return $benchmark
}

# Benchmark 1: Command Vetting Performance
$results.benchmarks.command_vetting = Measure-Benchmark -Name "Command Vetting (1000 commands)" -Iterations 1 -ScriptBlock {
    # Simple inline vetting function (core security checks only)
    function Test-CommandAllowed {
        param([string]$Command)
        
        # Allow only repo scripts invoked via pwsh -NoProfile -File scripts/...
        $allowedPattern = '^pwsh\s+-NoProfile\s+-File\s+scripts[\\/][\w\-.\\/]+\.ps1\b'
        if (-not ($Command -match $allowedPattern)) {
            return "Rejected: command must start with 'pwsh -NoProfile -File scripts/...ps1'"
        }
        
        # Check for path traversal (parent directory references)
        if ($Command -match '\.\.[/\\]' -or $Command -match '[/\\]\.\.') {
            return "Rejected: path traversal attempt detected (..)"
        }
        
        # Check for command chaining/injection
        if ($Command -match '[;&|`]' -or $Command -match '\$\(') {
            return "Rejected: command injection attempt detected"
        }
        
        return $null  # Allowed
    }
    
    $commands = @(
        "pwsh -NoProfile -File scripts/test.ps1"
        "pwsh -NoProfile -File scripts/build-source-distribution/Build_Source_Distribution.ps1 -RepositoryPath . -Package_LabVIEW_Version 2025 -SupportedBitness 64"
        "rm -rf /"
        "pwsh -NoProfile -File scripts/../other.ps1"
    )
    
    $vetted = 0
    for ($i = 0; $i -lt 1000; $i++) {
        $cmd = $commands[$i % $commands.Count]
        $result = Test-CommandAllowed -Command $cmd
        if ($null -eq $result) { $vetted++ }
    }
    
    return @{ total = 1000; vetted = $vetted }
}

# Benchmark 2: Mock Server Response Time
$results.benchmarks.mock_server_response = Measure-Benchmark -Name "Mock Server Response (100 requests)" -Iterations 1 -ScriptBlock {
    $mockJob = Start-Job -ScriptBlock {
        & "$using:PSScriptRoot/MockOllamaServer.ps1" -Port 11438 -ResponseDelay 0 -MaxRequests 150
    }
    
    try {
        Start-Sleep -Seconds 2
        
        $requestTimes = @()
        for ($i = 0; $i -lt 100; $i++) {
            $sw = [Diagnostics.Stopwatch]::StartNew()
            $response = Invoke-RestMethod -Uri "http://localhost:11438/api/tags" -Method Get -ErrorAction SilentlyContinue
            $sw.Stop()
            $requestTimes += $sw.ElapsedMilliseconds
        }
        
        $avgResponseTime = ($requestTimes | Measure-Object -Average).Average
        return @{ avg_response_ms = [math]::Round($avgResponseTime, 2); requests = 100 }
    }
    finally {
        Stop-Job $mockJob -ErrorAction SilentlyContinue
        Remove-Job $mockJob -Force -ErrorAction SilentlyContinue
    }
}

# Benchmark 3: Simulation Mode Overhead
$env:OLLAMA_EXECUTOR_MODE = "sim"
$env:OLLAMA_SIM_DELAY_MS = "0"
$env:OLLAMA_SIM_CREATE_ARTIFACTS = "false"

$results.benchmarks.simulation_overhead = Measure-Benchmark -Name "Simulation Provider (100 calls)" -Iterations 1 -ScriptBlock {
    $times = @()
    for ($i = 0; $i -lt 100; $i++) {
        $sw = [Diagnostics.Stopwatch]::StartNew()
        $result = & "$PSScriptRoot/SimulationProvider.ps1" `
            -Command "pwsh -NoProfile -File scripts/build-source-distribution/Build_Source_Distribution.ps1 -RepositoryPath . -Package_LabVIEW_Version 2025 -SupportedBitness 64" `
            -WorkingDirectory "."
        $sw.Stop()
        $times += $sw.ElapsedMilliseconds
    }
    
    $avgTime = ($times | Measure-Object -Average).Average
    return @{ avg_call_ms = [math]::Round($avgTime, 2); calls = 100 }
}

Remove-Item Env:\OLLAMA_EXECUTOR_MODE -ErrorAction SilentlyContinue
Remove-Item Env:\OLLAMA_SIM_DELAY_MS -ErrorAction SilentlyContinue
Remove-Item Env:\OLLAMA_SIM_CREATE_ARTIFACTS -ErrorAction SilentlyContinue

# Benchmark 4: Artifact Creation Performance
$env:OLLAMA_EXECUTOR_MODE = "sim"
$env:OLLAMA_SIM_DELAY_MS = "0"
$env:OLLAMA_SIM_CREATE_ARTIFACTS = "true"

$results.benchmarks.artifact_creation = Measure-Benchmark -Name "Artifact Creation (10 artifacts)" -Iterations 1 -ScriptBlock {
    $tempBase = if ($env:TEMP) { $env:TEMP } else { "/tmp" }
    $testDir = Join-Path $tempBase "perf-artifacts-$(New-Guid)"
    New-Item -ItemType Directory -Path $testDir -Force | Out-Null
    
    try {
        $times = @()
        for ($i = 0; $i -lt 10; $i++) {
            $sw = [Diagnostics.Stopwatch]::StartNew()
            $result = & "$PSScriptRoot/SimulationProvider.ps1" `
                -Command "pwsh -NoProfile -File scripts/build-source-distribution/Build_Source_Distribution.ps1 -RepositoryPath $testDir -Package_LabVIEW_Version 2025 -SupportedBitness 64" `
                -WorkingDirectory $testDir
            $sw.Stop()
            $times += $sw.ElapsedMilliseconds
        }
        
        $avgTime = ($times | Measure-Object -Average).Average
        return @{ avg_creation_ms = [math]::Round($avgTime, 2); artifacts = 10 }
    }
    finally {
        Remove-Item $testDir -Recurse -Force -ErrorAction SilentlyContinue
    }
}

Remove-Item Env:\OLLAMA_EXECUTOR_MODE -ErrorAction SilentlyContinue
Remove-Item Env:\OLLAMA_SIM_DELAY_MS -ErrorAction SilentlyContinue
Remove-Item Env:\OLLAMA_SIM_CREATE_ARTIFACTS -ErrorAction SilentlyContinue

# Benchmark 5: Full Executor Throughput
$results.benchmarks.executor_throughput = Measure-Benchmark -Name "Full Executor Cycle (5 runs)" -Iterations 5 -ScriptBlock {
    $env:OLLAMA_EXECUTOR_MODE = "sim"
    $env:OLLAMA_SIM_DELAY_MS = "10"
    $env:OLLAMA_HOST = "http://localhost:11438"
    
    $mockJob = Start-Job -ScriptBlock {
        & "$using:PSScriptRoot/MockOllamaServer.ps1" -Port 11438 -MaxRequests 20
    }
    
    try {
        Start-Sleep -Seconds 2
        
        $tempBase = if ($env:TEMP) { $env:TEMP } else { "/tmp" }
        $testDir = Join-Path $tempBase "perf-executor-$(New-Guid)"
        New-Item -ItemType Directory -Path $testDir -Force | Out-Null
        
        $output = & "$PSScriptRoot/Drive-Ollama-Executor.ps1" `
            -Endpoint "http://localhost:11438" `
            -Model "llama3-8b-local" `
            -RepoPath $testDir `
            -Goal "Performance test" `
            -MaxTurns 3 `
            -StopAfterFirstCommand `
            2>&1 | Out-String
        
        Remove-Item $testDir -Recurse -Force -ErrorAction SilentlyContinue
        
        return @{ completed = $output -match "Done:" }
    }
    finally {
        Stop-Job $mockJob -ErrorAction SilentlyContinue
        Remove-Job $mockJob -Force -ErrorAction SilentlyContinue
        Remove-Item Env:\OLLAMA_EXECUTOR_MODE -ErrorAction SilentlyContinue
        Remove-Item Env:\OLLAMA_SIM_DELAY_MS -ErrorAction SilentlyContinue
        Remove-Item Env:\OLLAMA_HOST -ErrorAction SilentlyContinue
    }
}

# Save results
$results | ConvertTo-Json -Depth 10 | Set-Content $OutputReport
Write-Host ""
Write-Host "Performance report saved to: $OutputReport" -ForegroundColor Green

# Compare against baseline if provided
if ($Baseline -and (Test-Path $Baseline)) {
    Write-Host ""
    Write-Host "=== Performance Comparison ===" -ForegroundColor Cyan
    
    $baselineData = Get-Content $Baseline | ConvertFrom-Json
    
    foreach ($benchName in $results.benchmarks.Keys) {
        if ($baselineData.benchmarks.PSObject.Properties[$benchName]) {
            $current = $results.benchmarks.$benchName.avg_duration_ms
            $baseline = $baselineData.benchmarks.$benchName.avg_duration_ms
            $delta = $current - $baseline
            $pctChange = if ($baseline -gt 0) { [math]::Round(($delta / $baseline) * 100, 2) } else { 0 }
            
            $color = if ($delta -gt 0) { "Red" } elseif ($delta -lt 0) { "Green" } else { "White" }
            $symbol = if ($delta -gt 0) { "▲" } elseif ($delta -lt 0) { "▼" } else { "=" }
            
            Write-Host "  $benchName`: $current ms ($symbol $pctChange%)" -ForegroundColor $color
        }
    }
}

Write-Host ""
Write-Host "=== Benchmark Summary ===" -ForegroundColor Cyan
foreach ($benchName in $results.benchmarks.Keys) {
    $bench = $results.benchmarks.$benchName
    Write-Host "  $benchName`: $($bench.avg_duration_ms)ms avg" -ForegroundColor White
}

Write-Host ""
Write-Host "Benchmark suite completed! ✓" -ForegroundColor Green

# Explicit exit code for CI/CD
exit 0
