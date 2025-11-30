#Requires -Version 7.0

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$script:RepoRoot = Split-Path -Parent (Split-Path -Parent (Split-Path -Parent $PSCommandPath))

$script:VendorToolsImported = $false
$script:GCliImported = $false
$script:VipmImported = $false

function Get-IconEditorLogDirectory {
    $logsRoot = Join-Path $script:RepoRoot 'tests\results\_agent\icon-editor\logs'
    if (-not (Test-Path -LiteralPath $logsRoot -PathType Container)) {
        try {
            New-Item -ItemType Directory -Path $logsRoot -Force | Out-Null
        } catch {}
    }
    return $logsRoot
}

function Invoke-IconEditorVendorToolsImport {
    param([string]$WorkspaceRoot)

    if ($script:VendorToolsImported) { return $true }

    $candidatePaths = New-Object System.Collections.Generic.List[string]
    if ($WorkspaceRoot) {
        $candidatePaths.Add((Join-Path $WorkspaceRoot 'tools\VendorTools.psm1')) | Out-Null
    }

    $locationCandidate = Join-Path (Get-Location).Path 'tools\VendorTools.psm1'
    if (-not $candidatePaths.Contains($locationCandidate)) {
        $candidatePaths.Add($locationCandidate) | Out-Null
    }

    foreach ($path in $candidatePaths) {
        if ([string]::IsNullOrWhiteSpace($path)) { continue }
        try {
            if (Test-Path -LiteralPath $path -PathType Leaf) {
                Import-Module $path -Force -ErrorAction Stop | Out-Null
                $script:VendorToolsImported = $true
                return $true
            }
        } catch {}
    }

    return $script:VendorToolsImported
}

function Invoke-IconEditorGCliImport {
    param([string]$WorkspaceRoot)

    if ($script:GCliImported) { return $true }

    $candidatePaths = New-Object System.Collections.Generic.List[string]
    if ($WorkspaceRoot) {
        $candidatePaths.Add((Join-Path $WorkspaceRoot 'tools\GCli.psm1')) | Out-Null
    }

    $locationCandidate = Join-Path (Get-Location).Path 'tools\GCli.psm1'
    if (-not $candidatePaths.Contains($locationCandidate)) {
        $candidatePaths.Add($locationCandidate) | Out-Null
    }

    foreach ($path in $candidatePaths) {
        if ([string]::IsNullOrWhiteSpace($path)) { continue }
        try {
            if (Test-Path -LiteralPath $path -PathType Leaf) {
                Import-Module $path -Force -ErrorAction Stop | Out-Null
                $script:GCliImported = $true
                return $true
            }
        } catch {}
    }

    return $script:GCliImported
}

function Invoke-IconEditorVipmImport {
    param([string]$WorkspaceRoot)

    if ($script:VipmImported) { return $true }

    $candidatePaths = New-Object System.Collections.Generic.List[string]
    if ($WorkspaceRoot) {
        $candidatePaths.Add((Join-Path $WorkspaceRoot 'tools\Vipm.psm1')) | Out-Null
    }

    $locationCandidate = Join-Path (Get-Location).Path 'tools\Vipm.psm1'
    if (-not $candidatePaths.Contains($locationCandidate)) {
        $candidatePaths.Add($locationCandidate) | Out-Null
    }

    foreach ($path in $candidatePaths) {
        if ([string]::IsNullOrWhiteSpace($path)) { continue }
        try {
            if (Test-Path -LiteralPath $path -PathType Leaf) {
                Import-Module $path -Force -ErrorAction Stop | Out-Null
                $script:VipmImported = $true
                return $true
            }
        } catch {}
    }

    return $script:VipmImported
}

function Get-IconEditorPackageName {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$VipbPath
    )

    $resolvedPath = Resolve-Path -LiteralPath $VipbPath -ErrorAction Stop
    $doc = New-Object System.Xml.XmlDocument
    $doc.PreserveWhitespace = $true
    $doc.Load($resolvedPath.ProviderPath)

    $nameNode = $doc.SelectSingleNode('/VI_Package_Builder_Settings/Library_General_Settings/Package_File_Name')
    if (-not $nameNode -or [string]::IsNullOrWhiteSpace($nameNode.InnerText)) {
        throw "Package_File_Name not found in '$($resolvedPath.ProviderPath)'."
    }

    return $nameNode.InnerText.Trim()
}

