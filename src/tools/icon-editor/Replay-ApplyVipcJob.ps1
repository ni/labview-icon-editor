#Requires -Version 7.0

<#
.SYNOPSIS
    Replays the "Apply VIPC Dependencies" job locally for diagnosis.

.DESCRIPTION
    Downloads (or accepts) the job log, infers the LabVIEW version/bitness
    used by the matrix entry, and re-invokes the apply-vipc action locally so
    the behaviour can be reproduced without waiting on self-hosted runners.

.PARAMETER RunId
    Workflow run identifier containing the job to replay.

.PARAMETER JobName
    Display title of the job (defaults to "Apply VIPC Dependencies (2026, 64)").

.PARAMETER Repository
    Optional owner/repo override when the run lives outside the current clone.

.PARAMETER LogPath
    Optional log path. When omitted and RunId is supplied, the script downloads
    the job log into a temporary file.

.PARAMETER Workspace
    Repository root that mirrors ${{ github.workspace }} for the original job.

.PARAMETER VipcPath
    Relative path to the VIPC file. Matches CI default of
    ".github/actions/apply-vipc/runner_dependencies.vipc".

.PARAMETER MinimumSupportedLVVersion
    LabVIEW version supplied to the action. When omitted the script attempts to
    derive it from the job title (e.g. "(2026, 64)").

.PARAMETER VipLabVIEWVersion
    Value forwarded to the action's vip_lv_version input. When omitted this
    falls back to MinimumSupportedLVVersion.

.PARAMETER SupportedBitness
    Architecture (32 or 64) to forward to the action.

.PARAMETER SkipExecution
    When set, the script resolves the parameters and prints the replay command
    without invoking the action. Useful for dry runs or shell completion.
#>

[CmdletBinding()]
param(
    [Parameter(ParameterSetName = 'Run')]
    [string]$RunId,

    [string]$JobName = 'Apply VIPC Dependencies (2026, 64)',

    [Parameter(ParameterSetName = 'Run')]
    [string]$Repository,

    [string]$LogPath,

    [string]$Workspace = (Get-Location).Path,

    [string]$VipcPath = '.github/actions/apply-vipc/runner_dependencies.vipc',

    [string]$MinimumSupportedLVVersion,

    [string]$VipLabVIEWVersion,

    [int]$SupportedBitness,

    [ValidateSet('g-cli','vipm')]
    [string]$Toolchain = 'g-cli',

    [switch]$SkipExecution
)

$ErrorActionPreference = 'Stop'
$PSModuleAutoLoadingPreference = 'None'
Set-StrictMode -Version Latest
Import-Module Microsoft.PowerShell.Management -ErrorAction Stop
$script:ReplayApplyVipcParameters = $PSBoundParameters

function Invoke-GitHubCli {
    param(
        [Parameter(Mandatory)][string[]]$Arguments,
        [switch]$Raw
    )

    $psi = New-Object System.Diagnostics.ProcessStartInfo
    $psi.FileName = 'gh'
    foreach ($arg in $Arguments) {
        [void]$psi.ArgumentList.Add($arg)
    }
    $psi.RedirectStandardOutput = $true
    $psi.RedirectStandardError = $true
    $psi.UseShellExecute = $false

    $process = [System.Diagnostics.Process]::Start($psi)
    $stdout = $process.StandardOutput.ReadToEnd()
    $stderr = $process.StandardError.ReadToEnd()
    $process.WaitForExit()

    if ($process.ExitCode -ne 0) {
        throw "gh $($Arguments -join ' ') failed: $stderr"
    }

    if ($Raw) { return $stdout }
    return ($stdout | ConvertFrom-Json)
}

function Invoke-ExternalPwsh {
    param([Parameter(Mandatory)][string[]]$Arguments)

    $pwshExe = (Get-Command pwsh).Source
    $psi = New-Object System.Diagnostics.ProcessStartInfo
    $psi.FileName = $pwshExe
    foreach ($arg in $Arguments) {
        [void]$psi.ArgumentList.Add($arg)
    }
    $psi.RedirectStandardOutput = $true
    $psi.RedirectStandardError = $true
    $psi.UseShellExecute = $false

    $proc = [System.Diagnostics.Process]::Start($psi)
    $stdout = $proc.StandardOutput.ReadToEnd()
    $stderr = $proc.StandardError.ReadToEnd()
    $proc.WaitForExit()

    return [pscustomobject]@{
        ExitCode = $proc.ExitCode
        StdOut   = $stdout
        StdErr   = $stderr
    }
}

