param(
    [string]$WorkspaceRoot = "C:\workspace",
    [string]$TargetDir = "",
    [string]$LabVIEWPath = "C:\Program Files\National Instruments\LabVIEW 2026\LabVIEW.exe",
    [string]$ProjectPath = "",
    [string]$BuildSpecName = "",
    [string]$TargetName = "",
    [string]$LabVIEWVersion = "",
    [switch]$BuildProjectSpec
)

$ErrorActionPreference = 'Stop'

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

function Resolve-LabVIEWVersionYear {
    param(
        [string]$VersionInput,
        [string]$LabVIEWExecutablePath
    )

    if (-not [string]::IsNullOrWhiteSpace($VersionInput)) {
        return $VersionInput
    }

    if (-not [string]::IsNullOrWhiteSpace($env:CONTAINER_PARITY_LABVIEW_VERSION)) {
        return $env:CONTAINER_PARITY_LABVIEW_VERSION
    }

    if ($LabVIEWExecutablePath -match 'LabVIEW\s+(?<year>\d{4})') {
        return $Matches['year']
    }

    return ''
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
    & LabVIEWCLI @Arguments
    $exitCode = $LASTEXITCODE
    $copiedLogs = Save-LabVIEWCliLog -WorkspaceRootPath $WorkspaceRootPath -OperationName $OperationName -BeforeLogPaths $beforeLogPaths

    return [pscustomobject]@{
        ExitCode   = $exitCode
        CopiedLogs = $copiedLogs
    }
}

if ([string]::IsNullOrWhiteSpace($TargetDir)) {
    $TargetDir = Join-Path $WorkspaceRoot 'Test\Templates'
}

if ([string]::IsNullOrWhiteSpace($ProjectPath)) {
    $ProjectPath = Join-Path $WorkspaceRoot 'lv_icon_editor.lvproj'
}

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
$enableDevMode = Test-EnabledValue -Value $env:CONTAINER_PARITY_ENABLE_DEVMODE
$buildOutputRelativePath = if ([string]::IsNullOrWhiteSpace($env:CONTAINER_PARITY_BUILD_OUTPUT_RELATIVE_PATH)) {
    'resource\plugins\lv_icon.lvlibp'
} else {
    $env:CONTAINER_PARITY_BUILD_OUTPUT_RELATIVE_PATH
}
$buildOutputPath = Join-Path $WorkspaceRoot $buildOutputRelativePath

if (-not (Get-Command LabVIEWCLI -ErrorAction SilentlyContinue)) {
    Write-Error "LabVIEWCLI is not available on PATH inside the container."
}

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

try {
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

    $setDevModeScript = $null
    $revertDevModeScript = $null
    $labviewYear = $null
    $devModeEnabled = $false
    if ($enableDevMode) {
        $setDevModeScript = Join-Path $WorkspaceRoot 'Tooling\Set-DevelopmentMode-NoLabVIEW.ps1'
        $revertDevModeScript = Join-Path $WorkspaceRoot 'Tooling\Revert-DevelopmentMode-NoLabVIEW.ps1'
        if (-not (Test-Path -LiteralPath $setDevModeScript -PathType Leaf)) {
            throw "Required script not found: $setDevModeScript"
        }
        if (-not (Test-Path -LiteralPath $revertDevModeScript -PathType Leaf)) {
            throw "Required script not found: $revertDevModeScript"
        }

        $labviewYear = Resolve-LabVIEWVersionYear -VersionInput $LabVIEWVersion -LabVIEWExecutablePath $LabVIEWPath
        if ([string]::IsNullOrWhiteSpace($labviewYear)) {
            throw "Unable to resolve LabVIEW version year for no-LabVIEW dev mode plumbing."
        }

        Write-Output "Preparing no-LabVIEW dev mode before build-spec execution."
        & $setDevModeScript `
            -LabVIEWVersion $labviewYear `
            -SupportedBitness 64 `
            -RepoRoot $WorkspaceRoot `
            -SkipProcessCheck `
            -SkipRepoVersionCheck
        if ($LASTEXITCODE -ne 0) {
            throw "Set-DevelopmentMode-NoLabVIEW failed with exit code $LASTEXITCODE."
        }
        $devModeEnabled = $true
    } else {
        Write-Output "No-LabVIEW dev mode is disabled for container parity (set CONTAINER_PARITY_ENABLE_DEVMODE=true to enable)."
    }

    $buildSpecError = $null
    try {
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
    } catch {
        $buildSpecError = $_
    } finally {
        if ($devModeEnabled) {
            Write-Output "Reverting no-LabVIEW dev mode after build-spec execution."
            & $revertDevModeScript `
                -LabVIEWVersion $labviewYear `
                -SupportedBitness 64 `
                -RepoRoot $WorkspaceRoot `
                -SkipProcessCheck `
                -SkipRepoVersionCheck
            if ($LASTEXITCODE -ne 0) {
                $revertError = "Revert-DevelopmentMode-NoLabVIEW failed with exit code $LASTEXITCODE."
                if ($buildSpecError) {
                    throw ("{0} Revert error: {1}" -f $buildSpecError.Exception.Message, $revertError)
                }
                throw $revertError
            }
        }
    }

    if ($buildSpecError) {
        throw $buildSpecError.Exception
    }
} finally {
    if (Test-Path -LiteralPath $stagingDir) {
        Remove-Item -LiteralPath $stagingDir -Recurse -Force -ErrorAction SilentlyContinue
    }
}
