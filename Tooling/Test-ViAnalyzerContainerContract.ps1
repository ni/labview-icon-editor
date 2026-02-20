#Requires -Version 7.0
[CmdletBinding()]
param(
    [string]$RepoRoot = '.',
    [switch]$WriteSummary
)

$ErrorActionPreference = 'Stop'

$repoRootPath = (Resolve-Path -Path $RepoRoot -ErrorAction Stop).Path
$ciWorkflowPath = Join-Path $repoRootPath '.github\workflows\ci.yml'
$parityWorkflowPath = Join-Path $repoRootPath '.github\workflows\labview-parity.yml'
$lvcontainerPath = Join-Path $repoRootPath '.lvcontainer'

$violations = New-Object System.Collections.Generic.List[object]

function Add-ContractViolation {
    param(
        [string]$Type,
        [string]$Message
    )

    $violations.Add([pscustomobject]@{
            Type    = $Type
            Message = $Message
        }) | Out-Null
}

if (-not (Test-Path -LiteralPath $ciWorkflowPath -PathType Leaf)) {
    Add-ContractViolation -Type 'missing-workflow' -Message "Required workflow file not found: .github/workflows/ci.yml"
}

if (-not (Test-Path -LiteralPath $parityWorkflowPath -PathType Leaf)) {
    Add-ContractViolation -Type 'missing-parity-workflow' -Message "Required workflow file not found: .github/workflows/labview-parity.yml"
}

if (-not (Test-Path -LiteralPath $lvcontainerPath -PathType Leaf)) {
    Add-ContractViolation -Type 'missing-lvcontainer' -Message 'Required container contract file not found: .lvcontainer'
}

$ciContent = if (Test-Path -LiteralPath $ciWorkflowPath -PathType Leaf) {
    Get-Content -LiteralPath $ciWorkflowPath -Raw
} else {
    ''
}

$parityContent = if (Test-Path -LiteralPath $parityWorkflowPath -PathType Leaf) {
    Get-Content -LiteralPath $parityWorkflowPath -Raw
} else {
    ''
}

if ($ciContent) {
    if ($ciContent -match '(?ms)^\s*container-contract:\s*$') {
        Add-ContractViolation -Type 'duplicate-container-contract-job' -Message 'ci.yml must not define a container-contract job after parity ownership cutover.'
    }

    if ($ciContent -notmatch '(?ms)^  vi-analyzer:\s*$') {
        Add-ContractViolation -Type 'missing-vi-analyzer-job' -Message 'ci.yml must define a vi-analyzer job for self-hosted Windows lanes.'
    }
    $viAnalyzerBlockMatch = [regex]::Match(
        $ciContent,
        '(?ms)^\s{2}vi-analyzer:\s*$.*?(?=^\s{2}[A-Za-z0-9_-]+:\s*$|\z)'
    )
    if (-not $viAnalyzerBlockMatch.Success) {
        Add-ContractViolation -Type 'missing-vi-analyzer-block' -Message 'ci.yml must include a resolvable vi-analyzer job block.'
    } else {
        $viAnalyzerBlock = $viAnalyzerBlockMatch.Value
        if ($viAnalyzerBlock -notmatch 'name:\s*VI Analyzer LabVIEW \${{\s*needs\.version-gate\.outputs\.raw\s*}} \${{\s*matrix\.bitness_label\s*}}') {
            Add-ContractViolation -Type 'missing-vi-analyzer-lane-name' -Message 'ci.yml vi-analyzer job name must use the descriptive contract VI Analyzer LabVIEW ${{ needs.version-gate.outputs.raw }} ${{ matrix.bitness_label }}.'
        }
        if ($viAnalyzerBlock -notmatch 'needs:\s*\[\s*run-metadata,\s*prerelease-context,\s*version-gate,\s*apply-deps-64,\s*apply-deps-32\s*\]') {
            Add-ContractViolation -Type 'missing-vi-analyzer-needs' -Message 'ci.yml vi-analyzer job must depend on run-metadata, prerelease-context, version-gate, apply-deps-64, and apply-deps-32.'
        }
        if ($viAnalyzerBlock -notmatch 'Tooling/Run-ViAnalyzer\.ps1') {
            Add-ContractViolation -Type 'missing-vi-analyzer-runner' -Message 'ci.yml vi-analyzer job must run Tooling/Run-ViAnalyzer.ps1.'
        }
        if ($viAnalyzerBlock -match "(?m)^\s*if:\s*\$\{\{\s*needs\.prerelease-context\.outputs\.ci_profile != 'release-priority'\s*\}\}") {
            Add-ContractViolation -Type 'vi-analyzer-release-priority-gated' -Message 'ci.yml vi-analyzer job must remain enabled for release-priority; do not gate it out by ci_profile.'
        }
    }
    if ($ciContent -notmatch '(?ms)^  publish-gate:\s*.*?\n\s*-\s*vi-analyzer\s*$') {
        Add-ContractViolation -Type 'missing-vi-analyzer-publish-gate' -Message 'publish-gate needs list must include vi-analyzer.'
    }
    if ($ciContent -notmatch '(?ms)^  pipeline-contract:\s*.*?\n\s*-\s*vi-analyzer\s*$') {
        Add-ContractViolation -Type 'missing-vi-analyzer-pipeline-contract' -Message 'pipeline-contract needs list must include vi-analyzer.'
    }
    if ($ciContent -notmatch '(?ms)\$requiredFullValidation\s*=\s*@\(\s*.*?''vi-analyzer''') {
        Add-ContractViolation -Type 'missing-vi-analyzer-required-full' -Message 'profile requiredFullValidation list in ci.yml must include vi-analyzer.'
    }
    $releasePriorityViAnalyzerRequiredCount = [regex]::Matches(
        $ciContent,
        '(?ms)''release-priority''\s*=\s*@\(\$requiredCommon\s*\+\s*@\(''vi-analyzer''\)\)'
    ).Count
    if ($releasePriorityViAnalyzerRequiredCount -lt 2) {
        Add-ContractViolation -Type 'missing-vi-analyzer-required-release-priority' -Message 'profile requiredByProfile release-priority list in ci.yml must include vi-analyzer for both publish-gate and pipeline-contract checks.'
    }
}

