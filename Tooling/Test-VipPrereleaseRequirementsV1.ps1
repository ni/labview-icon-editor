#Requires -Version 7.0
<#
.SYNOPSIS
    Lints VIP prerelease requirements v1 documents and workflow interfaces.

.DESCRIPTION
    Validates requirement IDs, ordering, atomicity heuristics, acceptance/trace
    coverage, and key workflow/action public interface contracts.
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [string]$RepoRoot,

    [Parameter(Mandatory = $false)]
    [string]$RequirementsPath = 'docs/vip-prerelease-requirements.md',

    [Parameter(Mandatory = $false)]
    [string]$AcceptancePath = 'docs/vip-prerelease-requirements-v1-acceptance.md',

    [Parameter(Mandatory = $false)]
    [string]$TracePath = 'docs/vip-prerelease-requirements-v0-to-v1-trace.md',

    [Parameter(Mandatory = $false)]
    [string]$WorkflowPath = '.github/workflows/ci-composite.yml',

    [Parameter(Mandatory = $false)]
    [string]$ComputeVersionActionPath = '.github/actions/compute-version/action.yml',

    [Parameter(Mandatory = $false)]
    [string]$StatusOutputPath = 'builds/status/vip-prerelease-requirements-lint.json',

    [switch]$WriteSummary
)

$ErrorActionPreference = 'Stop'

function Resolve-RepoRoot {
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
        [int]$LineNumber,
        [string]$Message
    )

    $script:findings += [pscustomobject]@{
        file = $FilePath
        line = $LineNumber
        message = $Message
    }

    if ($env:GITHUB_ACTIONS -eq 'true') {
        Write-Host ("::error file={0},line={1}::{2}" -f $FilePath, $LineNumber, $Message)
    } else {
        Write-Host ("ERROR: {0}:{1} {2}" -f $FilePath, $LineNumber, $Message)
    }
}

function Get-RequirementEntry {
    param([string]$FilePath)

    $entries = New-Object System.Collections.Generic.List[object]
    $lines = Get-Content -Path $FilePath
    for ($i = 0; $i -lt $lines.Count; $i++) {
        $line = $lines[$i]
        if ($line -match '^(VR-[A-Z]+-([0-9]{3})):\s*(.+)$') {
            $id = $matches[1]
            $ordinal = [int]$matches[2]
            $text = $matches[3].Trim()
            if ($id -match '^VR-([A-Z]+)-') {
                $family = $matches[1]
            } else {
                $family = ''
            }
            $entries.Add([pscustomobject]@{
                id = $id
                family = $family
                ordinal = $ordinal
                line = $i + 1
                text = $text
            })
        }
    }
    return ,$entries.ToArray()
}

function Test-AtomicityRule {
    param([string]$RequirementText)

    $reasons = New-Object System.Collections.Generic.List[string]
    $modalMatches = [regex]::Matches(
        $RequirementText,
        '\b(?:shall not|shall|should|may)\b',
        [System.Text.RegularExpressions.RegexOptions]::IgnoreCase
    )
    $shallMatches = [regex]::Matches(
        $RequirementText,
        '\bshall\b',
        [System.Text.RegularExpressions.RegexOptions]::IgnoreCase
    )

    # The acceptance gate targets independently testable "shall" obligations.
    if ($shallMatches.Count -gt 0) {
        if ($shallMatches.Count -ne 1) {
            $reasons.Add("contains $($shallMatches.Count) occurrences of 'shall'; expected exactly one.")
        }
        if ($modalMatches.Count -gt 1) {
            $reasons.Add("contains multiple modal keywords ($($modalMatches.Count)) around a shall obligation.")
        }
        if ([regex]::IsMatch($RequirementText, ';[^.]*\b(?:shall|should|may)\b', [System.Text.RegularExpressions.RegexOptions]::IgnoreCase)) {
            $reasons.Add("contains a semicolon followed by another modal clause.")
        }
        if ([regex]::IsMatch($RequirementText, ',\s*(?:and|or)\s+[^.;]*\b(?:shall|should|may)\b', [System.Text.RegularExpressions.RegexOptions]::IgnoreCase)) {
            $reasons.Add("contains a conjunction introducing another modal clause.")
        }
    }

    return ,$reasons.ToArray()
}

function Get-VrIdsFromFile {
    param([string]$FilePath)

    $content = Get-Content -Raw -Path $FilePath
    return [regex]::Matches($content, 'VR-[A-Z]+-[0-9]{3}') |
        ForEach-Object { $_.Value } |
        Sort-Object -Unique
}

