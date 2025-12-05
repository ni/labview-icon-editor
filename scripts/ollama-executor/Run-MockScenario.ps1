[CmdletBinding(DefaultParameterSetName = "Preset")]
param(
    [Parameter(ParameterSetName = "Preset")]
    [ValidateSet("package-build", "source-distribution", "local-sd-ppl", "reset-source-dist")]
    [string]$Task = "source-distribution",

    [Parameter(ParameterSetName = "Custom")]
    [string]$Command,

    [Parameter(ParameterSetName = "Custom")]
    [string]$Summary = "Scenario completed successfully.",

    [Parameter(ParameterSetName = "Custom")]
    [string]$LockedScriptPath,

    [Parameter(ParameterSetName = "Custom")]
    [string]$CommandScriptPath,

    [Parameter(ParameterSetName = "Custom")]
    [object]$CommandScriptParameters,

    [string]$RepoPath = ".",
    [int]$Port = 11436,
    [int]$CommandTimeoutSec = 60,
    [string]$Endpoint = $env:OLLAMA_HOST,
    [string]$ModelTag = $env:OLLAMA_MODEL_TAG,
    [switch]$KeepMockServer,
    [switch]$NoRun,
    [object]$LockedScriptParameters,
    [int]$MaxRequests = 10,
    [int]$LabVIEWVersion = 2025,
    [ValidateSet('0','3')]
    [string]$LabVIEWMinor = '3',
    [ValidateSet('32','64')]
    [string]$Bitness = '64'
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest
. "$PSScriptRoot/CommandBuilder.ps1"
. "$PSScriptRoot/SeededWorktree.ps1"

function ConvertTo-Hashtable {
    param([object]$InputObject, [string]$ParameterName)

    if ($null -eq $InputObject) { return @{} }

    $convertInner = {
        param($Value)

        if ($null -eq $Value) { return $null }

        if ($Value -is [System.Collections.IDictionary]) {
            $hash = @{}
            foreach ($key in $Value.Keys) {
                $hash[$key] = & $convertInner $Value[$key]
            }
            return $hash
        }

        if ($Value -is [System.Management.Automation.PSCustomObject]) {
            $hash = @{}
            foreach ($prop in $Value.PSObject.Properties) {
                $hash[$prop.Name] = & $convertInner $prop.Value
            }
            return $hash
        }

        if ($Value -is [System.Collections.IEnumerable] -and -not ($Value -is [string])) {
            return @($Value | ForEach-Object { & $convertInner $_ })
        }

        return $Value
    }

    if ($InputObject -is [string]) {
        try {
            $parsed = $InputObject | ConvertFrom-Json -Depth 10
        }
        catch {
            throw "Parameter '$ParameterName' could not be parsed as JSON: $($_.Exception.Message)"
        }
        return & $convertInner $parsed
    }

    if ($InputObject -isnot [System.Collections.IDictionary] -and $InputObject -isnot [System.Management.Automation.PSCustomObject]) {
        throw "Parameter '$ParameterName' must be a hashtable or JSON string."
    }

    return & $convertInner $InputObject
}

function New-ScriptCommand {
    param(
        [Parameter(Mandatory = $true)][string]$ScriptPath,
        [hashtable]$Parameters
    )

    $escapedScript = $ScriptPath.Replace('`', '``').Replace('"', '`"')
    $command = "pwsh -NoProfile -File `"$escapedScript`""
    if ($Parameters) {
        foreach ($key in ($Parameters.Keys | Sort-Object)) {
            $value = $Parameters[$key]
            if ($null -eq $value) {
                $command += " -$key"
                continue
            }

            if ($value -is [System.Management.Automation.SwitchParameter]) {
                if ($value.IsPresent) { $command += " -$key" }
                continue
            }

            if ($value -is [bool]) {
                $boolLiteral = $value.ToString().ToLower()
                $command += " -" + $key + ":" + $boolLiteral
                continue
            }

            if ($value -is [array]) {
                foreach ($item in $value) {
                    $escapedItem = $item.ToString().Replace('`', '``').Replace('"', '`"')
                    $command += " -$key `"$escapedItem`""
                }
                continue
            }

            $escapedValue = $value.ToString().Replace('`', '``').Replace('"', '`"')
            $command += " -$key `"$escapedValue`""
        }
    }

    return $command
}

$resolvedCommandParameters = ConvertTo-Hashtable -InputObject $CommandScriptParameters -ParameterName "CommandScriptParameters"
$resolvedLockedParameters = ConvertTo-Hashtable -InputObject $LockedScriptParameters -ParameterName "LockedScriptParameters"

$resolvedRepo = (Resolve-Path -LiteralPath $RepoPath).ProviderPath
$seededInfo = Get-SeededWorktree -RepoPath $resolvedRepo -TargetLabVIEWVersion $LabVIEWVersion -TargetLabVIEWMinor $LabVIEWMinor -TargetBitness $Bitness
$worktreePath = $seededInfo.WorktreePath
$repoArgument = Format-CommandValue $worktreePath

$resetCliArgs = @(
    'reset-source-dist',
    '--repo', $worktreePath,
    '--reset-archive-existing',
    '--reset-run-commit-index',
    '--reset-run-full-build',
    '--reset-emit-summary',
    '--reset-summary-json', 'builds/reports/source-dist-reset.json',
    '--reset-additional-path', 'builds/cache'
)
$resetCliCommand = New-InvokeRepoCliCommandString -CliName 'OrchestrationCli' -RepoRoot $worktreePath -CliArguments $resetCliArgs

$packageArgs = @(
    'package-build',
    '--repo', $worktreePath,
    '--bitness', $Bitness,
    '--lvlibp-bitness', 'both',
    '--major', '0',
    '--minor', '1',
    '--patch', '0',
    '--build', '1',
    '--company', 'LabVIEW-Community-CI-CD',
    '--author', 'Local Developer'
)
$packageCommand = New-InvokeRepoCliCommandString -CliName 'OrchestrationCli' -RepoRoot $worktreePath -CliArguments $packageArgs

$sourceDistCommand = "pwsh -NoProfile -File scripts/build-source-distribution/Build_Source_Distribution.ps1 -RepositoryPath $repoArgument -Package_LabVIEW_Version $LabVIEWVersion -SupportedBitness $Bitness"
$localSdPplCommand = "pwsh -NoProfile -File scripts/orchestration/Run-LocalSd-Ppl.ps1 -Repo $repoArgument -RunKey local-sd-ppl"

$taskMap = @{
    "source-distribution" = @{
        Command = $sourceDistCommand
        Summary = "Source distribution built successfully for LV$LabVIEWVersion $Bitness-bit"
        Script = "$PSScriptRoot/Run-Locked-SourceDistribution.ps1"
    }
    "package-build" = @{
        Command = $packageCommand
        Summary = "Package build completed successfully for LV$LabVIEWVersion $Bitness-bit (simulated)"
        Script = "$PSScriptRoot/Run-Locked-PackageBuild.ps1"
    }
    "local-sd-ppl" = @{
        Command = $localSdPplCommand
        Summary = "local-sd-ppl orchestration completed successfully for LV$LabVIEWVersion $Bitness-bit (simulated)"
        Script = "$PSScriptRoot/Run-Locked-LocalSdPpl.ps1"
    }
    "reset-source-dist" = @{
        Command = $resetCliCommand
        Summary = 'Source Distribution workspace reset completed successfully (simulated)'
        Script = "$PSScriptRoot/Run-Locked-ResetSourceDistribution.ps1"
    }
}

$usingPreset = ($PSCmdlet.ParameterSetName -eq "Preset")
if ($usingPreset) {
    $preset = $taskMap[$Task]
    if (-not $preset) {
        throw "Unknown task '$Task'."
    }
    $Command = $preset.Command
    $Summary = $preset.Summary
    $LockedScriptPath = $preset.Script
    if (-not [string]::IsNullOrWhiteSpace($Command) -and -not $resolvedLockedParameters.ContainsKey('SeedAssistantRunCommand')) {
        $resolvedLockedParameters['SeedAssistantRunCommand'] = $Command
    }
}
else {
    if ([string]::IsNullOrWhiteSpace($Command) -and [string]::IsNullOrWhiteSpace($CommandScriptPath)) {
        throw "Provide -Command or -CommandScriptPath for custom scenarios."
    }

    if ($CommandScriptPath) {
        $Command = New-ScriptCommand -ScriptPath $CommandScriptPath -Parameters $resolvedCommandParameters
    }

    if (-not $LockedScriptPath -and -not $NoRun) {
        throw "Custom scenarios require -LockedScriptPath when -NoRun is not specified."
    }
}

if (-not $NoRun -and ( -not $LockedScriptPath -or -not (Test-Path -LiteralPath $LockedScriptPath))) {
    throw "Locked script path '$LockedScriptPath' not found."
}

$mockServerScript = "$PSScriptRoot/MockOllamaServer.ps1"

# Build scenario payload
$runPayload = @{ run = $Command } | ConvertTo-Json -Compress
$donePayload = @{ done = $true; summary = $Summary } | ConvertTo-Json -Compress
$scenario = @{ turns = @(@{ response = $runPayload }, @{ response = $donePayload }) } | ConvertTo-Json -Depth 4
$scenarioPath = Join-Path ([System.IO.Path]::GetTempPath()) ("ollama-scenario-" + [guid]::NewGuid() + ".json")
Set-Content -LiteralPath $scenarioPath -Value $scenario -Encoding UTF8

Write-Host "[mock-scenario] Scenario file: $scenarioPath"

# Start mock server
$mockJob = Start-Job -ArgumentList $mockServerScript, $Port, $scenarioPath, $MaxRequests -ScriptBlock {
    param($serverScript, $listenPort, $scenarioFile, $requestLimit)
    & $serverScript -Port $listenPort -ScenarioFile $scenarioFile -MaxRequests $requestLimit | Write-Host
}

# Give the listener a brief moment to start
Start-Sleep -Milliseconds 200

$hostToUse = if ([string]::IsNullOrWhiteSpace($Endpoint)) { "http://localhost:$Port" } else { $Endpoint }
$modelToUse = if ([string]::IsNullOrWhiteSpace($ModelTag)) { "llama3-8b-local:latest" } else { $ModelTag }

$previousEnv = @{
    Host = $env:OLLAMA_HOST
    Model = $env:OLLAMA_MODEL_TAG
    Mode = $env:OLLAMA_EXECUTOR_MODE
}

$env:OLLAMA_HOST = $hostToUse
$env:OLLAMA_MODEL_TAG = $modelToUse
$env:OLLAMA_EXECUTOR_MODE = "sim"

Write-Host "[mock-scenario] OLLAMA_HOST=$hostToUse"
Write-Host "[mock-scenario] OLLAMA_MODEL_TAG=$modelToUse"
Write-Host "[mock-scenario] OLLAMA_EXECUTOR_MODE=sim"

if ($NoRun -and -not $KeepMockServer) {
    $KeepMockServer = $true
}

try {
    if ($NoRun) {
        Write-Host "[mock-scenario] Mock server running on port $Port (job id $($mockJob.Id))."
        Write-Host "[mock-scenario] Run your target script manually, then stop the job when done."
    }
    else {
    $lockedParams = @{ RepoPath = $resolvedRepo; CommandTimeoutSec = $CommandTimeoutSec }
    foreach ($key in $resolvedLockedParameters.Keys) {
        $lockedParams[$key] = $resolvedLockedParameters[$key]
    }

    Write-Host "[mock-scenario] Running $([System.IO.Path]::GetFileName($LockedScriptPath))"
    & $LockedScriptPath @lockedParams
    }
}
finally {
    if (-not $KeepMockServer) {
        if ($mockJob.State -eq 'Running') {
            Stop-Job -Id $mockJob.Id -ErrorAction SilentlyContinue
        }
        Receive-Job -Id $mockJob.Id -ErrorAction SilentlyContinue | Write-Host
        Remove-Job -Id $mockJob.Id -ErrorAction SilentlyContinue
        Remove-Item -LiteralPath $scenarioPath -ErrorAction SilentlyContinue
        Write-Host "[mock-scenario] Mock server stopped."
    }
    else {
        Write-Host "[mock-scenario] Mock server left running (job id $($mockJob.Id)). Use Stop-Job to end it and delete $scenarioPath when finished."
    }

    if ($null -eq $previousEnv.Host) { Remove-Item Env:OLLAMA_HOST -ErrorAction SilentlyContinue } else { $env:OLLAMA_HOST = $previousEnv.Host }
    if ($null -eq $previousEnv.Model) { Remove-Item Env:OLLAMA_MODEL_TAG -ErrorAction SilentlyContinue } else { $env:OLLAMA_MODEL_TAG = $previousEnv.Model }
    if ($null -eq $previousEnv.Mode) { Remove-Item Env:OLLAMA_EXECUTOR_MODE -ErrorAction SilentlyContinue } else { $env:OLLAMA_EXECUTOR_MODE = $previousEnv.Mode }
}
