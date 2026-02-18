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
    if ($ciContent -match '(?ms)^\s*vi-analyzer:\s*$') {
        Add-ContractViolation -Type 'duplicate-vi-analyzer-job' -Message 'ci.yml must not define a vi-analyzer job after parity ownership cutover.'
    }
    if ($ciContent -match '(?ms)publish-gate:\s*.*?needs:\s*.*?\n\s*-\s*vi-analyzer\s*$') {
        Add-ContractViolation -Type 'duplicate-vi-analyzer-publish-gate' -Message 'publish-gate needs list must not include vi-analyzer.'
    }
    if ($ciContent -match '(?ms)pipeline-contract:\s*.*?needs:\s*.*?\n\s*-\s*vi-analyzer\s*$') {
        Add-ContractViolation -Type 'duplicate-vi-analyzer-pipeline-contract' -Message 'pipeline-contract needs list must not include vi-analyzer.'
    }
    if ($ciContent -match "(?ms)\$requiredCommon\s*=\s*@\(\s*.*?'vi-analyzer'") {
        Add-ContractViolation -Type 'duplicate-vi-analyzer-required-common' -Message 'profile requiredCommon list in ci.yml must not include vi-analyzer.'
    }
}

if ($parityContent) {
    $viAnalyzerMatch = [regex]::Match(
        $parityContent,
        '(?ms)^\s*vi-analyzer-linux:\s*$.*?(?=^\s{2}[A-Za-z0-9_-]+:\s*$|\z)'
    )

    if (-not $viAnalyzerMatch.Success) {
        Add-ContractViolation -Type 'missing-parity-vi-analyzer-job' -Message 'labview-parity.yml must define vi-analyzer-linux job block.'
    } else {
        $viAnalyzerBlock = $viAnalyzerMatch.Value

        $requiredPatterns = @(
            @{
                Type    = 'parity-vi-analyzer-dynamic-name'
                Pattern = 'name:\s*VI Analyzer Linux container \${{\s*needs\.resolve-parity-context\.outputs\.lvcontainer_raw\s*}}'
                Message = 'vi-analyzer-linux job name must derive from resolve-parity-context.outputs.lvcontainer_raw.'
            },
            @{
                Type    = 'parity-vi-analyzer-needs-resolve'
                Pattern = 'needs:\s*\[\s*resolve-parity-context\s*\]'
                Message = 'vi-analyzer-linux needs list must include resolve-parity-context.'
            },
            @{
                Type    = 'parity-vi-analyzer-image-env'
                Pattern = 'LVIE_CONTAINER_CONTRACT_LINUX_IMAGE:\s*nationalinstruments/labview:\${{\s*needs\.resolve-parity-context\.outputs\.lvcontainer_linux_tag\s*}}'
                Message = 'vi-analyzer-linux job env must map LVIE_CONTAINER_CONTRACT_LINUX_IMAGE from resolve-parity-context linux tag output.'
            },
            @{
                Type    = 'parity-vi-analyzer-tag-env'
                Pattern = 'LVIE_CONTAINER_CONTRACT_TAG:\s*\${{\s*needs\.resolve-parity-context\.outputs\.lvcontainer_linux_tag\s*}}'
                Message = 'vi-analyzer-linux job env must map LVIE_CONTAINER_CONTRACT_TAG from resolve-parity-context outputs.'
            },
            @{
                Type    = 'parity-vi-analyzer-image-tag-env'
                Pattern = 'LVIE_CONTAINER_CONTRACT_IMAGE:\s*nationalinstruments/labview:\${{\s*needs\.resolve-parity-context\.outputs\.lvcontainer_linux_tag\s*}}'
                Message = 'vi-analyzer-linux job env must map LVIE_CONTAINER_CONTRACT_IMAGE from resolve-parity-context outputs.'
            },
            @{
                Type    = 'parity-vi-analyzer-os-env'
                Pattern = 'LVIE_CONTAINER_CONTRACT_OS:\s*linux'
                Message = 'vi-analyzer-linux job env must map LVIE_CONTAINER_CONTRACT_OS to linux.'
            },
            @{
                Type    = 'parity-vi-analyzer-os-guard'
                Pattern = '(?s)Validate vi-analyzer container selection.*?LVIE_CONTAINER_CONTRACT_OS.*?requires a linux container tag'
                Message = 'vi-analyzer-linux must fail fast when a non-linux container tag is selected.'
            },
            @{
                Type    = 'parity-vi-analyzer-pull-image'
                Pattern = 'image="\$\{LVIE_CONTAINER_CONTRACT_LINUX_IMAGE\}"'
                Message = 'vi-analyzer-linux pull step must use LVIE_CONTAINER_CONTRACT_LINUX_IMAGE.'
            },
            @{
                Type    = 'parity-vi-analyzer-runtime-year'
                Pattern = 'LVIE_VI_ANALYZER_LABVIEW_YEAR:\s*\${{\s*needs\.resolve-parity-context\.outputs\.lvcontainer_linux_year\s*}}'
                Message = 'vi-analyzer-linux runtime year must come from resolve-parity-context linux year output.'
            }
        )

        foreach ($check in $requiredPatterns) {
            if ($viAnalyzerBlock -notmatch $check.Pattern) {
                Add-ContractViolation -Type $check.Type -Message $check.Message
            }
        }

        $bannedPatterns = @(
            @{
                Type    = 'legacy-lv-release-format'
                Pattern = 'LV_RELEASE:\s*\${{\s*format\(''\{0\}q1'',\s*needs\.version-gate\.outputs\.year\)\s*}}'
                Message = 'vi-analyzer-linux pull step must not derive LV_RELEASE from needs.version-gate.outputs.year.'
            },
            @{
                Type    = 'legacy-linux-image-template'
                Pattern = 'image="nationalinstruments/labview:\$\{LV_RELEASE\}-linux"'
                Message = 'vi-analyzer-linux pull step must not build image from LV_RELEASE template.'
            }
        )

        foreach ($check in $bannedPatterns) {
            if ($viAnalyzerBlock -match $check.Pattern) {
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
            '- Result: CI duplicate lane removed and parity vi-analyzer wiring is valid.'
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
