#Requires -Version 7.0

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Initialize-VipmBuildTelemetry {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$RepoRoot
    )

    $resolved = (Resolve-Path -LiteralPath $RepoRoot -ErrorAction Stop).ProviderPath
    $logRoot = Join-Path $resolved 'tests\results\_agent\icon-editor\vipm-cli-build'
    if (-not (Test-Path -LiteralPath $logRoot -PathType Container)) {
        New-Item -ItemType Directory -Path $logRoot -Force | Out-Null
    }
    return (Resolve-Path -LiteralPath $logRoot).ProviderPath
}

function Write-VipmBuildTelemetry {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$LogRoot,
        [Parameter(Mandatory)][DateTime]$StartedAt,
        [Parameter(Mandatory)][DateTime]$CompletedAt,
        [Parameter(Mandatory)][string]$Toolchain,
        [string]$Provider,
        [object[]]$Artifacts,
        [hashtable]$Metadata,
        [switch]$DisplayOnly
    )

    if (-not (Test-Path -LiteralPath $LogRoot -PathType Container)) {
        New-Item -ItemType Directory -Path $LogRoot -Force | Out-Null
    }

    $artifactsToPersist = if ($Artifacts) { $Artifacts } else { @() }
    $artifactCount = 0
    if ($null -ne $artifactsToPersist) {
        if ($artifactsToPersist -is [System.Collections.ICollection]) {
            $artifactCount = $artifactsToPersist.Count
        } elseif ($artifactsToPersist) {
            $artifactCount = 1
        }
    }
    $payload = [ordered]@{
        schema          = 'icon-editor/vipm-package@v1'
        generatedAt     = (Get-Date).ToUniversalTime().ToString('o')
        startedAt       = $StartedAt.ToUniversalTime().ToString('o')
        completedAt     = $CompletedAt.ToUniversalTime().ToString('o')
        durationSeconds = [Math]::Round(($CompletedAt - $StartedAt).TotalSeconds, 3)
        toolchain       = $Toolchain
        provider        = $Provider
        displayOnly     = [bool]$DisplayOnly
        artifactCount   = $artifactCount
        artifacts       = $artifactsToPersist
        metadata        = $Metadata
    }

    $timestamp = Get-Date -Format 'yyyyMMddTHHmmssfff'
    $telemetryPath = Join-Path $LogRoot ("vipm-package-{0}.json" -f $timestamp)
    $payload | ConvertTo-Json -Depth 100 | Set-Content -LiteralPath $telemetryPath -Encoding UTF8
    return (Resolve-Path -LiteralPath $telemetryPath).ProviderPath
}

function Get-VipmBuildArtifacts {
    param(
        [Parameter(Mandatory)][string]$ResultsRoot,
        [string]$ArtifactFilter = '*.vip'
    )

    if (-not (Test-Path -LiteralPath $ResultsRoot -PathType Container)) {
        return @()
    }

    $files = Get-ChildItem -LiteralPath $ResultsRoot -Filter $ArtifactFilter -File -ErrorAction SilentlyContinue |
        Sort-Object LastWriteTimeUtc

    $artifacts = New-Object System.Collections.Generic.List[object]
    foreach ($file in $files) {
        $artifacts.Add([ordered]@{
            SourcePath       = $null
            DestinationPath  = $file.FullName
            Name             = $file.Name
            Kind             = 'vip'
            SizeBytes        = $file.Length
            LastWriteTimeUtc = $file.LastWriteTimeUtc.ToString('o')
        }) | Out-Null
    }

    return $artifacts
}

