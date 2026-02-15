param(
    [string]$WorkspaceRoot = "",
    [string]$TargetDir = "",
    [string]$LabVIEWPath = "C:\Program Files\National Instruments\LabVIEW 2026\LabVIEW.exe",
    [string]$ProjectPath = "",
    [string]$BuildSpecName = "",
    [string]$TargetName = "",
    [string]$LabVIEWVersion = "",
    [switch]$BuildProjectSpec
)

$ErrorActionPreference = 'Stop'

if (-not [string]::IsNullOrWhiteSpace($LabVIEWVersion)) {
    Write-Host ("LabVIEW version hint: {0}" -f $LabVIEWVersion)
}

$pathContractScript = Join-Path -Path $PSScriptRoot -ChildPath '..\support\PathContract.ps1'
if (-not (Test-Path -LiteralPath $pathContractScript -PathType Leaf)) {
    throw "Path contract helper was not found: $pathContractScript"
}

$pathContractLines = Get-Content -LiteralPath $pathContractScript -ErrorAction Stop
for ($lineIndex = 0; $lineIndex -lt $pathContractLines.Count; $lineIndex++) {
    $lineText = [string]$pathContractLines[$lineIndex]
    if ($lineText -match '^\s*#\s*requires\s+-version\b') {
        $lineNumber = $lineIndex + 1
        $psVersion = if ($PSVersionTable -and $PSVersionTable.PSVersion) { [string]$PSVersionTable.PSVersion } else { '<unknown>' }
        throw ("Path contract shell compatibility failure: PathContract.ps1 contains a file-scope #Requires -Version directive on line {0}: '{1}'. Current shell version: {2}. This script runs in Windows PowerShell 5.1 inside NI Windows containers. Remove file-scope #Requires -Version from Tooling/support/PathContract.ps1 to avoid ScriptRequiresUnmatchedPSVersion." -f $lineNumber, $lineText.Trim(), $psVersion)
    }
}

. $pathContractScript

function Test-EnabledValue {
    param(
        [AllowNull()]
        [string]$Value
    )

    if ([string]::IsNullOrWhiteSpace($Value)) {
        return $false
    }

    return $Value.Equals('1', [System.StringComparison]::OrdinalIgnoreCase) `
        -or $Value.Equals('true', [System.StringComparison]::OrdinalIgnoreCase) `
        -or $Value.Equals('yes', [System.StringComparison]::OrdinalIgnoreCase)
}

function ConvertTo-LabVIEWCliPortNumber {
    param(
        [AllowNull()]
        [string]$RawValue,
        [string]$Source
    )

    if ([string]::IsNullOrWhiteSpace($RawValue)) {
        return $null
    }

    $parsed = 0
    if (-not [int]::TryParse($RawValue, [ref]$parsed)) {
        if (-not [string]::IsNullOrWhiteSpace($Source)) {
            Write-Warning ("Ignoring invalid LabVIEW CLI port '{0}' from {1}" -f $RawValue, $Source)
        } else {
            Write-Warning ("Ignoring invalid LabVIEW CLI port '{0}'" -f $RawValue)
        }
        return $null
    }

    if ($parsed -lt 1 -or $parsed -gt 65535) {
        if (-not [string]::IsNullOrWhiteSpace($Source)) {
            Write-Warning ("Ignoring out-of-range LabVIEW CLI port '{0}' from {1}" -f $RawValue, $Source)
        } else {
            Write-Warning ("Ignoring out-of-range LabVIEW CLI port '{0}'" -f $RawValue)
        }
        return $null
    }

    return $parsed
}

function Get-LabVIEWIniValue {
    param(
        [string]$IniPath,
        [string]$Key
    )

    if ([string]::IsNullOrWhiteSpace($IniPath) -or -not (Test-Path -LiteralPath $IniPath -PathType Leaf)) {
        return $null
    }

    $escapedKey = [regex]::Escape($Key)
    foreach ($line in (Get-Content -LiteralPath $IniPath -ErrorAction Stop)) {
        $match = [regex]::Match($line, "^\s*$escapedKey\s*=\s*(?<value>.+?)\s*$", [System.Text.RegularExpressions.RegexOptions]::IgnoreCase)
        if ($match.Success) {
            return $match.Groups['value'].Value.Trim()
        }
    }

    return $null
}

