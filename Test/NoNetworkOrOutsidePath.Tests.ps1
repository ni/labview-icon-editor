param(
    [string]$RepoRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..')).ProviderPath
)

$targetRoots = @()
$scriptsTest = Join-Path $RepoRoot 'scripts\test'
if (Test-Path -LiteralPath $scriptsTest) { $targetRoots += $scriptsTest }
$scriptsUnit = Join-Path $RepoRoot 'scripts\run-unit-tests'
if (Test-Path -LiteralPath $scriptsUnit) { $targetRoots += $scriptsUnit }

$scriptFiles = $targetRoots | ForEach-Object {
    Get-ChildItem -LiteralPath $_ -Recurse -File -Include *.ps1,*.psm1,*.sh,*.cmd,*.bat
}

Describe "Repo hygiene: no network or out-of-repo commands" {
    It "contains no network-invoking commands in test harness scripts" {
        $bannedPatterns = @('Invoke-WebRequest','Invoke-RestMethod','curl\s','wget\s','http://','https://')
        $hits = @()
        foreach ($file in $scriptFiles) {
            $lineNumber = 0
            Get-Content -LiteralPath $file.FullName | ForEach-Object {
                $lineNumber++
                if ($_ -match '^\s*[#;]') { return }
                foreach ($pat in $bannedPatterns) {
                    if ($_ -match $pat) {
                        $hits += [pscustomobject]@{ File = $file.FullName; Line = $lineNumber; Pattern = $pat; Text = $_ }
                    }
                }
            }
        }
        $hits | Should -BeNullOrEmpty
    }

    It "contains no hard-coded absolute paths outside the repo root in test harness scripts" {
        $escapedRoot = [regex]::Escape($RepoRoot)
        $pattern = "(?i)(?:[A-Z]:\\|//)(?!$escapedRoot)"
        $hits = @()
        foreach ($file in $scriptFiles) {
            $lineNumber = 0
            Get-Content -LiteralPath $file.FullName | ForEach-Object {
                $lineNumber++
                if ($_ -match '^\s*[#;]') { return }
                if ($_ -match $pattern) {
                    $hits += [pscustomobject]@{ File = $file.FullName; Line = $lineNumber; Text = $_ }
                }
            }
        }
        $hits | Should -BeNullOrEmpty
    }
}
