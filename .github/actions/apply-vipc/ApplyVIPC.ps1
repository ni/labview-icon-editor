<#
.SYNOPSIS
    Installs runner dependencies for a given LabVIEW version/bitness from a
    vipm.toml manifest using the VIPM command line.

.DESCRIPTION
    Proof-of-concept replacement for the previous `g-cli vipc` flow. Instead of
    applying a binary .vipc file, this script:
      1. Resolves the vipm.toml manifest under the repo.
      2. Generates/refreshes the VIPM lock file via `vipm lock` (the lock is
         produced by VIPM, never hand-authored).
      3. Installs the locked dependency set via `vipm install`.

    LabVIEW version selection and 32-/64-bit support are preserved: the manifest
    is installed into each resolved LabVIEW year/bitness target, exactly as the
    prior VIPC flow did.

.EXAMPLE
    .\ApplyVIPC.ps1 -LabVIEWVersion "2021" -SupportedBitness "64" -RepoRoot "C:\labview-icon-editor" -VipmTomlPath ".github/actions/apply-vipc/vipm.toml" -Verbose
#>

[CmdletBinding()]  # Enables -Verbose and other common parameters
Param (
    [AllowNull()]
    [AllowEmptyString()]
    [Alias('MinimumSupportedLVVersion')]
    [string]$LabVIEWVersion = '2021',
    [AllowNull()]
    [AllowEmptyString()]
    [string]$VIP_LVVersion = '2021',
    [ValidateSet('32', '64')]
    [string]$SupportedBitness,
    [string]$RepoRoot,
    # Path (relative to repo) to the vipm.toml manifest.
    [string]$VipmTomlPath = '.github/actions/apply-vipc/vipm.toml',
    # Legacy .vipc path. Accepted for backward compatibility but ignored.
    [Alias('VIPCPath')]
    [string]$LegacyVIPCPath,
    # VIPM command-line executable (override for non-PATH installs).
    [string]$VipmExe = 'vipm',
    # Global --timeout in seconds passed to vipm; -1 waits indefinitely.
    [ValidateRange(-1, 3600)]
    [int]$VipmTimeoutSeconds = 900,
    # Force regeneration of vipm.lock even when it already matches vipm.toml.
    [switch]$UpdateLock,
    [string]$WorktreeRoot,
    [switch]$SkipWorktreeRootCheck
)

Write-Verbose "Script Name: $($MyInvocation.MyCommand.Definition)"
Write-Verbose "Parameters provided:"
Write-Verbose " - LabVIEWVersion:            $LabVIEWVersion"
Write-Verbose " - VIP_LVVersion:             $VIP_LVVersion"
Write-Verbose " - SupportedBitness:          $SupportedBitness"
Write-Verbose " - RepoRoot:                  $RepoRoot"
Write-Verbose " - VipmTomlPath:              $VipmTomlPath"

# -------------------------
# 1) Resolve Paths & Validate
# -------------------------
try {
    Write-Verbose "Attempting to resolve the 'RepoRoot'..."
    $ResolvedRepoRoot = (Resolve-Path -Path $RepoRoot -ErrorAction Stop).Path
    Write-Verbose "ResolvedRepoRoot: $ResolvedRepoRoot"

    $preflightScript = Join-Path -Path $ResolvedRepoRoot -ChildPath 'Tooling\Invoke-Preflight.ps1'
    if (Test-Path -Path $preflightScript) {
        . $preflightScript
        $scriptArgs = Convert-BoundParametersToArgumentList -BoundParameters $PSBoundParameters
        $relativeScript = if ($PSCommandPath) { Get-RepoRelativePath -RepoRoot $ResolvedRepoRoot -Path $PSCommandPath } else { $null }
        $preflight = Invoke-Preflight `
            -RepoRoot $ResolvedRepoRoot `
            -WorktreeRoot $WorktreeRoot `
            -LabVIEWVersion $LabVIEWVersion `
            -LabVIEWBitness $SupportedBitness `
            -SkipWorktreeRootCheck:$SkipWorktreeRootCheck `
            -AutoWorktree:$false `
            -ScriptPath $relativeScript `
            -ScriptArguments $scriptArgs
        if ($preflight.Reinvoked) {
            return
        }
        $ResolvedRepoRoot = $preflight.RepoRoot
    }

    Write-Verbose "Building full path for the vipm.toml manifest..."
    $ResolvedTomlPath = Join-Path -Path $ResolvedRepoRoot -ChildPath $VipmTomlPath -ErrorAction Stop
    Write-Verbose "ResolvedTomlPath:     $ResolvedTomlPath"

    Write-Verbose "Checking if the vipm.toml manifest exists at the resolved path..."
    if (-not (Test-Path $ResolvedTomlPath)) {
        Write-Error "The vipm.toml manifest does not exist at '$ResolvedTomlPath'."
        exit 1
    }
    Write-Verbose "The vipm.toml manifest was found successfully."

    $tomlDir = Split-Path -Parent $ResolvedTomlPath
    $ResolvedLockPath = Join-Path -Path $tomlDir -ChildPath 'vipm.lock'
    Write-Output "ResolvedTomlPath: $ResolvedTomlPath"
    Write-Output "ResolvedLockPath: $ResolvedLockPath"
}
catch {
    Write-Error "Error resolving paths. Ensure RepoRoot and VipmTomlPath are valid. Details: $($_.Exception.Message)"
    exit 1
}

# -------------------------
# 2) Build LabVIEW Version Strings
# -------------------------
Write-Verbose "Determining LabVIEW version strings..."

$versionHelper = Join-Path -Path $ResolvedRepoRoot -ChildPath 'Tooling\support\LabVIEWVersion.ps1'
if (-not (Test-Path -Path $versionHelper)) {
    throw "LabVIEW version helper not found at $versionHelper"
}
. $versionHelper

