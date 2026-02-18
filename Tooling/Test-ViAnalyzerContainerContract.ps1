#Requires -Version 7.0
[CmdletBinding()]
param(
    [string]$RepoRoot = '.',
    [switch]$WriteSummary
)

$ErrorActionPreference = 'Stop'

$repoRootPath = (Resolve-Path -Path $RepoRoot -ErrorAction Stop).Path
$workflowPath = Join-Path $repoRootPath '.github\workflows\ci.yml'
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

if (-not (Test-Path -LiteralPath $workflowPath -PathType Leaf)) {
    Add-ContractViolation -Type 'missing-workflow' -Message "Required workflow file not found: .github/workflows/ci.yml"
}

if (-not (Test-Path -LiteralPath $lvcontainerPath -PathType Leaf)) {
    Add-ContractViolation -Type 'missing-lvcontainer' -Message 'Required container contract file not found: .lvcontainer'
}

$content = if (Test-Path -LiteralPath $workflowPath -PathType Leaf) {
    Get-Content -LiteralPath $workflowPath -Raw
} else {
    ''
}

if ($content) {
    if ($content -notmatch '(?ms)^\s*container-contract:\s*$') {
        Add-ContractViolation -Type 'missing-container-contract-job' -Message 'ci.yml must define a container-contract job.'
    }

    foreach ($requiredOutput in @('raw', 'tag', 'image', 'os', 'year', 'minor', 'release_tag', 'linux_image')) {
        $pattern = "(?ms)^\s*container-contract:\s*.*?steps\.contract\.outputs\.{0}" -f [regex]::Escape($requiredOutput)
        if ($content -notmatch $pattern) {
            Add-ContractViolation -Type 'missing-container-contract-output' -Message ("container-contract job must expose output '{0}'." -f $requiredOutput)
        }
    }

    $viAnalyzerMatch = [regex]::Match(
        $content,
        '(?ms)^\s*vi-analyzer:\s*$.*?(?=^\s{2}[A-Za-z0-9_-]+:\s*$|\z)'
    )

    if (-not $viAnalyzerMatch.Success) {
        Add-ContractViolation -Type 'missing-vi-analyzer-job' -Message 'ci.yml must define vi-analyzer job block.'
    } else {
        $viAnalyzerBlock = $viAnalyzerMatch.Value

        $requiredPatterns = @(
            @{
                Type    = 'vi-analyzer-dynamic-name'
                Pattern = 'name:\s*VI Analyzer Linux container \${{\s*needs\.container-contract\.outputs\.raw\s*}}'
                Message = 'vi-analyzer job name must derive from needs.container-contract.outputs.raw.'
            },
            @{
                Type    = 'vi-analyzer-needs-container-contract'
                Pattern = 'needs:\s*\[[^\]]*container-contract[^\]]*\]'
                Message = 'vi-analyzer needs list must include container-contract.'
            },
            @{
                Type    = 'vi-analyzer-image-env'
                Pattern = 'LVIE_CONTAINER_CONTRACT_LINUX_IMAGE:\s*\${{\s*needs\.container-contract\.outputs\.linux_image\s*}}'
                Message = 'vi-analyzer job env must map LVIE_CONTAINER_CONTRACT_LINUX_IMAGE from container-contract outputs.'
            },
            @{
                Type    = 'vi-analyzer-tag-env'
                Pattern = 'LVIE_CONTAINER_CONTRACT_TAG:\s*\${{\s*needs\.container-contract\.outputs\.tag\s*}}'
                Message = 'vi-analyzer job env must map LVIE_CONTAINER_CONTRACT_TAG from container-contract outputs.'
            },
            @{
                Type    = 'vi-analyzer-image-tag-env'
                Pattern = 'LVIE_CONTAINER_CONTRACT_IMAGE:\s*\${{\s*needs\.container-contract\.outputs\.image\s*}}'
                Message = 'vi-analyzer job env must map LVIE_CONTAINER_CONTRACT_IMAGE from container-contract outputs.'
            },
            @{
                Type    = 'vi-analyzer-os-env'
                Pattern = 'LVIE_CONTAINER_CONTRACT_OS:\s*\${{\s*needs\.container-contract\.outputs\.os\s*}}'
                Message = 'vi-analyzer job env must map LVIE_CONTAINER_CONTRACT_OS from container-contract outputs.'
            },
            @{
                Type    = 'vi-analyzer-os-guard'
                Pattern = '(?s)Validate vi-analyzer container selection.*?LVIE_CONTAINER_CONTRACT_OS.*?requires a linux container tag'
                Message = 'vi-analyzer must fail fast when a non-linux container tag is selected.'
            },
            @{
                Type    = 'vi-analyzer-pull-image'
                Pattern = 'image="\$\{LVIE_CONTAINER_CONTRACT_LINUX_IMAGE\}"'
                Message = 'vi-analyzer pull step must use LVIE_CONTAINER_CONTRACT_LINUX_IMAGE.'
            },
            @{
                Type    = 'vi-analyzer-runtime-year'
                Pattern = 'LVIE_VI_ANALYZER_LABVIEW_YEAR:\s*\${{\s*needs\.container-contract\.outputs\.year\s*}}'
                Message = 'vi-analyzer runtime year must come from container-contract outputs.'
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
                Message = 'vi-analyzer pull step must not derive LV_RELEASE from needs.version-gate.outputs.year.'
            },
            @{
                Type    = 'legacy-linux-image-template'
                Pattern = 'image="nationalinstruments/labview:\$\{LV_RELEASE\}-linux"'
                Message = 'vi-analyzer pull step must not build image from LV_RELEASE template.'
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
            '- Result: vi-analyzer container contract wiring is valid.'
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