function Invoke-VipmPackageBuild {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][scriptblock]$InvokeAction,
        [Parameter(Mandatory)][string]$ModifyScriptPath,
        [string[]]$ModifyArguments = @(),
        [Parameter(Mandatory)][string]$BuildScriptPath,
        [string[]]$BuildArguments = @(),
        [string]$CloseScriptPath,
        [string[]]$CloseArguments = @(),
        [Parameter(Mandatory)][string]$IconEditorRoot,
        [Parameter(Mandatory)][string]$ResultsRoot,
        [DateTime]$ArtifactCutoffUtc = (Get-Date),
        [string]$ArtifactFilter = '*.vip',
        [string]$TelemetryRoot,
        [hashtable]$Metadata,
        [switch]$DisplayOnly,
        [string]$Toolchain = 'vipm',
        [string]$Provider
    )

    $resolvedIconRoot = (Resolve-Path -LiteralPath $IconEditorRoot -ErrorAction Stop).ProviderPath
    if (-not (Test-Path -LiteralPath $ResultsRoot -PathType Container)) {
        New-Item -ItemType Directory -Path $ResultsRoot -Force | Out-Null
    }
    $resolvedResults = (Resolve-Path -LiteralPath $ResultsRoot).ProviderPath

    $startTime = Get-Date

    if ($DisplayOnly) {
        $existingArtifacts = Get-VipmBuildArtifacts -ResultsRoot $resolvedResults -ArtifactFilter $ArtifactFilter
        $telemetryPath = $null
        if ($TelemetryRoot) {
            $telemetryPath = Write-VipmBuildTelemetry `
                -LogRoot $TelemetryRoot `
                -StartedAt $startTime `
                -CompletedAt (Get-Date) `
                -Toolchain $Toolchain `
                -Provider $Provider `
                -Artifacts $existingArtifacts `
                -Metadata $Metadata `
                -DisplayOnly
        }

        return [pscustomobject]@{
            Artifacts     = $existingArtifacts
            Toolchain     = $Toolchain
            Provider      = $Provider
            TelemetryPath = $telemetryPath
            DisplayOnly   = $true
        }
    }

    foreach ($scriptPath in @($ModifyScriptPath, $BuildScriptPath)) {
        if (-not (Test-Path -LiteralPath $scriptPath -PathType Leaf)) {
            throw "Required packaging script '$scriptPath' was not found."
        }
    }
    if ($CloseScriptPath -and (-not (Test-Path -LiteralPath $CloseScriptPath -PathType Leaf))) {
        throw "Close script '$CloseScriptPath' was not found."
    }

    $packagingModulePath = Join-Path (Split-Path -Parent $PSScriptRoot) 'vendor\IconEditorPackaging.psm1'
    if (-not (Test-Path -LiteralPath $packagingModulePath -PathType Leaf)) {
        throw "IconEditorPackaging module not found at '$packagingModulePath'."
    }
    Import-Module $packagingModulePath -Force | Out-Null

    $result = Invoke-IconEditorVipPackaging `
        -InvokeAction $InvokeAction `
        -ModifyVipbScriptPath $ModifyScriptPath `
        -BuildVipScriptPath $BuildScriptPath `
        -CloseScriptPath $CloseScriptPath `
        -IconEditorRoot $resolvedIconRoot `
        -ResultsRoot $resolvedResults `
        -ArtifactCutoffUtc $ArtifactCutoffUtc `
        -ModifyArguments $ModifyArguments `
        -BuildArguments $BuildArguments `
        -CloseArguments $CloseArguments `
        -ArtifactFilter $ArtifactFilter `
        -Toolchain $Toolchain `
        -Provider $Provider

    $completedAt = Get-Date
    $telemetryPath = $null
    if ($TelemetryRoot) {
        $telemetryPath = Write-VipmBuildTelemetry `
            -LogRoot $TelemetryRoot `
            -StartedAt $startTime `
            -CompletedAt $completedAt `
            -Toolchain $result.Toolchain `
            -Provider $result.Provider `
            -Artifacts $result.Artifacts `
            -Metadata $Metadata
    }

    return [pscustomobject]@{
        Artifacts     = $result.Artifacts
        Toolchain     = $result.Toolchain
        Provider      = $result.Provider
        TelemetryPath = $telemetryPath
        DisplayOnly   = $false
    }
}

Export-ModuleMember -Function `
    Initialize-VipmBuildTelemetry, `
    Write-VipmBuildTelemetry, `
    Invoke-VipmPackageBuild

function Test-ValidLabel {
  param([Parameter(Mandatory)][string]$Label)
  if ($Label -notmatch '^[A-Za-z0-9._-]{1,64}$') { throw "Invalid label: $Label" }
}

function Invoke-WithTimeout {
  [CmdletBinding()]
  param(
    [Parameter(Mandatory)][scriptblock]$ScriptBlock,
    [Parameter()][int]$TimeoutSec = 600
  )
  $job = Start-Job -ScriptBlock $ScriptBlock
  if (-not (Wait-Job $job -Timeout $TimeoutSec)) {
    try { Stop-Job $job -Force } catch {}
    throw "Operation timed out in $TimeoutSec s"
  }
  Receive-Job $job -ErrorAction Stop
}