function Resolve-LabVIEWCliPort {
    param(
        [string]$LabVIEWExecutablePath
    )

    $envCandidates = @(
        'LVIE_CONTAINER_PARITY_LABVIEWCLI_PORT',
        'LVIE_PARITY_LABVIEWCLI_PORT',
        'LVIE_LABVIEWCLI_PORT',
        'LVIE_LUNIT_PORT'
    )

    foreach ($name in $envCandidates) {
        $value = [Environment]::GetEnvironmentVariable($name)
        $port = ConvertTo-LabVIEWCliPortNumber -RawValue $value -Source ('$env:{0}' -f $name)
        if ($null -ne $port) {
            return [pscustomobject]@{
                PortNumber = [int]$port
                Source     = '$env:' + $name
            }
        }
    }

    if (-not [string]::IsNullOrWhiteSpace($LabVIEWExecutablePath)) {
        $iniPath = Join-Path -Path (Split-Path -Path $LabVIEWExecutablePath -Parent) -ChildPath 'LabVIEW.ini'
        try {
            $iniPortRaw = Get-LabVIEWIniValue -IniPath $iniPath -Key 'server.tcp.port'
            $iniPort = ConvertTo-LabVIEWCliPortNumber -RawValue $iniPortRaw -Source ('{0} (server.tcp.port)' -f $iniPath)
            if ($null -ne $iniPort) {
                return [pscustomobject]@{
                    PortNumber = [int]$iniPort
                    Source     = '{0} (server.tcp.port)' -f $iniPath
                }
            }
        } catch {
            Write-Warning ("Unable to resolve LabVIEW CLI port from LabVIEW.ini: {0}" -f $_.Exception.Message)
        }
    }

    return [pscustomobject]@{
        PortNumber = 3363
        Source     = 'default'
    }
}

function Test-LabVIEWPortListening {
    param(
        [int]$PortNumber,
        [int]$ProcessId
    )

    $netTcpCommand = Get-Command Get-NetTCPConnection -ErrorAction SilentlyContinue
    if (-not $netTcpCommand) {
        return $false
    }

    try {
        $listeners = Get-NetTCPConnection -State Listen -OwningProcess $ProcessId -ErrorAction Stop |
            Where-Object { $_.LocalPort -eq $PortNumber }
        return @($listeners).Count -gt 0
    } catch {
        return $false
    }
}

function Start-LabVIEWForCli {
    param(
        [string]$LabVIEWExecutablePath,
        [int]$PortNumber,
        [int]$TimeoutSeconds = 120
    )

    $netTcpCommand = Get-Command Get-NetTCPConnection -ErrorAction SilentlyContinue
    if (-not $netTcpCommand) {
        Write-Warning "Get-NetTCPConnection is not available; launching LabVIEW and waiting a fixed delay for startup."
        $process = Start-Process -FilePath $LabVIEWExecutablePath -PassThru
        Start-Sleep -Seconds 20
        return $process
    }

    $existingListener = Get-NetTCPConnection -State Listen -ErrorAction SilentlyContinue |
        Where-Object { $_.LocalPort -eq $PortNumber } |
        Select-Object -First 1
    if ($existingListener) {
        Write-Host ("Detected existing LabVIEW listener on port {0} (PID {1}); reusing running process." -f $PortNumber, $existingListener.OwningProcess)
        return $null
    }

    $process = Start-Process -FilePath $LabVIEWExecutablePath -PassThru
    Write-Host ("Launched LabVIEW process for parity operations (PID {0})." -f $process.Id)

    $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
    while ($stopwatch.Elapsed.TotalSeconds -lt $TimeoutSeconds) {
        if ($process.HasExited) {
            throw ("LabVIEW process exited before opening VI Server port {0}. Exit code: {1}" -f $PortNumber, $process.ExitCode)
        }

        if (Test-LabVIEWPortListening -PortNumber $PortNumber -ProcessId $process.Id) {
            Write-Host ("LabVIEW VI Server is listening on port {0} (PID {1})." -f $PortNumber, $process.Id)
            return $process
        }

        Start-Sleep -Milliseconds 500
        $process.Refresh()
    }

    throw ("Timed out waiting for LabVIEW to listen on port {0} (PID {1})." -f $PortNumber, $process.Id)
}

