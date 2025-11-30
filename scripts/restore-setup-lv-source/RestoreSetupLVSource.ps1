<#
.SYNOPSIS
    Restores the LabVIEW source setup from a packaged state.

.DESCRIPTION
    Calls RestoreSetupLVSourceCore.vi via g-cli to unzip the LabVIEW Icon API and
    remove the Localhost.LibraryPaths token from the LabVIEW INI file.

.PARAMETER Package_LabVIEW_Version
    LabVIEW version used to run g-cli.

.PARAMETER SupportedBitness
    Bitness of the LabVIEW environment ("32" or "64").

.PARAMETER RepositoryPath
    Path to the repository root.

.PARAMETER LabVIEW_Project
    Name of the LabVIEW project (without extension).

.PARAMETER Build_Spec
    Build specification name within the project.

.EXAMPLE
    .\RestoreSetupLVSource.ps1 -Package_LabVIEW_Version "2021" -SupportedBitness "64" -RepositoryPath "C:\labview-icon-editor" -LabVIEW_Project "lv_icon_editor" -Build_Spec "Editor Packed Library"
#>
param(
    [Alias('MinimumSupportedLVVersion')]
    [string]$Package_LabVIEW_Version,
    [ValidateSet('32','64')]
    [string]$SupportedBitness,
[string]$RepositoryPath,
[string]$LabVIEW_Project,
[string]$Build_Spec,
[int]$TimeoutSeconds = 15,
[int]$ConnectTimeoutSeconds = 10,
[int]$KillTimeoutSeconds = 5,
[switch]$KillLabVIEWOnExit,
[switch]$SkipOnTimeout
)

$ErrorActionPreference = 'Stop'

Write-Warning "Deprecated: prefer 'dotnet run --project Tooling/dotnet/OrchestrationCli/OrchestrationCli.csproj -- restore-sources --repo <path> --bitness <both|64|32> --lv-version <year>'; this script remains as a delegate."
Write-Information "[legacy-ps] restore-sources delegate invoked" -InformationAction Continue

# Normalize timeouts so g-cli has enough time to connect before the host times out, but cap host wait.
$connectSec = [Math]::Max(5, $ConnectTimeoutSeconds)
$killSec = [Math]::Max(5, $KillTimeoutSeconds)
$minHostWait = $connectSec + $killSec + 5
$maxHostWaitEnv = [int]::TryParse($env:RESTORE_MAX_HOST_WAIT_SEC, [ref]0) ? [int]$env:RESTORE_MAX_HOST_WAIT_SEC : 30
$waitSeconds = $minHostWait
if ($TimeoutSeconds -gt 0) {
    $waitSeconds = [Math]::Max($TimeoutSeconds, $minHostWait)
}
$waitSeconds = [Math]::Min($waitSeconds, [Math]::Max($minHostWait, $maxHostWaitEnv))
Write-Information ("Timeouts - connect: {0}s, kill-timeout: {1}s, host wait: {2}s (max cap {3}s)" -f $connectSec, $killSec, $waitSeconds, $maxHostWaitEnv) -InformationAction Continue

# If dev-mode isn't active (no repo path in LabVIEW.ini), skip the restore to avoid
# failing on unnecessary g-cli calls after earlier pipeline errors.
$iniCandidates = @()
$pf = $env:ProgramFiles
$pf86 = ${env:ProgramFiles(x86)}
if ($SupportedBitness -eq '32') {
    if ($pf86) { $iniCandidates += (Join-Path $pf86 "National Instruments\LabVIEW $Package_LabVIEW_Version\LabVIEW.ini") }
    if ($pf)   { $iniCandidates += (Join-Path $pf   "National Instruments\LabVIEW $Package_LabVIEW_Version (32-bit)\LabVIEW.ini") }
} else {
    if ($pf) { $iniCandidates += (Join-Path $pf "National Instruments\LabVIEW $Package_LabVIEW_Version\LabVIEW.ini") }
}
$iniPath = $iniCandidates | Where-Object { $_ -and (Test-Path -LiteralPath $_ -PathType Leaf) } | Select-Object -First 1
$tokenPresent = $false
if ($iniPath) {
    try {
        $content = Get-Content -LiteralPath $iniPath -Raw
        if ($content -match [regex]::Escape($RepositoryPath)) {
            $tokenPresent = $true
        }
    } catch {}
}
if (-not $tokenPresent) {
    Write-Information ("Dev-mode token for {0} not found in LabVIEW.ini; skipping restore." -f $RepositoryPath) -InformationAction Continue
    exit 0
}

