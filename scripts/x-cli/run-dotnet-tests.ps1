param(
    [string]$RepoRoot = '.',
    [string]$OutputRoot = 'builds/tests/dotnet',
    [string]$ForceSimulationSubcommands = 'srs',
    [string]$BuildConfiguration = 'Debug',
    [switch]$WhatIf
)

$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'

$RepoRoot = (Resolve-Path $RepoRoot).Path
Set-Location $RepoRoot

$runId = Get-Date -Format 'yyyyMMdd-HHmmss'
$runDir = Join-Path $OutputRoot $runId
$null = New-Item -ItemType Directory -Force -Path $runDir

if (-not [string]::IsNullOrWhiteSpace($ForceSimulationSubcommands)) {
    $env:XCLI_FORCE_SIMULATION_SUBCOMMANDS = $ForceSimulationSubcommands
}

function Invoke-Step {
    param(
        [string[]]$Command,
        [string]$Name,
        [string]$LogPath
    )
    Write-Host "==> $Name" -ForegroundColor Cyan
    if ($WhatIf) {
        Write-Host "WHATIF: $($Command -join ' ')"
        return 0
    }
    $cmd = $Command[0]
    $cmdArgs = if ($Command.Length -gt 1) { $Command[1..($Command.Length-1)] } else { @() }
    $null = & $cmd @cmdArgs *>&1 | Tee-Object -FilePath $LogPath -Append | Out-Host
    return [int]($LASTEXITCODE ?? 0)
}

$tests = @(
    @{ Name = 'XCli.Tests'; Project = 'Tooling/x-cli/tests/XCli.Tests/XCli.Tests.csproj' },
    @{ Name = 'SrsApi.Tests'; Project = 'Tooling/x-cli/tests/SrsApi.Tests/SrsApi.Tests.csproj' },
    @{ Name = 'ManifestValidationTests'; Project = 'Tooling/x-cli/tests/ManifestValidationTests/ManifestValidationTests.csproj' }
)

$builds = @(
    @{ Name = 'DevModeAgentCli'; Project = 'Tooling/dotnet/DevModeAgentCli/DevModeAgentCli.csproj' },
    @{ Name = 'IntegrationEngineCli'; Project = 'Tooling/dotnet/IntegrationEngineCli/IntegrationEngineCli.csproj' },
    @{ Name = 'OrchestrationCli'; Project = 'Tooling/dotnet/OrchestrationCli/OrchestrationCli.csproj' },
    @{ Name = 'RequirementsSummarizer'; Project = 'Tooling/dotnet/RequirementsSummarizer/RequirementsSummarizer.csproj' },
    @{ Name = 'VipbJsonTool'; Project = 'Tooling/dotnet/VipbJsonTool/VipbJsonTool.csproj' },
    @{ Name = 'OllamaSmokeCli'; Project = 'Tooling/dotnet/OllamaSmokeCli/OllamaSmokeCli.csproj' }
)

$skipped = @()
$buildQueue = @()
foreach ($b in $builds) {
    $projectPath = Join-Path $RepoRoot $b.Project
    if (-not (Test-Path -LiteralPath $projectPath)) {
        $skipped += "skip $($b.Name): project missing"
        Write-Host "SKIP build-$($b.Name): project not found at $projectPath" -ForegroundColor Yellow
        continue
    }
    $srcDir = Split-Path $projectPath -Parent
    $csFiles = Get-ChildItem -LiteralPath $srcDir -Filter *.cs -Recurse -File -ErrorAction SilentlyContinue |
        Where-Object { $_.FullName -notmatch "\\(bin|obj)\\" }
    if ($b.Name -eq 'VipbJsonTool' -and ($null -eq $csFiles -or $csFiles.Count -eq 0)) {
        $skipped += "skip $($b.Name): no source files"
        Write-Host "SKIP build-$($b.Name): no .cs files under $srcDir" -ForegroundColor Yellow
        continue
    }
    $b.ProjectPath = $projectPath
    $buildQueue += $b
}

$failures = @()
$stoppedAfter = $null
foreach ($b in $buildQueue) {
    $logPath = Join-Path $runDir ("{0}.build.log" -f $b.Name)
    $cmd = @('dotnet','build',$b.ProjectPath,'-c',$BuildConfiguration)
    $code = Invoke-Step -Command $cmd -Name "build-$($b.Name)" -LogPath $logPath
    if ($code -ne 0) {
        $failures += "build {0} (exit {1})" -f $b.Name,$code
        $stoppedAfter = $b.Name
        break
    }

    foreach ($t in $tests) {
        $testLog = Join-Path $runDir ("{0}-after-{1}.log" -f $t.Name,$b.Name)
        $trxName = "{0}-after-{1}.trx" -f $t.Name,$b.Name
        $cmd = @('dotnet','test',$t.Project,'-c',$BuildConfiguration,'--logger',"trx;LogFileName=$trxName",'--results-directory',$runDir)
        $code = Invoke-Step -Command $cmd -Name "$($t.Name) after $($b.Name)" -LogPath $testLog
        if ($code -ne 0) {
            $failures += "{0} after {1} (exit {2})" -f $t.Name,$b.Name,$code
            $stoppedAfter = $b.Name
            break
        }
    }

    if ($stoppedAfter) { break }
}

$summary = [pscustomobject]@{
    runId = $runId
    repo = $RepoRoot
    output = $runDir
    forceSimulation = $ForceSimulationSubcommands
    configuration = $BuildConfiguration
    skipped = $skipped
    stoppedAfter = $stoppedAfter
    failures = $failures
}
$summary | ConvertTo-Json -Depth 4 | Set-Content -Path (Join-Path $runDir 'summary.json') -Encoding UTF8

if ($failures.Count -gt 0) { exit 1 }
exit 0
