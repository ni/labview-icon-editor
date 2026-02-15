#Requires -Version 7.0
<#
.SYNOPSIS
    Runs LabVIEWCLI preflight for cache-clear and mass compile validation.

.DESCRIPTION
    Performs a deterministic preflight sequence:
      1. Resolve LabVIEW version, executable, and VI Server port.
      2. Attempt to clear compiled object cache through a custom LabVIEWCLI operation.
      3. Fall back to deleting version-scoped VIObjCache folders when custom operation is unavailable.
      4. Mass-compile a staged copy of the compile target directory via LabVIEWCLI.
      5. Emit operation logs and a machine-readable summary under TestResults.

    Default compile target resolution uses the base folder of the active worktree:
      - explicit -TargetDir (if provided)
      - parent directory of PROJECT_PATH (if available)
      - REPO_ROOT (if available)
      - RepoRoot parameter
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [AllowNull()]
    [AllowEmptyString()]
    [string]$LabVIEWVersion = '',

    [Parameter(Mandatory = $true)]
    [ValidateSet('32', '64', IgnoreCase = $true)]
    [string]$SupportedBitness,

    [Parameter(Mandatory = $false)]
    [string]$RepoRoot,

    [Parameter(Mandatory = $false)]
    [string]$TargetDir,

    [Parameter(Mandatory = $false)]
    [string[]]$ExcludeFiles = @('Polymorphic Template.vi'),

    [Parameter(Mandatory = $false)]
    [switch]$RequireCliCacheClearOp
)

$ErrorActionPreference = 'Stop'

function Resolve-RepoRoot {
    param(
        [string]$PathOverride
    )

    if (-not [string]::IsNullOrWhiteSpace($PathOverride)) {
        if (-not (Test-Path -Path $PathOverride)) {
            throw "RepoRoot does not exist: $PathOverride"
        }
        return (Resolve-Path -Path $PathOverride).Path
    }

    if (-not [string]::IsNullOrWhiteSpace($env:REPO_ROOT) -and (Test-Path -Path $env:REPO_ROOT)) {
        return (Resolve-Path -Path $env:REPO_ROOT).Path
    }

    $scriptRoot = if ($PSScriptRoot) { $PSScriptRoot } else { Split-Path -Parent $PSCommandPath }
    $git = Get-Command git -ErrorAction SilentlyContinue
    if ($git) {
        try {
            $gitRoot = git -C $scriptRoot rev-parse --show-toplevel 2>$null
            if ($LASTEXITCODE -eq 0 -and -not [string]::IsNullOrWhiteSpace($gitRoot)) {
                return (Resolve-Path -Path $gitRoot.Trim()).Path
            }
        } catch {
            Write-Verbose ("git rev-parse failed: {0}" -f $_.Exception.Message)
        }
    }

    return (Resolve-Path -Path (Join-Path $scriptRoot '..')).Path
}

function Get-LabVIEWInstallRoot {
    param(
        [string]$Version,
        [string]$Bitness
    )

    $candidates = @()
    $regPaths = @()
    if ($Bitness -eq '32') {
        $candidates += "C:\Program Files (x86)\National Instruments\LabVIEW $Version"
        $regPaths += "HKLM:\SOFTWARE\WOW6432Node\National Instruments\LabVIEW $Version"
    } else {
        $candidates += "C:\Program Files\National Instruments\LabVIEW $Version"
        $regPaths += "HKLM:\SOFTWARE\National Instruments\LabVIEW $Version"
    }

    foreach ($candidate in $candidates) {
        if (Test-Path -Path $candidate) {
            return $candidate
        }
    }

    foreach ($regPath in $regPaths) {
        try {
            $props = Get-ItemProperty -Path $regPath -ErrorAction Stop
            foreach ($name in @('Path', 'InstallDir', 'InstallPath')) {
                $value = $props.$name
                if (-not [string]::IsNullOrWhiteSpace($value) -and (Test-Path -Path $value)) {
                    return $value
                }
            }
        } catch {
            continue
        }
    }

    return $null
}

