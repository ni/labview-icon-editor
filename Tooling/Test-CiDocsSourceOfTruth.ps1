#Requires -Version 7.0
<#
.SYNOPSIS
    Validates that core documentation aligns with .github/workflows/ci.yml.

.DESCRIPTION
    Enforces a source-of-truth contract for CI documentation by checking:
    - ci.yml trigger branches
    - workflow_dispatch input surface
    - canonical job names
    - ci_profile token set
    - required synthetic check context name
    - absence of known stale claim tokens in core docs

.PARAMETER RepoRoot
    Repository root path. Defaults to current directory (or git root).

.PARAMETER WriteSummary
    Write pass/fail summary output to GITHUB_STEP_SUMMARY when available.

.PARAMETER SummaryPath
    Optional override path for summary output.
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [string]$RepoRoot = '.',

    [switch]$WriteSummary,

    [Parameter(Mandatory = $false)]
    [string]$SummaryPath
)

$ErrorActionPreference = 'Stop'

function Get-LeadingWhitespaceCount {
    param(
        [Parameter(Mandatory = $true)]
        [AllowEmptyString()]
        [string]$Value
    )

    $trimmedStart = $Value.TrimStart()
    return ($Value.Length - $trimmedStart.Length)
}

function Resolve-RepoRoot {
    param([string]$PathOverride)

    if (-not [string]::IsNullOrWhiteSpace($PathOverride)) {
        return (Resolve-Path -Path $PathOverride -ErrorAction Stop).Path
    }

    if (Get-Command git -ErrorAction SilentlyContinue) {
        try {
            $gitRoot = git rev-parse --show-toplevel 2>$null
            if ($LASTEXITCODE -eq 0 -and -not [string]::IsNullOrWhiteSpace($gitRoot)) {
                return (Resolve-Path -Path $gitRoot.Trim() -ErrorAction Stop).Path
            }
        } catch {
            Write-Verbose ("git rev-parse failed: {0}" -f $_.Exception.Message)
        }
    }

    return (Resolve-Path -Path '.').Path
}

function Resolve-SummaryPath {
    param(
        [string]$OverridePath,
        [string]$ResolvedRepoRoot
    )

    if (-not [string]::IsNullOrWhiteSpace($OverridePath)) {
        return $OverridePath
    }

    if (-not [string]::IsNullOrWhiteSpace($env:GITHUB_STEP_SUMMARY)) {
        return $env:GITHUB_STEP_SUMMARY
    }

    return (Join-Path $ResolvedRepoRoot 'TestResults\ci-docs-source-of-truth-summary.md')
}

function Get-WorkflowSurface {
    param([string[]]$Lines)

    $pushBranches = New-Object System.Collections.Generic.List[string]
    $pullRequestBranches = New-Object System.Collections.Generic.List[string]
    $workflowDispatchInputs = New-Object System.Collections.Generic.List[string]
    $jobs = New-Object System.Collections.Generic.List[string]

    $inOn = $false
    $inJobs = $false
    $currentEvent = $null
    $inBranches = $false
    $inWorkflowDispatch = $false
    $inDispatchInputs = $false

    for ($index = 0; $index -lt $Lines.Count; $index++) {
        $line = $Lines[$index]
        $trimmed = $line.Trim()
        $indent = Get-LeadingWhitespaceCount -Value $line

        if ($trimmed -match '^on:\s*$') {
            $inOn = $true
            $inJobs = $false
            $currentEvent = $null
            $inBranches = $false
            $inWorkflowDispatch = $false
            $inDispatchInputs = $false
            continue
        }

        if ($trimmed -match '^jobs:\s*$') {
            $inJobs = $true
            $inOn = $false
            $currentEvent = $null
            $inBranches = $false
            $inWorkflowDispatch = $false
            $inDispatchInputs = $false
            continue
        }

        if ($inOn -and $indent -le 0 -and -not [string]::IsNullOrWhiteSpace($trimmed) -and $trimmed -notmatch '^on:\s*$') {
            $inOn = $false
            $currentEvent = $null
            $inBranches = $false
            $inWorkflowDispatch = $false
            $inDispatchInputs = $false
        }

        if ($inOn) {
            if ($indent -eq 2 -and $trimmed -match '^(push|pull_request|workflow_dispatch):\s*$') {
                $currentEvent = $Matches[1]
                $inBranches = $false
                $inWorkflowDispatch = ($currentEvent -eq 'workflow_dispatch')
                $inDispatchInputs = $false
                continue
            }

            if ($inWorkflowDispatch -and $indent -eq 4 -and $trimmed -match '^inputs:\s*$') {
                $inDispatchInputs = $true
                continue
            }

            if ($inDispatchInputs) {
                if ($indent -eq 6 -and $trimmed -match '^([A-Za-z0-9_-]+):\s*$') {
                    $workflowDispatchInputs.Add($Matches[1]) | Out-Null
                    continue
                }

                if ($indent -le 4 -and -not [string]::IsNullOrWhiteSpace($trimmed)) {
                    $inDispatchInputs = $false
                }
            }

            if ($indent -eq 4 -and $trimmed -match '^branches:\s*$' -and ($currentEvent -eq 'push' -or $currentEvent -eq 'pull_request')) {
                $inBranches = $true
                continue
            }

            if ($inBranches) {
                if ($indent -eq 6 -and $trimmed -match '^-+\s*(.+?)\s*$') {
                    $value = $Matches[1].Trim()
                    if ($currentEvent -eq 'push') {
                        $pushBranches.Add($value) | Out-Null
                    } elseif ($currentEvent -eq 'pull_request') {
                        $pullRequestBranches.Add($value) | Out-Null
                    }
                    continue
                }

                if ($indent -le 4 -and -not [string]::IsNullOrWhiteSpace($trimmed)) {
                    $inBranches = $false
                }
            }
        }

        if ($inJobs) {
            if ($indent -eq 2 -and $trimmed -match '^([A-Za-z0-9_-]+):\s*$') {
                $jobs.Add($Matches[1]) | Out-Null
                continue
            }
        }
    }

    return [pscustomobject]@{
        PushBranches           = @($pushBranches)
        PullRequestBranches    = @($pullRequestBranches)
        WorkflowDispatchInputs = @($workflowDispatchInputs)
        Jobs                   = @($jobs)
    }
}

