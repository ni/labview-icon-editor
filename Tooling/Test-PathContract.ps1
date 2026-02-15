#Requires -Version 7.0
[CmdletBinding()]
param(
    [string]$RepoRoot = '.',
    [switch]$WriteSummary
)

$ErrorActionPreference = 'Stop'
$windowsContainerShellContract = 'powershell.exe 5.1'

$repoRootPath = (Resolve-Path -Path $RepoRoot -ErrorAction Stop).Path
$allowedLiteralPathSet = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
@(
    '.github/workflows/labview-parity.yml',
    '.github/workflows/ci-composite.yml',
    'Tooling/container-parity/path-contract.sh',
    'Tooling/container-parity/runlabview-linux.sh',
    'Tooling/container-parity/runlabview-windows.ps1',
    'Tooling/container-parity/devmode-linux.sh',
    'Tooling/container-parity/build-vip-linux.sh',
    'Tooling/support/PathContract.ps1',
    'docs/ci/path-root-contract.md'
) | ForEach-Object {
    [void]$allowedLiteralPathSet.Add($_)
}

$scanRoots = @(
    '.github/workflows',
    'Tooling/container-parity',
    'Tooling/support',
    'docs/ci'
)
$includePatterns = @('*.yml', '*.yaml', '*.ps1', '*.psm1', '*.sh', '*.md')
$candidateFiles = New-Object System.Collections.Generic.List[System.IO.FileInfo]
foreach ($scanRoot in $scanRoots) {
    $fullScanRoot = Join-Path -Path $repoRootPath -ChildPath $scanRoot
    if (-not (Test-Path -LiteralPath $fullScanRoot -PathType Container)) {
        continue
    }

    $items = Get-ChildItem -Path $fullScanRoot -Recurse -File -Include $includePatterns -ErrorAction Stop
    foreach ($item in $items) {
        $candidateFiles.Add($item)
    }
}

$literalPatterns = @('/workspace', 'C:\workspace')
$violationList = New-Object System.Collections.Generic.List[object]
foreach ($file in $candidateFiles) {
    $relativePath = [System.IO.Path]::GetRelativePath($repoRootPath, $file.FullName) -replace '\\', '/'
    $lineItems = Get-Content -LiteralPath $file.FullName -ErrorAction Stop
    $lineNumber = 0
    foreach ($lineText in $lineItems) {
        $lineNumber++
        foreach ($pattern in $literalPatterns) {
            if ($lineText -notlike "*$pattern*") {
                continue
            }

            if ($allowedLiteralPathSet.Contains($relativePath)) {
                continue
            }

            $violationList.Add([pscustomobject]@{
                    Type    = 'hardcoded-root-literal'
                    File    = $relativePath
                    Line    = $lineNumber
                    Pattern = $pattern
                    Message = "Hardcoded root literal '$pattern' is not allowlisted."
                }) | Out-Null
        }
    }
}

$contractScriptList = @(
    'Tooling/container-parity/runlabview-linux.sh',
    'Tooling/container-parity/devmode-linux.sh',
    'Tooling/container-parity/build-vip-linux.sh',
    'Tooling/container-parity/runlabview-windows.ps1'
)
foreach ($relativePath in $contractScriptList) {
    $fullPath = Join-Path -Path $repoRootPath -ChildPath $relativePath
    if (-not (Test-Path -LiteralPath $fullPath -PathType Leaf)) {
        continue
    }

    $lineItems = Get-Content -LiteralPath $fullPath -ErrorAction Stop
    $lineNumber = 0
    foreach ($lineText in $lineItems) {
        $lineNumber++

        if ($relativePath -like '*.sh') {
            if ($lineText -match '\$WORKSPACE_ROOT/' -or $lineText -match '\$\{WORKSPACE_ROOT\}/') {
                $violationList.Add([pscustomobject]@{
                        Type    = 'direct-workspace-root-join'
                        File    = $relativePath
                        Line    = $lineNumber
                        Pattern = '$WORKSPACE_ROOT/...'
                        Message = 'Use join_lvie_repo_path helper instead of direct workspace-root concatenation.'
                    }) | Out-Null
            }
        } else {
            if ($lineText -match '(?<![A-Za-z0-9_])\$WorkspaceRoot(?![A-Za-z0-9_])\\' -or $lineText -match 'Join-Path\s+(-Path\s+)?\$WorkspaceRoot(?![A-Za-z0-9_])') {
                $violationList.Add([pscustomobject]@{
                        Type    = 'direct-workspace-root-join'
                        File    = $relativePath
                        Line    = $lineNumber
                        Pattern = '$WorkspaceRoot\\...'
                        Message = 'Use Join-LvieRepoPath helper instead of direct workspace-root concatenation.'
                    }) | Out-Null
            }
        }
    }
}

$pathContractRelativePath = 'Tooling/support/PathContract.ps1'
$pathContractFullPath = Join-Path -Path $repoRootPath -ChildPath $pathContractRelativePath
if (Test-Path -LiteralPath $pathContractFullPath -PathType Leaf) {
    $lineItems = Get-Content -LiteralPath $pathContractFullPath -ErrorAction Stop
    $lineNumber = 0
    foreach ($lineText in $lineItems) {
        $lineNumber++
        if ($lineText -match '^\s*#\s*requires\s+-version\b') {
            $violationList.Add([pscustomobject]@{
                    Type    = 'windows-container-shell-compat'
                    File    = ($pathContractRelativePath -replace '\\', '/')
                    Line    = $lineNumber
                    Pattern = '#Requires -Version'
                    Message = 'PathContract helper is imported by Windows container parity under powershell.exe 5.1; do not add #Requires -Version (prevents ScriptRequiresUnmatchedPSVersion).'
                }) | Out-Null
        }
    }
}

if ($WriteSummary -and -not [string]::IsNullOrWhiteSpace($env:GITHUB_STEP_SUMMARY)) {
    if ($violationList.Count -eq 0) {
        $summaryLines = @(
            '### Path Contract Guard'
            '- Status: pass'
            '- Result: no path-contract violations detected.'
            ("- Windows container shell contract: {0}" -f $windowsContainerShellContract)
            '- PathContract.ps1 compatibility: pass (no file-scope #Requires -Version).'
        )
        $summaryLines | Out-File -FilePath $env:GITHUB_STEP_SUMMARY -Encoding utf8 -Append
    } else {
        $summaryLines = @(
            '### Path Contract Guard'
            '- Status: fail'
            ("- Violations: {0}" -f $violationList.Count)
            ("- Windows container shell contract: {0}" -f $windowsContainerShellContract)
            '- PathContract.ps1 compatibility: fail (would trigger ScriptRequiresUnmatchedPSVersion).'
        )
        $summaryLines | Out-File -FilePath $env:GITHUB_STEP_SUMMARY -Encoding utf8 -Append
    }
}

if ($violationList.Count -gt 0) {
    $formatted = $violationList | ForEach-Object {
        "{0}:{1} [{2}] {3}" -f $_.File, $_.Line, $_.Type, $_.Message
    }
    throw ("Path contract violations detected:{0}{1}" -f [Environment]::NewLine, ($formatted -join [Environment]::NewLine))
}

Write-Host ("PathContract.ps1 compatibility with Windows container shell ({0}): pass" -f $windowsContainerShellContract)
Write-Host "Path contract guard passed with no violations."