function Resolve-LabVIEWTcpSetting {
    param(
        [string]$IniPath
    )

    $defaultPort = 3363
    if (-not (Test-Path -Path $IniPath)) {
        return [pscustomobject]@{
            PortNumber = $defaultPort
            PortSource = 'default:3363 (ini missing)'
            Enabled = $true
            EnabledSource = 'default:true (ini missing)'
            IniPath = $IniPath
        }
    }

    $lines = Get-Content -Path $IniPath
    $portRaw = $null
    $enabledRaw = $null
    foreach ($line in $lines) {
        if ($line -match '(?i)^\s*server\.tcp\.port\s*=\s*(?<value>\d+)\s*$') {
            $portRaw = $Matches['value']
            continue
        }
        if ($line -match '(?i)^\s*server\.tcp\.enabled\s*=\s*(?<value>.+?)\s*$') {
            $enabledRaw = $Matches['value'].Trim()
            continue
        }
    }

    $port = $defaultPort
    $portSource = 'default:3363'
    if (-not [string]::IsNullOrWhiteSpace($portRaw)) {
        $parsedPort = 0
        if ([int]::TryParse($portRaw, [ref]$parsedPort) -and $parsedPort -ge 1 -and $parsedPort -le 65535) {
            $port = $parsedPort
            $portSource = "$IniPath (server.tcp.port)"
        } else {
            Write-Warning ("Invalid server.tcp.port value '{0}' in {1}. Falling back to {2}." -f $portRaw, $IniPath, $defaultPort)
        }
    }

    $enabled = $true
    $enabledSource = 'default:true'
    if (-not [string]::IsNullOrWhiteSpace($enabledRaw)) {
        switch -Regex ($enabledRaw.Trim()) {
            '^(?i:true|1|yes)$' {
                $enabled = $true
                $enabledSource = "$IniPath (server.tcp.enabled)"
                break
            }
            '^(?i:false|0|no)$' {
                $enabled = $false
                $enabledSource = "$IniPath (server.tcp.enabled)"
                break
            }
            default {
                Write-Warning ("Unrecognized server.tcp.enabled value '{0}' in {1}. Assuming enabled." -f $enabledRaw, $IniPath)
            }
        }
    }

    return [pscustomobject]@{
        PortNumber = $port
        PortSource = $portSource
        Enabled = $enabled
        EnabledSource = $enabledSource
        IniPath = $IniPath
    }
}

function Resolve-CompileTarget {
    param(
        [string]$TargetDirOverride,
        [string]$RepoRootResolved
    )

    if (-not [string]::IsNullOrWhiteSpace($TargetDirOverride)) {
        if (-not (Test-Path -Path $TargetDirOverride)) {
            throw "TargetDir does not exist: $TargetDirOverride"
        }
        $path = (Resolve-Path -Path $TargetDirOverride).Path
        return [pscustomobject]@{
            Path = $path
            Source = 'TargetDir parameter'
            ProjectPath = $null
        }
    }

    if (-not [string]::IsNullOrWhiteSpace($env:PROJECT_PATH) -and (Test-Path -Path $env:PROJECT_PATH)) {
        $projectPath = (Resolve-Path -Path $env:PROJECT_PATH).Path
        return [pscustomobject]@{
            Path = Split-Path -Path $projectPath -Parent
            Source = 'PROJECT_PATH parent'
            ProjectPath = $projectPath
        }
    }

    $repoProjectPath = Join-Path $RepoRootResolved 'lv_icon_editor.lvproj'
    if (Test-Path -Path $repoProjectPath) {
        $projectPath = (Resolve-Path -Path $repoProjectPath).Path
        return [pscustomobject]@{
            Path = Split-Path -Path $projectPath -Parent
            Source = 'repo project parent'
            ProjectPath = $projectPath
        }
    }

    if (-not [string]::IsNullOrWhiteSpace($env:REPO_ROOT) -and (Test-Path -Path $env:REPO_ROOT)) {
        $path = (Resolve-Path -Path $env:REPO_ROOT).Path
        return [pscustomobject]@{
            Path = $path
            Source = 'REPO_ROOT environment'
            ProjectPath = $null
        }
    }

    return [pscustomobject]@{
        Path = $RepoRootResolved
        Source = 'RepoRoot fallback'
        ProjectPath = $null
    }
}

function Get-LabVIEWCliTempLogPath {
    return @(
        Get-ChildItem -Path ([System.IO.Path]::GetTempPath()) -Filter 'lvtemporary_*.log' -File -ErrorAction SilentlyContinue |
            Sort-Object LastWriteTimeUtc -Descending |
            Select-Object -ExpandProperty FullName
    )
}