function Get-IconEditorPackagePath {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$VipbPath,
        [Parameter(Mandatory)][int]$Major,
        [Parameter(Mandatory)][int]$Minor,
        [Parameter(Mandatory)][int]$Patch,
        [Parameter(Mandatory)][int]$Build,
        [string]$WorkspaceRoot,
        [string]$OutputDirectory = '.github/builds/vip-stash'
    )

    $vipbFull = (Resolve-Path -LiteralPath $VipbPath -ErrorAction Stop).ProviderPath
    if (-not $WorkspaceRoot) {
        $WorkspaceRoot = (Get-Location).Path
    }

    $outputRoot = if ([System.IO.Path]::IsPathRooted($OutputDirectory)) {
        [System.IO.Path]::GetFullPath($OutputDirectory)
    } else {
        [System.IO.Path]::GetFullPath((Join-Path $WorkspaceRoot $OutputDirectory))
    }

  $packageName = Get-IconEditorPackageName -VipbPath $vipbFull
  $fileName = "{0}-{1}.{2}.{3}.{4}.vip" -f $packageName, $Major, $Minor, $Patch, $Build

  return Join-Path $outputRoot $fileName
}

function Invoke-IconEditorProcess {
  [CmdletBinding()]
  param(
    [Parameter(Mandatory)][string]$Binary,
    [string[]]$Arguments,
    [string]$WorkingDirectory,
    [switch]$Quiet
  )

  if ([string]::IsNullOrWhiteSpace($Binary)) {
    throw 'Invoke-IconEditorProcess requires a binary path.'
  }

  $psi = New-Object System.Diagnostics.ProcessStartInfo
  $psi.FileName = $Binary
  if ($Arguments) {
    foreach ($arg in $Arguments) {
      if ($null -eq $arg) { continue }
      [void]$psi.ArgumentList.Add([string]$arg)
    }
  }
  if ($WorkingDirectory) {
    $psi.WorkingDirectory = $WorkingDirectory
  }
  $psi.RedirectStandardOutput = $true
  $psi.RedirectStandardError = $true
  $psi.UseShellExecute = $false
  $psi.StandardOutputEncoding = [System.Text.Encoding]::UTF8
  $psi.StandardErrorEncoding = [System.Text.Encoding]::UTF8

  $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
  try {
    $process = [System.Diagnostics.Process]::Start($psi)
  } catch {
    throw "Failed to start provider process '$Binary': $($_.Exception.Message)"
  }

  if (-not $process) {
    throw "Failed to start provider process '$Binary'."
  }

  $stdout = $process.StandardOutput.ReadToEnd()
  $stderr = $process.StandardError.ReadToEnd()
  $process.WaitForExit()
  $stopwatch.Stop()

  $combinedOutput = ($stdout + "`n" + $stderr).Trim()
  $lines = @()
  if ($stdout) { $lines += $stdout -split "`r?`n" }
  if ($stderr) { $lines += $stderr -split "`r?`n" }
  $warnings = @(
    $lines | Where-Object {
      $_ -and ($_ -match '\[WARN\]' -or $_ -match '\[ERROR\]' -or $_ -match 'Comms Error' -or $_ -match '\b[Ee]rror\b')
    }
  )
  $logPath = $null
  if ($process.ExitCode -ne 0) {
    $logsRoot = Get-IconEditorLogDirectory
    if ($logsRoot) {
      $timestamp = Get-Date -Format 'yyyyMMddTHHmmssfff'
      $binaryLeaf = if ($Binary) { ($Binary -replace '[^A-Za-z0-9\-\.]+','_') } else { 'process' }
      $logFileName = "{0}-{1}.log" -f $binaryLeaf.Trim('_'), $timestamp
      $logPathCandidate = Join-Path $logsRoot $logFileName
      $logLines = @(
        "# Icon Editor process failure"
        "Timestamp: $(Get-Date -Format o)"
        "WorkingDirectory: $WorkingDirectory"
        "Binary: $Binary"
        "Arguments: $([string]::Join(' ', ($Arguments | ForEach-Object { if ($_ -match '\s') { '\"{0}\"' -f $_ } else { $_ } })))"
        "ExitCode: $($process.ExitCode)"
        "---- STDOUT ----"
        $stdout
        "---- STDERR ----"
        $stderr
      )
      try {
        Set-Content -LiteralPath $logPathCandidate -Value $logLines -Encoding UTF8
        $logPath = $logPathCandidate
      } catch {}
    }
  }

  if (-not $Quiet) {
    if (-not [string]::IsNullOrWhiteSpace($stdout)) {
      Write-Host $stdout
    }
    if (-not [string]::IsNullOrWhiteSpace($stderr)) {
      Write-Host $stderr
    }
  }

  return [pscustomobject]@{
    Binary          = $Binary
    Arguments       = @($Arguments)
    ExitCode        = $process.ExitCode
    StdOut          = $stdout
    StdErr          = $stderr
    Output          = $combinedOutput
    DurationSeconds = [Math]::Round($stopwatch.Elapsed.TotalSeconds, 3)
    Warnings        = $warnings
    LogPath         = $logPath
  }
}

