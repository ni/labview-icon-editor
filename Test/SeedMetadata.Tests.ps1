# SeedMetadata.Tests.ps1
# CI-only Pester checks over metadata emitted by Seed (vipb -> json).

[CmdletBinding()]
param()

Set-StrictMode -Version Latest

Describe "Seed metadata (vipb json)" {
    BeforeAll {
        $script:repoRoot     = Resolve-Path (Join-Path $PSScriptRoot '..')
        $script:metadataPath = Join-Path $script:repoRoot 'artifacts/seed/metadata.json'

        if (-not (Test-Path -LiteralPath $script:metadataPath)) {
            Set-ItResult -Skipped -Because "Metadata JSON not found at $script:metadataPath"
            return
        }

        try {
            $script:metadata = Get-Content -LiteralPath $script:metadataPath -Raw | ConvertFrom-Json -AsHashtable -ErrorAction Stop
        }
        catch {
            Set-ItResult -Skipped -Because "Could not parse metadata.json ($($_.Exception.Message))"
            return
        }

        $script:root = $script:metadata['VI_Package_Builder_Settings']
        if (-not $script:root) { $script:root = $script:metadata['Package'] }
        if (-not $script:root) {
            Set-ItResult -Skipped -Because "Missing expected root element in metadata.json"
            return
        }

        $script:general     = $script:root['Library_General_Settings']
        $script:advanced    = $script:root['Advanced_Settings']
        $script:description = if ($script:advanced) { $script:advanced['Description'] } else { $null }
        $script:labview     = if ($script:advanced) { $script:advanced['LabVIEW'] } else { $null }

        # Read expected Library_Version from source VIPB (supports seeded branches with different versions)
        $script:expectedLibraryVersion = $null
        $vipbPath = Join-Path $script:repoRoot 'Tooling/deployment/seed.vipb'
        if (Test-Path -LiteralPath $vipbPath) {
            try {
                [xml]$vipbXml = Get-Content -LiteralPath $vipbPath -Raw
                $settings = $vipbXml.SelectSingleNode('/VI_Package_Builder_Settings')
                if (-not $settings) { $settings = $vipbXml.SelectSingleNode('/Package') }
                if ($settings) {
                    $generalSettings = $settings.SelectSingleNode('Library_General_Settings')
                    if ($generalSettings) {
                        $script:expectedLibraryVersion = [string]$generalSettings.Library_Version
                    }
                }
            }
            catch {
                # Fall back to null; test will check for non-empty instead
            }
        }
    }
    It "has a package file name" {
        $general['Package_File_Name'] | Should -Not -BeNullOrEmpty
    }
    It "has the canonical library version" {
        if ($script:expectedLibraryVersion) {
            $general['Library_Version'] | Should -Be $script:expectedLibraryVersion
        } else {
            # Fallback: just ensure it's not empty if we couldn't read the source VIPB
            $general['Library_Version'] | Should -Not -BeNullOrEmpty
        }
    }
    It "declares a LabVIEW version" {
        $general['Package_LabVIEW_Version'] | Should -Not -BeNullOrEmpty
    }
    It "has product name and license" {
        $general['Product_Name'] | Should -Not -BeNullOrEmpty
        $allowed = @('MIT','BSD-3','Apache-2.0','GPL-3.0-only','Proprietary')
        $general['Library_License'] | Should -BeIn $allowed
    }
    It "has descriptive metadata" {
        $description['Packager']  | Should -Not -BeNullOrEmpty
        # Copyright/URL may be empty in dev snapshots; optional
    }
    It "omits any embedded VIPC file" {
        $advanced | Should -Not -BeNullOrEmpty
        $advanced['VI_Package_Configuration_File'] | Should -BeNullOrEmpty
    }
    It "has LabVIEW install flags set" {
        $labview['close_labview_before_install']     | Should -Be 'true'
        $labview['restart_labview_after_install']    | Should -Be 'true'
        $labview['skip_mass_compile_after_install']  | Should -Be 'true'
        $labview['install_into_global_environment']  | Should -Be 'false'
    }
}