function Save-NewLabVIEWCliLog {
    param(
        [string]$OperationName,
        [string[]]$BeforeLogs,
        [string]$DestinationRoot
    )

    $afterLogs = @(Get-LabVIEWCliTempLogPath)
    $newLogs = @()
    foreach ($path in $afterLogs) {
        if ($BeforeLogs -notcontains $path) {
            $newLogs += $path
        }
    }

    if ($newLogs.Count -eq 0 -and $afterLogs.Count -gt 0) {
        $newLogs = @($afterLogs[0])
    }

    $copied = @()
    $timestamp = Get-Date -Format 'yyyyMMdd-HHmmss'
    $index = 0
    foreach ($source in $newLogs) {
        if (-not (Test-Path -Path $source -PathType Leaf)) {
            continue
        }
        $index++
        $destination = Join-Path $DestinationRoot ("{0}-{1}-{2}.log" -f $OperationName.ToLowerInvariant(), $timestamp, $index)
        Copy-Item -Path $source -Destination $destination -Force
        $copied += $destination
        Write-Host ("Captured LabVIEWCLI log: {0}" -f $destination)
    }

    return $copied
}

function Invoke-LabVIEWCliOperation {
    param(
        [string]$LabVIEWCliPath,
        [string]$OperationName,
        [string[]]$Arguments,
        [string]$LabVIEWCliLogRoot
    )

    $beforeLogs = @(Get-LabVIEWCliTempLogPath)
    $start = Get-Date
    $rawOutput = & $LabVIEWCliPath @Arguments 2>&1
    $exitCode = $LASTEXITCODE
    $end = Get-Date

    $lines = @()
    foreach ($entry in $rawOutput) {
        if ($null -ne $entry) {
            $line = [string]$entry
            $lines += $line
            Write-Host $line
        }
    }

    $capturedLogs = Save-NewLabVIEWCliLog -OperationName $OperationName -BeforeLogs $beforeLogs -DestinationRoot $LabVIEWCliLogRoot

    return [pscustomobject]@{
        operation = $OperationName
        command = "LabVIEWCLI {0}" -f ($Arguments -join ' ')
        exit_code = $exitCode
        duration_seconds = [Math]::Round(($end - $start).TotalSeconds, 2)
        output_tail = @($lines | Select-Object -Last 80)
        log_paths = $capturedLogs
    }
}

function Test-LabVIEWCliConnectionFailure {
    param(
        [string[]]$OutputLines
    )

    if (-not $OutputLines -or $OutputLines.Count -eq 0) {
        return $false
    }

    $outputText = $OutputLines -join [Environment]::NewLine
    if ([string]::IsNullOrWhiteSpace($outputText)) {
        return $false
    }

    return ($outputText -match '(?i)Error\s*code\s*:\s*-350000' -or $outputText -match '(?i)failed to establish a connection with LabVIEW')
}

function Get-LabVIEWCliPortAttemptList {
    param(
        [Parameter(Mandatory = $true)]
        [int]$PrimaryPortNumber
    )

    $attemptPorts = New-Object System.Collections.Generic.List[int]
    $seenPorts = @{}
    foreach ($candidatePort in @($PrimaryPortNumber, 3370, 3363)) {
        if ($candidatePort -lt 1 -or $candidatePort -gt 65535) {
            continue
        }
        if ($seenPorts.ContainsKey($candidatePort)) {
            continue
        }
        $attemptPorts.Add($candidatePort) | Out-Null
        $seenPorts[$candidatePort] = $true
    }

    return @($attemptPorts.ToArray())
}

function Set-LabVIEWCliPortArgument {
    param(
        [Parameter(Mandatory = $true)]
        [string[]]$Arguments,
        [Parameter(Mandatory = $true)]
        [int]$PortNumber
    )

    $updated = New-Object System.Collections.Generic.List[string]
    $portSet = $false
    for ($index = 0; $index -lt $Arguments.Count; $index++) {
        $arg = [string]$Arguments[$index]
        if ($arg -ieq '-PortNumber') {
            if (-not $portSet) {
                $updated.Add('-PortNumber') | Out-Null
                $updated.Add($PortNumber.ToString()) | Out-Null
                $portSet = $true
            }
            if (($index + 1) -lt $Arguments.Count) {
                $index++
            }
            continue
        }

        $updated.Add($arg) | Out-Null
    }

    if (-not $portSet) {
        $updated.Add('-PortNumber') | Out-Null
        $updated.Add($PortNumber.ToString()) | Out-Null
    }

    return @($updated.ToArray())
}

