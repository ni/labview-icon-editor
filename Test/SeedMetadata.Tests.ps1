# SeedMetadata.Tests.ps1
# CI-only Pester checks over metadata emitted by Seed (vipb -> json).

[CmdletBinding()]
param()

Set-StrictMode -Version Latest

$repoRoot     = Resolve-Path (Join-Path $PSScriptRoot '..')
$metadataPath = Join-Path $repoRoot 'artifacts/seed/metadata.json'

if (-not (Test-Path -LiteralPath $metadataPath)) {
    Describe "Seed metadata" -Skip:$true {
        It "skipped" { }
    }
    return
}

$metadata = $null
try {
    $metadata = Get-Content -LiteralPath $metadataPath -Raw | ConvertFrom-Json -ErrorAction Stop
}
catch {
    Describe "Seed metadata" -Skip:$true {
        It "could not parse metadata.json" { }
    }
    return
}

$root = $metadata.VI_Package_Builder_Settings
if (-not $root) { $root = $metadata.Package }
if (-not $root) {
    Describe "Seed metadata" -Skip:$true {
        It "missing expected root element in metadata.json" { }
    }
    return
}

$general     = $root.Library_General_Settings
$description = $root.Description
$advanced    = $root.Advanced_Settings
$labview     = $advanced.LabVIEW

Describe "Seed metadata (vipb json)" {
    It "has a package file name" {
        $general.Package_File_Name | Should -Not -BeNullOrEmpty
    }
    It "has a four-part library version" {
        $general.Library_Version | Should -Match '^\d+\.\d+\.\d+\.\d+$'
    }
    It "declares a LabVIEW version" {
        $general.Package_LabVIEW_Version | Should -Not -BeNullOrEmpty
    }
    It "has product name and license" {
        $general.Product_Name | Should -Not -BeNullOrEmpty
        $allowed = @('MIT','BSD-3','Apache-2.0','GPL-3.0-only','Proprietary')
        $general.Library_License | Should -BeIn $allowed
    }
    It "has descriptive metadata" {
        $description.Packager  | Should -Not -BeNullOrEmpty
        $description.Copyright | Should -Not -BeNullOrEmpty
    }
    It "has LabVIEW install flags set" {
        $labview.close_labview_before_install     | Should -Be 'true'
        $labview.restart_labview_after_install    | Should -Be 'true'
        $labview.skip_mass_compile_after_install  | Should -Be 'true'
        $labview.install_into_global_environment  | Should -Be 'false'
    }
}