function Confirm-IconEditorPackageArtifact {
  [CmdletBinding()]
  param(
    [Parameter(Mandatory)][string]$PackagePath
  )

  if ([string]::IsNullOrWhiteSpace($PackagePath)) {
    throw 'Expected package path was not provided.'
  }

  try {
    $resolved = Resolve-Path -LiteralPath $PackagePath -ErrorAction Stop
  } catch {
    throw "Expected VI package '$PackagePath' was not produced."
  }

  $item = Get-Item -LiteralPath $resolved.Path -ErrorAction Stop
  if ($item -isnot [System.IO.FileInfo]) {
    throw "Expected VI package '$PackagePath' was not produced."
  }

  $hash = $null
  try {
    $hash = (Get-FileHash -LiteralPath $resolved.Path -Algorithm SHA256).Hash
  } catch {}

  return [pscustomobject]@{
    PackagePath      = $resolved.Path
    Sha256           = $hash
    SizeBytes        = $item.Length
    LastWriteTimeUtc = $item.LastWriteTimeUtc
  }
}

function Invoke-IconEditorVipBuild {
  [CmdletBinding()]
  param(
    [Parameter(Mandatory)][string]$VipbPath,
        [Parameter(Mandatory)][int]$Major,
        [Parameter(Mandatory)][int]$Minor,
        [Parameter(Mandatory)][int]$Patch,
        [Parameter(Mandatory)][int]$Build,
        [Parameter()][ValidateSet(32,64)][int]$SupportedBitness = 64,
        [Parameter()][int]$MinimumSupportedLVVersion = 2023,
        [Parameter()][ValidateSet(0,3)][int]$LabVIEWMinorRevision = 3,
        [Parameter(Mandatory)][string]$ReleaseNotesPath,
        [string]$WorkspaceRoot,
        [string]$OutputDirectory = '.github/builds/vip-stash',
        [ValidateSet('g-cli','vipm')][string]$Provider = 'g-cli',
        [string]$GCliProviderName,
        [string]$VipmProviderName,
        [int]$TimeoutSeconds = 300,
        [switch]$PreserveExisting,
        [switch]$Quiet
    )

    $vipbFull = (Resolve-Path -LiteralPath $VipbPath -ErrorAction Stop).ProviderPath

    if (-not $WorkspaceRoot) {
        $WorkspaceRoot = (Get-Location).Path
    } else {
        $WorkspaceRoot = (Resolve-Path -Path $WorkspaceRoot -ErrorAction Stop).ProviderPath
    }

    if (-not (Invoke-IconEditorVendorToolsImport -WorkspaceRoot $WorkspaceRoot)) {
        throw 'Unable to import VendorTools module required for icon editor helpers.'
    }

    $preflightWarnings = New-Object System.Collections.Generic.List[string]

    $providerKey = $Provider.ToLowerInvariant()
    switch ($providerKey) {
        'g-cli' {
            if (-not (Invoke-IconEditorGCliImport -WorkspaceRoot $WorkspaceRoot)) {
                throw 'Unable to import g-cli provider module (tools/GCli.psm1).'
            }

            $snapshot = Get-IconEditorViServerSnapshot -Version $MinimumSupportedLVVersion -Bitness $SupportedBitness -WorkspaceRoot $WorkspaceRoot
            if (-not $snapshot) {
                throw "Unable to verify LabVIEW VI Server configuration for $MinimumSupportedLVVersion ($SupportedBitness-bit)."
            }
            if ($snapshot.Status -ne 'ok') {
                $detail = if ($snapshot.Message) { $snapshot.Message } else { 'LabVIEW VI Server (server.tcp.enabled) must be TRUE before invoking g-cli.' }
                throw $detail
            }
            if ($snapshot.PSObject.Properties.Name -contains 'ServerEnabled' -and -not $snapshot.ServerEnabled) {
                $serverWarning = "LabVIEW VI Server appears disabled for $MinimumSupportedLVVersion ($SupportedBitness-bit); continuing because LabVIEW.ini is present."
                Write-Warning $serverWarning
                $preflightWarnings.Add($serverWarning) | Out-Null
            }
        }
        'vipm' {
            if (-not (Invoke-IconEditorVipmImport -WorkspaceRoot $WorkspaceRoot)) {
                throw 'Unable to import VIPM provider module (tools/Vipm.psm1).'
            }
        }
        default {
            throw "Unsupported provider '$Provider'."
        }
    }

    $releaseNotesFull = if ([System.IO.Path]::IsPathRooted($ReleaseNotesPath)) {
        [System.IO.Path]::GetFullPath($ReleaseNotesPath)
    } else {
        [System.IO.Path]::GetFullPath((Join-Path $WorkspaceRoot $ReleaseNotesPath))
    }

    $releaseNotesDir = Split-Path -Parent $releaseNotesFull
    if (-not (Test-Path -LiteralPath $releaseNotesDir -PathType Container)) {
        New-Item -ItemType Directory -Path $releaseNotesDir -Force | Out-Null
    }
    if (-not (Test-Path -LiteralPath $releaseNotesFull -PathType Leaf)) {
        New-Item -ItemType File -Path $releaseNotesFull -Force | Out-Null
    }

    $expectedPackage = Get-IconEditorPackagePath -VipbPath $vipbFull -Major $Major -Minor $Minor -Patch $Patch -Build $Build -WorkspaceRoot $WorkspaceRoot -OutputDirectory $OutputDirectory
    $expectedDir = Split-Path -Parent $expectedPackage
    if (-not (Test-Path -LiteralPath $expectedDir -PathType Container)) {
        New-Item -ItemType Directory -Path $expectedDir -Force | Out-Null
    }

    $removedPackage = $false
    if (-not $PreserveExisting.IsPresent -and (Test-Path -LiteralPath $expectedPackage -PathType Leaf)) {
        Remove-Item -LiteralPath $expectedPackage -Force
        $removedPackage = $true
    }

    $versionString = '{0}.{1}.{2}.{3}' -f $Major, $Minor, $Patch, $Build

    switch ($providerKey) {
        'g-cli' {
            $operationParams = @{
                labviewVersion   = $MinimumSupportedLVVersion.ToString()
                architecture     = $SupportedBitness.ToString()
                buildSpecPath    = $vipbFull
                buildVersion     = $versionString
                releaseNotesPath = $releaseNotesFull
                timeoutSeconds   = $TimeoutSeconds.ToString()
            }

            $invocationArgs = @{
                Operation = 'VipbBuild'
                Params    = $operationParams
            }
            if ($GCliProviderName) {
                $invocationArgs.ProviderName = $GCliProviderName
            }

            $invocation = Get-GCliInvocation @invocationArgs
        }
        'vipm' {
            $operationParams = @{
                vipbPath        = $vipbFull
                outputDirectory = $expectedDir
                buildVersion    = $versionString
            }

            $invocationArgs = @{
                Operation = 'BuildVip'
                Params    = $operationParams
            }
            if ($VipmProviderName) {
                $invocationArgs.ProviderName = $VipmProviderName
            }

            $invocation = Get-VipmInvocation @invocationArgs
        }
        default {
            throw "Unsupported provider '$Provider'."
        }
    }

    $processResult = Invoke-IconEditorProcess `
        -Binary $invocation.Binary `
        -Arguments $invocation.Arguments `
        -WorkingDirectory (Split-Path -Parent $vipbFull) `
        -Quiet:$Quiet

    if ($processResult.ExitCode -ne 0) {
        $errorMessage = ("Provider '{0}' exited with code {1}." -f $invocation.Provider, $processResult.ExitCode)
        if ($processResult.Output) {
            $errorMessage = $errorMessage + " Output:`n{0}" -f $processResult.Output
        }
        throw $errorMessage
    }

    $artifact = Confirm-IconEditorPackageArtifact -PackagePath $expectedPackage

    $combinedWarnings = @()
    if ($preflightWarnings.Count -gt 0) {
        $combinedWarnings += $preflightWarnings.ToArray()
    }
    if ($processResult.Warnings) {
        $combinedWarnings += $processResult.Warnings
    }

    return [pscustomobject]@{
        ExitCode            = $processResult.ExitCode
        StdOut              = $processResult.StdOut
        StdErr              = $processResult.StdErr
        Output              = $processResult.Output
        Warnings            = $combinedWarnings
        DurationSeconds     = $processResult.DurationSeconds
        PackagePath         = $artifact.PackagePath
        PackageSha256       = $artifact.Sha256
        PackageSize         = $artifact.SizeBytes
        PackageTimestampUtc = $artifact.LastWriteTimeUtc
        RemovedExisting     = $removedPackage
        ReleaseNotes        = $releaseNotesFull
        Provider            = $invocation.Provider
        ProviderBinary      = $invocation.Binary
    }
}