function Parse-ApplyVipcJobTitle {
    param([Parameter(Mandatory)][string]$Title)

    $pattern = 'Apply VIPC Dependencies\s*\((?<version>[\d\.]+),\s*(?<bitness>\d+)\)'
    $match = [regex]::Match($Title, $pattern)
    if (-not $match.Success) { return $null }

    return [pscustomobject]@{
        Version = $match.Groups['version'].Value
        Bitness = [int]$match.Groups['bitness'].Value
    }
}

function Resolve-ApplyVipcParameters {
    param(
        [string]$RunId,
        [string]$JobName,
        [string]$Repository,
        [string]$LogPath,
        [string]$MinimumSupportedLVVersion,
        [string]$VipLabVIEWVersion,
        [int]$SupportedBitness
    )

    $jobLogPath = $LogPath
    $resolvedVersion = $MinimumSupportedLVVersion
    $resolvedBitness = $SupportedBitness
    $resolvedDisplayTitle = $JobName

    if ($RunId) {
        $args = @('run','view',$RunId,'--json','jobs')
        if ($Repository) {
            $args += @('--repo',$Repository)
        }
        $runInfo = Invoke-GitHubCli -Arguments $args
        if (-not $runInfo.jobs) {
            throw "Run $RunId did not expose any jobs."
        }

        $job = $runInfo.jobs | Where-Object { $_.displayTitle -eq $JobName }
        if (-not $job) {
            $job = $runInfo.jobs | Where-Object { $_.name -eq $JobName }
        }
        if (-not $job) {
            throw "Unable to locate job '$JobName' in run $RunId. Available titles: $($runInfo.jobs.displayTitle -join ', ')"
        }

        $resolvedDisplayTitle = $job.displayTitle
        $parsed = Parse-ApplyVipcJobTitle -Title $resolvedDisplayTitle
        if ($parsed) {
            if (-not $resolvedVersion) { $resolvedVersion = $parsed.Version }
            if (-not $resolvedBitness) { $resolvedBitness = $parsed.Bitness }
        }

        if (-not $jobLogPath) {
            $tmp = [System.IO.Path]::GetTempFileName()
            Remove-Item -LiteralPath $tmp
            $tmp = "$tmp.log"
            $logArgs = @('run','view',$RunId,'--job',$job.jobId,'--log')
            if ($Repository) {
                $logArgs += @('--repo',$Repository)
            }
            $logContent = Invoke-GitHubCli -Arguments $logArgs -Raw
            Set-Content -LiteralPath $tmp -Value $logContent -Encoding UTF8
            $jobLogPath = $tmp
        }
    }

    if (-not $resolvedVersion) {
        throw "MinimumSupportedLVVersion was not provided and could not be inferred from the job title."
    }
    if (-not $resolvedBitness) {
        throw "SupportedBitness was not provided and could not be inferred from the job title."
    }

    if (-not $VipLabVIEWVersion) {
        $VipLabVIEWVersion = $resolvedVersion
    }

    return [pscustomobject]@{
        Version       = [string]$resolvedVersion
        VipVersion    = [string]$VipLabVIEWVersion
        Bitness       = $resolvedBitness
        DisplayTitle  = $resolvedDisplayTitle
        LogPath       = $jobLogPath
    }
}