function Find-FirstIdLine {
    param(
        [string]$FilePath,
        [string]$Id
    )

    $lines = Get-Content -Path $FilePath
    for ($i = 0; $i -lt $lines.Count; $i++) {
        if ($lines[$i] -match [regex]::Escape($Id)) {
            return $i + 1
        }
    }
    return 1
}

function Test-PatternPresence {
    param(
        [string]$FilePath,
        [string]$Content,
        [string]$Pattern,
        [string]$Message
    )

    if (-not [regex]::IsMatch($Content, $Pattern, [System.Text.RegularExpressions.RegexOptions]::IgnoreCase)) {
        Add-Finding -FilePath $FilePath -LineNumber 1 -Message $Message
    }
}

$script:findings = @()
$resolvedRepoRoot = Resolve-RepoRoot -PathOverride $RepoRoot

$requirementsFile = Resolve-PathFromRoot -Root $resolvedRepoRoot -Path $RequirementsPath
$acceptanceFile = Resolve-PathFromRoot -Root $resolvedRepoRoot -Path $AcceptancePath
$traceFile = Resolve-PathFromRoot -Root $resolvedRepoRoot -Path $TracePath
$workflowFile = Resolve-PathFromRoot -Root $resolvedRepoRoot -Path $WorkflowPath
$computeVersionActionFile = Resolve-PathFromRoot -Root $resolvedRepoRoot -Path $ComputeVersionActionPath
$statusOutputFile = Resolve-PathFromRoot -Root $resolvedRepoRoot -Path $StatusOutputPath

$requirements = @()
$acceptanceIds = @()
$traceIds = @()

