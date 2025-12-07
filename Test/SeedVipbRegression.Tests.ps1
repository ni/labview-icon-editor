# SeedVipbRegression.Tests.ps1
# Regression tests for Tooling/deployment/seed.vipb
# Ensures downstream consumers of Package_LabVIEW_Version and other fields don't regress.

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

Describe "Seed VIPB regression tests" {
    BeforeAll {
        $script:repoRoot = Resolve-Path (Join-Path $PSScriptRoot '..')
        $script:seedVipbPath = Join-Path $script:repoRoot 'Tooling/deployment/seed.vipb'
        $script:tempDir = Join-Path $script:repoRoot 'Test/tmp/seed-vipb-regression'
        $script:seedJsonPath = Join-Path $script:tempDir 'seed.json'
        $script:roundTripVipbPath = Join-Path $script:tempDir 'roundtrip.vipb'
        $script:roundTripJsonPath = Join-Path $script:tempDir 'roundtrip.json'

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
            '/repo/Test/tmp/seed-vipb-regression/seed.json'
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
        $script:advanced = $script:vipbData['Advanced_Settings']
        $script:customActions = if ($script:advanced) { $script:advanced['Custom_Action_VIs'] } else { $null }
        $script:description = if ($script:advanced) { $script:advanced['Description'] } else { $null }
        $script:destinations = if ($script:advanced) { $script:advanced['Destinations'] } else { $null }
    }

    AfterAll {
        if ($script:tempDir -and (Test-Path $script:tempDir)) {
            Remove-Item -LiteralPath $script:tempDir -Recurse -Force -ErrorAction SilentlyContinue
        }
    }

    Context "Core metadata fields" {
        It "has Package_LabVIEW_Version == '23.3 (64-bit)'" {
            if (-not $script:dockerAvailable -or -not $script:seedImageAvailable) {
                Set-ItResult -Skipped -Because "Docker or seed:latest image not available"
                return
            }
            $script:general['Package_LabVIEW_Version'] | Should -Be '23.3 (64-bit)'
        }

        It "has Library_Version == '0.1.0.1'" {
            if (-not $script:dockerAvailable -or -not $script:seedImageAvailable) {
                Set-ItResult -Skipped -Because "Docker or seed:latest image not available"
                return
            }
            $script:general['Library_Version'] | Should -Be '0.1.0.1'
        }

        It "has Package_File_Name == 'NI_Icon_editor'" {
            if (-not $script:dockerAvailable -or -not $script:seedImageAvailable) {
                Set-ItResult -Skipped -Because "Docker or seed:latest image not available"
                return
            }
            $script:general['Package_File_Name'] | Should -Be 'NI_Icon_editor'
        }

        It "has Company_Name == 'svelderrainruiz'" {
            if (-not $script:dockerAvailable -or -not $script:seedImageAvailable) {
                Set-ItResult -Skipped -Because "Docker or seed:latest image not available"
                return
            }
            $script:general['Company_Name'] | Should -Be 'svelderrainruiz'
        }

        It "has Product_Name == 'LabVIEW Icon Editor'" {
            if (-not $script:dockerAvailable -or -not $script:seedImageAvailable) {
                Set-ItResult -Skipped -Because "Docker or seed:latest image not available"
                return
            }
            $script:general['Product_Name'] | Should -Be 'LabVIEW Icon Editor'
        }

        It "has Library_License == 'MIT'" {
            if (-not $script:dockerAvailable -or -not $script:seedImageAvailable) {
                Set-ItResult -Skipped -Because "Docker or seed:latest image not available"
                return
            }
            $script:general['Library_License'] | Should -Be 'MIT'
        }
    }

    Context "Custom action VIs" {
        It "has Pre-Build_VI == null" {
            if (-not $script:dockerAvailable -or -not $script:seedImageAvailable) {
                Set-ItResult -Skipped -Because "Docker or seed:latest image not available"
                return
            }
            $script:customActions | Should -Not -BeNullOrEmpty
            $script:customActions['Pre-Build_VI'] | Should -BeNullOrEmpty
        }

        It "has Post-Build_VI == null" {
            if (-not $script:dockerAvailable -or -not $script:seedImageAvailable) {
                Set-ItResult -Skipped -Because "Docker or seed:latest image not available"
                return
            }
            $script:customActions | Should -Not -BeNullOrEmpty
            $script:customActions['Post-Build_VI'] | Should -BeNullOrEmpty
        }

        It "has Pre-Install_VI == null" {
            if (-not $script:dockerAvailable -or -not $script:seedImageAvailable) {
                Set-ItResult -Skipped -Because "Docker or seed:latest image not available"
                return
            }
            $script:customActions | Should -Not -BeNullOrEmpty
            $script:customActions['Pre-Install_VI'] | Should -BeNullOrEmpty
        }

        It "has Post-Install_VI == null" {
            if (-not $script:dockerAvailable -or -not $script:seedImageAvailable) {
                Set-ItResult -Skipped -Because "Docker or seed:latest image not available"
                return
            }
            $script:customActions | Should -Not -BeNullOrEmpty
            $script:customActions['Post-Install_VI'] | Should -BeNullOrEmpty
        }

        It "has Pre-Uninstall_VI == null" {
            if (-not $script:dockerAvailable -or -not $script:seedImageAvailable) {
                Set-ItResult -Skipped -Because "Docker or seed:latest image not available"
                return
            }
            $script:customActions | Should -Not -BeNullOrEmpty
            $script:customActions['Pre-Uninstall_VI'] | Should -BeNullOrEmpty
        }

        It "has Post-Uninstall_VI == null" {
            if (-not $script:dockerAvailable -or -not $script:seedImageAvailable) {
                Set-ItResult -Skipped -Because "Docker or seed:latest image not available"
                return
            }
            $script:customActions | Should -Not -BeNullOrEmpty
            $script:customActions['Post-Uninstall_VI'] | Should -BeNullOrEmpty
        }
    }

    Context "Advanced settings" {
        It "has VI_Package_Configuration_File == 'seed.vipc'" {
            if (-not $script:dockerAvailable -or -not $script:seedImageAvailable) {
                Set-ItResult -Skipped -Because "Docker or seed:latest image not available"
                return
            }
            $script:advanced | Should -Not -BeNullOrEmpty
            $script:advanced['VI_Package_Configuration_File'] | Should -Be 'seed.vipc'
        }

        It "has Description.Packager == 'svelderrainruiz'" {
            if (-not $script:dockerAvailable -or -not $script:seedImageAvailable) {
                Set-ItResult -Skipped -Because "Docker or seed:latest image not available"
                return
            }
            $script:description | Should -Not -BeNullOrEmpty
            $script:description['Packager'] | Should -Be 'svelderrainruiz'
        }
    }

    Context "Destinations" {
        It "includes LVAddons destination" {
            if (-not $script:dockerAvailable -or -not $script:seedImageAvailable) {
                Set-ItResult -Skipped -Because "Docker or seed:latest image not available"
                return
            }
            $script:destinations | Should -Not -BeNullOrEmpty
            
            # Check if there's an LVAddons in Additional_Destination array
            $lvaddonsFound = $false
            
            # Check Additional_Destination (can be array or single object)
            $additionalDests = $script:destinations['Additional_Destination']
            if ($additionalDests) {
                if ($additionalDests -is [array]) {
                    foreach ($dest in $additionalDests) {
                        if ($dest -is [hashtable]) {
                            $name = $dest['Name']
                            $path = $dest['Path']
                            if ($name -match 'LVAddons' -or $path -match 'LVAddons|niiconeditor64') {
                                $lvaddonsFound = $true
                                break
                            }
                        }
                    }
                } elseif ($additionalDests -is [hashtable]) {
                    $name = $additionalDests['Name']
                    $path = $additionalDests['Path']
                    if ($name -match 'LVAddons' -or $path -match 'LVAddons|niiconeditor64') {
                        $lvaddonsFound = $true
                    }
                }
            }
            
            # Also check other destination types
            if (-not $lvaddonsFound) {
                foreach ($key in $script:destinations.Keys) {
                    if ($key -eq '#whitespace') { continue }
                    $dest = $script:destinations[$key]
                    if ($dest -is [hashtable] -and $dest.ContainsKey('Path')) {
                        $path = $dest['Path']
                        if ($path -match 'LVAddons|niiconeditor64') {
                            $lvaddonsFound = $true
                            break
                        }
                    }
                }
            }
            
            $lvaddonsFound | Should -BeTrue -Because "Destinations should include an LVAddons path with niiconeditor64"
        }
    }

    Context "Round-trip test" {
        It "preserves fields after json2vipb -> vipb2json round-trip" {
            if (-not $script:dockerAvailable -or -not $script:seedImageAvailable) {
                Set-ItResult -Skipped -Because "Docker or seed:latest image not available"
                return
            }
            # Convert JSON back to VIPB
            $dockerArgs = @(
                'run', '--rm',
                '-v', "${script:repoRoot}:/repo",
                '-w', '/repo',
                '--entrypoint', '/usr/local/bin/VipbJsonTool',
                'seed:latest',
                'json2vipb',
                "/repo/Test/tmp/seed-vipb-regression/seed.json",
                "/repo/Test/tmp/seed-vipb-regression/roundtrip.vipb"
            )
            
            $json2vipbOutput = & docker @dockerArgs 2>&1
            if ($LASTEXITCODE -ne 0) {
                Write-Host "json2vipb output: $json2vipbOutput"
            }
            $LASTEXITCODE | Should -Be 0 -Because "json2vipb should succeed"

            # Convert the round-trip VIPB back to JSON
            $dockerArgs = @(
                'run', '--rm',
                '-v', "${script:repoRoot}:/repo",
                '-w', '/repo',
                '--entrypoint', '/usr/local/bin/VipbJsonTool',
                'seed:latest',
                'vipb2json',
                "/repo/Test/tmp/seed-vipb-regression/roundtrip.vipb",
                "/repo/Test/tmp/seed-vipb-regression/roundtrip.json"
            )
            
            $vipb2jsonRtOutput = & docker @dockerArgs 2>&1
            if ($LASTEXITCODE -ne 0) {
                Write-Host "vipb2json output: $vipb2jsonRtOutput"
            }
            $LASTEXITCODE | Should -Be 0 -Because "vipb2json on round-trip VIPB should succeed"

            # Parse the round-trip JSON
            $roundTripData = Get-Content -LiteralPath $script:roundTripJsonPath -Raw | ConvertFrom-Json -AsHashtable -ErrorAction Stop
            $rtGeneral = $roundTripData['Library_General_Settings']
            $rtAdvanced = $roundTripData['Advanced_Settings']

            # Assert key fields are preserved (ignoring IDs and timestamps)
            $rtGeneral['Package_LabVIEW_Version'] | Should -Be $script:general['Package_LabVIEW_Version']
            $rtGeneral['Library_Version'] | Should -Be $script:general['Library_Version']
            $rtGeneral['Package_File_Name'] | Should -Be $script:general['Package_File_Name']
            $rtGeneral['Company_Name'] | Should -Be $script:general['Company_Name']
            $rtGeneral['Product_Name'] | Should -Be $script:general['Product_Name']
            $rtGeneral['Library_License'] | Should -Be $script:general['Library_License']
            $rtAdvanced['VI_Package_Configuration_File'] | Should -Be $script:advanced['VI_Package_Configuration_File']
        }
    }
}
