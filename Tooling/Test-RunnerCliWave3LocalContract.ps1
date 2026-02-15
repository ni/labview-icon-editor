#Requires -Version 7.0
<#
.SYNOPSIS
    Enforces Wave 3 runner-cli local-orchestration migration contract.

.DESCRIPTION
    Validates that local orchestration and targeted dev-mode action entrypoints
    route through runner-cli wrappers for missing-in-project, ppl build, and
    dev-mode prepare/restore source flows.
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [string]$RepoRoot,

    [Parameter(Mandatory = $false)]
    [string]$StatusOutputPath = 'builds/status/runner-cli-wave3-local-contract.json'
)

$ErrorActionPreference = 'Stop'

function Resolve-RepoRootPath {
    param([string]$PathOverride)

    if (-not [string]::IsNullOrWhiteSpace($PathOverride)) {
        return (Resolve-Path -Path $PathOverride -ErrorAction Stop).Path
    }

    $scriptRoot = if ($PSScriptRoot) { $PSScriptRoot } else { Split-Path -Parent $PSCommandPath }
    try {
        $gitRoot = git -C $scriptRoot rev-parse --show-toplevel 2>$null
        if ($LASTEXITCODE -eq 0 -and -not [string]::IsNullOrWhiteSpace($gitRoot)) {
            return (Resolve-Path -Path $gitRoot.Trim() -ErrorAction Stop).Path
        }
    } catch {
        Write-Verbose ("git rev-parse failed: {0}" -f $_.Exception.Message)
    }

    return (Resolve-Path -Path (Join-Path $scriptRoot '..')).Path
}

function Resolve-PathFromRoot {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Root,
        [Parameter(Mandatory = $true)]
        [string]$Path
    )

    if ([System.IO.Path]::IsPathRooted($Path)) {
        return [System.IO.Path]::GetFullPath($Path)
    }

    return [System.IO.Path]::GetFullPath((Join-Path $Root $Path))
}

function Add-Finding {
    param(
        [string]$FilePath,
        [string]$Code,
        [string]$Message
    )

    $script:findings += [pscustomobject]@{
        file = $FilePath
        code = $Code
        message = $Message
    }
}

function Test-Pattern {
    param(
        [string]$FilePath,
        [string]$Content,
        [string]$Pattern,
        [string]$Code,
        [string]$Message,
        [switch]$MustNotExist
    )

    $matched = [regex]::IsMatch($Content, $Pattern, [System.Text.RegularExpressions.RegexOptions]::IgnoreCase)
    if ($MustNotExist) {
        if ($matched) {
            Add-Finding -FilePath $FilePath -Code $Code -Message $Message
        }
        return
    }

    if (-not $matched) {
        Add-Finding -FilePath $FilePath -Code $Code -Message $Message
    }
}

$script:findings = @()
$resolvedRepoRoot = Resolve-RepoRootPath -PathOverride $RepoRoot
$localScriptPath = Resolve-PathFromRoot -Root $resolvedRepoRoot -Path 'Tooling/Run-CICompositeLocal.ps1'
$setDevModePath = Resolve-PathFromRoot -Root $resolvedRepoRoot -Path '.github/actions/set-development-mode/Set_Development_Mode.ps1'
$revertDevModePath = Resolve-PathFromRoot -Root $resolvedRepoRoot -Path '.github/actions/revert-development-mode/RevertDevelopmentMode.ps1'
$statusPath = Resolve-PathFromRoot -Root $resolvedRepoRoot -Path $StatusOutputPath

foreach ($requiredPath in @($localScriptPath, $setDevModePath, $revertDevModePath)) {
    if (-not (Test-Path -LiteralPath $requiredPath -PathType Leaf)) {
        Add-Finding -FilePath $requiredPath -Code 'missing-file' -Message 'Required file is missing.'
    }
}

