<#
#    .SYNOPSIS
#        Configures the repository for development mode.
#
#    .DESCRIPTION
#        Removes existing packed libraries, adds INI tokens, prepares LabVIEW
#        sources for both 32-bit and 64-bit environments, and closes LabVIEW.
#
#    .PARAMETER RepositoryPath
#        Path to the repository root.
#
#    .EXAMPLE
#        .\Set_Development_Mode.ps1 -RepositoryPath "C:\\labview-icon-editor"
#
#>

param(
    [Parameter(Mandatory = $true)]
    [ValidateScript({ Test-Path $_ })]
    [string]$RepositoryPath,

    # Optional override; if not provided we read Package_LabVIEW_Version from the repo .vipb
    [Parameter(Mandatory = $false)]
    [string]$Package_LabVIEW_Version,

    # Limit work to a single bitness (default 64-bit)
    [Parameter(Mandatory = $false)]
    [ValidateSet('32','64')]
    [string]$SupportedBitness = '64'
)

# Define LabVIEW project name
$LabVIEW_Project = 'lv_icon_editor'

# Determine the directory where this script is located
$ScriptDirectory = Split-Path -Parent -Path $MyInvocation.MyCommand.Definition
Write-Information "Script Directory: $ScriptDirectory" -InformationAction Continue

# Normalize repository path early and re-validate
$RepositoryPath = (Resolve-Path -LiteralPath $RepositoryPath).Path
if (-not (Test-Path -LiteralPath $RepositoryPath)) {
    throw "RepositoryPath '$RepositoryPath' does not exist."
}

# Build paths to the helper scripts (normalize to absolute paths to avoid "..\" segments in logs)
$AddTokenScript = [System.IO.Path]::GetFullPath((Join-Path -Path $ScriptDirectory -ChildPath '..\add-token-to-labview\AddTokenToLabVIEW.ps1'))
$PrepareScript  = [System.IO.Path]::GetFullPath((Join-Path -Path $ScriptDirectory -ChildPath '..\prepare-labview-source\Prepare_LabVIEW_source.ps1'))
$CloseScript    = [System.IO.Path]::GetFullPath((Join-Path -Path $RepositoryPath  -ChildPath 'scripts/close-labview/Close_LabVIEW.ps1'))

Write-Information "AddTokenToLabVIEW script: $AddTokenScript" -InformationAction Continue
Write-Information "Prepare_LabVIEW_source script: $PrepareScript" -InformationAction Continue
Write-Information "Close_LabVIEW script: $CloseScript" -InformationAction Continue

# Helper function to execute scripts and stop on error
function Invoke-ScriptSafe {
    param(
        [string]$ScriptPath,
        [hashtable]$ArgumentMap,
        [string[]]$ArgumentList
    )
    if (-not $ScriptPath) { throw "ScriptPath is required" }
    if (-not (Test-Path -LiteralPath $ScriptPath)) { throw "ScriptPath '$ScriptPath' not found" }

    $render = if ($ArgumentMap) {
        ($ArgumentMap.GetEnumerator() | ForEach-Object { "-$($_.Key) $($_.Value)" }) -join ' '
    } else {
        ($ArgumentList -join ' ')
    }
    Write-Information ("Executing: {0} {1}" -f $ScriptPath, $render) -InformationAction Continue
    try {
        if ($ArgumentMap) {
            & $ScriptPath @ArgumentMap
        } elseif ($ArgumentList) {
            & $ScriptPath @ArgumentList
        } else {
            & $ScriptPath
        }
    }
    catch {
        $msg = "Error occurred while executing: $ScriptPath $($ArgumentList -join ' '). Exiting."
        if ($_.Exception) { $msg += " Inner: $($_.Exception.Message)" }
        if ($_.InvocationInfo) { $msg += " At: $($_.InvocationInfo.PositionMessage)" }
        Write-Error $msg
        throw
    }
}

