<#
.SYNOPSIS
    Runs MissingInProjectCLI.vi via G-CLI and streams the VI's output.

.PARAMETER LVVersion
    LabVIEW version (e.g. "2021").

.PARAMETER Arch
    Bitness ("32" or "64").

.PARAMETER ProjectFile
    Full path to the .lvproj that should be inspected.

.NOTES
    - Leaves exit status in $LASTEXITCODE for the caller.
    - Does NOT call 'exit' to avoid terminating a parent session.
#>
#Requires -Version 7.0
[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$LVVersion,
[Parameter(Mandatory)][ValidateSet('32','64')][string]$Arch,
[Parameter(Mandatory)][string]$ProjectFile
)
$ErrorActionPreference = 'Stop'
Write-Information "[GCLI] Starting Missing-in-Project check ..." -InformationAction Continue

Write-Warning "Deprecated: prefer 'pwsh scripts/common/invoke-repo-cli.ps1 -Cli OrchestrationCli -- missing-check --repo <path> --bitness <both|64|32> --project <lvproj> --lv-version <year>'; this script remains as a delegate."
Write-Information "[legacy-ps] missing-check delegate invoked" -InformationAction Continue

$projectInput = $ProjectFile
try {
    $ProjectFile = (Resolve-Path -LiteralPath $ProjectFile -ErrorAction Stop).ProviderPath
}
catch {
    Write-Warning ("Project file not found or invalid path '{0}': {1}" -f $projectInput, $_.Exception.Message)
    $global:LASTEXITCODE = 3
    return
}

function Get-ExceptionDetails {
    param([Parameter(Mandatory)][System.Management.Automation.ErrorRecord]$ErrorRecord)
    @{
        message   = $ErrorRecord.Exception.Message
        type      = $ErrorRecord.Exception.GetType().FullName
        category  = $ErrorRecord.CategoryInfo.ToString()
        script    = $ErrorRecord.InvocationInfo.ScriptName
        line      = $ErrorRecord.InvocationInfo.ScriptLineNumber
        position  = $ErrorRecord.InvocationInfo.PositionMessage
        stack     = $ErrorRecord.ScriptStackTrace
    }
}

# ---------- paths ----------
$gcliLogPath  = Join-Path -Path $PSScriptRoot -ChildPath 'missing_in_project_gcli.log'
$metaPath     = Join-Path -Path $PSScriptRoot -ChildPath 'missing_in_project_meta.json'
Remove-Item $gcliLogPath, $metaPath -ErrorAction SilentlyContinue

# ---------- sanity checks ----------
$gcliCmd = Get-Command g-cli -ErrorAction SilentlyContinue
if (-not $gcliCmd) {
    Write-Warning "g-cli executable not found in PATH."
    $global:LASTEXITCODE = 127
    return
}

$viPath = Join-Path -Path $PSScriptRoot -ChildPath 'MissingInProjectCLI.vi'
if (-not (Test-Path $viPath)) {
    Write-Warning "VI not found: $viPath"
    $global:LASTEXITCODE = 2
    return
}

# ---------- diagnostics snapshot ----------
$gcliVersion = ""
try {
    $gcliVersion = (& g-cli --version) -join ' '
}
catch {
    $gcliVersion = $_.Exception.Message
}

$gcliArgs = @(
    '--lv-ver', $LVVersion,
    '--arch',   $Arch,
    $viPath,
    '--',
    $ProjectFile
)
$commandPreview = "g-cli " + ($gcliArgs -join ' ')
$meta = [ordered]@{
    timestamp       = (Get-Date -Format o)
    lvVersion       = $LVVersion
    arch            = $Arch
    projectFile     = $ProjectFile
    workingDir      = (Get-Location).Path
    gcliPath        = $gcliCmd.Source
    gcliVersion     = $gcliVersion
    commandPreview  = $commandPreview
    args            = $gcliArgs
    environment     = @{
        PATH             = $env:PATH
        GITHUB_WORKSPACE = $env:GITHUB_WORKSPACE
        ACTION_PATH      = $PSScriptRoot
    }
    machine         = $env:COMPUTERNAME
    user            = $env:USERNAME
    psVersion       = $PSVersionTable.PSVersion.ToString()
}

Write-Information "VI path      : $viPath" -InformationAction Continue
Write-Information "Project file : $ProjectFile" -InformationAction Continue
Write-Information "LabVIEW ver  : $LVVersion  ($Arch-bit)" -InformationAction Continue
Write-Information "g-cli path   : $($gcliCmd.Source)" -InformationAction Continue
Write-Information "g-cli ver    : $gcliVersion" -InformationAction Continue
Write-Information "Working dir  : $(Get-Location)" -InformationAction Continue
Write-Information "Command      : $commandPreview" -InformationAction Continue
Write-Information "--------------------------------------------------" -InformationAction Continue

$gcliOutput = @()
$exitCode   = -1
$invokeError = $null

try {
    # Capture output while writing to a log file; Tee-Object cannot use -Variable and -FilePath together
    $gcliOutput = & g-cli @gcliArgs 2>&1 | Tee-Object -FilePath $gcliLogPath
    $exitCode   = $LASTEXITCODE
}
catch {
    $invokeError = $_
    $gcliOutput  = @($invokeError.ToString())
    $exitCode    = -1
}

$meta.exitCode = $exitCode
$meta.outputPreview = @{
    first = ($gcliOutput | ForEach-Object { $_.ToString() } | Select-Object -First 5)
    last  = ($gcliOutput | ForEach-Object { $_.ToString() } | Select-Object -Last 5)
}
if ($invokeError) {
    $meta.invokeError = Get-ExceptionDetails -ErrorRecord $invokeError
}

$meta | ConvertTo-Json -Depth 16 | Set-Content -Path $metaPath -Encoding UTF8

# relay all output so the wrapper can capture & parse
$gcliOutput | ForEach-Object { Write-Output $_ }

if ($exitCode -eq 0) {
    Write-Information "Missing-in-Project check passed (no missing files)." -InformationAction Continue
    Remove-Item $gcliLogPath, $metaPath -ErrorAction SilentlyContinue
} else {
    Write-Warning "Missing-in-Project check FAILED - exit code $exitCode"
    Write-Warning ("g-cli output saved to {0}" -f $gcliLogPath)
    Write-Warning ("Metadata saved to {0}" -f $metaPath)

    $firstLines = $gcliOutput | Select-Object -First 5
    $lastLines  = $gcliOutput | Select-Object -Last 5
    if ($firstLines) {
        Write-Warning ("Output (first 5 lines):`n{0}" -f ($firstLines -join [Environment]::NewLine))
    }
    if ($lastLines) {
        Write-Warning ("Output (last 5 lines):`n{0}" -f ($lastLines -join [Environment]::NewLine))
    }
    if ($invokeError) {
        Write-Warning ("Invocation error: {0}" -f $invokeError.Exception.Message)
    }
}

# close LabVIEW if still running (harmless if not)
$closeScript = Join-Path (Split-Path $PSScriptRoot -Parent) 'close-labview\Close_LabVIEW.ps1'
try {
    if (-not (Test-Path -LiteralPath $closeScript)) {
        throw "Close_LabVIEW.ps1 not found at expected path: $closeScript"
    }
    & $closeScript -Package_LabVIEW_Version $LVVersion -SupportedBitness $Arch | Out-Null
}
catch {
    Write-Warning ("Failed to close LabVIEW after missing-in-project run: {0}" -f $_.Exception.Message)
}

$global:LASTEXITCODE = $exitCode
return
