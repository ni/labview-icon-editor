#Requires -Version 7.0
<#
.SYNOPSIS
    Enforces Wave 1 runner-cli migration contract in CI workflows.

.DESCRIPTION
    Validates that unit-tests/build-vip/apply-deps lanes invoke runner-cli
    wrappers instead of direct script calls.
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [string]$RepoRoot,

    [Parameter(Mandatory = $false)]
    [string]$StatusOutputPath = 'builds/status/runner-cli-wave1-workflow-contract.json'
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

function Test-ExecutionPolicyAllowlist {
    param(
        [Parameter(Mandatory = $true)]
        [string]$FilePath,
        [Parameter(Mandatory = $true)]
        [string]$Content,
        [Parameter(Mandatory = $true)]
        [string[]]$Allowlist
    )

    $policyMatches = [regex]::Matches($Content, '(?im)-ExecutionPolicy\s+([A-Za-z]+)')
    foreach ($match in $policyMatches) {
        $policyValue = [string]$match.Groups[1].Value
        if ($Allowlist -notcontains $policyValue) {
            Add-Finding `
                -FilePath $FilePath `
                -Code 'forbidden-legacy-call' `
                -Message ("{0} uses non-allowlisted execution policy value '{1}'." -f [System.IO.Path]::GetFileName($FilePath), $policyValue)
        }
    }
}

$script:findings = @()
$resolvedRepoRoot = Resolve-RepoRootPath -PathOverride $RepoRoot
$ciPath = Resolve-PathFromRoot -Root $resolvedRepoRoot -Path '.github/workflows/ci.yml'
$ciCompositePath = Resolve-PathFromRoot -Root $resolvedRepoRoot -Path '.github/workflows/ci-composite.yml'
$statusPath = Resolve-PathFromRoot -Root $resolvedRepoRoot -Path $StatusOutputPath

foreach ($workflowPath in @($ciPath, $ciCompositePath)) {
    if (-not (Test-Path -LiteralPath $workflowPath -PathType Leaf)) {
        Add-Finding -FilePath $workflowPath -Code 'missing-workflow' -Message 'Required workflow file is missing.'
    }
}

if ($script:findings.Count -eq 0) {
    $ciContent = Get-Content -LiteralPath $ciPath -Raw
    $ciCompositeContent = Get-Content -LiteralPath $ciCompositePath -Raw

    Test-Pattern -FilePath $ciPath -Content $ciContent `
        -Pattern 'Tooling/runner-cli/RunnerCli/RunnerCli\.csproj' `
        -Code 'missing-required-pattern' `
        -Message 'ci.yml must resolve runner-cli project path.'
    Test-Pattern -FilePath $ciCompositePath -Content $ciCompositeContent `
        -Pattern 'Tooling/runner-cli/RunnerCli/RunnerCli\.csproj' `
        -Code 'missing-required-pattern' `
        -Message 'ci-composite.yml must resolve runner-cli project path.'

    Test-Pattern -FilePath $ciPath -Content $ciContent `
        -Pattern "'lunit', 'run'" `
        -Code 'missing-required-pattern' `
        -Message 'ci.yml unit-tests lanes must invoke runner-cli lunit run.'
    Test-Pattern -FilePath $ciCompositePath -Content $ciCompositeContent `
        -Pattern "'lunit', 'run'" `
        -Code 'missing-required-pattern' `
        -Message 'ci-composite.yml unit-tests lanes must invoke runner-cli lunit run.'

    Test-Pattern -FilePath $ciPath -Content $ciContent `
        -Pattern "'release', 'package'" `
        -Code 'missing-required-pattern' `
        -Message 'ci.yml build-vip lane must invoke runner-cli release package.'
    Test-Pattern -FilePath $ciCompositePath -Content $ciCompositeContent `
        -Pattern "'release', 'package'" `
        -Code 'missing-required-pattern' `
        -Message 'ci-composite.yml build-vip lane must invoke runner-cli release package.'

    Test-Pattern -FilePath $ciPath -Content $ciContent `
        -Pattern 'SHADOW_PROMOTION_MIN_GREENS:\s*5' `
        -Code 'missing-required-pattern' `
        -Message 'ci.yml must set SHADOW_PROMOTION_MIN_GREENS to 5.'
    Test-Pattern -FilePath $ciCompositePath -Content $ciCompositeContent `
        -Pattern 'SHADOW_PROMOTION_MIN_GREENS:\s*5' `
        -Code 'missing-required-pattern' `
        -Message 'ci-composite.yml must set SHADOW_PROMOTION_MIN_GREENS to 5.'
    Test-Pattern -FilePath $ciPath -Content $ciContent `
        -Pattern 'build-vip-shadow:' `
        -Code 'missing-required-pattern' `
        -Message 'ci.yml must define non-gating build-vip-shadow lane.'
    Test-Pattern -FilePath $ciCompositePath -Content $ciCompositeContent `
        -Pattern 'build-vip-shadow:' `
        -Code 'missing-required-pattern' `
        -Message 'ci-composite.yml must define non-gating build-vip-shadow lane.'
    Test-Pattern -FilePath $ciPath -Content $ciContent `
        -Pattern 'lvie\.shadow-run-performance-metrics' `
        -Code 'missing-required-pattern' `
        -Message 'ci.yml shadow lane must emit performance metrics schema markers.'
    Test-Pattern -FilePath $ciCompositePath -Content $ciCompositeContent `
        -Pattern 'lvie\.shadow-run-performance-metrics' `
        -Code 'missing-required-pattern' `
        -Message 'ci-composite.yml shadow lane must emit performance metrics schema markers.'

    Test-Pattern -FilePath $ciCompositePath -Content $ciCompositeContent `
        -Pattern "'vipc', 'assert'" `
        -Code 'missing-required-pattern' `
        -Message 'ci-composite.yml apply-deps lanes must invoke runner-cli vipc assert.'
    Test-Pattern -FilePath $ciCompositePath -Content $ciCompositeContent `
        -Pattern "'vipc', 'apply'" `
        -Code 'missing-required-pattern' `
        -Message 'ci-composite.yml apply-deps informational lanes must invoke runner-cli vipc apply.'

    Test-Pattern -FilePath $ciPath -Content $ciContent `
        -Pattern "'ppl', 'build'" `
        -Code 'missing-required-pattern' `
        -Message 'ci.yml build-ppl lanes must invoke runner-cli ppl build.'
    Test-Pattern -FilePath $ciCompositePath -Content $ciCompositeContent `
        -Pattern "'ppl', 'build'" `
        -Code 'missing-required-pattern' `
        -Message 'ci-composite.yml build-ppl lanes must invoke runner-cli ppl build.'
    Test-Pattern -FilePath $ciCompositePath -Content $ciCompositeContent `
        -Pattern "parity\s+run" `
        -Code 'missing-required-pattern' `
        -Message 'ci-composite.yml container PPL lanes must invoke runner-cli parity run.'

    Test-Pattern -FilePath $ciPath -Content $ciContent `
        -Pattern 'Invoke-VipBuild\.ps1' `
        -Code 'forbidden-legacy-call' `
        -Message 'ci.yml must not call Invoke-VipBuild.ps1 directly after Wave 1 migration.' `
        -MustNotExist
    Test-Pattern -FilePath $ciCompositePath -Content $ciCompositeContent `
        -Pattern 'Invoke-VipBuild\.ps1' `
        -Code 'forbidden-legacy-call' `
        -Message 'ci-composite.yml must not call Invoke-VipBuild.ps1 directly after Wave 1 migration.' `
        -MustNotExist

    Test-Pattern -FilePath $ciPath -Content $ciContent `
        -Pattern 'RunUnitTests\.ps1' `
        -Code 'forbidden-legacy-call' `
        -Message 'ci.yml must not call RunUnitTests.ps1 directly in unit-test lanes after Wave 1 migration.' `
        -MustNotExist
    Test-Pattern -FilePath $ciCompositePath -Content $ciCompositeContent `
        -Pattern 'RunUnitTests\.ps1' `
        -Code 'forbidden-legacy-call' `
        -Message 'ci-composite.yml must not call RunUnitTests.ps1 directly in unit-test lanes after Wave 1 migration.' `
        -MustNotExist

    Test-Pattern -FilePath $ciCompositePath -Content $ciCompositeContent `
        -Pattern 'ApplyVIPC\.ps1' `
        -Code 'forbidden-legacy-call' `
        -Message 'ci-composite.yml must not call ApplyVIPC.ps1 directly in apply-deps lanes after Wave 1 migration.' `
        -MustNotExist

    Test-Pattern -FilePath $ciPath -Content $ciContent `
        -Pattern 'BuildProjectSpec\.ps1' `
        -Code 'forbidden-legacy-call' `
        -Message 'ci.yml must not call BuildProjectSpec.ps1 directly in build-ppl lanes after Wave 2 migration.' `
        -MustNotExist
    Test-Pattern -FilePath $ciCompositePath -Content $ciCompositeContent `
        -Pattern 'BuildProjectSpec\.ps1' `
        -Code 'forbidden-legacy-call' `
        -Message 'ci-composite.yml must not call BuildProjectSpec.ps1 directly in build-ppl lanes after Wave 2 migration.' `
        -MustNotExist
    Test-Pattern -FilePath $ciCompositePath -Content $ciCompositeContent `
        -Pattern 'runlabview-linux\.sh' `
        -Code 'forbidden-legacy-call' `
        -Message 'ci-composite.yml must not directly invoke runlabview-linux.sh in container PPL lanes after Wave 2 migration.' `
        -MustNotExist
    Test-Pattern -FilePath $ciCompositePath -Content $ciCompositeContent `
        -Pattern 'runlabview-windows\.ps1' `
        -Code 'forbidden-legacy-call' `
        -Message 'ci-composite.yml must not directly invoke runlabview-windows.ps1 in container PPL lanes after Wave 2 migration.' `
        -MustNotExist
    $allowedExecutionPolicies = @('RemoteSigned', 'AllSigned', 'Restricted', 'Undefined', 'Default')
    Test-ExecutionPolicyAllowlist -FilePath $ciPath -Content $ciContent -Allowlist $allowedExecutionPolicies
    Test-ExecutionPolicyAllowlist -FilePath $ciCompositePath -Content $ciCompositeContent -Allowlist $allowedExecutionPolicies
}

$status = [ordered]@{
    status = if ($script:findings.Count -eq 0) { 'pass' } else { 'fail' }
    generated_utc = (Get-Date).ToUniversalTime().ToString('o')
    repo_root = $resolvedRepoRoot
    workflow_paths = @($ciPath, $ciCompositePath)
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
    throw ("runner-cli-wave1-workflow-contract failed ({0} findings; codes={1})." -f $script:findings.Count, $codes)
}

Write-Host ("runner-cli-wave1-workflow-contract passed. status={0}" -f $statusPath)