if ($parityContent) {
    if ($parityContent -match '(?ms)^\s*vi-analyzer-linux:\s*$') {
        Add-ContractViolation -Type 'legacy-vi-analyzer-job-present' -Message 'labview-parity.yml must not define a standalone vi-analyzer-linux job; merge responsibilities into parity-linux.'
    }

    $parityLinuxMatch = [regex]::Match(
        $parityContent,
        '(?ms)^\s*parity-linux:\s*$.*?(?=^\s{2}[A-Za-z0-9_-]+:\s*$|\z)'
    )

    if (-not $parityLinuxMatch.Success) {
        Add-ContractViolation -Type 'missing-parity-linux-job' -Message 'labview-parity.yml must define parity-linux job block.'
    } else {
        $parityLinuxBlock = $parityLinuxMatch.Value

        $requiredPatterns = @(
            @{
                Type    = 'parity-linux-dynamic-name'
                Pattern = 'name:\s*Parity \(Linux Container \${{\s*needs\.resolve-parity-context\.outputs\.lvcontainer_raw\s*}}\)'
                Message = 'parity-linux job name must derive from resolve-parity-context.outputs.lvcontainer_raw.'
            },
            @{
                Type    = 'parity-linux-needs-resolve'
                Pattern = 'needs:\s*\[\s*resolve-parity-context\s*\]'
                Message = 'parity-linux needs list must include resolve-parity-context.'
            },
            @{
                Type    = 'parity-linux-vi-analyzer-image-env'
                Pattern = 'LVIE_CONTAINER_CONTRACT_LINUX_IMAGE:\s*nationalinstruments/labview:\${{\s*needs\.resolve-parity-context\.outputs\.lvcontainer_linux_tag\s*}}'
                Message = 'parity-linux job env must map LVIE_CONTAINER_CONTRACT_LINUX_IMAGE from resolve-parity-context linux tag output.'
            },
            @{
                Type    = 'parity-linux-vi-analyzer-tag-env'
                Pattern = 'LVIE_CONTAINER_CONTRACT_TAG:\s*\${{\s*needs\.resolve-parity-context\.outputs\.lvcontainer_linux_tag\s*}}'
                Message = 'parity-linux job env must map LVIE_CONTAINER_CONTRACT_TAG from resolve-parity-context outputs.'
            },
            @{
                Type    = 'parity-linux-vi-analyzer-image-tag-env'
                Pattern = 'LVIE_CONTAINER_CONTRACT_IMAGE:\s*nationalinstruments/labview:\${{\s*needs\.resolve-parity-context\.outputs\.lvcontainer_linux_tag\s*}}'
                Message = 'parity-linux job env must map LVIE_CONTAINER_CONTRACT_IMAGE from resolve-parity-context outputs.'
            },
            @{
                Type    = 'parity-linux-vi-analyzer-os-env'
                Pattern = 'LVIE_CONTAINER_CONTRACT_OS:\s*linux'
                Message = 'parity-linux job env must map LVIE_CONTAINER_CONTRACT_OS to linux.'
            },
            @{
                Type    = 'parity-linux-vi-analyzer-tasks-env'
                Pattern = 'LVIE_VI_ANALYZER_TASKS_PATH:\s*Tooling/vi-analyzer/tasks\.linux\.json'
                Message = 'parity-linux job env must define LVIE_VI_ANALYZER_TASKS_PATH to Tooling/vi-analyzer/tasks.linux.json.'
            },
            @{
                Type    = 'parity-linux-vi-analyzer-os-guard'
                Pattern = '(?s)Validate merged vi-analyzer container selection.*?LVIE_CONTAINER_CONTRACT_OS.*?requires a linux container tag'
                Message = 'parity-linux merged vi-analyzer path must fail fast when a non-linux container tag is selected.'
            },
            @{
                Type    = 'parity-linux-vi-analyzer-pull-image'
                Pattern = 'image="\$\{LVIE_CONTAINER_CONTRACT_LINUX_IMAGE\}"'
                Message = 'parity-linux merged vi-analyzer pull step must use LVIE_CONTAINER_CONTRACT_LINUX_IMAGE.'
            },
            @{
                Type    = 'parity-linux-vi-analyzer-runtime-year'
                Pattern = 'LVIE_VI_ANALYZER_LABVIEW_YEAR:\s*\${{\s*needs\.resolve-parity-context\.outputs\.lvcontainer_linux_year\s*}}'
                Message = 'parity-linux merged vi-analyzer runtime year must come from resolve-parity-context linux year output.'
            },
            @{
                Type    = 'parity-linux-vi-analyzer-worker'
                Pattern = 'run-vi-analyzer-linux\.sh'
                Message = 'parity-linux must run Tooling/container-parity/run-vi-analyzer-linux.sh for merged VI Analyzer responsibilities.'
            },
            @{
                Type    = 'parity-linux-vi-analyzer-artifacts'
                Pattern = 'vi-analyzer-reports-parity'
                Message = 'parity-linux must upload vi-analyzer-reports-parity artifact.'
            },
            @{
                Type    = 'parity-linux-vi-analyzer-status-artifact'
                Pattern = 'vi-analyzer-status-parity'
                Message = 'parity-linux must upload vi-analyzer-status-parity artifact.'
            }
        )

        foreach ($check in $requiredPatterns) {
            if ($parityLinuxBlock -notmatch $check.Pattern) {
                Add-ContractViolation -Type $check.Type -Message $check.Message
            }
        }

        $bannedPatterns = @(
            @{
                Type    = 'legacy-lv-release-format'
                Pattern = 'LV_RELEASE:\s*\${{\s*format\(''\{0\}q1'',\s*needs\.version-gate\.outputs\.year\)\s*}}'
                Message = 'merged parity-linux vi-analyzer pull step must not derive LV_RELEASE from needs.version-gate.outputs.year.'
            },
            @{
                Type    = 'legacy-linux-image-template'
                Pattern = 'image="nationalinstruments/labview:\$\{LV_RELEASE\}-linux"'
                Message = 'merged parity-linux vi-analyzer pull step must not build image from LV_RELEASE template.'
            }
        )

        foreach ($check in $bannedPatterns) {
            if ($parityLinuxBlock -match $check.Pattern) {
                Add-ContractViolation -Type $check.Type -Message $check.Message
            }
        }
    }

    $parityWindowsMatch = [regex]::Match(
        $parityContent,
        '(?ms)^\s*parity-windows:\s*$.*?(?=^\s{2}[A-Za-z0-9_-]+:\s*$|\z)'
    )

    if (-not $parityWindowsMatch.Success) {
        Add-ContractViolation -Type 'missing-parity-windows-job' -Message 'labview-parity.yml must define parity-windows job block.'
    } else {
        $parityWindowsBlock = $parityWindowsMatch.Value

        $requiredWindowsPatterns = @(
            @{
                Type    = 'parity-windows-dynamic-name'
                Pattern = 'name:\s*Parity \(Windows Container \${{\s*needs\.resolve-parity-context\.outputs\.lvcontainer_windows_tag\s*}}\)'
                Message = 'parity-windows job name must derive from resolve-parity-context.outputs.lvcontainer_windows_tag.'
            },
            @{
                Type    = 'parity-windows-needs-resolve'
                Pattern = 'needs:\s*\[\s*resolve-parity-context\s*\]'
                Message = 'parity-windows needs list must include resolve-parity-context.'
            },
            @{
                Type    = 'parity-windows-vi-analyzer-step'
                Pattern = 'Run merged VI Analyzer tasks \(Windows container\)'
                Message = 'parity-windows must run merged VI Analyzer tasks in the Windows container lane.'
            },
            @{
                Type    = 'parity-windows-vi-analyzer-worker'
                Pattern = 'run-vi-analyzer-windows\.ps1'
                Message = 'parity-windows merged vi-analyzer step must invoke Tooling/container-parity/run-vi-analyzer-windows.ps1.'
            },
            @{
                Type    = 'parity-windows-vi-analyzer-tasks-env'
                Pattern = 'LVIE_VI_ANALYZER_TASKS_PATH:\s*Tooling\\vi-analyzer\\tasks\.json'
                Message = 'parity-windows job env must define LVIE_VI_ANALYZER_TASKS_PATH to Tooling\\vi-analyzer\\tasks.json.'
            },
            @{
                Type    = 'parity-windows-vi-analyzer-reports-env'
                Pattern = 'LVIE_VI_ANALYZER_REPORTS_ROOT:\s*builds\\vi-analyzer\\windows-container'
                Message = 'parity-windows job env must define LVIE_VI_ANALYZER_REPORTS_ROOT to builds\\vi-analyzer\\windows-container.'
            },
            @{
                Type    = 'parity-windows-vi-analyzer-status-env'
                Pattern = 'LVIE_VI_ANALYZER_STATUS_PATH:\s*builds\\status\\vi-analyzer-summary\.parity\.windows\.json'
                Message = 'parity-windows job env must define LVIE_VI_ANALYZER_STATUS_PATH to builds\\status\\vi-analyzer-summary.parity.windows.json.'
            },
            @{
                Type    = 'parity-windows-vi-analyzer-logs-artifact'
                Pattern = 'vi-analyzer-windows-logs-parity'
                Message = 'parity-windows must upload vi-analyzer-windows-logs-parity artifact.'
            },
            @{
                Type    = 'parity-windows-vi-analyzer-reports-artifact'
                Pattern = 'vi-analyzer-reports-parity-windows'
                Message = 'parity-windows must upload vi-analyzer-reports-parity-windows artifact.'
            },
            @{
                Type    = 'parity-windows-vi-analyzer-status-artifact'
                Pattern = 'vi-analyzer-status-parity-windows'
                Message = 'parity-windows must upload vi-analyzer-status-parity-windows artifact.'
            }
        )

        foreach ($check in $requiredWindowsPatterns) {
            if ($parityWindowsBlock -notmatch $check.Pattern) {
                Add-ContractViolation -Type $check.Type -Message $check.Message
            }
        }
    }
}

if ($WriteSummary -and -not [string]::IsNullOrWhiteSpace($env:GITHUB_STEP_SUMMARY)) {
    if ($violations.Count -eq 0) {
        @(
            '### VI Analyzer Container Contract Guard'
            '- Status: pass'
            '- Result: Self-hosted CI vi-analyzer and parity merged container vi-analyzer wiring are valid for both Linux and Windows lanes.'
        ) | Out-File -FilePath $env:GITHUB_STEP_SUMMARY -Encoding utf8 -Append
    } else {
        @(
            '### VI Analyzer Container Contract Guard'
            '- Status: fail'
            ("- Violations: {0}" -f $violations.Count)
        ) | Out-File -FilePath $env:GITHUB_STEP_SUMMARY -Encoding utf8 -Append
    }
}

if ($violations.Count -gt 0) {
    $formatted = $violations | ForEach-Object {
        "[{0}] {1}" -f $_.Type, $_.Message
    }
    throw ("VI Analyzer container contract violations detected:{0}{1}" -f [Environment]::NewLine, ($formatted -join [Environment]::NewLine))
}

Write-Host 'VI Analyzer container contract guard passed with no violations.'
