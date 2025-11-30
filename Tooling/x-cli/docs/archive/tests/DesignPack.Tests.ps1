# Legacy Pester test for design pack generation (archived)
Describe "Design Pack (design preset)" {
    BeforeAll {
        $tmpDir         = Join-Path $PSScriptRoot "tmp"
        if (Test-Path $tmpDir) { Remove-Item $tmpDir -Recurse -Force }
        New-Item -Type Directory -Path $tmpDir | Out-Null

        $designZip      = Join-Path $tmpDir "design_pack.zip"
        $designExtract  = Join-Path $tmpDir "extracted_design"
        $packScript     = (Resolve-Path "$PSScriptRoot/../../scripts/jarvis-pack.ps1").Path

        # Run pack script with design preset
        & $packScript -Preset "design" -Output $designZip
        Expand-Archive -Path $designZip -DestinationPath $designExtract -Force

        # Load manifest JSON from design pack
        $designManifest = Get-Content -Path (Join-Path $designExtract "MANIFEST.json") -Raw | ConvertFrom-Json
    }
    It "includes the expected files in the ZIP" {
        Test-Path (Join-Path $designExtract "AGENTS.md") | Should -BeTrue
        Test-Path (Join-Path $designExtract "docs/traceability.yaml") | Should -BeTrue
        Test-Path (Join-Path $designExtract "scripts/validate_design.py") | Should -BeTrue
        Test-Path (Join-Path $designExtract ".github/workflows/design-lock.yml") | Should -BeTrue
        Test-Path (Join-Path $designExtract "MANIFEST.json") | Should -BeTrue
    }
    It "generates a correct MANIFEST.json with SHA256 and size for each file" {
        $expectedFiles = @(
            "AGENTS.md",
            "docs/traceability.yaml",
            "scripts/validate_design.py",
            ".github/workflows/design-lock.yml"
        )
        foreach ($relPath in $expectedFiles) {
            $entry = $designManifest | Where-Object { $_.path -eq $relPath }
            $entry | Should -Not -Be $null

            $filePath = Join-Path $designExtract $relPath
            (Get-FileHash -Algorithm SHA256 -Path $filePath).Hash | Should -Be $entry.sha256
            (Get-Item $filePath).Length | Should -Be $entry.size
        }
    }
    It "produces the same content for 'full' preset alias" {
        $fullZip     = Join-Path $tmpDir "design_full_pack.zip"
        $fullExtract = Join-Path $tmpDir "extracted_full"
        # Run pack script with 'full' alias preset
        if (Test-Path $fullZip) { Remove-Item $fullZip -Force }
        & $packScript -Preset "full" -Output $fullZip
        Expand-Archive -Path $fullZip -DestinationPath $fullExtract -Force

        $fullManifest = Get-Content -Path (Join-Path $fullExtract "MANIFEST.json") -Raw | ConvertFrom-Json
        # Compare manifest entries between design and full packs (should be identical)
        $diff = Compare-Object -ReferenceObject $designManifest -DifferenceObject $fullManifest -Property path, sha256, size
        $diff.Count | Should -Be 0  # no differences expected
    }
    AfterAll {
        Remove-Item $tmpDir -Recurse -Force
    }
}