function Add-Violation {
    param(
        [System.Collections.Generic.List[object]]$List,
        [string]$Type,
        [string]$Path,
        [string]$Message
    )

    $List.Add([pscustomobject]@{
            Type    = $Type
            Path    = $Path
            Message = $Message
        }) | Out-Null
}

function Assert-ContainsAll {
    param(
        [string[]]$Actual,
        [string[]]$Expected
    )

    $missing = @()
    foreach ($item in $Expected) {
        if ($Actual -notcontains $item) {
            $missing += $item
        }
    }
    return $missing
}

$repoRootPath = Resolve-RepoRoot -PathOverride $RepoRoot
$violations = New-Object 'System.Collections.Generic.List[object]'

$ciWorkflowRelative = '.github/workflows/ci.yml'
$ciWorkflowPath = Join-Path $repoRootPath ($ciWorkflowRelative -replace '/', [System.IO.Path]::DirectorySeparatorChar)
if (-not (Test-Path -LiteralPath $ciWorkflowPath -PathType Leaf)) {
    Add-Violation -List $violations -Type 'missing-ci-workflow' -Path $ciWorkflowRelative -Message 'ci.yml was not found.'
} else {
    $ciLines = Get-Content -LiteralPath $ciWorkflowPath -ErrorAction Stop
    $ciRaw = Get-Content -LiteralPath $ciWorkflowPath -Raw -ErrorAction Stop
    $surface = Get-WorkflowSurface -Lines $ciLines

    $pushExpected = @('main', 'develop', 'release/*')
    $prExpected = @('main', 'develop', 'release/*', 'feature/*', 'hotfix/*')
    $dispatchInputsExpected = @(
        'dispatch_tag',
        'allow_baseline_update',
        'expected_sha',
        'strict_sha',
        'publish_prerelease',
        'force_gcli_lunit',
        'vipc_apply_info',
        'source_test_mode',
        'source_test_labview_year_override'
    )
    $jobsExpected = @(
        'run-metadata',
        'prerelease-context',
        'runner-cli-build',
        'runner-cli-build-win',
        'version-gate',
        'core-conformance-hosted-linux',
        'core-conformance-hosted-windows',
        'conformance-full',
        'powershell-lint',
        'vip-prerelease-requirements-lint',
        'docs-lint',
        'pylavi-validate',
        'changes',
        'apply-deps-64',
        'apply-deps-32',
        'vi-analyzer',
        'version',
        'unit-tests',
        'build-ppl-x86',
        'build-ppl-x64',
        'build-vip',
        'build-ppl-linux-container',
        'build-ppl-windows-container',
        'codex-skill-layer-asset',
        'publish-gate',
        'publish-prerelease',
        'pipeline-contract',
        'required-context'
    )

    $missingPush = Assert-ContainsAll -Actual $surface.PushBranches -Expected $pushExpected
    if ($missingPush.Count -gt 0) {
        Add-Violation -List $violations -Type 'trigger-push-branches' -Path $ciWorkflowRelative -Message ("push branches missing: {0}" -f ($missingPush -join ', '))
    }

    $missingPr = Assert-ContainsAll -Actual $surface.PullRequestBranches -Expected $prExpected
    if ($missingPr.Count -gt 0) {
        Add-Violation -List $violations -Type 'trigger-pr-branches' -Path $ciWorkflowRelative -Message ("pull_request branches missing: {0}" -f ($missingPr -join ', '))
    }

    $missingDispatchInputs = Assert-ContainsAll -Actual $surface.WorkflowDispatchInputs -Expected $dispatchInputsExpected
    if ($missingDispatchInputs.Count -gt 0) {
        Add-Violation -List $violations -Type 'dispatch-inputs' -Path $ciWorkflowRelative -Message ("workflow_dispatch inputs missing: {0}" -f ($missingDispatchInputs -join ', '))
    }

    $missingJobs = Assert-ContainsAll -Actual $surface.Jobs -Expected $jobsExpected
    if ($missingJobs.Count -gt 0) {
        Add-Violation -List $violations -Type 'job-surface' -Path $ciWorkflowRelative -Message ("jobs missing: {0}" -f ($missingJobs -join ', '))
    }

    foreach ($profileName in @('release-priority', 'pr-fast', 'full')) {
        if ($ciRaw -notmatch [regex]::Escape($profileName)) {
            Add-Violation -List $violations -Type 'ci-profile-surface' -Path $ciWorkflowRelative -Message ("ci_profile token '{0}' not found." -f $profileName)
        }
    }

    if ($ciRaw -notmatch 'CI Required / Lint\+Contract') {
        Add-Violation -List $violations -Type 'required-context-name' -Path $ciWorkflowRelative -Message "Required synthetic check name 'CI Required / Lint+Contract' not found."
    }
}