function Remove-LabVIEWCliPortArgument {
    param(
        [Parameter(Mandatory = $true)]
        [string[]]$Arguments
    )

    $updated = New-Object System.Collections.Generic.List[string]
    for ($index = 0; $index -lt $Arguments.Count; $index++) {
        $arg = [string]$Arguments[$index]
        if ($arg -ieq '-PortNumber') {
            if (($index + 1) -lt $Arguments.Count) {
                $index++
            }
            continue
        }

        $updated.Add($arg) | Out-Null
    }

    return @($updated.ToArray())
}

function Get-OutputTail {
    param(
        [string[]]$Lines,
        [int]$MaxLines = 80
    )

    if (-not $Lines -or $Lines.Count -eq 0) {
        return @()
    }

    if ($Lines.Count -le $MaxLines) {
        return @($Lines)
    }

    $start = $Lines.Count - $MaxLines
    return @($Lines[$start..($Lines.Count - 1)])
}

function New-LabVIEWCliOperationResultWithRetryInfo {
    param(
        [Parameter(Mandatory = $true)]
        [pscustomobject]$BaseResult,
        [string[]]$Attempts,
        [AllowNull()]
        [int]$PortNumber,
        [AllowNull()]
        [string]$PortSource,
        [bool]$UsedImplicitPort,
        [string[]]$CombinedOutput
    )

    return [pscustomobject]@{
        operation         = $BaseResult.operation
        command           = $BaseResult.command
        exit_code         = $BaseResult.exit_code
        duration_seconds  = $BaseResult.duration_seconds
        output_tail       = Get-OutputTail -Lines $CombinedOutput -MaxLines 80
        log_paths         = @($BaseResult.log_paths)
        attempts          = @($Attempts)
        selected_port     = $PortNumber
        selected_port_source = $PortSource
        used_implicit_port = $UsedImplicitPort
    }
}

