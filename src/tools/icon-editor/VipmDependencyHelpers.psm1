#Requires -Version 7.0

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Test-VipmCliReady {
    param(
        [Parameter(Mandatory)][string]$LabVIEWVersion,
        [Parameter(Mandatory)][string]$LabVIEWBitness,
        [Parameter(Mandatory)][string]$RepoRoot,
        [Parameter(Mandatory)][string]$ProviderName,
        [string]$VipcPath
    )

    Import-Module (Join-Path $RepoRoot 'tools' 'VendorTools.psm1') -Force
    $labviewExe = Find-LabVIEWVersionExePath -Version ([int]$LabVIEWVersion) -Bitness ([int]$LabVIEWBitness)
    if (-not $labviewExe) {
        throw "LabVIEW $LabVIEWVersion ($LabVIEWBitness-bit) was not detected. Install or configure that version before applying VIPC dependencies."
    }

    Import-Module (Join-Path $RepoRoot 'tools' 'Vipm.psm1') -Force
    $params = @{
        vipcPath       = $VipcPath
        labviewVersion = $LabVIEWVersion
        labviewBitness = $LabVIEWBitness
    }

    $providerExtras = Get-VipmProviderInstallParameters -ProviderName $ProviderName -RepoRoot $RepoRoot -LabVIEWVersion $LabVIEWVersion -LabVIEWBitness $LabVIEWBitness -VipcPath $VipcPath
    foreach ($key in $providerExtras.Keys) {
        $params[$key] = $providerExtras[$key]
    }

    try {
        $null = Get-VipmInvocation -Operation 'InstallVipc' -Params $params -ProviderName $ProviderName
    } catch {
        throw "vipmcli/g-cli provider '$ProviderName' is not ready: $($_.Exception.Message)"
    }

    return [pscustomobject]@{
        provider   = $ProviderName
        labviewExe = $labviewExe
    }
}

function Get-VipmDisplayVersionString {
    param(
        [Parameter(Mandatory)][string]$LabVIEWVersion,
        [Parameter(Mandatory)][string]$LabVIEWBitness
    )

    $key = ("{0}-{1}" -f $LabVIEWVersion, $LabVIEWBitness)
    switch ($key) {
        '2021-64' { return '21.0 (64-bit)' }
        '2021-32' { return '21.0' }
        '2022-64' { return '22.3 (64-bit)' }
        '2022-32' { return '22.3' }
        '2023-64' { return '23.3 (64-bit)' }
        '2023-32' { return '23.3' }
        '2024-64' { return '24.3 (64-bit)' }
        '2024-32' { return '24.3' }
        '2025-64' { return '25.3 (64-bit)' }
        '2025-32' { return '25.3' }
        default {
            if ($LabVIEWBitness -eq '64') {
                return ("{0} (64-bit)" -f $LabVIEWVersion)
            }
            return $LabVIEWVersion
        }
    }
}

function Resolve-VipmApplyVipcPath {
    param([Parameter(Mandatory)][string]$RepoRoot)

    $candidate = Join-Path $RepoRoot 'vendor\icon-editor\Tooling\deployment\Applyvipc.vi'
    if (-not (Test-Path -LiteralPath $candidate -PathType Leaf)) {
        throw "Applyvipc.vi not found at '$candidate'. Ensure vendor/icon-editor assets are present."
    }
    return (Resolve-Path -LiteralPath $candidate).Path
}

function Get-VipmProviderInstallParameters {
    param(
        [Parameter(Mandatory)][string]$ProviderName,
        [Parameter(Mandatory)][string]$RepoRoot,
        [Parameter(Mandatory)][string]$LabVIEWVersion,
        [Parameter(Mandatory)][string]$LabVIEWBitness,
        [string]$VipcPath
    )

    $extras = @{}
    switch ($ProviderName.ToLowerInvariant()) {
        'vipm-gcli' {
            if (-not $VipcPath) {
                throw 'vipm-gcli provider requires a VIPC path.'
            }
            $extras.applyVipcPath = Resolve-VipmApplyVipcPath -RepoRoot $RepoRoot
            $extras.targetVersion = Get-VipmDisplayVersionString -LabVIEWVersion $LabVIEWVersion -LabVIEWBitness $LabVIEWBitness
        }
    }

    return $extras
}

function Initialize-VipmTelemetry {
    param([Parameter(Mandatory)][string]$RepoRoot)

    $root = Join-Path $RepoRoot 'tests\results\_agent\icon-editor\vipm-install'
    if (-not (Test-Path -LiteralPath $root -PathType Container)) {
        New-Item -ItemType Directory -Path $root -Force | Out-Null
    }
    return (Resolve-Path -LiteralPath $root).Path
}