function Invoke-ApplyVipcReplay {
    param(
        [Parameter(Mandatory)][pscustomobject]$Resolved,
        [Parameter(Mandatory)][string]$Workspace,
        [Parameter(Mandatory)][string]$VipcPath,
        [string]$Toolchain,
        [switch]$SkipExecution
    )

    $workspaceRoot = (Resolve-Path -LiteralPath $Workspace -ErrorAction Stop).ProviderPath
    $applyScript = '.github/actions/apply-vipc/ApplyVIPC.ps1'
    $applyFull = Join-Path $workspaceRoot $applyScript
    if (-not (Test-Path -LiteralPath $applyFull -PathType Leaf)) {
        throw "apply-vipc script not found at '$applyFull'."
    }

    $vipcRelative = $VipcPath
    $vipcFull = Join-Path $workspaceRoot $vipcRelative
    if (-not (Test-Path -LiteralPath $vipcFull -PathType Leaf)) {
        throw "VIPC file not found at '$vipcFull'."
    }

    $displayTitle = $null
    if ($Resolved.PSObject.Properties['DisplayTitle']) {
        $displayTitle = $Resolved.DisplayTitle
    }
    if (-not $displayTitle) {
        $displayTitle = "Apply VIPC Dependencies ($($Resolved.Version), $($Resolved.Bitness))"
    }

    Write-Host "Replaying $displayTitle"
    Write-Host " LabVIEW version: $($Resolved.Version)"
    Write-Host " VIP LV version : $($Resolved.VipVersion)"
    Write-Host " Bitness        : $($Resolved.Bitness)"
    if ($Resolved.LogPath) {
        Write-Host " Job log        : $($Resolved.LogPath)"
    }

    $pwshArgs = @(
        '-NoLogo','-NoProfile','-File',$applyScript,
        '-IconEditorRoot', $workspaceRoot,
        '-VIPCPath', $vipcRelative,
        '-MinimumSupportedLVVersion', $Resolved.Version,
        '-VIP_LVVersion', $Resolved.VipVersion,
        '-SupportedBitness', $Resolved.Bitness
    )
    if ($Toolchain) {
        $pwshArgs += @('-Toolchain', $Toolchain)
    }

    Write-Host ""
    Write-Host "Invocation:"
    Write-Host "pwsh $($pwshArgs -join ' ')"

    if ($SkipExecution) {
        Write-Host ""
        Write-Host "SkipExecution requested; not invoking apply-vipc."
        return
    }

    $result = Invoke-ExternalPwsh -Arguments $pwshArgs
    if ($result.StdOut) { Write-Host $result.StdOut.Trim() }
    if ($result.StdErr) { Write-Host $result.StdErr.Trim() }

    if ($result.ExitCode -ne 0) {
        throw "apply-vipc exited with code $($result.ExitCode)."
    }

    Write-Host "apply-vipc completed successfully."
}

function Invoke-ReplayApplyVipcJob {
    param(
        [hashtable]$InitialParameters
    )

    if (-not $InitialParameters.ContainsKey('JobName') -or [string]::IsNullOrWhiteSpace($InitialParameters['JobName'])) {
        $InitialParameters['JobName'] = 'Apply VIPC Dependencies (2023, 64)'
    }
    if (-not $InitialParameters.ContainsKey('Workspace')) {
        $InitialParameters['Workspace'] = (Get-Location).Path
    }
    if (-not $InitialParameters.ContainsKey('VipcPath')) {
        $InitialParameters['VipcPath'] = '.github/actions/apply-vipc/runner_dependencies.vipc'
    }
    $resolved = Resolve-ApplyVipcParameters @InitialParameters

    $skipExecutionFlag = $false
    if ($InitialParameters.ContainsKey('SkipExecution')) {
        $skipExecutionFlag = [bool]$InitialParameters['SkipExecution']
    }

    $toolchainValue = 'g-cli'
    if ($InitialParameters.ContainsKey('Toolchain') -and $null -ne $InitialParameters['Toolchain']) {
        $toolchainValue = $InitialParameters['Toolchain']
    }

    Invoke-ApplyVipcReplay -Resolved $resolved -Workspace $InitialParameters.Workspace -VipcPath $InitialParameters.VipcPath -Toolchain $toolchainValue -SkipExecution:$skipExecutionFlag
}

if ($MyInvocation.InvocationName -ne '.') {
    Invoke-ReplayApplyVipcJob -InitialParameters $script:ReplayApplyVipcParameters
}

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
