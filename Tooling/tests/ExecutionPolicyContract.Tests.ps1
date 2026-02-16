#Requires -Version 7.0
#Requires -Modules Pester

$ErrorActionPreference = 'Stop'

Describe 'Execution policy contract' {
    BeforeAll {
        $script:repoRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
        $script:allowedExecutionPolicies = @('RemoteSigned', 'AllSigned', 'Restricted', 'Undefined', 'Default')
        $script:disallowedPolicy = [string]([char[]](66, 121, 112, 97, 115, 115))

        $includePattern = '\.(yml|yaml|ps1|psm1|psd1|md|cs|json)$'
        $script:governedFiles = @(
            git -C $script:repoRoot ls-files |
                Where-Object { $_ -match $includePattern } |
                ForEach-Object { Join-Path $script:repoRoot $_ }
        )
    }

    It 'keeps tracked governed files free of disallowed execution-policy literal tokens' {
        $findings = New-Object 'System.Collections.Generic.List[string]'
        $disallowedEscaped = [regex]::Escape($script:disallowedPolicy)

        $patterns = @(
            ('(?im)(-ExecutionPolicy|ExecutionPolicy)\s+`?[''"]?' + $disallowedEscaped + '\b'),
            ('(?im)"-ExecutionPolicy"\s*,\s*"' + $disallowedEscaped + '"')
        )

        foreach ($file in $script:governedFiles) {
            $content = Get-Content -LiteralPath $file -Raw
            if ($null -eq $content) {
                $content = ''
            }
            foreach ($pattern in $patterns) {
                if ([regex]::IsMatch($content, $pattern)) {
                    $relativePath = [System.IO.Path]::GetRelativePath($script:repoRoot, $file).Replace('\', '/')
                    $findings.Add($relativePath)
                    break
                }
            }
        }

        @($findings) | Should -BeNullOrEmpty -Because ("disallowed execution-policy literal token found in: {0}" -f (($findings | Sort-Object -Unique) -join ', '))
    }

    It 'uses only allowlisted literal execution-policy values' {
        $findings = New-Object 'System.Collections.Generic.List[string]'

        foreach ($file in $script:governedFiles) {
            $content = Get-Content -LiteralPath $file -Raw
            if ($null -eq $content) {
                $content = ''
            }
            $relativePath = [System.IO.Path]::GetRelativePath($script:repoRoot, $file).Replace('\', '/')
            $extension = [System.IO.Path]::GetExtension($file).ToLowerInvariant()

            if ($extension -in @('.ps1', '.psm1', '.psd1', '.yml', '.yaml')) {
                $commandMatches = [regex]::Matches($content, '(?im)-ExecutionPolicy\s+[''"]?([A-Za-z]+)[''"]?')
                foreach ($match in $commandMatches) {
                    $policyValue = [string]$match.Groups[1].Value
                    if ($script:allowedExecutionPolicies -notcontains $policyValue) {
                        $findings.Add(("{0}:{1}" -f $relativePath, $policyValue))
                    }
                }
            }

            if ($extension -in @('.cs', '.json')) {
                $arrayMatches = [regex]::Matches($content, '(?im)"-ExecutionPolicy"\s*,\s*"([A-Za-z]+)"')
                foreach ($match in $arrayMatches) {
                    $policyValue = [string]$match.Groups[1].Value
                    if ($script:allowedExecutionPolicies -notcontains $policyValue) {
                        $findings.Add(("{0}:{1}" -f $relativePath, $policyValue))
                    }
                }
            }
        }

        @($findings) | Should -BeNullOrEmpty -Because ("non-allowlisted execution-policy literal values found: {0}" -f (($findings | Sort-Object -Unique) -join ', '))
    }
}