function Invoke-LabVIEWCliOperationWithConnectionRetry {
    param(
        [Parameter(Mandatory = $true)]
        [string]$LabVIEWCliPath,
        [Parameter(Mandatory = $true)]
        [string]$OperationName,
        [Parameter(Mandatory = $true)]
        [string[]]$Arguments,
        [Parameter(Mandatory = $true)]
        [string]$LabVIEWCliLogRoot,
        [Parameter(Mandatory = $true)]
        [int]$PrimaryPortNumber,
        [switch]$AllowImplicitPortFallback
    )

    $attemptSummaries = New-Object System.Collections.Generic.List[string]
    $combinedOutput = New-Object System.Collections.Generic.List[string]
    $lastResult = $null
    $lastPortNumber = $null
    $lastPortSource = $null
    $sawConnectionFailure = $false

    $portAttempts = @(Get-LabVIEWCliPortAttemptList -PrimaryPortNumber $PrimaryPortNumber)
    foreach ($portNumber in $portAttempts) {
        $portSource = if ($portNumber -eq $PrimaryPortNumber) { 'primary' } else { "fallback:$portNumber" }
        if ($portNumber -ne $PrimaryPortNumber) {
            Write-Warning ("{0}: retrying with fallback port {1} ({2})." -f $OperationName, $portNumber, $portSource)
        }

        $portArgs = Set-LabVIEWCliPortArgument -Arguments $Arguments -PortNumber $portNumber
        $attemptName = "{0}-port{1}" -f $OperationName, $portNumber
        $result = Invoke-LabVIEWCliOperation -LabVIEWCliPath $LabVIEWCliPath -OperationName $attemptName -Arguments $portArgs -LabVIEWCliLogRoot $LabVIEWCliLogRoot
        $lastResult = $result
        $lastPortNumber = $portNumber
        $lastPortSource = $portSource
        $attemptSummaries.Add(("port:{0} source:{1} exit:{2}" -f $portNumber, $portSource, $result.exit_code)) | Out-Null
        foreach ($line in @($result.output_tail)) {
            $combinedOutput.Add($line) | Out-Null
        }

        if ($result.exit_code -eq 0) {
            return New-LabVIEWCliOperationResultWithRetryInfo -BaseResult $result -Attempts @($attemptSummaries.ToArray()) -PortNumber $portNumber -PortSource $portSource -UsedImplicitPort:$false -CombinedOutput @($combinedOutput.ToArray())
        }

        if (Test-LabVIEWCliConnectionFailure -OutputLines $result.output_tail) {
            $sawConnectionFailure = $true
            continue
        }

        return New-LabVIEWCliOperationResultWithRetryInfo -BaseResult $result -Attempts @($attemptSummaries.ToArray()) -PortNumber $portNumber -PortSource $portSource -UsedImplicitPort:$false -CombinedOutput @($combinedOutput.ToArray())
    }

    if ($AllowImplicitPortFallback -and $sawConnectionFailure) {
        Write-Warning ("{0}: explicit port attempts failed with connection errors; retrying without -PortNumber." -f $OperationName)
        $implicitArgs = Remove-LabVIEWCliPortArgument -Arguments $Arguments
        $implicitName = "{0}-implicit" -f $OperationName
        $implicitResult = Invoke-LabVIEWCliOperation -LabVIEWCliPath $LabVIEWCliPath -OperationName $implicitName -Arguments $implicitArgs -LabVIEWCliLogRoot $LabVIEWCliLogRoot
        $lastResult = $implicitResult
        $lastPortNumber = $null
        $lastPortSource = 'implicit-default'
        $attemptSummaries.Add(("port:implicit source:implicit-default exit:{0}" -f $implicitResult.exit_code)) | Out-Null
        foreach ($line in @($implicitResult.output_tail)) {
            $combinedOutput.Add($line) | Out-Null
        }

        if ($implicitResult.exit_code -eq 0) {
            return New-LabVIEWCliOperationResultWithRetryInfo -BaseResult $implicitResult -Attempts @($attemptSummaries.ToArray()) -PortNumber $null -PortSource 'implicit-default' -UsedImplicitPort:$true -CombinedOutput @($combinedOutput.ToArray())
        }
    }

    if ($null -eq $lastResult) {
        return [pscustomobject]@{
            operation            = $OperationName
            command              = "LabVIEWCLI <not-invoked>"
            exit_code            = 1
            duration_seconds     = 0
            output_tail          = @("No LabVIEWCLI attempts were executed for $OperationName.")
            log_paths            = @()
            attempts             = @($attemptSummaries.ToArray())
            selected_port        = $lastPortNumber
            selected_port_source = $lastPortSource
            used_implicit_port   = $false
        }
    }

    return New-LabVIEWCliOperationResultWithRetryInfo -BaseResult $lastResult -Attempts @($attemptSummaries.ToArray()) -PortNumber $lastPortNumber -PortSource $lastPortSource -UsedImplicitPort:($lastPortSource -eq 'implicit-default') -CombinedOutput @($combinedOutput.ToArray())
}

function ConvertTo-ExcludePattern {
    param(
        [string[]]$Patterns
    )

    $normalized = New-Object System.Collections.Generic.List[string]
    foreach ($pattern in $Patterns) {
        if ([string]::IsNullOrWhiteSpace($pattern)) {
            continue
        }
        $parts = $pattern -split ';'
        foreach ($part in $parts) {
            $trimmed = $part.Trim()
            if (-not [string]::IsNullOrWhiteSpace($trimmed)) {
                $normalized.Add($trimmed)
            }
        }
    }
    return @($normalized.ToArray())
}

