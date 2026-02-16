#Requires -Version 7.0
[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [string]$RepoRoot,

    [Parameter(Mandatory = $false)]
    [ValidateSet('warn', 'enforce')]
    [string]$Mode
)

$ErrorActionPreference = 'Stop'

function Resolve-CiDebtRepoRoot {
    param([string]$PathOverride)

    if (-not [string]::IsNullOrWhiteSpace($PathOverride)) {
        return (Resolve-Path -Path $PathOverride -ErrorAction Stop).Path
    }

    $scriptRoot = if ($PSScriptRoot) { $PSScriptRoot } else { Split-Path -Parent $PSCommandPath }
    $git = Get-Command git -ErrorAction SilentlyContinue
    if ($git) {
        try {
            $gitRoot = git -C $scriptRoot rev-parse --show-toplevel 2>$null
            if ($LASTEXITCODE -eq 0 -and -not [string]::IsNullOrWhiteSpace($gitRoot)) {
                return (Resolve-Path -Path $gitRoot.Trim() -ErrorAction Stop).Path
            }
        } catch {
            Write-Verbose ("git rev-parse failed: {0}" -f $_.Exception.Message)
        }
    }

    return (Resolve-Path -Path (Join-Path $scriptRoot '..\..\..') -ErrorAction Stop).Path
}

function Resolve-PolicyMode {
    param([string]$ModeOverride)

    if (-not [string]::IsNullOrWhiteSpace($ModeOverride)) {
        return $ModeOverride
    }

    $envMode = [string]$env:CI_DEBT_POLICY_MODE
    if (-not [string]::IsNullOrWhiteSpace($envMode)) {
        $normalized = $envMode.Trim().ToLowerInvariant()
        if ($normalized -in @('warn', 'enforce')) {
            return $normalized
        }
    }

    $enforceAfter = [string]$env:CI_DEBT_POLICY_ENFORCE_AFTER_UTC
    if ([string]::IsNullOrWhiteSpace($enforceAfter)) {
        $enforceAfter = '2026-02-19T00:00:00Z'
    }

    $enforceAfterUtc = [DateTimeOffset]::Parse($enforceAfter)
    if ([DateTimeOffset]::UtcNow -ge $enforceAfterUtc) {
        return 'enforce'
    }

    return 'warn'
}

function Add-Finding {
    param(
        [System.Collections.Generic.List[object]]$Findings,
        [string]$Rule,
        [string]$File,
        [string]$Message
    )

    $Findings.Add([pscustomobject]@{
        Rule = $Rule
        File = $File
        Message = $Message
    }) | Out-Null
}

function Test-ForbidPattern {
    param(
        [string]$Root,
        [string]$RelativePath,
        [string]$Pattern,
        [string]$Rule,
        [string]$Message,
        [System.Collections.Generic.List[object]]$Findings
    )

    $path = Join-Path $Root $RelativePath
    if (-not (Test-Path -Path $path)) {
        Add-Finding -Findings $Findings -Rule "$Rule.missing-file" -File $RelativePath -Message 'Expected file is missing.'
        return
    }

    $lineNumber = 0
    Get-Content -Path $path | ForEach-Object {
        $lineNumber++
        if ($_ -match $Pattern) {
            Add-Finding -Findings $Findings -Rule $Rule -File ("{0}:{1}" -f $RelativePath, $lineNumber) -Message $Message
        }
    }
}

function Test-RequirePattern {
    param(
        [string]$Root,
        [string]$RelativePath,
        [string]$Pattern,
        [string]$Rule,
        [string]$Message,
        [System.Collections.Generic.List[object]]$Findings
    )

    $path = Join-Path $Root $RelativePath
    if (-not (Test-Path -Path $path)) {
        Add-Finding -Findings $Findings -Rule "$Rule.missing-file" -File $RelativePath -Message 'Expected file is missing.'
        return
    }

    $raw = Get-Content -Path $path -Raw
    if ($raw -notmatch $Pattern) {
        Add-Finding -Findings $Findings -Rule $Rule -File $RelativePath -Message $Message
    }
}

$resolvedRoot = Resolve-CiDebtRepoRoot -PathOverride $RepoRoot
$policyMode = Resolve-PolicyMode -ModeOverride $Mode
$findings = New-Object System.Collections.Generic.List[object]

$criticalScripts = @(
    'Tooling/Invoke-PSScriptAnalyzer.ps1',
    'Tooling/New-CIWorktree.ps1',
    'Tooling/New-CIWorktreeForJob.ps1',
    'Tooling/Invoke-MissingIEFilesFromLVInstall.ps1',
    'Tooling/Invoke-Preflight.ps1',
    'Tooling/Ensure-RunnerCli.ps1'
)

foreach ($scriptPath in $criticalScripts) {
    Test-ForbidPattern `
        -Root $resolvedRoot `
        -RelativePath $scriptPath `
        -Pattern '(?i)\bgk\b|support[\\/]+git\.cmd|Enable-.*GitShim|LVIE_REQUIRE_.*GIT.*CLI' `
        -Rule 'fatal-legacy-git-shim-reference' `
        -Message "Critical scripts must not reference legacy git-shim tooling." `
        -Findings $findings
}

Test-RequirePattern `
    -Root $resolvedRoot `
    -RelativePath '.github/workflows/ci-composite.yml' `
    -Pattern 'Capture VerifyIEPaths diagnostics' `
    -Rule 'verify-iepaths-diagnostics-contract' `
    -Message "ci-composite must emit explicit Verify IE Paths setup diagnostics." `
    -Findings $findings

Test-RequirePattern `
    -Root $resolvedRoot `
    -RelativePath '.github/workflows/ci-composite.yml' `
    -Pattern 'Required job verdict:' `
    -Rule 'pipeline-contract-verdict-contract' `
    -Message "Pipeline Contract must emit required-job verdict output." `
    -Findings $findings

Test-RequirePattern `
    -Root $resolvedRoot `
    -RelativePath '.github/workflows/ci-composite.yml' `
    -Pattern 'Root-cause failures:' `
    -Rule 'pipeline-contract-root-cause-contract' `
    -Message "Pipeline Contract must emit root-cause failure output." `
    -Findings $findings

$summaryLines = @(
    "## CI Debt Policy Gate",
    "",
    "- Mode: $policyMode",
    "- Findings: $($findings.Count)",
    ""
)

if ($findings.Count -gt 0) {
    $summaryLines += "### Findings"
    foreach ($finding in $findings) {
        $summaryLines += "- [$($finding.Rule)] $($finding.File): $($finding.Message)"
    }
} else {
    $summaryLines += "No policy findings detected."
}
$summaryLines += ""

if (-not [string]::IsNullOrWhiteSpace($env:GITHUB_STEP_SUMMARY)) {
    $summaryLines | Out-File -FilePath $env:GITHUB_STEP_SUMMARY -Append -Encoding utf8
}

if ($findings.Count -gt 0) {
    if ($policyMode -eq 'enforce') {
        throw ("CI debt policy gate failed with {0} finding(s)." -f $findings.Count)
    }

    Write-Warning ("CI debt policy gate found {0} finding(s) in warn mode." -f $findings.Count)
} else {
    Write-Host "CI debt policy gate passed."
}
