#Requires -Version 7.0
[CmdletBinding()]
param(
    [string]$RepoRoot = '.',
    [switch]$WriteSummary
)

$ErrorActionPreference = 'Stop'

$repoRootPath = (Resolve-Path -Path $RepoRoot -ErrorAction Stop).Path

$coreWorkflowFiles = @(
    '.github/workflows/ci.yml',
    '.github/workflows/ci-composite.yml',
    '.github/workflows/labview-parity.yml',
    '.github/workflows/development-mode-toggle.yml',
    '.github/workflows/runner-cli.yml',
    '.github/workflows/runner-audit.yml'
)

$manualOnlyWorkflowFiles = @(
    '.github/workflows/stale-issues.yml',
    '.github/workflows/labels-sync.yml',
    '.github/workflows/label-metadata-gate.yml',
    '.github/workflows/label-metadata-audit.yml',
    '.github/workflows/label-metadata-normalize.yml',
    '.github/workflows/repo-agnostic-issue-routing.yml',
    '.github/workflows/ci-debt-train.yml',
    '.github/workflows/ci-debt-policy-gate.yml'
)

$pipelineContractFiles = @(
    '.github/workflows/ci.yml',
    '.github/workflows/ci-composite.yml'
)

function Get-LeadingWhitespaceCount {
    param(
        [Parameter(Mandatory = $true)]
        [AllowEmptyString()]
        [string]$Value
    )

    $trimmedStart = $Value.TrimStart()
    return ($Value.Length - $trimmedStart.Length)
}

function Remove-InlineComment {
    param(
        [Parameter(Mandatory = $true)]
        [AllowEmptyString()]
        [string]$Value
    )

    $index = $Value.IndexOf('#')
    if ($index -lt 0) {
        return $Value
    }

    if ($index -eq 0) {
        return ''
    }

    $before = $Value.Substring($index - 1, 1)
    if ([char]::IsWhiteSpace($before)) {
        return $Value.Substring(0, $index)
    }

    return $Value
}

function ConvertTo-YamlToken {
    param(
        [Parameter(Mandatory = $true)]
        [AllowEmptyString()]
        [string]$Value
    )

    $cleaned = (Remove-InlineComment -Value $Value).Trim()
    if ($cleaned.Length -ge 2) {
        if (($cleaned.StartsWith("'") -and $cleaned.EndsWith("'")) -or ($cleaned.StartsWith('"') -and $cleaned.EndsWith('"'))) {
            $cleaned = $cleaned.Substring(1, $cleaned.Length - 2)
        }
    }

    return $cleaned.Trim()
}

function Add-EventName {
    param(
        [Parameter(Mandatory = $true)]
        [AllowEmptyCollection()]
        [System.Collections.Generic.List[string]]$EventList,

        [Parameter(Mandatory = $true)]
        [AllowEmptyString()]
        [string]$RawValue
    )

    $normalized = (ConvertTo-YamlToken -Value $RawValue).ToLowerInvariant()
    if ([string]::IsNullOrWhiteSpace($normalized)) {
        return
    }

    if ($normalized -notmatch '^[a-z0-9_-]+$') {
        return
    }

    if ($EventList -notcontains $normalized) {
        $EventList.Add($normalized) | Out-Null
    }
}

function Add-InlineEventFromRhsValue {
    param(
        [Parameter(Mandatory = $true)]
        [AllowEmptyCollection()]
        [System.Collections.Generic.List[string]]$EventList,

        [Parameter(Mandatory = $true)]
        [AllowEmptyString()]
        [string]$Rhs
    )

    $value = ConvertTo-YamlToken -Value $Rhs
    if ([string]::IsNullOrWhiteSpace($value)) {
        return
    }

    if ($value -match '^\[(?<inner>.*)\]$') {
        $inner = $Matches['inner']
        foreach ($part in ($inner -split ',')) {
            $token = ConvertTo-YamlToken -Value $part
            if ($token -match '^(?<event>[a-zA-Z0-9_-]+)\s*:?\s*$') {
                Add-EventName -EventList $EventList -RawValue $Matches['event']
            }
        }
        return
    }

    if ($value -match '^\{(?<inner>.*)\}$') {
        $inner = $Matches['inner']
        $regexMatches = [regex]::Matches($inner, '(?m)(["'']?[A-Za-z0-9_-]+["'']?)\s*:')
        foreach ($item in $regexMatches) {
            Add-EventName -EventList $EventList -RawValue $item.Groups[1].Value
        }
        return
    }

    if ($value -match '^(?<event>[a-zA-Z0-9_-]+)\s*:?\s*$') {
        Add-EventName -EventList $EventList -RawValue $Matches['event']
    }
}