try {
    foreach ($path in @($requirementsFile, $acceptanceFile, $traceFile, $workflowFile, $computeVersionActionFile)) {
        if (-not (Test-Path -Path $path)) {
            Add-Finding -FilePath $path -LineNumber 1 -Message 'Required file is missing.'
        }
    }

    if ($script:findings.Count -eq 0) {
        $requirements = Get-RequirementEntry -FilePath $requirementsFile
        if (-not $requirements -or $requirements.Count -eq 0) {
            Add-Finding -FilePath $requirementsFile -LineNumber 1 -Message 'No VR requirement IDs were found.'
        }

        $duplicateGroups = $requirements | Group-Object id | Where-Object { $_.Count -gt 1 }
        foreach ($group in $duplicateGroups) {
            $line = ($group.Group | Select-Object -First 1).line
            Add-Finding -FilePath $requirementsFile -LineNumber $line -Message ("Duplicate requirement ID detected: {0}" -f $group.Name)
        }

        $families = $requirements | Group-Object family
        foreach ($familyGroup in $families) {
            $ordered = $familyGroup.Group | Sort-Object line
            $previous = -1
            foreach ($entry in $ordered) {
                if ($entry.ordinal -le $previous) {
                    Add-Finding -FilePath $requirementsFile -LineNumber $entry.line -Message ("Non-monotonic requirement ordering in family VR-{0}: found {1:000} after {2:000}." -f $familyGroup.Name, $entry.ordinal, $previous)
                }
                $previous = $entry.ordinal
            }
        }

        foreach ($entry in $requirements) {
            $reasons = Test-AtomicityRule -RequirementText $entry.text
            foreach ($reason in $reasons) {
                Add-Finding -FilePath $requirementsFile -LineNumber $entry.line -Message ("{0} {1}" -f $entry.id, $reason)
            }
        }

        $acceptanceIds = Get-VrIdsFromFile -FilePath $acceptanceFile
        $traceIds = Get-VrIdsFromFile -FilePath $traceFile
        $requirementIds = $requirements | ForEach-Object { $_.id } | Sort-Object -Unique

        $requirementSet = New-Object 'System.Collections.Generic.HashSet[string]' ([System.StringComparer]::OrdinalIgnoreCase)
        foreach ($id in $requirementIds) { $null = $requirementSet.Add($id) }
        $acceptanceSet = New-Object 'System.Collections.Generic.HashSet[string]' ([System.StringComparer]::OrdinalIgnoreCase)
        foreach ($id in $acceptanceIds) { $null = $acceptanceSet.Add($id) }
        $traceSet = New-Object 'System.Collections.Generic.HashSet[string]' ([System.StringComparer]::OrdinalIgnoreCase)
        foreach ($id in $traceIds) { $null = $traceSet.Add($id) }

        foreach ($id in $requirementIds) {
            $entry = $requirements | Where-Object { $_.id -eq $id } | Select-Object -First 1
            if (-not $acceptanceSet.Contains($id)) {
                Add-Finding -FilePath $requirementsFile -LineNumber $entry.line -Message ("Requirement ID missing from acceptance matrix: {0}" -f $id)
            }
            if (-not $traceSet.Contains($id)) {
                Add-Finding -FilePath $requirementsFile -LineNumber $entry.line -Message ("Requirement ID missing from trace matrix: {0}" -f $id)
            }
        }

        foreach ($id in $acceptanceIds) {
            if (-not $requirementSet.Contains($id)) {
                $line = Find-FirstIdLine -FilePath $acceptanceFile -Id $id
                Add-Finding -FilePath $acceptanceFile -LineNumber $line -Message ("Acceptance matrix references unknown requirement ID: {0}" -f $id)
            }
        }

        foreach ($id in $traceIds) {
            if (-not $requirementSet.Contains($id)) {
                $line = Find-FirstIdLine -FilePath $traceFile -Id $id
                Add-Finding -FilePath $traceFile -LineNumber $line -Message ("Trace matrix references unknown requirement ID: {0}" -f $id)
            }
        }

        $workflowContent = Get-Content -Raw -Path $workflowFile
        $computeActionContent = Get-Content -Raw -Path $computeVersionActionFile

        Test-PatternPresence -FilePath $workflowFile -Content $workflowContent -Pattern 'workflow_dispatch:[\s\S]*publish_prerelease:' -Message "Workflow dispatch input 'publish_prerelease' is missing."
        Test-PatternPresence -FilePath $workflowFile -Content $workflowContent -Pattern 'workflow_dispatch:[\s\S]*strict_sha:' -Message "Workflow dispatch input 'strict_sha' is missing."
        Test-PatternPresence -FilePath $workflowFile -Content $workflowContent -Pattern 'strict_sha=true is required when publish_prerelease=true\.' -Message "run-metadata strict_sha publish-intent enforcement is missing."
        Test-PatternPresence -FilePath $workflowFile -Content $workflowContent -Pattern 'github\.rest\.repos\.getCommit' -Message "prerelease-context merge-commit eligibility check hook is missing."
        Test-PatternPresence -FilePath $workflowFile -Content $workflowContent -Pattern 'develop-push-not-merge-commit' -Message "prerelease-context merge-commit publish reason token is missing."
        Test-PatternPresence -FilePath $workflowFile -Content $workflowContent -Pattern 'develop-push-merged-pr-sha-mismatch' -Message "prerelease-context merged PR SHA mismatch reason token is missing."
        Test-PatternPresence -FilePath $workflowFile -Content $workflowContent -Pattern 'Manual prerelease publish requires expected_sha to reference a merged develop merge commit\.' -Message "manual prerelease merge-commit fail-fast enforcement is missing."
        Test-PatternPresence -FilePath $workflowFile -Content $workflowContent -Pattern 'Manual prerelease publish requires expected_sha to match the merged develop PR merge SHA\.' -Message "manual prerelease merged PR SHA match fail-fast enforcement is missing."
        Test-PatternPresence -FilePath $workflowFile -Content $workflowContent -Pattern 'Manual prerelease publish requires expected_sha to be associated with a merged PR targeting develop\.' -Message "manual prerelease merged develop PR association fail-fast enforcement is missing."
        Test-PatternPresence -FilePath $workflowFile -Content $workflowContent -Pattern 'prerelease-context:[\s\S]*outputs:[\s\S]*bump_conflict:' -Message "prerelease-context output 'bump_conflict' is missing."
        Test-PatternPresence -FilePath $workflowFile -Content $workflowContent -Pattern 'prerelease-context:[\s\S]*outputs:[\s\S]*bump_conflict_labels:' -Message "prerelease-context output 'bump_conflict_labels' is missing."
        Test-PatternPresence -FilePath $workflowFile -Content $workflowContent -Pattern 'bump_type_override:\s*\$\{\{\s*needs\.prerelease-context\.outputs\.bump_type_override\s*\}\}' -Message "version job is not wiring prerelease-context bump_type_override into compute-version."
        Test-PatternPresence -FilePath $workflowFile -Content $workflowContent -Pattern 'publish-prerelease:' -Message "publish-prerelease job is missing."
        Test-PatternPresence -FilePath $workflowFile -Content $workflowContent -Pattern 'release_tag:\s*\$\{\{\s*steps\.publish\.outputs\.release_tag\s*\}\}' -Message "publish-prerelease output 'release_tag' is missing."
        Test-PatternPresence -FilePath $workflowFile -Content $workflowContent -Pattern 'release_url:\s*\$\{\{\s*steps\.publish\.outputs\.release_url\s*\}\}' -Message "publish-prerelease output 'release_url' is missing."
        Test-PatternPresence -FilePath $workflowFile -Content $workflowContent -Pattern 'release_id:\s*\$\{\{\s*steps\.publish\.outputs\.release_id\s*\}\}' -Message "publish-prerelease output 'release_id' is missing."
        Test-PatternPresence -FilePath $workflowFile -Content $workflowContent -Pattern 'publish_status:\s*\$\{\{\s*steps\.publish\.outputs\.publish_status\s*\}\}' -Message "publish-prerelease output 'publish_status' is missing."
        Test-PatternPresence -FilePath $workflowFile -Content $workflowContent -Pattern 'builds/status/prerelease-publish\.json' -Message "Prerelease publish status path is missing."
        Test-PatternPresence -FilePath $workflowFile -Content $workflowContent -Pattern 'name:\s*prerelease-publish-status' -Message "Prerelease publish status artifact contract is missing."
        Test-PatternPresence -FilePath $workflowFile -Content $workflowContent -Pattern 'codex-skill-layer-asset:' -Message "Codex skill-layer asset job is missing."
        Test-PatternPresence -FilePath $workflowFile -Content $workflowContent -Pattern "requiredAssets = @\('vip', 'release_notes', 'labviewcli-logs', 'vip-build-status', 'linux-packed-library', 'windows-packed-library', 'codex-skill-layer'\)" -Message "Full/pr-fast required prerelease assets are missing codex skill-layer."
        Test-PatternPresence -FilePath $workflowFile -Content $workflowContent -Pattern "requiredAssets = @\('linux-packed-library', 'windows-packed-library', 'codex-skill-layer'\)" -Message "Release-priority required prerelease assets are missing codex skill-layer."

        Test-PatternPresence -FilePath $computeVersionActionFile -Content $computeActionContent -Pattern 'bump_type_override:' -Message "compute-version input 'bump_type_override' is missing."
        Test-PatternPresence -FilePath $computeVersionActionFile -Content $computeActionContent -Pattern 'allowedWithNone' -Message "compute-version allowed override set is missing."
        Test-PatternPresence -FilePath $computeVersionActionFile -Content $computeActionContent -Pattern '\bnone\b' -Message "compute-version override value 'none' is missing."
        Test-PatternPresence -FilePath $computeVersionActionFile -Content $computeActionContent -Pattern 'context\.eventName' -Message "compute-version PR event check should use context.eventName."
    }
} catch {
    Add-Finding -FilePath $requirementsFile -LineNumber 1 -Message ("Unhandled linter error: {0}" -f $_.Exception.Message)
}