if ($script:findings.Count -eq 0) {
    $localContent = Get-Content -LiteralPath $localScriptPath -Raw
    $setDevModeContent = Get-Content -LiteralPath $setDevModePath -Raw
    $revertDevModeContent = Get-Content -LiteralPath $revertDevModePath -Raw

    Test-Pattern -FilePath $localScriptPath -Content $localContent `
        -Pattern 'Invoke-RunnerCliCommand' `
        -Code 'missing-required-pattern' `
        -Message 'Run-CICompositeLocal.ps1 must route orchestration through Invoke-RunnerCliCommand.'
    Test-Pattern -FilePath $localScriptPath -Content $localContent `
        -Pattern "missing-in-project" `
        -Code 'missing-required-pattern' `
        -Message 'Run-CICompositeLocal.ps1 must invoke runner-cli missing-in-project.'
    Test-Pattern -FilePath $localScriptPath -Content $localContent `
        -Pattern "'ppl',\s*'build'" `
        -Code 'missing-required-pattern' `
        -Message 'Run-CICompositeLocal.ps1 must invoke runner-cli ppl build.'

    Test-Pattern -FilePath $setDevModePath -Content $setDevModeContent `
        -Pattern "'dev-mode',\s*'prepare-source'" `
        -Code 'missing-required-pattern' `
        -Message 'Set_Development_Mode.ps1 must invoke runner-cli dev-mode prepare-source.'
    Test-Pattern -FilePath $revertDevModePath -Content $revertDevModeContent `
        -Pattern "'dev-mode',\s*'restore-source'" `
        -Code 'missing-required-pattern' `
        -Message 'RevertDevelopmentMode.ps1 must invoke runner-cli dev-mode restore-source.'

    Test-Pattern -FilePath $localScriptPath -Content $localContent `
        -Pattern 'Invoke-MissingInProjectCLI\.ps1' `
        -Code 'forbidden-legacy-call' `
        -Message 'Run-CICompositeLocal.ps1 must not directly call Invoke-MissingInProjectCLI.ps1 after Wave 3 migration.' `
        -MustNotExist
    Test-Pattern -FilePath $localScriptPath -Content $localContent `
        -Pattern 'BuildProjectSpec\.ps1' `
        -Code 'forbidden-legacy-call' `
        -Message 'Run-CICompositeLocal.ps1 must not directly call BuildProjectSpec.ps1 after Wave 3 migration.' `
        -MustNotExist
    Test-Pattern -FilePath $setDevModePath -Content $setDevModeContent `
        -Pattern '&\s*\$PrepareScript' `
        -Code 'forbidden-legacy-call' `
        -Message 'Set_Development_Mode.ps1 must not directly invoke Prepare_LabVIEW_source.ps1 after Wave 3 migration.' `
        -MustNotExist
    Test-Pattern -FilePath $revertDevModePath -Content $revertDevModeContent `
        -Pattern '&\s*\$RestoreScript' `
        -Code 'forbidden-legacy-call' `
        -Message 'RevertDevelopmentMode.ps1 must not directly invoke RestoreSetupLVSource.ps1 after Wave 3 migration.' `
        -MustNotExist
}

$status = [ordered]@{
    status = if ($script:findings.Count -eq 0) { 'pass' } else { 'fail' }
    generated_utc = (Get-Date).ToUniversalTime().ToString('o')
    repo_root = $resolvedRepoRoot
    paths = @(
        $localScriptPath,
        $setDevModePath,
        $revertDevModePath
    )
    finding_count = $script:findings.Count
    findings = $script:findings
}

$statusDir = Split-Path -Parent $statusPath
if (-not (Test-Path -LiteralPath $statusDir -PathType Container)) {
    New-Item -Path $statusDir -ItemType Directory -Force | Out-Null
}
$status | ConvertTo-Json -Depth 8 | Out-File -LiteralPath $statusPath -Encoding utf8

if ($script:findings.Count -gt 0) {
    $codes = ($script:findings | ForEach-Object { $_.code } | Sort-Object -Unique) -join ','
    throw ("runner-cli-wave3-local-contract failed ({0} findings; codes={1})." -f $script:findings.Count, $codes)
}

Write-Host ("runner-cli-wave3-local-contract passed. status={0}" -f $statusPath)