$gcliArgs = @(
    '--lv-ver', $Package_LabVIEW_Version,
    '--arch', $SupportedBitness,
    '--connect-timeout', ([int][TimeSpan]::FromSeconds($connectSec).TotalMilliseconds),
    '--kill-timeout', ([int][TimeSpan]::FromSeconds($killSec).TotalMilliseconds),
    '-v', "$RepositoryPath\Tooling\RestoreSetupLVSourceCore.vi",
    '--',
    "$RepositoryPath\$LabVIEW_Project.lvproj",
    "$Build_Spec"
)
if ($KillLabVIEWOnExit) {
    $gcliArgs += '--kill'
}

Write-Information ("Executing g-cli: {0}" -f ($gcliArgs -join ' ')) -InformationAction Continue
try {
    $psi = New-Object System.Diagnostics.ProcessStartInfo
    $psi.FileName = "g-cli"
    foreach ($arg in $gcliArgs) { $psi.ArgumentList.Add($arg) }
    $psi.RedirectStandardOutput = $true
    $psi.RedirectStandardError = $true
    $psi.UseShellExecute = $false
    $proc = [System.Diagnostics.Process]::Start($psi)
    if (-not $proc) { throw "Failed to start g-cli process." }
    if (-not $proc.WaitForExit([Math]::Max(1,$waitSeconds) * 1000)) {
        try { $proc.Kill($true) } catch {}
        $message = "g-cli restore timed out after $waitSeconds second(s)."
        if ($SkipOnTimeout) {
            Write-Warning $message
            return
        }
        throw $message
    }
    $exit = $proc.ExitCode
    $out = $proc.StandardOutput.ReadToEnd()
    $err = $proc.StandardError.ReadToEnd()
    if ($out) { Write-Information $out -InformationAction Continue }
    if ($err) { Write-Verbose $err }
    $connectionIssues = ($out -match 'No connection established' -or $out -match 'Timed out waiting for app to connect' -or $out -match 'connection.*timed out' -or $err -match 'No connection established' -or $err -match 'Timed out waiting for app to connect')
    if ($exit -ne 0 -and $connectionIssues) {
        Write-Warning "Restore skipped: g-cli could not connect to LabVIEW (dev mode likely not active or blocked)."
        exit 0
    }
    if ($exit -ne 0 -and -not $out -and -not $err) {
        Write-Warning "Restore skipped: g-cli returned $exit with no diagnostics (likely dev mode inactive)."
        exit 0
    }
    if ($exit -eq 0) {
        Write-Information "Unzipped vi.lib/LabVIEW Icon API and removed localhost.library path from ini file." -InformationAction Continue
        exit 0
    }
    Write-Warning "g-cli exited with $exit during restore."
    exit $exit
}
finally {
    # Ensure LabVIEW is not left running after restore attempts
    $closeScript = Join-Path -Path $PSScriptRoot -ChildPath '..\close-labview\Close_LabVIEW.ps1'
    if (Test-Path -LiteralPath $closeScript -PathType Leaf) {
        try {
            & $closeScript -MinimumSupportedLVVersion $Package_LabVIEW_Version -SupportedBitness $SupportedBitness -TimeoutSeconds 30 -KillLabVIEW -KillTimeoutSeconds $killSec | Out-Null
        } catch {
            Write-Warning ("Failed to close LabVIEW after restore: {0}" -f $_.Exception.Message)
        }
    }
}