function Get-WorkflowEventName {
    param(
        [Parameter(Mandatory = $true)]
        [AllowEmptyString()]
        [string[]]$Lines
    )

    $eventList = New-Object System.Collections.Generic.List[string]
    $insideOnBlock = $false
    $onIndent = -1
    $eventIndent = -1

    for ($index = 0; $index -lt $Lines.Count; $index++) {
        $line = $Lines[$index]
        $trimmed = $line.Trim()

        if (-not $insideOnBlock) {
            if ($trimmed -match '^(?:on|''on''|"on")\s*:\s*(?<rhs>.*)$') {
                $insideOnBlock = $true
                $onIndent = Get-LeadingWhitespaceCount -Value $line
                $eventIndent = -1
                Add-InlineEventFromRhsValue -EventList $eventList -Rhs $Matches['rhs']

                if (-not [string]::IsNullOrWhiteSpace((ConvertTo-YamlToken -Value $Matches['rhs']))) {
                    $insideOnBlock = $false
                    $onIndent = -1
                }
            }

            continue
        }

        if ([string]::IsNullOrWhiteSpace($trimmed) -or $trimmed.StartsWith('#')) {
            continue
        }

        $indent = Get-LeadingWhitespaceCount -Value $line
        if ($indent -le $onIndent) {
            $insideOnBlock = $false
            $onIndent = -1
            $eventIndent = -1
            $index--
            continue
        }

        $content = ConvertTo-YamlToken -Value $trimmed
        if ([string]::IsNullOrWhiteSpace($content)) {
            continue
        }

        if ($content -match '^-+\s*(?<item>.+)$') {
            if ($eventIndent -lt 0) {
                $eventIndent = $indent
            }

            if ($indent -eq $eventIndent -and $Matches['item'] -match '^(?<event>[a-zA-Z0-9_-]+)\s*:?\s*$') {
                Add-EventName -EventList $eventList -RawValue $Matches['event']
            }

            continue
        }

        if ($content -match '^(?<key>["'']?[A-Za-z0-9_-]+["'']?)\s*:\s*(?<rhs>.*)$') {
            if ($eventIndent -lt 0) {
                $eventIndent = $indent
            }

            if ($indent -eq $eventIndent) {
                Add-EventName -EventList $eventList -RawValue $Matches['key']
            }
        }
    }

    return @($eventList)
}

function Resolve-RepoFilePath {
    param(
        [Parameter(Mandatory = $true)]
        [string]$RepoRootPath,

        [Parameter(Mandatory = $true)]
        [string]$RelativePath
    )

    return Join-Path -Path $RepoRootPath -ChildPath ($RelativePath -replace '/', [System.IO.Path]::DirectorySeparatorChar)
}

$violationList = New-Object System.Collections.Generic.List[object]

foreach ($relativePathRaw in $coreWorkflowFiles) {
    $relativePath = $relativePathRaw -replace '\\', '/'
    $fullPath = Resolve-RepoFilePath -RepoRootPath $repoRootPath -RelativePath $relativePath
    if (-not (Test-Path -LiteralPath $fullPath -PathType Leaf)) {
        $violationList.Add([pscustomobject]@{
                Type    = 'missing-core-workflow'
                File    = $relativePath
                Line    = 0
                Pattern = '<file-exists>'
                Message = 'Required core workflow file is missing.'
            }) | Out-Null
    }
}

