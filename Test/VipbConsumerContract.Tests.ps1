# VipbConsumerContract.Tests.ps1
# Consumer contract tests for Package_LabVIEW_Version parsing
# Ensures downstream consumers can reliably extract major, minor, and bitness from seed.vipb

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

Describe "VIPB consumer contract tests" {
    BeforeAll {
        $script:repoRoot = Resolve-Path (Join-Path $PSScriptRoot '..')
        $script:seedVipbPath = Join-Path $script:repoRoot 'Tooling/deployment/seed.vipb'
        $script:tempDir = Join-Path $script:repoRoot 'Test/tmp/vipb-consumer-contract'
        $script:seedJsonPath = Join-Path $script:tempDir 'seed.json'
        
        # Expected values (single source of truth)
        $script:expectedLVVersion = '23.3 (64-bit)'
        $script:expectedMajor = 2023
        $script:expectedMinor = 3
        $script:expectedBitness = 64
        
        # Shared regex pattern for version parsing
        $script:versionPattern = '(\d{2,4})\.(\d+)\s*\((\d+)-bit\)'

        # Ensure temp directory exists
        if (-not (Test-Path $script:tempDir)) {
            New-Item -ItemType Directory -Path $script:tempDir -Force | Out-Null
        }

        # Check if Docker is available
        $script:dockerAvailable = $false
        $script:seedImageAvailable = $false
        try {
            $dockerVersion = docker --version 2>&1
            if ($LASTEXITCODE -eq 0) {
                $script:dockerAvailable = $true
                
                # Check if seed:latest image is available
                $imageCheck = docker images -q seed:latest 2>&1
                if ($LASTEXITCODE -eq 0 -and $imageCheck) {
                    $script:seedImageAvailable = $true
                }
            }
        }
        catch {
            $script:dockerAvailable = $false
        }

        if (-not $script:dockerAvailable) {
            Set-ItResult -Skipped -Because "Docker is not available"
            return
        }

        if (-not $script:seedImageAvailable) {
            Set-ItResult -Skipped -Because "seed:latest Docker image is not available. Build it with: docker build -f Tooling/seed/Dockerfile -t seed:latest ."
            return
        }

        # Convert VIPB to JSON using Docker
        $dockerArgs = @(
            'run', '--rm',
            '-v', "${script:repoRoot}:/repo",
            '-w', '/repo',
            '--entrypoint', '/usr/local/bin/VipbJsonTool',
            'seed:latest',
            'vipb2json',
            '/repo/Tooling/deployment/seed.vipb',
            '/repo/Test/tmp/vipb-consumer-contract/seed.json'
        )
        
        $vipb2jsonOutput = & docker @dockerArgs 2>&1
        if ($LASTEXITCODE -ne 0) {
            Write-Host "vipb2json output: $vipb2jsonOutput"
            throw "vipb2json failed with exit code $LASTEXITCODE"
        }

        if (-not (Test-Path $script:seedJsonPath)) {
            throw "vipb2json did not produce JSON at $script:seedJsonPath"
        }

        # Parse the JSON
        try {
            $script:vipbData = Get-Content -LiteralPath $script:seedJsonPath -Raw | ConvertFrom-Json -AsHashtable -ErrorAction Stop
        }
        catch {
            throw "Could not parse seed.json: $($_.Exception.Message)"
        }

        # The JSON structure has attributes at the root level with @ prefix
        # and child elements like Library_General_Settings directly under root
        $script:general = $script:vipbData['Library_General_Settings']
        $script:packageLVVersion = $script:general['Package_LabVIEW_Version']
    }

    AfterAll {
        if ($script:tempDir -and (Test-Path $script:tempDir)) {
            try {
                Remove-Item -LiteralPath $script:tempDir -Recurse -Force -ErrorAction Stop
            }
            catch {
                Write-Warning "Could not remove temp directory '$script:tempDir': $($_.Exception.Message)"
            }
        }
    }

    Context "Package_LabVIEW_Version contract" {
        It "has exact string '23.3 (64-bit)'" {
            if (-not $script:dockerAvailable -or -not $script:seedImageAvailable) {
                Set-ItResult -Skipped -Because "Docker or seed:latest image not available"
                return
            }
            $script:packageLVVersion | Should -Be $script:expectedLVVersion -Because @"
Package_LabVIEW_Version mismatch detected!

Expected: '$script:expectedLVVersion'
Actual:   '$($script:packageLVVersion)'

If you need to change the LabVIEW version in seed.vipb:
1. Update Tooling/deployment/seed.vipb
2. Update this test's expected value in BeforeAll
3. Update all downstream consumers that parse Package_LabVIEW_Version
4. Update documentation referencing the LabVIEW version

This test exists to prevent accidental version drift.
"@
        }

        It "can be parsed to extract major version (2023)" {
            if (-not $script:dockerAvailable -or -not $script:seedImageAvailable) {
                Set-ItResult -Skipped -Because "Docker or seed:latest image not available"
                return
            }
            # Parse the version string to extract major version
            # Expected format: "23.3 (64-bit)" or "2023.3 (64-bit)"
            $match = [regex]::Match($script:packageLVVersion, $script:versionPattern)
            $match.Success | Should -BeTrue -Because "Package_LabVIEW_Version should match pattern 'XX.Y (ZZ-bit)'"
            
            $majorStr = $match.Groups[1].Value
            [int]$major = 0
            [int]::TryParse($majorStr, [ref]$major) | Should -BeTrue
            
            # Normalize: if 2-digit year, add 2000
            if ($major -lt 100) {
                $major += 2000
            }
            
            $major | Should -Be $script:expectedMajor -Because "Major version should be $script:expectedMajor for LabVIEW $script:expectedLVVersion"
        }

        It "can be parsed to extract minor version (3)" {
            if (-not $script:dockerAvailable -or -not $script:seedImageAvailable) {
                Set-ItResult -Skipped -Because "Docker or seed:latest image not available"
                return
            }
            $match = [regex]::Match($script:packageLVVersion, $script:versionPattern)
            $match.Success | Should -BeTrue
            
            $minorStr = $match.Groups[2].Value
            [int]$minor = 0
            [int]::TryParse($minorStr, [ref]$minor) | Should -BeTrue
            
            $minor | Should -Be $script:expectedMinor -Because "Minor version should be $script:expectedMinor for LabVIEW $script:expectedLVVersion"
        }

        It "can be parsed to extract bitness (64)" {
            if (-not $script:dockerAvailable -or -not $script:seedImageAvailable) {
                Set-ItResult -Skipped -Because "Docker or seed:latest image not available"
                return
            }
            $match = [regex]::Match($script:packageLVVersion, $script:versionPattern)
            $match.Success | Should -BeTrue
            
            $bitnessStr = $match.Groups[3].Value
            [int]$bitness = 0
            [int]::TryParse($bitnessStr, [ref]$bitness) | Should -BeTrue
            
            $bitness | Should -Be $script:expectedBitness -Because "Bitness should be $script:expectedBitness for 64-bit LabVIEW"
        }
    }

    Context "Parseability guarantees" {
        It "Package_LabVIEW_Version is not null or empty" {
            if (-not $script:dockerAvailable -or -not $script:seedImageAvailable) {
                Set-ItResult -Skipped -Because "Docker or seed:latest image not available"
                return
            }
            $script:packageLVVersion | Should -Not -BeNullOrEmpty -Because "Package_LabVIEW_Version must always be populated"
        }

        It "Package_LabVIEW_Version contains expected pattern" {
            if (-not $script:dockerAvailable -or -not $script:seedImageAvailable) {
                Set-ItResult -Skipped -Because "Docker or seed:latest image not available"
                return
            }
            # Ensure it matches the expected format for reliable parsing
            $script:packageLVVersion | Should -Match '^\d{2,4}\.\d+\s*\(\d+-bit\)$' -Because "Version string must follow pattern 'XX.Y (ZZ-bit)'"
        }
    }
}