$statusDir = Split-Path -Parent $statusOutputFile
if (-not (Test-Path -Path $statusDir)) {
    New-Item -Path $statusDir -ItemType Directory -Force | Out-Null
}

$status = [ordered]@{
    status = if ($script:findings.Count -eq 0) { 'pass' } else { 'fail' }
    generated_utc = (Get-Date).ToUniversalTime().ToString('o')
    repo_root = $resolvedRepoRoot
    requirements_path = $requirementsFile
    acceptance_path = $acceptanceFile
    trace_path = $traceFile
    workflow_path = $workflowFile
    compute_version_action_path = $computeVersionActionFile
    requirement_count = @($requirements).Count
    acceptance_id_count = @($acceptanceIds).Count
    trace_id_count = @($traceIds).Count
    finding_count = $script:findings.Count
    findings = $script:findings
}
$status | ConvertTo-Json -Depth 8 | Out-File -FilePath $statusOutputFile -Encoding utf8

if ($WriteSummary -and -not [string]::IsNullOrWhiteSpace($env:GITHUB_STEP_SUMMARY)) {
    $lines = @()
    $lines += '### VIP Pre-Release Requirements v1 Lint'
    $lines += ''
    $lines += "- Result: **$($status.status)**"
    $lines += "- Requirements: ``$requirementsFile``"
    $lines += "- Acceptance: ``$acceptanceFile``"
    $lines += "- Trace: ``$traceFile``"
    $lines += "- Findings: $($status.finding_count)"
    if ($status.finding_count -gt 0) {
        $lines += ''
        $lines += 'Top findings:'
        foreach ($finding in ($script:findings | Select-Object -First 20)) {
            $lines += "- ``$($finding.file):$($finding.line)`` $($finding.message)"
        }
    }
    Add-Content -Path $env:GITHUB_STEP_SUMMARY -Value ($lines -join [Environment]::NewLine)
}

if ($script:findings.Count -gt 0) {
    throw ("VIP prerelease requirements v1 lint failed with {0} finding(s)." -f $script:findings.Count)
}

Write-Host ("VIP prerelease requirements v1 lint passed ({0} requirements checked)." -f @($requirements).Count)