function Test-LabVIEWPrelaunchForCli {
    param(
        [string]$WorkspaceRootPath
    )

    if (-not [string]::IsNullOrWhiteSpace($env:LVIE_PRELAUNCH_LABVIEW_FOR_CLI)) {
        $explicit = $null
        if ([bool]::TryParse($env:LVIE_PRELAUNCH_LABVIEW_FOR_CLI, [ref]$explicit)) {
            return [bool]$explicit
        }
    }

    # Windows container parity mounts the repo at C:\workspace. In that mode,
    # direct LabVIEW prelaunch can fail to expose a listening VI Server port.
    # Keep prelaunch enabled for self-hosted parity unless explicitly overridden.
    try {
        $normalizedWorkspace = [System.IO.Path]::GetFullPath($WorkspaceRootPath).TrimEnd('\', '/')
        if ($normalizedWorkspace.Equals('C:\workspace', [System.StringComparison]::OrdinalIgnoreCase)) {
            return $false
        }
    } catch {
        Write-Verbose ("Unable to normalize workspace path '{0}' for prelaunch detection: {1}" -f $WorkspaceRootPath, $_.Exception.Message)
        # If normalization fails, default to enabling prelaunch for safety.
    }

    return $true
}

function Sync-IconEditorSourcesForBuildSpec {
    param(
        [string]$WorkspaceRootPath,
        [string]$LabVIEWExecutablePath
    )

    if (-not (Test-Path -LiteralPath $WorkspaceRootPath -PathType Container)) {
        throw "Workspace root does not exist: $WorkspaceRootPath"
    }

    $labviewRoot = Split-Path -Path $LabVIEWExecutablePath -Parent
    if ([string]::IsNullOrWhiteSpace($labviewRoot) -or -not (Test-Path -LiteralPath $labviewRoot -PathType Container)) {
        throw "Unable to resolve LabVIEW install root from LabVIEW path: $LabVIEWExecutablePath"
    }

    $repoPlugins = Join-Path $WorkspaceRootPath 'resource\plugins'
    $repoIconApi = Join-Path $WorkspaceRootPath 'vi.lib\LabVIEW Icon API'
    $requiredPaths = @(
        (Join-Path $repoPlugins 'NIIconEditor'),
        (Join-Path $repoPlugins 'lv_IconEditor.lvlib'),
        (Join-Path $repoPlugins 'lv_icon.vi'),
        $repoIconApi
    )

    foreach ($path in $requiredPaths) {
        if (-not (Test-Path -LiteralPath $path)) {
            throw "Required Icon Editor source path is missing: $path"
        }
    }

    $installPlugins = Join-Path $labviewRoot 'resource\plugins'
    $installIconApi = Join-Path $labviewRoot 'vi.lib\LabVIEW Icon API'
    New-Item -Path $installPlugins -ItemType Directory -Force | Out-Null
    New-Item -Path $installIconApi -ItemType Directory -Force | Out-Null

    Copy-Item -LiteralPath (Join-Path $repoPlugins 'NIIconEditor') -Destination $installPlugins -Recurse -Force

    foreach ($fileName in @('lv_IconEditor.lvlib', 'lv_icon.vi', 'lv_icon.vit', 'SAMPLE_lv_icon.vi')) {
        $sourcePath = Join-Path $repoPlugins $fileName
        if (Test-Path -LiteralPath $sourcePath -PathType Leaf) {
            Copy-Item -LiteralPath $sourcePath -Destination $installPlugins -Force
        }
    }

    Get-ChildItem -LiteralPath $repoIconApi -Force | Copy-Item -Destination $installIconApi -Recurse -Force

    $probe = Join-Path $installPlugins 'NIIconEditor\Miscellaneous\Classes Initialization.vi'
    if (-not (Test-Path -LiteralPath $probe -PathType Leaf)) {
        throw "Icon Editor source synchronization failed. Missing probe file: $probe"
    }

    Write-Output "Synchronized Icon Editor sources into LabVIEW install:"
    Write-Output "  resource\\plugins -> $installPlugins"
    Write-Output "  vi.lib\\LabVIEW Icon API -> $installIconApi"
}

function Get-LabVIEWCliTempLogPath {
    param(
        [string]$TempRoot = ([System.IO.Path]::GetTempPath())
    )

    return @(
        Get-ChildItem -LiteralPath $TempRoot -Filter 'lvtemporary_*.log' -File -ErrorAction SilentlyContinue |
            Sort-Object LastWriteTimeUtc -Descending |
            Select-Object -ExpandProperty FullName
    )
}

function Save-LabVIEWCliLog {
    param(
        [string]$WorkspaceRootPath,
        [string]$OperationName,
        [string[]]$BeforeLogPaths
    )

    $logRoot = Join-Path $WorkspaceRootPath 'TestResults\container-parity\windows\logs'
    New-Item -Path $logRoot -ItemType Directory -Force | Out-Null
    $timestamp = Get-Date -Format 'yyyyMMdd-HHmmss'
    $beforeSet = @{}
    foreach ($path in $BeforeLogPaths) {
        if (-not [string]::IsNullOrWhiteSpace($path)) {
            $beforeSet[$path] = $true
        }
    }

    $afterLogPaths = @(Get-LabVIEWCliTempLogPath)
    $newLogPaths = @()
    foreach ($source in $afterLogPaths) {
        if (-not $beforeSet.ContainsKey($source)) {
            $newLogPaths += $source
        }
    }

    if ($newLogPaths.Count -eq 0 -and $afterLogPaths.Count -gt 0) {
        $newLogPaths = @($afterLogPaths[0])
    }

    $copied = @()
    $index = 0
    foreach ($source in $newLogPaths) {
        if (-not (Test-Path -LiteralPath $source -PathType Leaf)) {
            continue
        }
        $index++
        $destination = Join-Path $logRoot ("{0}-{1}-{2}.log" -f $OperationName.ToLowerInvariant(), $timestamp, $index)
        Copy-Item -LiteralPath $source -Destination $destination -Force
        $copied += $destination
        Write-Output "Captured LabVIEWCLI log: $destination"
    }

    return $copied
}

function Invoke-LabVIEWCliOperation {
    param(
        [string]$OperationName,
        [string[]]$Arguments,
        [string]$WorkspaceRootPath
    )

    $beforeLogPaths = @(Get-LabVIEWCliTempLogPath)
    $outputLines = & LabVIEWCLI @Arguments 2>&1
    $exitCode = $LASTEXITCODE
    $outputText = if ($null -eq $outputLines) {
        ''
    } else {
        @($outputLines | ForEach-Object { $_.ToString() }) -join [Environment]::NewLine
    }
    if (-not [string]::IsNullOrWhiteSpace($outputText)) {
        Write-Output $outputText
    }
    $copiedLogs = Save-LabVIEWCliLog -WorkspaceRootPath $WorkspaceRootPath -OperationName $OperationName -BeforeLogPaths $beforeLogPaths

    return [pscustomobject]@{
        ExitCode   = $exitCode
        CopiedLogs = $copiedLogs
        OutputText = $outputText
    }
}

$repoRootResolution = Resolve-LvieRepoRoot `
    -LvieRepoRoot $env:LVIE_REPO_ROOT `
    -WorkspaceRoot $WorkspaceRoot `
    -RepoRoot $env:REPO_ROOT `
    -DefaultRepoRoot 'C:\workspace'
$WorkspaceRoot = $repoRootResolution.Path

$projectRelativePath = if ([string]::IsNullOrWhiteSpace($env:LVIE_PROJECT_RELATIVE_PATH)) {
    if ([string]::IsNullOrWhiteSpace($env:PROJECT_PATH_REL)) {
        'lv_icon_editor.lvproj'
    } else {
        $env:PROJECT_PATH_REL
    }
} else {
    $env:LVIE_PROJECT_RELATIVE_PATH
}

$projectPathCanonicalCandidate = if ([string]::IsNullOrWhiteSpace($ProjectPath)) { $env:LVIE_PROJECT_PATH } else { $ProjectPath }
$projectPathAliasCandidate = if ([string]::IsNullOrWhiteSpace($ProjectPath)) { $env:PROJECT_PATH } else { $null }
$projectPathResolution = Resolve-LvieProjectPath `
    -LvieProjectPath $projectPathCanonicalCandidate `
    -ProjectPath $projectPathAliasCandidate `
    -RepoRoot $WorkspaceRoot `
    -ProjectRelativePath $projectRelativePath `
    -DefaultProjectRelativePath 'lv_icon_editor.lvproj'
$ProjectPath = $projectPathResolution.Path

$targetDirRelativePath = if ([string]::IsNullOrWhiteSpace($env:TARGET_DIR_REL)) {
    'Test\Templates'
} else {
    $env:TARGET_DIR_REL
}
$targetDirSource = 'parameter:TargetDir'
if ([string]::IsNullOrWhiteSpace($TargetDir)) {
    if (-not [string]::IsNullOrWhiteSpace($env:TARGET_DIR)) {
        $TargetDir = $env:TARGET_DIR
        $targetDirSource = '$env:TARGET_DIR'
    } else {
        $TargetDir = Join-LvieRepoPath -RepoRoot $WorkspaceRoot -RelativePath $targetDirRelativePath
        $targetDirSource = '$env:TARGET_DIR_REL'
    }
}

$env:LVIE_REPO_ROOT = $WorkspaceRoot
$env:LVIE_PROJECT_PATH = $ProjectPath
$env:LVIE_PROJECT_RELATIVE_PATH = $projectPathResolution.RelativePath
$env:WORKSPACE_ROOT = $WorkspaceRoot
$env:REPO_ROOT = $WorkspaceRoot
$env:PROJECT_PATH = $ProjectPath

Write-Output ("Resolved repo root: {0} (source: {1})" -f $WorkspaceRoot, $repoRootResolution.Source)
Write-Output ("Resolved project path: {0} (source: {1})" -f $ProjectPath, $projectPathResolution.Source)
Write-Output ("Resolved target directory: {0} (source: {1})" -f $TargetDir, $targetDirSource)

if ([string]::IsNullOrWhiteSpace($BuildSpecName)) {
    $BuildSpecName = if ([string]::IsNullOrWhiteSpace($env:CONTAINER_PARITY_BUILD_SPEC_NAME)) {
        'Editor Packed Library'
    } else {
        $env:CONTAINER_PARITY_BUILD_SPEC_NAME
    }
}

if ([string]::IsNullOrWhiteSpace($TargetName)) {
    $TargetName = if ([string]::IsNullOrWhiteSpace($env:CONTAINER_PARITY_TARGET_NAME)) {
        'My Computer'
    } else {
        $env:CONTAINER_PARITY_TARGET_NAME
    }
}

$buildSpecEnabled = $BuildProjectSpec.IsPresent -or (Test-EnabledValue -Value $env:CONTAINER_PARITY_BUILD_SPEC)
$buildOutputRelativePath = if ([string]::IsNullOrWhiteSpace($env:CONTAINER_PARITY_BUILD_OUTPUT_RELATIVE_PATH)) {
    'resource\plugins\lv_icon.lvlibp'
} else {
    $env:CONTAINER_PARITY_BUILD_OUTPUT_RELATIVE_PATH
}
$buildOutputPath = Join-LvieRepoPath -RepoRoot $WorkspaceRoot -RelativePath $buildOutputRelativePath

if (-not (Get-Command LabVIEWCLI -ErrorAction SilentlyContinue)) {
    Write-Error "LabVIEWCLI is not available on PATH inside the container."
}

$portResolution = Resolve-LabVIEWCliPort -LabVIEWExecutablePath $LabVIEWPath
Write-Output ("Using LabVIEWCLI port: {0} (source: {1})" -f $portResolution.PortNumber, $portResolution.Source)

if (-not (Test-Path -LiteralPath $TargetDir -PathType Container)) {
    Write-Error "Target directory does not exist: $TargetDir"
}

$excludeRaw = $env:CONTAINER_PARITY_EXCLUDE_FILES
if ([string]::IsNullOrWhiteSpace($excludeRaw)) {
    $excludeRaw = 'Polymorphic Template.vi'
}
$excludeFiles = @($excludeRaw.Split(';', [System.StringSplitOptions]::RemoveEmptyEntries) | ForEach-Object { $_.Trim() } | Where-Object { $_ })

$stagingDir = Join-Path ([System.IO.Path]::GetTempPath()) ("lvie-parity-{0}" -f [Guid]::NewGuid().ToString('N'))
New-Item -Path $stagingDir -ItemType Directory -Force | Out-Null
$launchedLabVIEWProcess = $null

try {
    $shouldPrelaunch = Test-LabVIEWPrelaunchForCli -WorkspaceRootPath $WorkspaceRoot
    if ($shouldPrelaunch) {
        $launchedLabVIEWProcess = Start-LabVIEWForCli -LabVIEWExecutablePath $LabVIEWPath -PortNumber $portResolution.PortNumber
    } else {
        Write-Output "Skipping LabVIEW prelaunch for CLI operations in container workspace mode."
    }

    Copy-Item -Path (Join-Path $TargetDir '*') -Destination $stagingDir -Recurse -Force
    foreach ($relativePath in $excludeFiles) {
        $candidate = Join-Path $stagingDir $relativePath
        if (Test-Path -LiteralPath $candidate) {
            Write-Output "Excluding template from parity compile: $relativePath"
            Remove-Item -LiteralPath $candidate -Recurse -Force
        }
    }

    Write-Output "Running LabVIEWCLI MassCompile in headless mode."
    Write-Output "Target directory: $TargetDir"
    Write-Output "LabVIEW path: $LabVIEWPath"
    Write-Output ("Excluded templates: {0}" -f ($excludeFiles -join '; '))
    Write-Output "Staging directory: $stagingDir"

    $massCompile = Invoke-LabVIEWCliOperation -OperationName 'MassCompile' -Arguments @(
        '-LogToConsole', 'TRUE',
        '-OperationName', 'MassCompile',
        '-DirectoryToCompile', $stagingDir,
        '-LabVIEWPath', $LabVIEWPath,
        '-PortNumber', $portResolution.PortNumber.ToString(),
        '-Headless'
    ) -WorkspaceRootPath $WorkspaceRoot
    if ($massCompile.ExitCode -ne 0) {
        throw "LabVIEWCLI MassCompile failed with exit code $($massCompile.ExitCode)."
    }

    Write-Output "MassCompile completed successfully."

    if (-not $buildSpecEnabled) {
        Write-Output "Build specification step disabled (set CONTAINER_PARITY_BUILD_SPEC=true to enable)."
        return
    }

    if (-not (Test-Path -LiteralPath $ProjectPath -PathType Leaf)) {
        throw "Project file does not exist: $ProjectPath"
    }

    Write-Output "Synchronizing workspace Icon Editor sources into LabVIEW install before build-spec execution."
    Sync-IconEditorSourcesForBuildSpec -WorkspaceRootPath $WorkspaceRoot -LabVIEWExecutablePath $LabVIEWPath

    Write-Output "Running LabVIEWCLI ExecuteBuildSpec in headless mode."
    Write-Output "Project path: $ProjectPath"
    Write-Output "Build specification: $BuildSpecName"
    Write-Output "Target name: $TargetName"
    Write-Output "Expected output: $buildOutputPath"

    $buildSpec = Invoke-LabVIEWCliOperation -OperationName 'ExecuteBuildSpec' -Arguments @(
        '-LogToConsole', 'TRUE',
        '-OperationName', 'ExecuteBuildSpec',
        '-ProjectPath', $ProjectPath,
        '-BuildSpecName', $BuildSpecName,
        '-TargetName', $TargetName,
        '-LabVIEWPath', $LabVIEWPath,
        '-PortNumber', $portResolution.PortNumber.ToString(),
        '-Headless'
    ) -WorkspaceRootPath $WorkspaceRoot
    if ($buildSpec.ExitCode -ne 0) {
        throw "LabVIEWCLI ExecuteBuildSpec failed with exit code $($buildSpec.ExitCode)."
    }

    if (-not (Test-Path -LiteralPath $buildOutputPath -PathType Leaf)) {
        throw "Build specification output not found at expected path: $buildOutputPath"
    }

    $buildOutput = Get-Item -LiteralPath $buildOutputPath
    Write-Output ("Build specification completed: {0} ({1} bytes)" -f $buildOutput.FullName, $buildOutput.Length)
} finally {
    if ($launchedLabVIEWProcess -and -not $launchedLabVIEWProcess.HasExited) {
        try {
            Write-Output ("Closing launched LabVIEW process (PID {0})." -f $launchedLabVIEWProcess.Id)
            $closeResult = Invoke-LabVIEWCliOperation -OperationName 'CloseLabVIEW' -Arguments @(
                '-LogToConsole', 'TRUE',
                '-OperationName', 'CloseLabVIEW',
                '-LabVIEWPath', $LabVIEWPath,
                '-PortNumber', $portResolution.PortNumber.ToString()
            ) -WorkspaceRootPath $WorkspaceRoot

            if ($closeResult.ExitCode -ne 0) {
                Write-Warning ("CloseLabVIEW returned exit code {0} for PID {1}." -f $closeResult.ExitCode, $launchedLabVIEWProcess.Id)
            }

            Start-Sleep -Seconds 2
            $launchedLabVIEWProcess.Refresh()
            if (-not $launchedLabVIEWProcess.HasExited) {
                Write-Warning ("Launched LabVIEW process PID {0} is still running after CloseLabVIEW." -f $launchedLabVIEWProcess.Id)
            }
        } catch {
            Write-Warning ("Failed to close launched LabVIEW process PID {0}: {1}" -f $launchedLabVIEWProcess.Id, $_.Exception.Message)
        }
    }

    if (Test-Path -LiteralPath $stagingDir) {
        Remove-Item -LiteralPath $stagingDir -Recurse -Force -ErrorAction SilentlyContinue
    }
}