function Get-IconEditorViServerSnapshot {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][int]$Version,
        [Parameter(Mandatory)][ValidateSet(32,64)][int]$Bitness,
        [string]$WorkspaceRoot
    )

    if (-not $IsWindows) { return $null }

    if (-not (Invoke-IconEditorVendorToolsImport -WorkspaceRoot $WorkspaceRoot)) {
        return [pscustomobject]@{
            Version = $Version
            Bitness = $Bitness
            Status  = 'vendor-tools-missing'
            Message = 'tools/VendorTools.psm1 not available'
        }
    }

    $exePath = $null
    try {
        $exePath = Find-LabVIEWVersionExePath -Version $Version -Bitness $Bitness
    } catch {
        return [pscustomobject]@{
            Version = $Version
            Bitness = $Bitness
            Status  = 'error'
            Message = "Find-LabVIEWVersionExePath failed: $($_.Exception.Message)"
        }
    }

    if (-not $exePath) {
        return [pscustomobject]@{
            Version = $Version
            Bitness = $Bitness
            Status  = 'missing'
            Message = 'LabVIEW executable not found'
        }
    }

    $iniPath = $null
    try {
        $iniPath = Get-LabVIEWIniPath -LabVIEWExePath $exePath
    } catch {
        return [pscustomobject]@{
            Version = $Version
            Bitness = $Bitness
            Status  = 'error'
            ExePath = $exePath
            Message = "LabVIEW.ini path resolution failed: $($_.Exception.Message)"
        }
    }

    if (-not $iniPath) {
        return [pscustomobject]@{
            Version = $Version
            Bitness = $Bitness
            Status  = 'missing-ini'
            ExePath = $exePath
            Message = 'LabVIEW.ini not found'
        }
    }

    $enabledValue = $null
    $portValue = $null
    try { $enabledValue = Get-LabVIEWIniValue -LabVIEWIniPath $iniPath -Key 'server.tcp.enabled' } catch {}
    try { $portValue = Get-LabVIEWIniValue -LabVIEWIniPath $iniPath -Key 'server.tcp.port' } catch {}

    $enabledNormalized = $null
    if ($enabledValue) {
        $enabledNormalized = $enabledValue.Trim()
    }

    $enabledFlag = $false
    if ($enabledNormalized) {
        $tmpBool = $false
        if ([bool]::TryParse($enabledNormalized, [ref]$tmpBool)) {
            $enabledFlag = $tmpBool
        } elseif ($enabledNormalized -eq '1') {
            $enabledFlag = $true
        } elseif ($enabledNormalized.Equals('TRUE', [System.StringComparison]::OrdinalIgnoreCase)) {
            $enabledFlag = $true
        }
    }

    $parsedPort = $null
    if (-not [string]::IsNullOrWhiteSpace($portValue)) {
        $tmp = 0
        if ([int]::TryParse($portValue, [ref]$tmp)) {
            $parsedPort = $tmp
        }
    }

    return [pscustomobject]@{
        Version = $Version
        Bitness = $Bitness
        Status  = 'ok'
        ExePath = $exePath
        IniPath = $iniPath
        Enabled = if ($enabledValue) { $enabledValue } else { 'unknown' }
        ServerEnabled = $enabledFlag
        Port    = if ($parsedPort -ne $null) { $parsedPort } else { $portValue }
    }
}

function Get-IconEditorViServerSnapshots {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][int]$Version,
        [int[]]$Bitness = @(32, 64),
        [string]$WorkspaceRoot
    )

    if (-not $IsWindows) { return @() }

    $results = New-Object System.Collections.Generic.List[object]
    foreach ($bit in $Bitness) {
        try {
            $snapshot = Get-IconEditorViServerSnapshot -Version $Version -Bitness $bit -WorkspaceRoot $WorkspaceRoot
            if ($snapshot) { $results.Add($snapshot) | Out-Null }
        } catch {
            $results.Add([pscustomobject]@{
                Version = $Version
                Bitness = $bit
                Status  = 'error'
                Message = $_.Exception.Message
            }) | Out-Null
        }
    }
    return $results.ToArray()
}

Export-ModuleMember -Function `
    Get-IconEditorPackageName, `
    Get-IconEditorPackagePath, `
    Invoke-IconEditorProcess, `
    Confirm-IconEditorPackageArtifact, `
    Invoke-IconEditorVipBuild, `
    Get-IconEditorViServerSnapshot, `
    Get-IconEditorViServerSnapshots

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
