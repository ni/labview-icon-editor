<#
.SYNOPSIS
    Reverts the repository from development mode.

.DESCRIPTION
    Restores the packaged LabVIEW sources for both 32-bit and 64-bit
    environments and closes any running LabVIEW instances.

.PARAMETER RepositoryPath
    Path to the repository root.

.EXAMPLE
    .\RevertDevelopmentMode.ps1 -RepositoryPath "C:\labview-icon-editor"
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
    } catch {
        $msg = "Error occurred while executing: $ScriptPath $($ArgumentList -join ' '). Exiting."
        if ($_.Exception) { $msg += " Inner: $($_.Exception.Message)" }
        if ($_.InvocationInfo) { $msg += " At: $($_.InvocationInfo.PositionMessage)" }
        Write-Error $msg
        throw
    }
}

# Sequential script execution with error handling
try {
    # Always resolve from VIPB to ensure determinism; ignore inbound overrides
    $Package_LabVIEW_Version = & (Join-Path $RepositoryPath 'scripts/get-package-lv-version.ps1') -RepositoryPath $RepositoryPath
    Write-Information ("Detected LabVIEW version from VIPB: {0}" -f $Package_LabVIEW_Version) -InformationAction Continue

    $targetBitness = $SupportedBitness
    Write-Information ("Targeting bitness: {0}-bit" -f $targetBitness) -InformationAction Continue
    # Build the script paths
    $CloseScript   = Join-Path -Path $RepositoryPath -ChildPath 'scripts/close-labview/Close_LabVIEW.ps1'

    $arch = $targetBitness

    # Skip restore when no dev-mode token exists for this repo (avoids g-cli deadtime on stale bindings)
    function Should-RunRestore {
        param(
            [Parameter(Mandatory)][string]$RepoPath,
            [Parameter(Mandatory)][string]$LvVersion,
            [Parameter(Mandatory)][string]$Bitness
        )
        try {
            $vendorTools = Join-Path $RepoPath 'src/tools/VendorTools.psm1'
            if (-not (Test-Path -LiteralPath $vendorTools -PathType Leaf)) { return $true }
            Import-Module $vendorTools -Force -ErrorAction Stop
            $lvExe = Resolve-LabVIEWExePath -Version ([int]$LvVersion) -Bitness ([int]$Bitness) -ErrorAction Stop
            $ini  = Get-LabVIEWIniPath -LabVIEWExePath $lvExe
            if (-not (Test-Path -LiteralPath $ini -PathType Leaf)) { return $true }
            $content = Get-Content -LiteralPath $ini -Raw -ErrorAction Stop
            if ($content -match [regex]::Escape($RepoPath)) { return $true }
            Write-Information ("Dev-mode token for {0} not found in {1}; skipping restore." -f $RepoPath, $ini) -InformationAction Continue
            return $false
        } catch {
            Write-Information ("Unable to verify LabVIEW.ini token: {0}. Proceeding with restore." -f $_.Exception.Message) -InformationAction Continue
            return $true
        }
    }

    if (Should-RunRestore -RepoPath $RepositoryPath -LvVersion $Package_LabVIEW_Version -Bitness $arch) {
        $resolver = Join-Path $ScriptDirectory '..\common\resolve-repo-cli.ps1'
        $prov = $null
        try {
            if (-not (Test-Path -LiteralPath $resolver -PathType Leaf)) {
                throw "CLI resolver not found at $resolver"
            }
            $prov = & $resolver -CliName 'OrchestrationCli' -RepoPath $RepositoryPath -SourceRepoPath $RepositoryPath -PrintProvenance:$false
        } catch {
            $warnMsg = ("Skipping restore because OrchestrationCli could not be resolved: {0}" -f $_.Exception.Message)
            if ($env:CI) {
                Write-Information $warnMsg -InformationAction Continue
            } else {
                Write-Warning $warnMsg
            }
        }

        if ($prov) {
            $orchestrationArgs = @(
                'restore-sources',
                '--repo', $RepositoryPath,
                '--bitness', $arch,
                '--lv-version', $Package_LabVIEW_Version
            )
            Write-Information ("Restore via OrchestrationCli: {0}" -f (($prov.Command + $orchestrationArgs) -join ' ')) -InformationAction Continue
            & $prov.Command[0] @($prov.Command[1..($prov.Command.Count-1)]) @orchestrationArgs
            if ($LASTEXITCODE -ne 0) {
                throw ("restore-sources failed with exit {0} for {1}-bit LabVIEW {2}" -f $LASTEXITCODE, $arch, $Package_LabVIEW_Version)
            }
        }
        else {
            Write-Information "Restore skipped because OrchestrationCli is unavailable; continuing unbind cleanup." -InformationAction Continue
        }
    } else {
        Write-Information "Restore skipped because this repo is not currently bound in LabVIEW.ini." -InformationAction Continue
    }

    if (Test-Path -LiteralPath $CloseScript -PathType Leaf) {
        Invoke-ScriptSafe -ScriptPath $CloseScript -ArgumentMap @{
            MinimumSupportedLVVersion = $Package_LabVIEW_Version
            SupportedBitness          = $arch
        }
    }
    else {
        $warnMsg = ("Close_LabVIEW.ps1 not found at {0}; skipping close step." -f $CloseScript)
        if ($env:CI) {
            Write-Information $warnMsg -InformationAction Continue
        } else {
            Write-Warning $warnMsg
        }
    }

} catch {
    Write-Error "An unexpected error occurred during script execution: $($_.Exception.Message)"
    exit 1
}

Write-Information "All scripts executed successfully." -InformationAction Continue

