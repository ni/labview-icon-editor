#Requires -Version 7.0
[CmdletBinding()]
param(
    [string]$RepoRoot = '.',
    [ValidateSet('all', 'ci-only')]
    [string]$Scope = 'all',
    [switch]$WriteSummary
)

$ErrorActionPreference = 'Stop'

$repoRootPath = (Resolve-Path -Path $RepoRoot -ErrorAction Stop).Path

$allTargetFiles = @(
    '.github/workflows/ci.yml',
    '.github/workflows/ci-composite.yml',
    '.github/workflows/labview-parity.yml',
    '.github/workflows/development-mode-toggle.yml',
    'Tooling/container-parity/runlabview-windows.ps1',
    'Tooling/container-parity/runlabview-linux.sh'
)

$targetFiles = switch ($Scope) {
    'ci-only' {
        @(
            '.github/workflows/ci.yml',
            '.github/workflows/labview-parity.yml',
            '.github/workflows/development-mode-toggle.yml',
            'Tooling/container-parity/runlabview-windows.ps1',
            'Tooling/container-parity/runlabview-linux.sh'
        )
    }
    default {
        $allTargetFiles
    }
}

$ruleList = @(
    [pscustomobject]@{
        Type    = 'workflow-devmode-script'
        Pattern = 'Set_Development_Mode\.ps1|RevertDevelopmentMode\.ps1'
        Message = 'Automation workflows must not invoke dev-mode toggle scripts.'
        Files   = @(
            '.github/workflows/ci.yml',
            '.github/workflows/ci-composite.yml',
            '.github/workflows/labview-parity.yml',
            '.github/workflows/development-mode-toggle.yml'
        )
    },
    [pscustomobject]@{
        Type    = 'workflow-revert-devmode-input'
        Pattern = 'revert_dev_mode'
        Message = 'CI workflows must not pass revert_dev_mode teardown inputs.'
        Files   = @(
            '.github/workflows/ci.yml',
            '.github/workflows/ci-composite.yml',
            '.github/workflows/labview-parity.yml'
        )
    },
    [pscustomobject]@{
        Type    = 'workflow-devmode-smoke-job'
        Pattern = 'devmode-no-labview-smoke|DevMode\.NoLabVIEW Smoke'
        Message = 'ci-composite.yml must not include the devmode-no-labview-smoke job or dependencies.'
        Files   = @(
            '.github/workflows/ci-composite.yml'
        )
    },
    [pscustomobject]@{
        Type    = 'workflow-devmode-linux-coupling'
        Pattern = 'devmode-linux\.sh'
        Message = 'Container parity workflows must not call devmode-linux.sh.'
        Files   = @(
            '.github/workflows/ci-composite.yml',
            '.github/workflows/labview-parity.yml'
        )
    },
    [pscustomobject]@{
        Type    = 'container-selector-plumbing'
        Pattern = 'Run Icon Editor from Source Selector\.vi|Invoke-LabVIEWCliSelectorMode|Get-LabVIEWCliSelectorPortAttemptList|SELECTOR_VI_PATH|resolve_selector_port|run_selector_mode'
        Message = 'Container parity scripts must not include selector mode set/unset plumbing.'
        Files   = @(
            'Tooling/container-parity/runlabview-windows.ps1',
            'Tooling/container-parity/runlabview-linux.sh'
        )
    },
    [pscustomobject]@{
        Type    = 'container-devmode-plumbing'
        Pattern = 'CONTAINER_PARITY_ENABLE_DEVMODE|Set-DevelopmentMode-NoLabVIEW\.ps1|Revert-DevelopmentMode-NoLabVIEW\.ps1|DEVMODE_SCRIPT'
        Message = 'Container parity scripts must not include CI dev-mode toggle plumbing.'
        Files   = @(
            'Tooling/container-parity/runlabview-windows.ps1',
            'Tooling/container-parity/runlabview-linux.sh'
        )
    }
)

$violationList = New-Object System.Collections.Generic.List[object]

foreach ($relativePathRaw in $targetFiles) {
    $relativePath = $relativePathRaw -replace '\\', '/'
    $fullPath = Join-Path -Path $repoRootPath -ChildPath ($relativePathRaw -replace '/', [System.IO.Path]::DirectorySeparatorChar)
    if (-not (Test-Path -LiteralPath $fullPath -PathType Leaf)) {
        $violationList.Add([pscustomobject]@{
                Type    = 'missing-target-file'
                File    = $relativePath
                Line    = 0
                Pattern = '<file-exists>'
                Message = 'Required CI contract file is missing.'
            }) | Out-Null
        continue
    }

    $lineItems = Get-Content -LiteralPath $fullPath -ErrorAction Stop
    $lineNumber = 0
    foreach ($lineText in $lineItems) {
        $lineNumber++
        foreach ($rule in $ruleList) {
            if ($rule.Files -notcontains $relativePath) {
                continue
            }

            if ($lineText -match $rule.Pattern) {
                $violationList.Add([pscustomobject]@{
                        Type    = $rule.Type
                        File    = $relativePath
                        Line    = $lineNumber
                        Pattern = $rule.Pattern
                        Message = $rule.Message
                    }) | Out-Null
            }
        }
    }
}

if ($WriteSummary -and -not [string]::IsNullOrWhiteSpace($env:GITHUB_STEP_SUMMARY)) {
    if ($violationList.Count -eq 0) {
        @(
            '### CI Selector/DevMode Contract Guard'
            '- Status: pass'
            '- Result: no CI selector/dev-mode contract violations detected.'
        ) | Out-File -FilePath $env:GITHUB_STEP_SUMMARY -Encoding utf8 -Append
    } else {
        @(
            '### CI Selector/DevMode Contract Guard'
            '- Status: fail'
            ("- Violations: {0}" -f $violationList.Count)
        ) | Out-File -FilePath $env:GITHUB_STEP_SUMMARY -Encoding utf8 -Append
    }
}

if ($violationList.Count -gt 0) {
    $formatted = $violationList | ForEach-Object {
        "{0}:{1} [{2}] {3}" -f $_.File, $_.Line, $_.Type, $_.Message
    }
    throw ("CI selector/dev-mode contract violations detected:{0}{1}" -f [Environment]::NewLine, ($formatted -join [Environment]::NewLine))
}

Write-Host 'CI selector/dev-mode contract guard passed with no violations.'