# Extract LabVIEW version from the repo's VIPB (Package_LabVIEW_Version)
function Get-LabVIEWVersionFromVipb {
    param(
        [Parameter(Mandatory)][string]$RootPath
    )

    $vipb = Get-ChildItem -Path $RootPath -Filter *.vipb -File -Recurse | Select-Object -First 1
    if (-not $vipb) {
        throw "No .vipb file found under $RootPath"
    }

    $text = Get-Content -LiteralPath $vipb.FullName -Raw
    $match = [regex]::Match($text, '<Package_LabVIEW_Version>(?<ver>[^<]+)</Package_LabVIEW_Version>', 'IgnoreCase')
    if (-not $match.Success) {
        throw "Unable to locate Package_LabVIEW_Version in $($vipb.FullName)"
    }

    $raw = $match.Groups['ver'].Value
    # Expect formats like '21.0 (64-bit)'
    $verMatch = [regex]::Match($raw, '^(?<majmin>\d{2}\.\d)')
    if (-not $verMatch.Success) {
        throw "Unable to parse LabVIEW version from '$raw' in $($vipb.FullName)"
    }
    $maj = [int]($verMatch.Groups['majmin'].Value.Split('.')[0])
    # Convert 21 -> 2021, 23 -> 2023, etc.
    $lvVersion = if ($maj -ge 20) { "20$maj" } else { $maj.ToString() }
    return $lvVersion
}

try {
    if (-not [string]::IsNullOrWhiteSpace($Package_LabVIEW_Version)) {
        Write-Information ("Using provided LabVIEW version override: {0}" -f $Package_LabVIEW_Version) -InformationAction Continue
    }
    else {
        $Package_LabVIEW_Version = & (Join-Path $RepositoryPath 'scripts/get-package-lv-version.ps1') -RepositoryPath $RepositoryPath
        Write-Information ("Detected LabVIEW version from VIPB: {0}" -f $Package_LabVIEW_Version) -InformationAction Continue
    }

    $targetBitness = $SupportedBitness
    Write-Information ("Targeting bitness: {0}-bit" -f $targetBitness) -InformationAction Continue

    # Quick g-cli sanity (helps diagnose missing or broken installs)
    $gcli = Get-Command g-cli -ErrorAction SilentlyContinue
    if (-not $gcli) {
        throw "g-cli is not available on PATH; install g-cli before running development-mode tasks."
    }
    $probe = & g-cli --help 2>&1
    if ($LASTEXITCODE -ne 0) {
        throw "g-cli --help failed with exit code $LASTEXITCODE. Output: $($probe -join '; ')"
    }

    # Remove existing packed libraries (if the folder exists)
    $PluginsPath = Join-Path -Path $RepositoryPath -ChildPath 'resource\plugins'
    if (Test-Path $PluginsPath) {
        # Build and execute the removal command only if the plugins folder exists
        # Remove via pipeline to avoid IE
        Get-ChildItem -Path $PluginsPath -Filter '*.lvlibp' -ErrorAction SilentlyContinue | Remove-Item -Force -Recurse -Confirm:$false
    }
    else {
        Write-Information "No 'resource\plugins' directory found at $PluginsPath; skipping removal of packed libraries." -InformationAction Continue
    }

    $arch = $targetBitness

    Invoke-ScriptSafe -ScriptPath $AddTokenScript -ArgumentMap @{
        Package_LabVIEW_Version   = $Package_LabVIEW_Version
        SupportedBitness          = $arch
        RepositoryPath            = $RepositoryPath
    }

    Invoke-ScriptSafe -ScriptPath $PrepareScript -ArgumentMap @{
        Package_LabVIEW_Version   = $Package_LabVIEW_Version
        SupportedBitness          = $arch
        RepositoryPath            = $RepositoryPath
        LabVIEW_Project           = $LabVIEW_Project
        Build_Spec                = 'Editor Packed Library'
    }

    Invoke-ScriptSafe -ScriptPath $CloseScript -ArgumentMap @{
        Package_LabVIEW_Version   = $Package_LabVIEW_Version
        SupportedBitness          = $arch
    }
}
catch {
    Write-Error "An unexpected error occurred during script execution: $($_.Exception.Message)"
    exit 1
}

Write-Information "All scripts executed successfully." -InformationAction Continue
