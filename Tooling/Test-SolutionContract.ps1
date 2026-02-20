#Requires -Version 7.0
[CmdletBinding()]
param(
    [string]$RepoRoot = '.',
    [switch]$WriteSummary
)

$ErrorActionPreference = 'Stop'

function Add-ContractViolation {
    param(
        [System.Collections.Generic.List[object]]$Violations,
        [string]$Type,
        [string]$Message
    )

    $Violations.Add([pscustomobject]@{
            Type    = $Type
            Message = $Message
        }) | Out-Null
}

function Test-PathUnderRoot {
    param(
        [Parameter(Mandatory = $true)]
        [string]$RootPath,
        [Parameter(Mandatory = $true)]
        [string]$CandidatePath
    )

    $normalizedRoot = [System.IO.Path]::GetFullPath($RootPath).TrimEnd('\', '/')
    $normalizedCandidate = [System.IO.Path]::GetFullPath($CandidatePath)

    if ($normalizedCandidate.Equals($normalizedRoot, [System.StringComparison]::OrdinalIgnoreCase)) {
        return $true
    }

    $rootWithSeparator = $normalizedRoot + [System.IO.Path]::DirectorySeparatorChar
    return $normalizedCandidate.StartsWith($rootWithSeparator, [System.StringComparison]::OrdinalIgnoreCase)
}

$repoRootPath = (Resolve-Path -Path $RepoRoot -ErrorAction Stop).Path
$solutionRelativePath = 'labview-icon-editor.sln'
$solutionPath = Join-Path $repoRootPath $solutionRelativePath

$requiredProjectPaths = @(
    'Tooling\runner-cli\RunnerCli\RunnerCli.csproj',
    'Tooling\runner-cli\RunnerCli.Tests\RunnerCli.Tests.csproj'
)

$violations = New-Object System.Collections.Generic.List[object]
$solutionProjectRelativePaths = New-Object System.Collections.Generic.List[string]

if (-not (Test-Path -LiteralPath $solutionPath -PathType Leaf)) {
    Add-ContractViolation -Violations $violations -Type 'missing-solution-file' -Message ("Required solution file not found: {0}" -f $solutionPath)
} else {
    $solutionContent = Get-Content -LiteralPath $solutionPath -Raw -ErrorAction Stop
    $projectMatches = [regex]::Matches(
        $solutionContent,
        '(?m)^\s*Project\("(?<type>[^"]+)"\)\s*=\s*"(?<name>[^"]+)"\s*,\s*"(?<path>[^"]+)"\s*,\s*"\{[^"]+\}"\s*$'
    )

    foreach ($match in $projectMatches) {
        $projectPathValue = [string]$match.Groups['path'].Value
        if (-not $projectPathValue.EndsWith('.csproj', [System.StringComparison]::OrdinalIgnoreCase)) {
            continue
        }

        $projectRelativePath = ($projectPathValue -replace '/', '\').Trim()
        $projectRelativePathNative = $projectRelativePath -replace '[\\/]', [System.IO.Path]::DirectorySeparatorChar
        $solutionProjectRelativePaths.Add($projectRelativePath) | Out-Null
        $projectFullPath = [System.IO.Path]::GetFullPath((Join-Path $repoRootPath $projectRelativePathNative))

        if (-not (Test-PathUnderRoot -RootPath $repoRootPath -CandidatePath $projectFullPath)) {
            Add-ContractViolation -Violations $violations -Type 'solution-project-outside-repo' -Message ("Solution project path '{0}' resolves outside repository root." -f $projectRelativePath)
            continue
        }

        if (-not (Test-Path -LiteralPath $projectFullPath -PathType Leaf)) {
            Add-ContractViolation -Violations $violations -Type 'solution-project-file-missing' -Message ("Solution project path '{0}' does not exist: {1}" -f $projectRelativePath, $projectFullPath)
        }
    }

    foreach ($requiredPath in $requiredProjectPaths) {
        $requiredNormalized = ($requiredPath -replace '/', '\')
        $requiredNative = $requiredNormalized -replace '[\\/]', [System.IO.Path]::DirectorySeparatorChar
        $entryExists = $false
        foreach ($entryPath in $solutionProjectRelativePaths) {
            if ($entryPath.Equals($requiredNormalized, [System.StringComparison]::OrdinalIgnoreCase)) {
                $entryExists = $true
                break
            }
        }

        if (-not $entryExists) {
            Add-ContractViolation -Violations $violations -Type 'missing-required-solution-project' -Message ("Solution must include project '{0}'." -f $requiredNormalized)
        }

        $requiredFullPath = [System.IO.Path]::GetFullPath((Join-Path $repoRootPath $requiredNative))
        if (-not (Test-Path -LiteralPath $requiredFullPath -PathType Leaf)) {
            Add-ContractViolation -Violations $violations -Type 'required-solution-project-file-missing' -Message ("Required project file not found: {0}" -f $requiredFullPath)
        }
    }
}

if ($WriteSummary -and -not [string]::IsNullOrWhiteSpace($env:GITHUB_STEP_SUMMARY)) {
    if ($violations.Count -eq 0) {
        @(
            '### Solution Contract Guard'
            '- Status: pass'
            ("- Solution file: {0}" -f $solutionRelativePath)
            ("- Tracked C# projects: {0}" -f $solutionProjectRelativePaths.Count)
        ) | Out-File -FilePath $env:GITHUB_STEP_SUMMARY -Encoding utf8 -Append
    } else {
        @(
            '### Solution Contract Guard'
            '- Status: fail'
            ("- Violations: {0}" -f $violations.Count)
            ("- Solution file: {0}" -f $solutionRelativePath)
        ) | Out-File -FilePath $env:GITHUB_STEP_SUMMARY -Encoding utf8 -Append
    }
}

if ($violations.Count -gt 0) {
    $formatted = $violations | ForEach-Object {
        "[{0}] {1}" -f $_.Type, $_.Message
    }
    throw ("Solution contract violations detected:{0}{1}" -f [Environment]::NewLine, ($formatted -join [Environment]::NewLine))
}

Write-Host ("Solution contract guard passed: {0}" -f $solutionPath)
