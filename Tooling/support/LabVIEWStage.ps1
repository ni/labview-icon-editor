#Requires -Version 7.0
<#
.SYNOPSIS
    Shared helpers for LabVIEW stage execution.
#>

$ErrorActionPreference = 'Stop'

function Get-OutputTail {
    param(
        [string[]]$Lines,
        [int]$MaxLines = 20
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

function New-LabVIEWStageStepLog {
    param(
        [string]$Name,
        [datetime]$StartTime,
        [datetime]$EndTime,
        [int]$ExitCode,
        [string]$ErrorMessage,
        [string[]]$OutputLines
    )

    $durationMs = [int]([Math]::Round(($EndTime - $StartTime).TotalMilliseconds))
    return [pscustomobject]@{
        Name       = $Name
        StartUtc   = $StartTime.ToUniversalTime().ToString('o')
        EndUtc     = $EndTime.ToUniversalTime().ToString('o')
        DurationMs = $durationMs
        ExitCode   = $ExitCode
        Error      = $ErrorMessage
        OutputTail = Get-OutputTail -Lines $OutputLines -MaxLines 20
    }
}

function New-LabVIEWStageLogContext {
    param(
        [string]$StageName,
        [string]$RepoRoot,
        [string]$LogRootOverride
    )

    $timestamp = Get-Date -Format 'yyyyMMdd-HHmmss'
    $safeStage = ($StageName -replace '[^a-zA-Z0-9_.-]', '_')
    $logRoot = if ([string]::IsNullOrWhiteSpace($LogRootOverride)) {
        if (-not [string]::IsNullOrWhiteSpace($env:LVIE_STAGE_LOG_ROOT)) {
            $env:LVIE_STAGE_LOG_ROOT
        } else {
            Join-Path $RepoRoot 'TestResults\agent-logs'
        }
    } else {
        $LogRootOverride
    }

    New-Item -Path $logRoot -ItemType Directory -Force | Out-Null
    $logFile = Join-Path $logRoot ("labview-stage-{0}-{1}.jsonl" -f $safeStage, $timestamp)
    $summaryFile = Join-Path $logRoot ("labview-stage-{0}-{1}-summary.json" -f $safeStage, $timestamp)

    return [pscustomobject]@{
        LogRoot     = $logRoot
        LogFile     = $logFile
        SummaryFile = $summaryFile
        Timestamp   = $timestamp
    }
}

function Write-LabVIEWStageLogEntry {
    param(
        [string]$LogFile,
        [psobject]$Entry
    )

    $json = $Entry | ConvertTo-Json -Depth 10 -Compress
    Add-Content -Path $LogFile -Value $json
}

function Write-LabVIEWStageSummary {
    param(
        [string]$SummaryFile,
        [psobject[]]$Entries,
        [string]$StageName,
        [string]$LogFile
    )

    $total = if ($Entries) { $Entries.Count } else { 0 }
    $skipped = if ($Entries) { ($Entries | Where-Object { $_.Result.Skipped }).Count } else { 0 }
    $succeeded = if ($Entries) { ($Entries | Where-Object { $_.Result.Succeeded }).Count } else { 0 }
    $failed = $total - $skipped - $succeeded

    $summary = [pscustomobject]@{
        StageName  = $StageName
        Timestamp = (Get-Date).ToUniversalTime().ToString('o')
        Total      = $total
        Succeeded  = $succeeded
        Failed     = $failed
        Skipped    = $skipped
        LogFile    = $LogFile
    }

    $summary | ConvertTo-Json -Depth 6 | Set-Content -Path $SummaryFile

    Write-Host ("LabVIEWStage summary: {0} total={1} ok={2} failed={3} skipped={4}" -f $StageName, $total, $succeeded, $failed, $skipped)
    Write-Host ("LabVIEWStage log: {0}" -f $LogFile)
    Write-Host ("LabVIEWStage summary: {0}" -f $SummaryFile)
}

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

    return (Resolve-Path -Path (Join-Path $scriptRoot '..\..')).Path
}

function Resolve-LabVIEWVersion {
    param(
        [string]$VersionInput,
        [string]$RepoRoot
    )

    $resolvedVersion = $VersionInput
    $helper = Join-Path -Path $RepoRoot -ChildPath 'Tooling\support\LabVIEWVersion.ps1'
    if (Test-Path -Path $helper) {
        . $helper
        $info = Get-LabVIEWVersionInfo -VersionInput $VersionInput -RepoRoot $RepoRoot
        if ($info -and $info.Year) {
            $resolvedVersion = $info.Year
        }
    }
    if ([string]::IsNullOrWhiteSpace($resolvedVersion)) {
        $resolvedVersion = '2021'
    }
    return $resolvedVersion
}

function Get-BitnessList {
    param(
        [string]$BitnessInput
    )

    if ([string]::IsNullOrWhiteSpace($BitnessInput)) {
        return @('64')
    }

    $normalized = $BitnessInput.Trim().ToLowerInvariant()
    if (@('both', 'all', 'auto') -contains $normalized) {
        return @('64', '32')
    }

    $parts = $normalized -split '[,; ]+' | Where-Object { $_ }
    $bitnesses = foreach ($part in $parts) {
        switch ($part) {
            '32' { '32' }
            '64' { '64' }
        }
    }

    $bitnesses = $bitnesses | Where-Object { $_ } | Select-Object -Unique
    if (-not $bitnesses) {
        return @('64')
    }

    return @($bitnesses)
}

function Resolve-BitnessList {
    param(
        [string[]]$Bitnesses,
        [string]$FallbackInput
    )

    if ($Bitnesses -and $Bitnesses.Count -gt 0) {
        return @($Bitnesses | Select-Object -Unique)
    }

    return Get-BitnessList -BitnessInput $FallbackInput
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

function ConvertTo-LabVIEWCliPortNumber {
    param(
        [AllowNull()]
        [AllowEmptyString()]
        [string]$RawValue,

        [Parameter(Mandatory = $true)]
        [string]$Source
    )

    if ([string]::IsNullOrWhiteSpace($RawValue)) {
        return $null
    }

    $parsedPort = 0
    if (-not [int]::TryParse($RawValue.Trim(), [ref]$parsedPort) -or $parsedPort -lt 1 -or $parsedPort -gt 65535) {
        Write-Warning ("Ignoring invalid port value '{0}' from {1}. Expected integer range 1-65535." -f $RawValue, $Source)
        return $null
    }

    return $parsedPort
}

function Get-LabVIEWIniTcpSetting {
    param(
        [Parameter(Mandatory = $true)]
        [string]$LabVIEWExecutablePath
    )

    $iniPath = Join-Path -Path (Split-Path -Path $LabVIEWExecutablePath -Parent) -ChildPath 'LabVIEW.ini'
    $portRaw = $null
    $enabledRaw = $null
    $enabledValue = $null

    if (-not (Test-Path -Path $iniPath -PathType Leaf)) {
        return [pscustomobject]@{
            IniPath      = $iniPath
            PortRaw      = $portRaw
            EnabledRaw   = $enabledRaw
            EnabledValue = $enabledValue
        }
    }

    try {
        $lines = Get-Content -Path $iniPath -ErrorAction Stop
    } catch {
        Write-Warning ("Unable to read LabVIEW.ini at {0}: {1}" -f $iniPath, $_.Exception.Message)
        return [pscustomobject]@{
            IniPath      = $iniPath
            PortRaw      = $portRaw
            EnabledRaw   = $enabledRaw
            EnabledValue = $enabledValue
        }
    }

    foreach ($line in $lines) {
        if ($null -eq $line) {
            continue
        }
        if ($line -match '^\s*server\.tcp\.port\s*=\s*(.+?)\s*$') {
            $portRaw = $Matches[1].Trim()
            continue
        }
        if ($line -match '^\s*server\.tcp\.enabled\s*=\s*(.+?)\s*$') {
            $enabledRaw = $Matches[1].Trim()
            continue
        }
    }

    if (-not [string]::IsNullOrWhiteSpace($enabledRaw)) {
        $normalized = $enabledRaw.Trim().ToLowerInvariant()
        if (@('true', 't', '1', 'yes', 'y') -contains $normalized) {
            $enabledValue = $true
        } elseif (@('false', 'f', '0', 'no', 'n') -contains $normalized) {
            $enabledValue = $false
        } else {
            Write-Warning ("Ignoring unrecognized server.tcp.enabled value '{0}' in {1}." -f $enabledRaw, $iniPath)
        }
    }

    return [pscustomobject]@{
        IniPath      = $iniPath
        PortRaw      = $portRaw
        EnabledRaw   = $enabledRaw
        EnabledValue = $enabledValue
    }
}

function Resolve-LabVIEWCliPort {
    param(
        [Parameter(Mandatory = $true)]
        [ValidateSet('32', '64')]
        [string]$Bitness,

        [Parameter(Mandatory = $true)]
        [string]$LabVIEWExecutablePath
    )

    $bitnessEnvName = "LVIE_LUNIT_PORT_{0}" -f $Bitness
    $bitnessEnvValue = [Environment]::GetEnvironmentVariable($bitnessEnvName)
    $bitnessPort = ConvertTo-LabVIEWCliPortNumber -RawValue $bitnessEnvValue -Source ('$env:{0}' -f $bitnessEnvName)
    if ($null -ne $bitnessPort) {
        return [pscustomobject]@{
            PortNumber     = $bitnessPort
            Source         = ('$env:{0}' -f $bitnessEnvName)
            HasEnvOverride = $true
            IniPath        = $null
            ViServerEnabled = $null
        }
    }

    $genericEnvValue = [Environment]::GetEnvironmentVariable('LVIE_LUNIT_PORT')
    $genericPort = ConvertTo-LabVIEWCliPortNumber -RawValue $genericEnvValue -Source '$env:LVIE_LUNIT_PORT'
    if ($null -ne $genericPort) {
        return [pscustomobject]@{
            PortNumber      = $genericPort
            Source          = '$env:LVIE_LUNIT_PORT'
            HasEnvOverride  = $true
            IniPath         = $null
            ViServerEnabled = $null
        }
    }

    $iniSettings = Get-LabVIEWIniTcpSetting -LabVIEWExecutablePath $LabVIEWExecutablePath
    $iniPort = ConvertTo-LabVIEWCliPortNumber -RawValue $iniSettings.PortRaw -Source ('{0} (server.tcp.port)' -f $iniSettings.IniPath)
    if ($null -ne $iniPort) {
        return [pscustomobject]@{
            PortNumber      = $iniPort
            Source          = ('{0} (server.tcp.port)' -f $iniSettings.IniPath)
            HasEnvOverride  = $false
            IniPath         = $iniSettings.IniPath
            ViServerEnabled = $iniSettings.EnabledValue
        }
    }

    if ($iniSettings.EnabledValue -eq $false) {
        throw ("VI Server TCP is disabled in {0}. Set LVIE_LUNIT_PORT_{1} or LVIE_LUNIT_PORT to override." -f $iniSettings.IniPath, $Bitness)
    }

    return [pscustomobject]@{
        PortNumber      = 3363
        Source          = 'default:3363'
        HasEnvOverride  = $false
        IniPath         = $iniSettings.IniPath
        ViServerEnabled = $iniSettings.EnabledValue
    }
}

function Invoke-LabVIEWCli {
    param(
        [Parameter(Mandatory = $true)]
        [string[]]$Arguments
    )

    $labviewCliCommand = Get-Command LabVIEWCLI -ErrorAction SilentlyContinue
    if (-not $labviewCliCommand) {
        throw "LabVIEWCLI is not available on PATH."
    }

    $rawOutput = & $labviewCliCommand.Source @Arguments 2>&1
    $exitCode = $LASTEXITCODE
    $lines = @()
    foreach ($entry in $rawOutput) {
        if ($null -ne $entry) {
            $lines += [string]$entry
        }
    }
    $lines | Out-Host

    return [pscustomobject]@{
        ExitCode    = $exitCode
        OutputLines = $lines
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

function New-LabVIEWCliResultWithRetryInfo {
    param(
        [Parameter(Mandatory = $true)]
        [pscustomobject]$Result,
        [string[]]$Attempts,
        [AllowNull()]
        [int]$PortNumber,
        [AllowNull()]
        [string]$PortSource,
        [bool]$UsedImplicitPort
    )

    return [pscustomobject]@{
        ExitCode         = $Result.ExitCode
        OutputLines      = @($Result.OutputLines)
        Attempts         = @($Attempts)
        PortNumber       = $PortNumber
        PortSource       = $PortSource
        UsedImplicitPort = $UsedImplicitPort
    }
}

function Invoke-LabVIEWCliWithConnectionRetry {
    param(
        [Parameter(Mandatory = $true)]
        [string]$OperationName,
        [Parameter(Mandatory = $true)]
        [string[]]$Arguments,
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
        $result = Invoke-LabVIEWCli -Arguments $portArgs
        $lastResult = $result
        $lastPortNumber = $portNumber
        $lastPortSource = $portSource

        $attemptSummaries.Add(("port:{0} source:{1} exit:{2}" -f $portNumber, $portSource, $result.ExitCode)) | Out-Null
        foreach ($line in @($result.OutputLines)) {
            $combinedOutput.Add($line) | Out-Null
        }

        if ($result.ExitCode -eq 0) {
            return [pscustomobject]@{
                ExitCode         = 0
                OutputLines      = @($combinedOutput.ToArray())
                Attempts         = @($attemptSummaries.ToArray())
                PortNumber       = $portNumber
                PortSource       = $portSource
                UsedImplicitPort = $false
            }
        }

        if (Test-LabVIEWCliConnectionFailure -OutputLines $result.OutputLines) {
            $sawConnectionFailure = $true
            continue
        }

        return New-LabVIEWCliResultWithRetryInfo -Result $result -Attempts @($attemptSummaries.ToArray()) -PortNumber $portNumber -PortSource $portSource -UsedImplicitPort:$false
    }

    if ($AllowImplicitPortFallback -and $sawConnectionFailure) {
        Write-Warning ("{0}: explicit port attempts failed with connection errors; retrying without -PortNumber." -f $OperationName)
        $implicitArgs = Remove-LabVIEWCliPortArgument -Arguments $Arguments
        $implicitResult = Invoke-LabVIEWCli -Arguments $implicitArgs
        $lastResult = $implicitResult
        $lastPortNumber = $null
        $lastPortSource = 'implicit-default'
        $attemptSummaries.Add(("port:implicit source:implicit-default exit:{0}" -f $implicitResult.ExitCode)) | Out-Null
        foreach ($line in @($implicitResult.OutputLines)) {
            $combinedOutput.Add($line) | Out-Null
        }

        if ($implicitResult.ExitCode -eq 0) {
            return [pscustomobject]@{
                ExitCode         = 0
                OutputLines      = @($combinedOutput.ToArray())
                Attempts         = @($attemptSummaries.ToArray())
                PortNumber       = $null
                PortSource       = 'implicit-default'
                UsedImplicitPort = $true
            }
        }
    }

    if ($null -eq $lastResult) {
        return [pscustomobject]@{
            ExitCode         = 1
            OutputLines      = @("No LabVIEWCLI attempts were executed for $OperationName.")
            Attempts         = @($attemptSummaries.ToArray())
            PortNumber       = $lastPortNumber
            PortSource       = $lastPortSource
            UsedImplicitPort = $false
        }
    }

    $finalOutput = if ($combinedOutput.Count -gt 0) { @($combinedOutput.ToArray()) } else { @($lastResult.OutputLines) }
    return [pscustomobject]@{
        ExitCode         = $lastResult.ExitCode
        OutputLines      = $finalOutput
        Attempts         = @($attemptSummaries.ToArray())
        PortNumber       = $lastPortNumber
        PortSource       = $lastPortSource
        UsedImplicitPort = ($lastPortSource -eq 'implicit-default')
    }
}

function Invoke-RunIconEditorFromSourceSelector {
    param(
        [Parameter(Mandatory = $true)]
        [string]$RepoRoot,

        [Parameter(Mandatory = $true)]
        [string]$LabVIEWVersion,

        [Parameter(Mandatory = $true)]
        [ValidateSet('32', '64')]
        [string]$Bitness,

        [Parameter(Mandatory = $true)]
        [ValidateSet('enable', 'disable')]
        [string]$Mode
    )

    try {
        $selectorViPath = Join-Path $RepoRoot 'Tooling\Run Icon Editor from Source Selector.vi'
        if (-not (Test-Path -Path $selectorViPath -PathType Leaf)) {
            throw "Selector VI not found at $selectorViPath"
        }

        $installRoot = Get-LabVIEWInstallRoot -Version $LabVIEWVersion -Bitness $Bitness
        if ([string]::IsNullOrWhiteSpace($installRoot)) {
            throw "LabVIEW $LabVIEWVersion ($Bitness-bit) install not found."
        }

        $labviewExecutablePath = Join-Path $installRoot 'LabVIEW.exe'
        if (-not (Test-Path -Path $labviewExecutablePath -PathType Leaf)) {
            throw "LabVIEW executable not found at $labviewExecutablePath"
        }

        $portResolution = Resolve-LabVIEWCliPort -Bitness $Bitness -LabVIEWExecutablePath $labviewExecutablePath
        $selectorMode = if ($Mode -eq 'enable') { 'set' } else { 'unset' }
        Write-Host ("Running selector VI mode '{0}' ({1}-bit) via LabVIEWCLI on port {2} (source: {3})" -f $selectorMode, $Bitness, $portResolution.PortNumber, $portResolution.Source)

        return Invoke-LabVIEWCliWithConnectionRetry -OperationName ("Selector-{0}-{1}-bit" -f $selectorMode, $Bitness) -PrimaryPortNumber $portResolution.PortNumber -AllowImplicitPortFallback -Arguments @(
            '-OperationName', 'RunVI',
            '-LabVIEWPath', $labviewExecutablePath,
            '-PortNumber', $portResolution.PortNumber.ToString(),
            '-VIPath', $selectorViPath,
            '-Headless',
            $selectorMode
        )
    } catch {
        $message = $_.Exception.Message
        Write-Error $message
        return [pscustomobject]@{
            ExitCode    = 1
            OutputLines = @($message)
        }
    }
}

function Invoke-LabVIEWScript {
    param(
        [string]$ScriptPath,
        [string[]]$Arguments
    )

    $pwsh = (Get-Command pwsh -ErrorAction Stop).Source
    $rawOutput = & $pwsh -NoProfile -File $ScriptPath @Arguments 2>&1
    $exitCode = $LASTEXITCODE
    $lines = @()
    foreach ($entry in $rawOutput) {
        if ($null -ne $entry) {
            $lines += [string]$entry
        }
    }
    $lines | Out-Host
    return [pscustomobject]@{
        ExitCode    = $exitCode
        OutputLines = $lines
    }
}

function Invoke-LabVIEWClose {
    param(
        [string]$RepoRoot,
        [string]$LabVIEWVersion,
        [string]$Bitness
    )

    $closeScript = Join-Path -Path $RepoRoot -ChildPath '.github\actions\close-labview\Close_LabVIEW.ps1'
    if (-not (Test-Path -Path $closeScript)) {
        throw "Close_LabVIEW.ps1 not found at $closeScript"
    }

    return Invoke-LabVIEWScript -ScriptPath $closeScript -Arguments @(
        '-LabVIEWVersion', $LabVIEWVersion,
        '-SupportedBitness', $Bitness
    )
}

function Invoke-DevModeNoLabVIEW {
    param(
        [string]$RepoRoot,
        [string]$LabVIEWVersion,
        [string]$Bitness,
        [ValidateSet('enable', 'disable')]
        [string]$Mode,
        [switch]$SkipProcessCheck
    )

    if ($SkipProcessCheck) {
        Write-Verbose "SkipProcessCheck is ignored for selector-based dev-mode toggles."
    }

    return Invoke-RunIconEditorFromSourceSelector `
        -RepoRoot $RepoRoot `
        -LabVIEWVersion $LabVIEWVersion `
        -Bitness $Bitness `
        -Mode $Mode
}

function New-LabVIEWStageContext {
    param(
        [string]$StageName,
        [string]$RepoRoot,
        [string]$LabVIEWVersion,
        [string]$Bitness,
        [int]$ConnectTimeoutMs
    )

    return [pscustomobject]@{
        StageName        = $StageName
        RepoRoot         = $RepoRoot
        LabVIEWVersion   = $LabVIEWVersion
        Bitness          = $Bitness
        ConnectTimeoutMs = $ConnectTimeoutMs
    }
}

function Invoke-LabVIEWStage {
    param(
        [Parameter(Mandatory = $true)]
        [string]$StageName,

        [Parameter(Mandatory = $true)]
        [string]$RepoRoot,

        [Parameter(Mandatory = $true)]
        [string]$LabVIEWVersion,

        [string[]]$Bitnesses,

        [int]$ConnectTimeoutMs = 120000,

        [switch]$DevModeNoLabVIEW,

        [switch]$SkipDevModeProcessCheck,

        [switch]$CloseBetweenStages,

        [switch]$SkipOnBaselineFailure,

        [string]$LogRoot,

        [Parameter(Mandatory = $true)]
        [scriptblock]$Action
    )

    $closeBetweenStagesEnabled = $CloseBetweenStages.IsPresent -or -not $PSBoundParameters.ContainsKey('CloseBetweenStages')
    $skipOnBaselineFailureEnabled = $SkipOnBaselineFailure.IsPresent -or -not $PSBoundParameters.ContainsKey('SkipOnBaselineFailure')
    $skipDevModeProcessCheckEnabled = $SkipDevModeProcessCheck.IsPresent
    if (-not $skipDevModeProcessCheckEnabled -and -not [string]::IsNullOrWhiteSpace($env:LVIE_SKIP_DEVMODE_PROCESS_CHECK)) {
        $skipSetting = $env:LVIE_SKIP_DEVMODE_PROCESS_CHECK.Trim().ToLowerInvariant()
        if (@('1', 'true', 'yes', 'y', 'on') -contains $skipSetting) {
            $skipDevModeProcessCheckEnabled = $true
        }
    }

    $resolvedRepoRoot = Resolve-RepoRoot -PathOverride $RepoRoot
    $resolvedVersion = Resolve-LabVIEWVersion -VersionInput $LabVIEWVersion -RepoRoot $resolvedRepoRoot
    $bitnessList = Resolve-BitnessList -Bitnesses $Bitnesses -FallbackInput $env:LABVIEW_BITNESS

    $logContext = New-LabVIEWStageLogContext -StageName $StageName -RepoRoot $resolvedRepoRoot -LogRootOverride $LogRoot
    $results = @()
    $logEntries = @()
    foreach ($bitness in $bitnessList) {
        $bitnessStart = Get-Date
        $closeBeforeInfo = $null
        $baselineInfo = $null
        $enableInfo = $null
        $actionInfo = $null
        $revertInfo = $null
        $closeAfterInfo = $null
        $resultEntry = $null

        if (-not (Get-LabVIEWInstallRoot -Version $resolvedVersion -Bitness $bitness)) {
            $resultEntry = [pscustomobject]@{
                StageName  = $StageName
                Bitness    = $bitness
                Succeeded  = $false
                Skipped    = $true
                SkipReason = "LabVIEW $resolvedVersion ($bitness-bit) install not found."
                ExitCode   = $null
                Error      = $null
            }
            $results += $resultEntry
            $bitnessEnd = Get-Date
            $logEntry = [pscustomobject]@{
                StageName       = $StageName
                LabVIEWVersion  = $resolvedVersion
                Bitness         = $bitness
                RepoRoot        = $resolvedRepoRoot
                StartUtc        = $bitnessStart.ToUniversalTime().ToString('o')
                EndUtc          = $bitnessEnd.ToUniversalTime().ToString('o')
                DurationMs      = [int]([Math]::Round(($bitnessEnd - $bitnessStart).TotalMilliseconds))
                DevModeNoLabVIEW = [bool]$DevModeNoLabVIEW
                SkipDevModeProcessCheck = [bool]$skipDevModeProcessCheckEnabled
                CloseBetweenStages = [bool]$closeBetweenStagesEnabled
                Result          = $resultEntry
                Steps           = [pscustomobject]@{
                    CloseBefore   = $closeBeforeInfo
                    BaselineRevert = $baselineInfo
                    EnableDevMode = $enableInfo
                    Action        = $actionInfo
                    RevertDevMode  = $revertInfo
                    CloseAfter    = $closeAfterInfo
                }
            }
            $logEntries += $logEntry
            try { Write-LabVIEWStageLogEntry -LogFile $logContext.LogFile -Entry $logEntry } catch { Write-Verbose ("LabVIEWStage: failed to write stage log entry. {0}" -f $_.Exception.Message) }
            continue
        }

        if ($closeBetweenStagesEnabled) {
            $closeStart = Get-Date
            $closeResult = Invoke-LabVIEWClose -RepoRoot $resolvedRepoRoot -LabVIEWVersion $resolvedVersion -Bitness $bitness
            $closeEnd = Get-Date
            $closeBeforeInfo = New-LabVIEWStageStepLog -Name 'close-before' -StartTime $closeStart -EndTime $closeEnd -ExitCode $closeResult.ExitCode -ErrorMessage $null -OutputLines $closeResult.OutputLines
        }

        if ($DevModeNoLabVIEW) {
            $baselineStart = Get-Date
            $baseline = Invoke-DevModeNoLabVIEW -RepoRoot $resolvedRepoRoot -LabVIEWVersion $resolvedVersion -Bitness $bitness -Mode 'disable' -SkipProcessCheck:$skipDevModeProcessCheckEnabled
            $baselineEnd = Get-Date
            $baselineInfo = New-LabVIEWStageStepLog -Name 'baseline-revert' -StartTime $baselineStart -EndTime $baselineEnd -ExitCode $baseline.ExitCode -ErrorMessage $null -OutputLines $baseline.OutputLines
            if ($baseline.ExitCode -ne 0) {
                if ($skipOnBaselineFailureEnabled) {
                    $resultEntry = [pscustomobject]@{
                        StageName  = $StageName
                        Bitness    = $bitness
                        Succeeded  = $false
                        Skipped    = $true
                        SkipReason = "Baseline dev mode revert failed with exit code $($baseline.ExitCode)."
                        ExitCode   = $baseline.ExitCode
                        Error      = $null
                    }
                    if ($closeBetweenStagesEnabled) {
                        $closeAfterStart = Get-Date
                        $closeAfterResult = Invoke-LabVIEWClose -RepoRoot $resolvedRepoRoot -LabVIEWVersion $resolvedVersion -Bitness $bitness
                        $closeAfterEnd = Get-Date
                        $closeAfterInfo = New-LabVIEWStageStepLog -Name 'close-after' -StartTime $closeAfterStart -EndTime $closeAfterEnd -ExitCode $closeAfterResult.ExitCode -ErrorMessage $null -OutputLines $closeAfterResult.OutputLines
                    }
                    $results += $resultEntry
                    $bitnessEnd = Get-Date
                    $logEntry = [pscustomobject]@{
                        StageName       = $StageName
                        LabVIEWVersion  = $resolvedVersion
                        Bitness         = $bitness
                        RepoRoot        = $resolvedRepoRoot
                        StartUtc        = $bitnessStart.ToUniversalTime().ToString('o')
                        EndUtc          = $bitnessEnd.ToUniversalTime().ToString('o')
                        DurationMs      = [int]([Math]::Round(($bitnessEnd - $bitnessStart).TotalMilliseconds))
                        DevModeNoLabVIEW = [bool]$DevModeNoLabVIEW
                        SkipDevModeProcessCheck = [bool]$skipDevModeProcessCheckEnabled
                        CloseBetweenStages = [bool]$closeBetweenStagesEnabled
                        Result          = $resultEntry
                        Steps           = [pscustomobject]@{
                            CloseBefore    = $closeBeforeInfo
                            BaselineRevert = $baselineInfo
                            EnableDevMode  = $enableInfo
                            Action         = $actionInfo
                            RevertDevMode  = $revertInfo
                            CloseAfter     = $closeAfterInfo
                        }
                    }
                    $logEntries += $logEntry
                    try { Write-LabVIEWStageLogEntry -LogFile $logContext.LogFile -Entry $logEntry } catch { Write-Verbose ("LabVIEWStage: failed to write baseline log entry. {0}" -f $_.Exception.Message) }
                    continue
                }
                throw "Baseline dev mode revert failed with exit code $($baseline.ExitCode)."
            }
        }

        $exitCode = $null
        $errorMessage = $null
        $devModeEnabled = $false
        try {
            if ($DevModeNoLabVIEW) {
                $enableStart = Get-Date
                $enable = Invoke-DevModeNoLabVIEW -RepoRoot $resolvedRepoRoot -LabVIEWVersion $resolvedVersion -Bitness $bitness -Mode 'enable' -SkipProcessCheck:$skipDevModeProcessCheckEnabled
                $enableEnd = Get-Date
                $enableInfo = New-LabVIEWStageStepLog -Name 'enable-devmode' -StartTime $enableStart -EndTime $enableEnd -ExitCode $enable.ExitCode -ErrorMessage $null -OutputLines $enable.OutputLines
                if ($enable.ExitCode -ne 0) {
                    $exitCode = $enable.ExitCode
                    throw "Dev mode enable failed with exit code $($enable.ExitCode)."
                }
                $devModeEnabled = $true
            }

            $context = New-LabVIEWStageContext -StageName $StageName -RepoRoot $resolvedRepoRoot -LabVIEWVersion $resolvedVersion -Bitness $bitness -ConnectTimeoutMs $ConnectTimeoutMs
            $actionStart = Get-Date
            $actionResult = $null
            $actionError = $null
            try {
                $actionResult = & $Action $context
            } catch {
                $actionError = $_.Exception.Message
            }
            $actionEnd = Get-Date

            if ($actionResult -is [int]) {
                $exitCode = $actionResult
            } elseif ($actionResult -and $null -ne $actionResult.ExitCode) {
                $exitCode = $actionResult.ExitCode
            } elseif ($null -ne $LASTEXITCODE) {
                $exitCode = $LASTEXITCODE
            } else {
                $exitCode = 0
            }

            $actionOutput = if ($actionResult -and $actionResult.OutputLines) { $actionResult.OutputLines } else { $null }
            $actionInfo = New-LabVIEWStageStepLog -Name 'action' -StartTime $actionStart -EndTime $actionEnd -ExitCode $exitCode -ErrorMessage $actionError -OutputLines $actionOutput

            if ($actionError) {
                throw $actionError
            }

            if ($exitCode -ne 0) {
                throw "Stage '$StageName' failed with exit code $exitCode."
            }

            $resultEntry = [pscustomobject]@{
                StageName  = $StageName
                Bitness    = $bitness
                Succeeded  = $true
                Skipped    = $false
                SkipReason = $null
                ExitCode   = $exitCode
                Error      = $null
            }
        } catch {
            $errorMessage = $_.Exception.Message
            $resultEntry = [pscustomobject]@{
                StageName  = $StageName
                Bitness    = $bitness
                Succeeded  = $false
                Skipped    = $false
                SkipReason = $null
                ExitCode   = $exitCode
                Error      = $errorMessage
            }
        } finally {
            if ($devModeEnabled) {
                $revertStart = Get-Date
                $revertResult = Invoke-DevModeNoLabVIEW -RepoRoot $resolvedRepoRoot -LabVIEWVersion $resolvedVersion -Bitness $bitness -Mode 'disable' -SkipProcessCheck:$skipDevModeProcessCheckEnabled
                $revertEnd = Get-Date
                $revertInfo = New-LabVIEWStageStepLog -Name 'revert-devmode' -StartTime $revertStart -EndTime $revertEnd -ExitCode $revertResult.ExitCode -ErrorMessage $null -OutputLines $revertResult.OutputLines
            }
            if ($closeBetweenStagesEnabled) {
                $closeAfterStart = Get-Date
                $closeAfterResult = Invoke-LabVIEWClose -RepoRoot $resolvedRepoRoot -LabVIEWVersion $resolvedVersion -Bitness $bitness
                $closeAfterEnd = Get-Date
                $closeAfterInfo = New-LabVIEWStageStepLog -Name 'close-after' -StartTime $closeAfterStart -EndTime $closeAfterEnd -ExitCode $closeAfterResult.ExitCode -ErrorMessage $null -OutputLines $closeAfterResult.OutputLines
            }
        }

        $results += $resultEntry
        $bitnessEnd = Get-Date
        $logEntry = [pscustomobject]@{
            StageName       = $StageName
            LabVIEWVersion  = $resolvedVersion
            Bitness         = $bitness
            RepoRoot        = $resolvedRepoRoot
            StartUtc        = $bitnessStart.ToUniversalTime().ToString('o')
            EndUtc          = $bitnessEnd.ToUniversalTime().ToString('o')
            DurationMs      = [int]([Math]::Round(($bitnessEnd - $bitnessStart).TotalMilliseconds))
            DevModeNoLabVIEW = [bool]$DevModeNoLabVIEW
            SkipDevModeProcessCheck = [bool]$skipDevModeProcessCheckEnabled
            CloseBetweenStages = [bool]$closeBetweenStagesEnabled
            Result          = $resultEntry
            Steps           = [pscustomobject]@{
                CloseBefore    = $closeBeforeInfo
                BaselineRevert = $baselineInfo
                EnableDevMode  = $enableInfo
                Action         = $actionInfo
                RevertDevMode  = $revertInfo
                CloseAfter     = $closeAfterInfo
            }
        }
        $logEntries += $logEntry
        try { Write-LabVIEWStageLogEntry -LogFile $logContext.LogFile -Entry $logEntry } catch { Write-Verbose ("LabVIEWStage: failed to write stage log entry. {0}" -f $_.Exception.Message) }
    }

    try { Write-LabVIEWStageSummary -SummaryFile $logContext.SummaryFile -Entries $logEntries -StageName $StageName -LogFile $logContext.LogFile } catch { Write-Verbose ("LabVIEWStage: failed to write summary. {0}" -f $_.Exception.Message) }
    return $results
}