function Get-VipmInstalledPackages {
    param(
        [Parameter(Mandatory)][string]$LabVIEWVersion,
        [Parameter(Mandatory)][string]$LabVIEWBitness
    )

    $vipmCommand = Get-Command vipm -ErrorAction Stop
    $output = & $vipmCommand.Source 'list' '--installed' '--labview-version' $LabVIEWVersion '--labview-bitness' $LabVIEWBitness '--color-mode' 'never' 2>&1
    if ($LASTEXITCODE -ne 0) {
        throw "vipm list --installed failed: $output"
    }

    $packages = @()
    foreach ($line in ($output -split [Environment]::NewLine)) {
        if ($line -match '^\s+(?<name>.+?)\s+\((?<identifier>.+?)\sv(?<version>[^\)]+)\)') {
            $packages += [ordered]@{
                name       = $Matches.name.Trim()
                identifier = $Matches.identifier.Trim()
                version    = $Matches.version.Trim()
            }
        }
    }

    return [pscustomobject]@{
        rawOutput = $output
        packages  = $packages
    }
}

$serializerOptions = [System.Text.Json.JsonSerializerOptions]::new()
$serializerOptions.WriteIndented = $true
$serializerOptions.ReferenceHandler = [System.Text.Json.Serialization.ReferenceHandler]::Preserve
$serializerOptions.DefaultIgnoreCondition = [System.Text.Json.Serialization.JsonIgnoreCondition]::WhenWritingNull

function ConvertTo-SerializableObject {
    param([object]$Value)

    if ($null -eq $Value) { return $null }

    $type = $Value.GetType()
    if ($type.IsPrimitive -or $Value -is [string] -or $Value -is [decimal] -or $Value -is [datetime]) {
        return $Value
    }

    if ($Value -is [System.Collections.IDictionary]) {
        $dict = @{}
        foreach ($key in $Value.Keys) {
            $dict[$key] = ConvertTo-SerializableObject -Value $Value[$key]
        }
        return $dict
    }

    if ($Value -is [System.Collections.IEnumerable] -and -not ($Value -is [string])) {
        $list = New-Object System.Collections.ArrayList
        foreach ($item in $Value) {
            $list.Add((ConvertTo-SerializableObject -Value $item)) | Out-Null
        }
        return $list
    }

    if ($Value -is [System.Management.Automation.PSCustomObject] -or $Value -is [psobject]) {
        $cleanObject = [pscustomobject]@{}
        foreach ($prop in $Value.PSObject.Properties) {
            $cleanObject | Add-Member -NotePropertyName $prop.Name -NotePropertyValue (ConvertTo-SerializableObject -Value $prop.Value)
        }
        return $cleanObject
    }

    return $Value.ToString()
}

function Write-VipmTelemetryLog {
    param(
        [Parameter(Mandatory)][string]$LogRoot,
        [Parameter(Mandatory)][string]$Provider,
        [Parameter(Mandatory)][string]$Binary,
        [Parameter(Mandatory)][string[]]$Arguments,
        [Parameter(Mandatory)][string]$WorkingDirectory,
        [Parameter(Mandatory)][int]$ExitCode,
        [string]$StdOut,
        [string]$StdErr,
        [string]$LabVIEWVersion,
        [string]$LabVIEWBitness
    )

    $payload = [ordered]@{
        schema         = 'icon-editor/vipm-install@v1'
        generatedAt    = (Get-Date).ToString('o')
        provider       = $Provider
        binary         = $Binary
        arguments      = $Arguments
        workingDir     = $WorkingDirectory
        labviewVersion = $LabVIEWVersion
        labviewBitness = $LabVIEWBitness
        exitCode       = $ExitCode
        stdout         = ($StdOut ?? '').Trim()
        stderr         = ($StdErr ?? '').Trim()
    }

    $logName = ('vipm-install-{0:yyyyMMddTHHmmssfff}.json' -f (Get-Date))
    $logPath = Join-Path $LogRoot $logName
    $cleanPayload = ConvertTo-SerializableObject -Value $payload
    $json = [System.Text.Json.JsonSerializer]::Serialize($cleanPayload, $serializerOptions)
    Set-Content -LiteralPath $logPath -Encoding UTF8 -Value $json
    return $logPath
}

function Write-VipmInstalledPackagesLog {
    param(
        [Parameter(Mandatory)][string]$LogRoot,
        [Parameter(Mandatory)][string]$LabVIEWVersion,
        [Parameter(Mandatory)][string]$LabVIEWBitness,
        [Parameter(Mandatory)][pscustomobject]$PackageInfo
    )

    $payload = [ordered]@{
        schema         = 'icon-editor/vipm-installed@v1'
        generatedAt    = (Get-Date).ToString('o')
        labviewVersion = $LabVIEWVersion
        labviewBitness = $LabVIEWBitness
        packages       = $PackageInfo.packages
        rawOutput      = $PackageInfo.rawOutput
    }

    $logName = ('vipm-installed-{0}-{1}bit-{2:yyyyMMddTHHmmssfff}.json' -f $LabVIEWVersion, $LabVIEWBitness, (Get-Date))
    $logPath = Join-Path $LogRoot $logName
    $cleanPayload = ConvertTo-SerializableObject -Value $payload
    $json = [System.Text.Json.JsonSerializer]::Serialize($cleanPayload, $serializerOptions)
    Set-Content -LiteralPath $logPath -Encoding UTF8 -Value $json
    return $logPath
}