foreach ($relativePathRaw in ($pipelineContractFiles + '.github/workflows/development-mode-toggle.yml' + $manualOnlyWorkflowFiles)) {
    $relativePath = $relativePathRaw -replace '\\', '/'
    $fullPath = Resolve-RepoFilePath -RepoRootPath $repoRootPath -RelativePath $relativePath
    if (-not (Test-Path -LiteralPath $fullPath -PathType Leaf)) {
        continue
    }

    $lineItems = Get-Content -LiteralPath $fullPath -ErrorAction Stop

    if ($pipelineContractFiles -contains $relativePath) {
        $pipelineContractLine = 0
        for ($lineNumber = 1; $lineNumber -le $lineItems.Count; $lineNumber++) {
            $lineText = $lineItems[$lineNumber - 1].Trim()
            if ($lineText.StartsWith('#')) {
                continue
            }

            if ($lineText -match '^[''"]?pipeline-contract[''"]?\s*:') {
                $pipelineContractLine = $lineNumber
                break
            }
        }

        if ($pipelineContractLine -eq 0) {
            $violationList.Add([pscustomobject]@{
                    Type    = 'missing-pipeline-contract-job'
                    File    = $relativePath
                    Line    = 0
                    Pattern = 'jobs.pipeline-contract'
                    Message = 'pipeline-contract job is required.'
                }) | Out-Null
        }
    }

    $events = @(Get-WorkflowEventName -Lines $lineItems)
    if ($relativePath -eq '.github/workflows/development-mode-toggle.yml') {
        $allowedEvents = @('workflow_dispatch', 'workflow_call')
        $unexpectedEvents = @($events | Where-Object { $allowedEvents -notcontains $_ })
        if (($events -notcontains 'workflow_dispatch') -or $unexpectedEvents.Count -gt 0) {
            $violationList.Add([pscustomobject]@{
                    Type    = 'development-mode-toggle-not-manual'
                    File    = $relativePath
                    Line    = 0
                    Pattern = 'workflow_dispatch|workflow_call'
                    Message = 'development-mode-toggle workflow must use explicit manual triggers only (workflow_dispatch, optional workflow_call).'
                }) | Out-Null
        }
    }

    if ($manualOnlyWorkflowFiles -contains $relativePath) {
        if ($events.Count -ne 1 -or $events[0] -ne 'workflow_dispatch') {
            $violationList.Add([pscustomobject]@{
                    Type    = 'workflow-not-manual-only'
                    File    = $relativePath
                    Line    = 0
                    Pattern = 'on: workflow_dispatch'
                    Message = 'Collaboration-heavy workflow must be manual-only.'
                }) | Out-Null
        }
    }
}

$ciCompositePath = Resolve-RepoFilePath -RepoRootPath $repoRootPath -RelativePath '.github/workflows/ci-composite.yml'
if (Test-Path -LiteralPath $ciCompositePath -PathType Leaf) {
    $ciCompositeContent = Get-Content -LiteralPath $ciCompositePath -Raw -ErrorAction Stop

    if ($ciCompositeContent -match "publishMode\s*=\s*'auto'") {
        $violationList.Add([pscustomobject]@{
                Type    = 'publish-not-explicit-intent'
                File    = '.github/workflows/ci-composite.yml'
                Line    = 0
                Pattern = "publishMode = 'auto'"
                Message = 'Publish mode must not auto-publish on push. Manual intent is required.'
            }) | Out-Null
    }

    if ($ciCompositeContent -match 'develop-push-merged-pr-merge-commit') {
        $violationList.Add([pscustomobject]@{
                Type    = 'publish-auto-reason-present'
                File    = '.github/workflows/ci-composite.yml'
                Line    = 0
                Pattern = 'develop-push-merged-pr-merge-commit'
                Message = 'Legacy auto-publish reason token is forbidden in solo mode.'
            }) | Out-Null
    }

    if ($ciCompositeContent -notmatch 'manual-intent-required-develop-push') {
        $violationList.Add([pscustomobject]@{
                Type    = 'manual-intent-reason-missing'
                File    = '.github/workflows/ci-composite.yml'
                Line    = 0
                Pattern = 'manual-intent-required-develop-push'
                Message = 'Solo manual-intent publish reason token is required for develop push events.'
            }) | Out-Null
    }
}

if ($WriteSummary -and -not [string]::IsNullOrWhiteSpace($env:GITHUB_STEP_SUMMARY)) {
    if ($violationList.Count -eq 0) {
        @(
            '### Solo Maintainer Workflow Contract Guard'
            '- Status: pass'
            '- Result: solo-maintainer workflow contract validated.'
        ) | Out-File -FilePath $env:GITHUB_STEP_SUMMARY -Encoding utf8 -Append
    } else {
        @(
            '### Solo Maintainer Workflow Contract Guard'
            '- Status: fail'
            ("- Violations: {0}" -f $violationList.Count)
        ) | Out-File -FilePath $env:GITHUB_STEP_SUMMARY -Encoding utf8 -Append
    }
}

if ($violationList.Count -gt 0) {
    $formatted = $violationList | ForEach-Object {
        "{0}:{1} [{2}] {3}" -f $_.File, $_.Line, $_.Type, $_.Message
    }
    throw ("Solo-maintainer workflow contract violations detected:{0}{1}" -f [Environment]::NewLine, ($formatted -join [Environment]::NewLine))
}

Write-Host 'Solo-maintainer workflow contract guard passed with no violations.'
