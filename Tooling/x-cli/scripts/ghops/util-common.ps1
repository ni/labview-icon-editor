param()

# Common utilities for PowerShell ghops scripts

Set-StrictMode -Version Latest

function Get-RepoSlug {
    param(
        [string]$Default = 'LabVIEW-Community-CI-CD/x-cli'
    )
    if ($env:GITHUB_REPOSITORY -and $env:GITHUB_REPOSITORY.Trim().Length -gt 0) {
        return $env:GITHUB_REPOSITORY
    }
    return $Default
}

function Ensure-Gh {
    param([switch]$AllowDryRun)
    if ($AllowDryRun) { return }
    if (-not (Get-Command gh -ErrorAction SilentlyContinue)) {
        Write-Error "error: gh CLI is required. Install from https://cli.github.com/" -ErrorAction Stop
    }
}

function Ensure-Git {
    param([switch]$AllowDryRun)
    if ($AllowDryRun) { return }
    if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
        Write-Error "error: git is required." -ErrorAction Stop
    }
}

function Invoke-Logged {
    param(
        [switch]$DryRun,
        [Parameter(ValueFromRemainingArguments)] $Cmd
    )
    Add-LogCommand -Cmd $Cmd
    if ($DryRun) {
        if (-not $Script:__GhopsJsonMode) { Write-Host "[dry-run] $($Cmd -join ' ')" }
        return
    }
    & @Cmd
}

# Simple JSON logging helpers
$Script:__GhopsLog = @{ dryRun = $false; repo = ''; commands = @() }
$Script:__GhopsJsonMode = $false

function Initialize-Log {
    param([bool]$DryRun,[string]$Repo,[switch]$Json)
    $Script:__GhopsLog = @{ dryRun = $DryRun; repo = $Repo; commands = @() }
    $Script:__GhopsJsonMode = [bool]$Json
}

function Add-LogCommand {
    param([string[]]$Cmd)
    if (-not $Script:__GhopsLog) { return }
    $Script:__GhopsLog.commands += ,(@($Cmd) -join ' ')
}

function Flush-Log {
    param([switch]$Json,[hashtable]$Extra)
    if (-not $Json) { return }
    $obj = [ordered]@{}
    $obj.dryRun  = $Script:__GhopsLog.dryRun
    $obj.repo    = $Script:__GhopsLog.repo
    if ($Extra) { foreach ($k in $Extra.Keys) { $obj[$k] = $Extra[$k] } }
    $obj.commands = $Script:__GhopsLog.commands
    $obj | ConvertTo-Json -Depth 6
}

function Write-Notice {
    param([string]$Message)
    if (-not $Script:__GhopsJsonMode) { Write-Host $Message }
}