function Remove-StagingExcludedItem {
    param(
        [string]$StagingRoot,
        [string[]]$Patterns
    )

    $removed = New-Object System.Collections.Generic.List[string]
    foreach ($pattern in $Patterns) {
        if ([string]::IsNullOrWhiteSpace($pattern)) {
            continue
        }

        $hasSeparator = $pattern.Contains('\') -or $pattern.Contains('/')
        if ($hasSeparator) {
            $relative = $pattern.TrimStart('\', '/')
            $candidate = Join-Path $StagingRoot $relative
            if (Test-Path -Path $candidate) {
                Write-Host ("Excluding staged path: {0}" -f $candidate)
                Remove-Item -Path $candidate -Recurse -Force
                $removed.Add($candidate)
            }
            continue
        }

        $matchedItems = @(Get-ChildItem -Path $StagingRoot -Recurse -Force -ErrorAction SilentlyContinue | Where-Object { $_.Name -ieq $pattern })
        foreach ($item in $matchedItems) {
            Write-Host ("Excluding staged item: {0}" -f $item.FullName)
            Remove-Item -Path $item.FullName -Recurse -Force
            $removed.Add($item.FullName)
        }
    }

    return @($removed.ToArray())
}

function Clear-VIObjCacheFallback {
    param(
        [string]$NumericVersion
    )

    $documentsPath = [Environment]::GetFolderPath('MyDocuments')
    $cacheRoot = Join-Path $documentsPath 'LabVIEW Data\VIObjCache'
    if (-not (Test-Path -Path $cacheRoot)) {
        return [pscustomobject]@{
            cache_root = $cacheRoot
            matched_paths = @()
            removed_paths = @()
            failed_paths = @()
            errors = @()
            status = 'cache-root-missing'
        }
    }

    $matched = @(Get-ChildItem -Path $cacheRoot -Directory -ErrorAction SilentlyContinue | Where-Object {
        $_.Name.StartsWith($NumericVersion, [System.StringComparison]::OrdinalIgnoreCase)
    })

    $removed = New-Object System.Collections.Generic.List[string]
    $failed = New-Object System.Collections.Generic.List[string]
    $errors = New-Object System.Collections.Generic.List[object]
    foreach ($item in $matched) {
        Write-Host ("Removing compiled cache path: {0}" -f $item.FullName)
        try {
            Remove-Item -Path $item.FullName -Recurse -Force
            $removed.Add($item.FullName)
        }
        catch {
            $message = $_.Exception.Message
            Write-Warning ("Failed to remove compiled cache path '{0}': {1}" -f $item.FullName, $message)
            $failed.Add($item.FullName)
            $errors.Add([pscustomobject]@{
                path = $item.FullName
                message = $message
                exception_type = $_.Exception.GetType().FullName
            })
        }
    }

    $status = 'no-match'
    if ($matched.Count -gt 0) {
        if ($failed.Count -eq 0) {
            $status = 'removed'
        } elseif ($removed.Count -eq 0) {
            $status = 'locked'
        } else {
            $status = 'partial-locked'
        }
    }

    return [pscustomobject]@{
        cache_root = $cacheRoot
        matched_paths = @($matched | ForEach-Object { $_.FullName })
        removed_paths = @($removed.ToArray())
        failed_paths = @($failed.ToArray())
        errors = @($errors.ToArray())
        status = $status
    }
}

$repoRootResolved = Resolve-RepoRoot -PathOverride $RepoRoot
$versionHelper = Join-Path $repoRootResolved 'Tooling\support\LabVIEWVersion.ps1'
if (-not (Test-Path -Path $versionHelper)) {
    throw "LabVIEW version helper not found at $versionHelper"
}
. $versionHelper
$versionInfo = Get-LabVIEWVersionInfo -VersionInput $LabVIEWVersion -RepoRoot $repoRootResolved

$installRoot = Get-LabVIEWInstallRoot -Version $versionInfo.Year -Bitness $SupportedBitness
if ([string]::IsNullOrWhiteSpace($installRoot)) {
    throw "LabVIEW $($versionInfo.Year) ($SupportedBitness-bit) install not found."
}

$labviewPath = Join-Path $installRoot 'LabVIEW.exe'
if (-not (Test-Path -Path $labviewPath)) {
    throw "LabVIEW executable not found at $labviewPath"
}

$tcpSettings = Resolve-LabVIEWTcpSetting -IniPath (Join-Path $installRoot 'LabVIEW.ini')
if (-not $tcpSettings.Enabled) {
    throw ("VI Server TCP is disabled for {0} according to {1}. Enable server.tcp.enabled before running preflight." -f $labviewPath, $tcpSettings.IniPath)
}

$labviewCliCommand = Get-Command LabVIEWCLI -ErrorAction SilentlyContinue
if (-not $labviewCliCommand) {
    throw "LabVIEWCLI is not available on PATH."
}
$labviewCliPath = $labviewCliCommand.Source

$targetResolution = Resolve-CompileTarget -TargetDirOverride $TargetDir -RepoRootResolved $repoRootResolved
$compileTarget = $targetResolution.Path
if (-not (Test-Path -Path $compileTarget -PathType Container)) {
    throw "Compile target directory not found: $compileTarget"
}

$artifactRoot = Join-Path $repoRootResolved ("TestResults\labviewcli-masscompile\{0}" -f $SupportedBitness)
$labviewCliLogRoot = Join-Path $artifactRoot 'labviewcli'
New-Item -Path $artifactRoot -ItemType Directory -Force | Out-Null
New-Item -Path $labviewCliLogRoot -ItemType Directory -Force | Out-Null

$summaryPath = Join-Path $artifactRoot 'summary.json'
$stagingDir = Join-Path ([System.IO.Path]::GetTempPath()) ("lvie-masscompile-{0}" -f [Guid]::NewGuid().ToString('N'))
New-Item -Path $stagingDir -ItemType Directory -Force | Out-Null

$normalizedExcludes = ConvertTo-ExcludePattern -Patterns $ExcludeFiles
$failure = $null
$summary = [ordered]@{
    timestamp_utc = (Get-Date).ToUniversalTime().ToString('o')
    status = 'running'
    repo_root = $repoRootResolved
    project_path = $targetResolution.ProjectPath
    compile_target_path = $compileTarget
    compile_target_source = $targetResolution.Source
    staging_dir = $stagingDir
    excludes = $normalizedExcludes
    labview = [ordered]@{
        raw_version = $versionInfo.Raw
        year = $versionInfo.Year
        numeric_version = $versionInfo.NumericVersion
        bitness = $SupportedBitness
        executable = $labviewPath
        ini_path = $tcpSettings.IniPath
        tcp_port = $tcpSettings.PortNumber
        tcp_port_source = $tcpSettings.PortSource
    }
    labviewcli = [ordered]@{
        executable = $labviewCliPath
        logs_root = $labviewCliLogRoot
    }
    cache_clear = [ordered]@{
        method = 'none'
        require_cli_operation = [bool]$RequireCliCacheClearOp
        custom_operation_attempted = $false
        custom_operation = $null
        fallback = $null
    }
    mass_compile = $null
    operations = @()
    error_message = $null
}

try {
    Write-Host ("Resolved compile target: {0} (source: {1})" -f $compileTarget, $targetResolution.Source)
    Write-Host ("LabVIEW executable: {0}" -f $labviewPath)
    Write-Host ("LabVIEWCLI executable: {0}" -f $labviewCliPath)
    Write-Host ("Using VI Server port: {0} ({1})" -f $tcpSettings.PortNumber, $tcpSettings.PortSource)

    Write-Host ("Staging compile target into: {0}" -f $stagingDir)
    $sourceItems = @(Get-ChildItem -Path $compileTarget -Force -ErrorAction Stop)
    foreach ($item in $sourceItems) {
        if ($item.Name -ieq '.git') {
            continue
        }
        Copy-Item -Path $item.FullName -Destination $stagingDir -Recurse -Force
    }

    $removedExclusions = Remove-StagingExcludedItem -StagingRoot $stagingDir -Patterns $normalizedExcludes
    $summary['removed_exclusions'] = $removedExclusions

    $closeBefore = Invoke-LabVIEWCliOperationWithConnectionRetry -LabVIEWCliPath $labviewCliPath -OperationName 'CloseLabVIEW-before' -PrimaryPortNumber $tcpSettings.PortNumber -AllowImplicitPortFallback -Arguments @(
        '-OperationName', 'CloseLabVIEW',
        '-LabVIEWPath', $labviewPath,
        '-PortNumber', $tcpSettings.PortNumber.ToString(),
        '-LogToConsole', 'TRUE',
        '-Verbosity', 'Default'
    ) -LabVIEWCliLogRoot $labviewCliLogRoot
    $summary.operations += $closeBefore

    $customOperationsRoot = Join-Path $repoRootResolved 'Tooling\labviewcli-operations'
    if (Test-Path -Path $customOperationsRoot) {
        $summary.cache_clear.custom_operation_attempted = $true
        $customOp = Invoke-LabVIEWCliOperationWithConnectionRetry -LabVIEWCliPath $labviewCliPath -OperationName 'ClearCompiledObjectCache' -PrimaryPortNumber $tcpSettings.PortNumber -AllowImplicitPortFallback -Arguments @(
            '-OperationName', 'ClearCompiledObjectCache',
            '-LabVIEWPath', $labviewPath,
            '-PortNumber', $tcpSettings.PortNumber.ToString(),
            '-LogToConsole', 'TRUE',
            '-Verbosity', 'Default',
            '-AdditionalOperationDirectory', $customOperationsRoot
        ) -LabVIEWCliLogRoot $labviewCliLogRoot
        $summary.operations += $customOp
        $summary.cache_clear.custom_operation = $customOp

        if ($customOp.exit_code -eq 0) {
            $summary.cache_clear.method = 'cli-custom-operation'
        } else {
            if ($RequireCliCacheClearOp) {
                throw ("ClearCompiledObjectCache custom operation failed with exit code {0} and fallback is disabled." -f $customOp.exit_code)
            }
            $fallbackResult = Clear-VIObjCacheFallback -NumericVersion $versionInfo.NumericVersion
            $summary.cache_clear.method = 'filesystem-fallback'
            $summary.cache_clear.fallback = $fallbackResult
        }
    } else {
        if ($RequireCliCacheClearOp) {
            throw "Tooling/labviewcli-operations was not found and fallback is disabled."
        }
        $fallbackResult = Clear-VIObjCacheFallback -NumericVersion $versionInfo.NumericVersion
        $summary.cache_clear.method = 'filesystem-fallback'
        $summary.cache_clear.fallback = $fallbackResult
    }

    $massCompile = Invoke-LabVIEWCliOperationWithConnectionRetry -LabVIEWCliPath $labviewCliPath -OperationName 'MassCompile' -PrimaryPortNumber $tcpSettings.PortNumber -AllowImplicitPortFallback -Arguments @(
        '-LogToConsole', 'TRUE',
        '-OperationName', 'MassCompile',
        '-DirectoryToCompile', $stagingDir,
        '-LabVIEWPath', $labviewPath,
        '-PortNumber', $tcpSettings.PortNumber.ToString(),
        '-Headless'
    ) -LabVIEWCliLogRoot $labviewCliLogRoot
    $summary.operations += $massCompile
    $summary.mass_compile = $massCompile

    if ($massCompile.exit_code -ne 0) {
        $outputTail = @($massCompile.output_tail)
        $hasAliasMismatchWarning = ($outputTail | Where-Object { $_ -like '* was loaded from *' }).Count -gt 0
        if ($massCompile.exit_code -eq 3 -and $hasAliasMismatchWarning) {
            $warningMessage = 'MassCompile returned exit code 3 with staged alias-mismatch warnings. Continuing preflight.'
            Write-Warning $warningMessage
            $summary['mass_compile_warning'] = $warningMessage
        } else {
            throw ("MassCompile failed with exit code {0}." -f $massCompile.exit_code)
        }
    }

    $closeAfter = Invoke-LabVIEWCliOperationWithConnectionRetry -LabVIEWCliPath $labviewCliPath -OperationName 'CloseLabVIEW-after' -PrimaryPortNumber $tcpSettings.PortNumber -AllowImplicitPortFallback -Arguments @(
        '-OperationName', 'CloseLabVIEW',
        '-LabVIEWPath', $labviewPath,
        '-PortNumber', $tcpSettings.PortNumber.ToString(),
        '-LogToConsole', 'TRUE',
        '-Verbosity', 'Default'
    ) -LabVIEWCliLogRoot $labviewCliLogRoot
    $summary.operations += $closeAfter

    $summary.status = 'success'
    Write-Host "LabVIEWCLI mass-compile preflight completed successfully."
}
catch {
    $failure = $_
    $summary.status = 'failure'
    $summary.error_message = $_.Exception.Message
    Write-Error $_
}
finally {
    if (Test-Path -Path $stagingDir) {
        Remove-Item -Path $stagingDir -Recurse -Force -ErrorAction SilentlyContinue
    }
    $summary['completed_utc'] = (Get-Date).ToUniversalTime().ToString('o')
    $summary | ConvertTo-Json -Depth 8 | Out-File -FilePath $summaryPath -Encoding utf8
    Write-Host ("Wrote preflight summary: {0}" -f $summaryPath)
}

if ($failure) {
    throw $failure
}
