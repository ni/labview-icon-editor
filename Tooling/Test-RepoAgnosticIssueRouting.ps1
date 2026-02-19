#Requires -Version 7.0
[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [string]$RepoRoot,

    [Parameter(Mandatory = $false)]
    [string[]]$TargetFiles
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

$resolvedRoot = Resolve-RepoRoot -PathOverride $RepoRoot

$defaultTargets = @(
    'AGENTS.md',
    'CONTRIBUTING.md',
    'Tooling/README.md',
    'docs/ci/actions/maintainers-guide.md',
    '.github/ISSUE_TEMPLATE/config.yml',
    '.github/ISSUE_TEMPLATE/feature_request.yml'
)

$targets = if ($TargetFiles -and $TargetFiles.Count -gt 0) { $TargetFiles } else { $defaultTargets }

$rules = @(
    [pscustomobject]@{
        Id = 'upstream-issues-url'
        Pattern = 'https://github\.com/ni/labview-icon-editor/issues'
        Message = 'Hardcoded upstream issue URL is not allowed. Use current-repository routing.'
    },
    [pscustomobject]@{
        Id = 'upstream-discussions-url'
        Pattern = 'https://github\.com/ni/labview-icon-editor/discussions'
        Message = 'Hardcoded upstream discussion URL is not allowed. Use current-repository routing.'
    },
    [pscustomobject]@{
        Id = 'fork-issues-url'
        Pattern = 'https://github\.com/svelderrainruiz/labview-icon-editor/issues'
        Message = 'Hardcoded fork issue URL is not allowed. Use current-repository routing.'
    },
    [pscustomobject]@{
        Id = 'fork-discussions-url'
        Pattern = 'https://github\.com/svelderrainruiz/labview-icon-editor/discussions'
        Message = 'Hardcoded fork discussion URL is not allowed. Use current-repository routing.'
    },
    [pscustomobject]@{
        Id = 'fixed-repo-flag-upstream'
        Pattern = '--repo\s+ni/labview-icon-editor'
        Message = 'Fixed --repo target is not allowed. Resolve current repository first and use --repo $repo.'
    },
    [pscustomobject]@{
        Id = 'fixed-repo-flag-fork'
        Pattern = '--repo\s+svelderrainruiz/labview-icon-editor'
        Message = 'Fixed --repo target is not allowed. Resolve current repository first and use --repo $repo.'
    },
    [pscustomobject]@{
        Id = 'gh-repo-view-auto-resolution'
        Pattern = 'gh repo view --json nameWithOwner --jq \.nameWithOwner'
        Message = 'gh repo view auto-resolution is not allowed. Use Tooling/Resolve-GitHubRepo.ps1.'
    }
)

$findings = New-Object System.Collections.Generic.List[object]

foreach ($relativePath in $targets) {
    $fullPath = if ([System.IO.Path]::IsPathRooted($relativePath)) {
        $relativePath
    } else {
        Join-Path $resolvedRoot $relativePath
    }

    if (-not (Test-Path -Path $fullPath)) {
        $findings.Add([pscustomobject]@{
            File = $relativePath
            Line = 1
            Rule = 'missing-file'
            Message = 'Target file not found.'
            Match = ''
        })
        continue
    }

    $lineNumber = 0
    Get-Content -Path $fullPath | ForEach-Object {
        $lineNumber++
        $line = $_
        foreach ($rule in $rules) {
            if ($line -match $rule.Pattern) {
                $findings.Add([pscustomobject]@{
                    File = $relativePath
                    Line = $lineNumber
                    Rule = $rule.Id
                    Message = $rule.Message
                    Match = $Matches[0]
                })
            }
        }
    }
}

if ($findings.Count -gt 0) {
    Write-Host 'Repo-agnostic issue/discussion routing check failed.'
    foreach ($finding in $findings) {
        Write-Host ("- {0}:{1} [{2}] {3} Match='{4}'" -f $finding.File, $finding.Line, $finding.Rule, $finding.Message, $finding.Match)
    }
    throw ("Found {0} repo-routing violation(s)." -f $findings.Count)
}

Write-Host ("Repo-agnostic issue/discussion routing check passed for {0} file(s)." -f $targets.Count)