$minInfo = Get-LabVIEWVersionInfo -VersionInput $LabVIEWVersion -RepoRoot $ResolvedRepoRoot
$vipInfo = Get-LabVIEWVersionInfo -VersionInput $VIP_LVVersion -RepoRoot $ResolvedRepoRoot

Write-Output "Installing dependencies for LabVIEW $($minInfo.NumericVersion) ($SupportedBitness-bit)..."

# Preserve prior VIPC behavior: install into the minimum-supported LabVIEW year,
# and additionally into the VIP LabVIEW year when the two differ.
$targetYears = @($minInfo.Year)
if ($vipInfo.NumericVersion -ne $minInfo.NumericVersion -or $vipInfo.Year -ne $minInfo.Year) {
    Write-Verbose "VIP_LVVersion and LabVIEWVersion differ; adding target year $($vipInfo.Year)..."
    $targetYears += $vipInfo.Year
}

# -------------------------
# 3) Minimal vipm.toml reader (for logging/validation only)
# -------------------------
function Get-VipmDependencies {
    param([string]$Path)

    $deps = [ordered]@{}
    $inDependencies = $false
    foreach ($line in (Get-Content -Path $Path)) {
        $trimmed = $line.Trim()
        if ($trimmed -eq '' -or $trimmed.StartsWith('#')) { continue }
        if ($trimmed -match '^\[(.+)\]$') {
            $inDependencies = ($Matches[1] -eq 'dependencies')
            continue
        }
        if ($inDependencies -and $trimmed -match '^"?(?<name>[^"=]+?)"?\s*=\s*"(?<version>[^"]*)"') {
            $deps[$Matches['name'].Trim()] = $Matches['version'].Trim()
        }
    }
    return $deps
}

$dependencies = Get-VipmDependencies -Path $ResolvedTomlPath
if ($dependencies.Count -eq 0) {
    Write-Error "No [dependencies] found in $ResolvedTomlPath."
    exit 1
}
Write-Verbose ("Manifest declares {0} package(s):" -f $dependencies.Count)
foreach ($name in $dependencies.Keys) {
    Write-Verbose (" - {0} = {1}" -f $name, $dependencies[$name])
}

# -------------------------
# 4) Generate the lock (via VIPM) and install
# -------------------------
function Invoke-Vipm {
    param(
        [Parameter(Mandatory)][string[]]$Arguments,
        [Parameter(Mandatory)][string]$FailureMessage
    )

    Write-Output ("Executing: {0} {1}" -f $VipmExe, ($Arguments -join ' '))
    $output = & $VipmExe @Arguments 2>&1
    $exitCode = $LASTEXITCODE
    if ($output) {
        $output | ForEach-Object { Write-Host $_ }
    }
    if ($exitCode -ne 0) {
        throw ("{0} (exit code {1})." -f $FailureMessage, $exitCode)
    }
}

try {
    # Run vipm from the manifest directory so `vipm lock`/`vipm install`
    # discover this vipm.toml (both search upward from the working directory).
    Push-Location -Path $tomlDir
    # Suppress interactive prompts for CI.
    $env:VIPM_NONINTERACTIVE = '1'
    try {
        # Regenerate vipm.lock from vipm.toml when missing or when explicitly
        # requested. `vipm lock` is the only command that creates the lock; it
        # is produced by VIPM and never edited by hand.
        if ($UpdateLock -or -not (Test-Path -Path $ResolvedLockPath)) {
            Write-Output "Generating vipm.lock from vipm.toml via 'vipm lock'..."
            $lockArgs = @('lock', '--timeout', $VipmTimeoutSeconds)
            Invoke-Vipm -Arguments $lockArgs -FailureMessage 'vipm lock failed'

            if (-not (Test-Path -Path $ResolvedLockPath)) {
                throw "vipm lock succeeded, but vipm.lock was not found at the expected path '$ResolvedLockPath'."
            }

            Write-Output "vipm.lock found at: $ResolvedLockPath"
        }
        else {
            Write-Output "vipm.lock found at: $ResolvedLockPath"
            Write-Verbose "vipm.lock already present; reusing it. Pass -UpdateLock to regenerate."
        }

        foreach ($year in ($targetYears | Select-Object -Unique)) {
            Write-Output ("Installing dependencies into LabVIEW {0} ({1}-bit)..." -f $year, $SupportedBitness)
            # `vipm install` reads vipm.lock when in sync, else vipm.toml;
            # --labview-version (YYYY) / --labview-bitness override the target.
            $installArgs = @(
                'install',
                '--labview-version', $year,
                '--labview-bitness', $SupportedBitness,
                '--timeout', $VipmTimeoutSeconds
            )
            Invoke-Vipm -Arguments $installArgs -FailureMessage ("vipm install failed for LabVIEW {0} ({1}-bit)" -f $year, $SupportedBitness)

            try {
                Write-Output ("Closing LabVIEW {0} ({1}-bit) after install..." -f $year, $SupportedBitness)
                & g-cli --lv-ver $year --arch $SupportedBitness QuitLabVIEW | Out-Null
            }
            catch {
                Write-Warning ("Failed to close LabVIEW {0} ({1}-bit): {2}" -f $year, $SupportedBitness, $_.Exception.Message)
            }
        }
    }
    finally {
        Pop-Location
    }

    $global:LASTEXITCODE = 0
    Write-Host ("Successfully installed dependencies for LabVIEW {0} ({1}-bit)." -f $minInfo.NumericVersion, $SupportedBitness)
}
catch {
    Write-Error "An error occurred while installing the vipm.toml dependencies. Details: $($_.Exception.Message)"
    exit 1
}