$coreDocs = @(
    'README.md',
    'CONTRIBUTING.md',
    'docs/README.md',
    'docs/ci-workflows.md',
    'docs/ci/troubleshooting-faq.md',
    'docs/manual-instructions.md',
    'docs/automated-setup.md',
    'docs/powershell-dependency-scripts.md',
    'docs/ci/actions/build-vi-package.md',
    'docs/ci/actions/runner-setup-guide.md',
    'Tooling/README.md',
    'AGENTS.md'
)

$staleRules = @(
    [pscustomobject]@{
        Id      = 'stale-issue-status-gate'
        Pattern = '(?i)\bissue-status\b'
        Message = "Stale issue-status gate claim detected. ci.yml is source of truth and has no issue-status gate."
    },
    [pscustomobject]@{
        Id      = 'stale-dev-mode-gate-job'
        Pattern = '(?i)\bdev-mode-gate\b'
        Message = "Stale dev-mode-gate job reference detected. ci.yml has no dev-mode-gate job."
    },
    [pscustomobject]@{
        Id      = 'stale-pr-only-companion-claim'
        Pattern = '(?i)PR-only non-publishing companion workflow'
        Message = "Stale PR-only/non-publishing claim detected for ci.yml."
    },
    [pscustomobject]@{
        Id      = 'stale-legacy-release-trigger-claim'
        Pattern = '(?i)release-alpha/\*|release-beta/\*|release-rc/\*'
        Message = "Legacy alpha/beta/rc trigger claim detected in core docs. ci.yml trigger contract uses main|develop|release/* plus PR target filters."
    },
    [pscustomobject]@{
        Id      = 'stale-fixed-26.1-baseline-claim'
        Pattern = '(?<![0-9])26\.1(?![0-9])'
        Message = "Fixed 26.1 baseline claim detected. Core docs must describe .lvversion-driven version sourcing."
    }
)

foreach ($relativePath in $coreDocs) {
    $fullPath = Join-Path $repoRootPath ($relativePath -replace '/', [System.IO.Path]::DirectorySeparatorChar)
    if (-not (Test-Path -LiteralPath $fullPath -PathType Leaf)) {
        Add-Violation -List $violations -Type 'missing-core-doc' -Path $relativePath -Message 'Required core doc file is missing.'
        continue
    }

    $content = Get-Content -LiteralPath $fullPath -Raw -ErrorAction Stop
    foreach ($rule in $staleRules) {
        if ($content -match $rule.Pattern) {
            Add-Violation -List $violations -Type $rule.Id -Path $relativePath -Message $rule.Message
        }
    }
}

if ($WriteSummary) {
    $summaryPath = Resolve-SummaryPath -OverridePath $SummaryPath -ResolvedRepoRoot $repoRootPath
    $summaryLines = @(
        '## CI Docs Source-of-Truth Contract'
        ("- Violations: {0}" -f $violations.Count)
    )
    if ($violations.Count -eq 0) {
        $summaryLines += '- Status: pass'
    } else {
        $summaryLines += '- Status: fail'
        $summaryLines += ''
        $summaryLines += '### Violations'
        $summaryLines += ($violations | ForEach-Object { "- [{0}] `{1}`: {2}" -f $_.Type, $_.Path, $_.Message })
    }

    $summaryDir = Split-Path -Path $summaryPath -Parent
    if (-not [string]::IsNullOrWhiteSpace($summaryDir) -and -not (Test-Path -Path $summaryDir -PathType Container)) {
        New-Item -Path $summaryDir -ItemType Directory -Force | Out-Null
    }

    $summaryLines | Out-File -FilePath $summaryPath -Encoding utf8 -Append
}

if ($violations.Count -gt 0) {
    $formatted = $violations | ForEach-Object { "[{0}] {1}: {2}" -f $_.Type, $_.Path, $_.Message }
    throw ("CI docs source-of-truth contract failed:{0}{1}" -f [Environment]::NewLine, ($formatted -join [Environment]::NewLine))
}

Write-Host 'CI docs source-of-truth contract passed.'