function Invoke-VipmProcess {
    param(
        [Parameter(Mandatory)][pscustomobject]$Invocation,
        [string]$WorkingDirectory
    )

    $psi = New-Object System.Diagnostics.ProcessStartInfo
    $psi.FileName = $Invocation.Binary
    foreach ($arg in $Invocation.Arguments) {
        if ($null -ne $arg) {
            [void]$psi.ArgumentList.Add([string]$arg)
        }
    }
    if ($WorkingDirectory) {
        $psi.WorkingDirectory = $WorkingDirectory
    }
    $psi.RedirectStandardOutput = $true
    $psi.RedirectStandardError = $true
    $psi.UseShellExecute = $false

    $process = [System.Diagnostics.Process]::Start($psi)
    $stdout = $process.StandardOutput.ReadToEnd()
    $stderr = $process.StandardError.ReadToEnd()
    $process.WaitForExit()

    if ($stdout) { Write-Host $stdout.Trim() }
    if ($stderr) { Write-Host $stderr.Trim() }

    return [pscustomobject]@{
        ExitCode = $process.ExitCode
        StdOut   = $stdout
        StdErr   = $stderr
    }
}

function Install-VipmVipc {
    param(
        [Parameter(Mandatory)][string]$VipcPath,
        [Parameter(Mandatory)][string]$LabVIEWVersion,
        [Parameter(Mandatory)][string]$LabVIEWBitness,
        [Parameter(Mandatory)][string]$RepoRoot,
        [Parameter(Mandatory)][string]$TelemetryRoot,
        [Parameter(Mandatory)][string]$ProviderName
    )

    $params = @{
        vipcPath       = $VipcPath
        labviewVersion = $LabVIEWVersion
        labviewBitness = $LabVIEWBitness
    }

    $extras = Get-VipmProviderInstallParameters -ProviderName $ProviderName -RepoRoot $RepoRoot -LabVIEWVersion $LabVIEWVersion -LabVIEWBitness $LabVIEWBitness -VipcPath $VipcPath
    foreach ($key in $extras.Keys) {
        $params[$key] = $extras[$key]
    }

    $invocation = Get-VipmInvocation -Operation 'InstallVipc' -Params $params -ProviderName $ProviderName
    $result = Invoke-VipmProcess -Invocation $invocation -WorkingDirectory (Split-Path -Parent $VipcPath)
    Write-VipmTelemetryLog `
        -LogRoot $TelemetryRoot `
        -Provider $invocation.Provider `
        -Binary $invocation.Binary `
        -Arguments $invocation.Arguments `
        -WorkingDirectory (Split-Path -Parent $VipcPath) `
        -ExitCode $result.ExitCode `
        -StdOut $result.StdOut `
        -StdErr $result.StdErr `
        -LabVIEWVersion $LabVIEWVersion `
        -LabVIEWBitness $LabVIEWBitness | Out-Null

    if ($result.ExitCode -ne 0) {
        $message = "Process exited with code $($result.ExitCode)."
        if ($result.StdErr) {
            $message += [Environment]::NewLine + $result.StdErr.Trim()
        }
        throw $message
    }

    $packageInfo = $null
    if ($ProviderName -eq 'vipm') {
        $packageInfo = Get-VipmInstalledPackages -LabVIEWVersion $LabVIEWVersion -LabVIEWBitness $LabVIEWBitness
        Write-VipmInstalledPackagesLog `
            -LogRoot $TelemetryRoot `
            -LabVIEWVersion $LabVIEWVersion `
            -LabVIEWBitness $LabVIEWBitness `
            -PackageInfo $packageInfo | Out-Null
    } else {
        $packageInfo = [pscustomobject]@{
            rawOutput = ''
            packages  = @()
        }
    }

    return [ordered]@{
        version  = $LabVIEWVersion
        bitness  = $LabVIEWBitness
        packages = $packageInfo.packages
    }
}

function Show-VipmDependencies {
    param(
        [Parameter(Mandatory)][string]$LabVIEWVersion,
        [Parameter(Mandatory)][string]$LabVIEWBitness,
        [Parameter(Mandatory)][string]$TelemetryRoot,
        [Parameter(Mandatory)][string]$ProviderName
    )

    if ($ProviderName -ne 'vipm') {
        throw "DisplayOnly mode requires the classic VIPM provider. Provider '$ProviderName' does not support listing installed packages."
    }

    $packageInfo = Get-VipmInstalledPackages -LabVIEWVersion $LabVIEWVersion -LabVIEWBitness $LabVIEWBitness
    Write-VipmInstalledPackagesLog `
        -LogRoot $TelemetryRoot `
        -LabVIEWVersion $LabVIEWVersion `
        -LabVIEWBitness $LabVIEWBitness `
        -PackageInfo $packageInfo | Out-Null

    return [ordered]@{
        version  = $LabVIEWVersion
        bitness  = $LabVIEWBitness
        packages = $packageInfo.packages
    }
}

Export-ModuleMember -Function Test-VipmCliReady, Initialize-VipmTelemetry, Install-VipmVipc, Show-VipmDependencies

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
