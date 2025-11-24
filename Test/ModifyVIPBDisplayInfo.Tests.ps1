$PSScriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$repoRoot = $null
$scriptPath = $null
$fixtureSource = $null
$tempRoot = $null

Describe "ModifyVIPBDisplayInfo.ps1" {
    BeforeAll {
        $script:repoRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot "..")).Path
        $script:scriptPath = Join-Path $script:repoRoot ".github/actions/modify-vipb-display-info/ModifyVIPBDisplayInfo.ps1"
        # Locate the single .vipb in the repo instead of hard-coding a fixture
        $vipbFiles = Get-ChildItem -Path $script:repoRoot -Filter *.vipb -File -Recurse
        if ($vipbFiles.Count -eq 1) {
            $script:fixtureSource = $vipbFiles[0].FullName
        } else {
            $script:fixtureSource = $null
            $script:failureReason = if ($vipbFiles.Count -eq 0) {
                "Expected a single .vipb in the repo but found none. The ModifyVIPBDisplayInfo test must gate the workflow."
            } else {
                "Expected a single .vipb in the repo but found $($vipbFiles.Count). The ModifyVIPBDisplayInfo test must gate the workflow."
            }
        }
        $script:tempRoot = Join-Path $script:repoRoot "Test/tmp"
        $script:hasFixture = [bool]$script:fixtureSource
        New-Item -ItemType Directory -Path $script:tempRoot -Force | Out-Null
    }

    AfterAll {
        if ($script:tempRoot -and (Test-Path $script:tempRoot)) {
            Remove-Item -Path $script:tempRoot -Recurse -Force
        }
    }

    It "updates VIPB metadata according to DisplayInformation JSON" {
        if (-not $script:hasFixture) {
            throw $script:failureReason
        }

        $vipbPath = Join-Path $script:tempRoot ("fixture_{0}.vipb" -f ([guid]::NewGuid().ToString("N")))
        Copy-Item -Path $fixtureSource -Destination $vipbPath

        $releaseNotesPath = Join-Path $script:tempRoot ("release_notes_{0}.md" -f ([guid]::NewGuid().ToString("N")))
        $releaseNotesContent = "Release notes content from file"
        Set-Content -Path $releaseNotesPath -Value $releaseNotesContent

        $displayInformation = [ordered]@{
            "Company Name"                 = "svelderrainruiz"
            "Product Name"                 = "labview-icon-editor"
            "Product Description Summary"  = "Source for LabVIEW's icon editor"
            "Product Description"          = "Source for LabVIEW's icon editor"
            "Author Name (Person or Company)" = "svelderrainruiz/labview-icon-editor"
            "Product Homepage (URL)"       = "https://github.com/svelderrainruiz/labview-icon-editor"
            "Legal Copyright"              = "© 2025 svelderrainruiz"
            "License Agreement Name"       = "LICENSE"
            "Release Notes - Change Log"   = $releaseNotesContent
            "Package Version"              = @{ major = 1; minor = 4; patch = 1; build = 1194 }
        }

        $displayInformationJson = $displayInformation | ConvertTo-Json -Depth 5
        $relativeVipbPath = [System.IO.Path]::GetRelativePath($repoRoot, $vipbPath)

        & $scriptPath `
            -SupportedBitness 64 `
            -RepositoryPath $repoRoot `
            -VIPBPath $relativeVipbPath `
            -Package_LabVIEW_Version 2023 `
            -LabVIEWMinorRevision 3 `
            -Major 1 `
            -Minor 4 `
            -Patch 1 `
            -Build 1194 `
            -Commit "deadbeef" `
            -ReleaseNotesFile $releaseNotesPath `
            -DisplayInformationJSON $displayInformationJson

        $vipbXml = [xml](Get-Content -Raw -Path $vipbPath)
        $generalSettings = $vipbXml.VI_Package_Builder_Settings.Library_General_Settings
        $descriptionSettings = $vipbXml.VI_Package_Builder_Settings.Advanced_Settings.Description
        $licenseSetting = $vipbXml.VI_Package_Builder_Settings.Advanced_Settings.License_Agreement_Filepath

        $generalSettings.Company_Name | Should -Be $displayInformation."Company Name"
        $generalSettings.Product_Name | Should -Be $displayInformation."Product Name"
        $descriptionSettings.One_Line_Description_Summary | Should -Be $displayInformation."Product Description Summary"
        $descriptionSettings.Packager | Should -Be $displayInformation."Author Name (Person or Company)"
        $descriptionSettings.URL | Should -Be $displayInformation."Product Homepage (URL)"
        # Some files include a trailing newline; trim for comparison
        $descriptionSettings.Release_Notes.Trim() | Should -Be $releaseNotesContent.Trim()
        $descriptionSettings.Description | Should -Match "Commit: deadbeef"
        # VIPB can emit an absolute path; assert on filename only
        (Split-Path -Leaf $licenseSetting) | Should -Be "LICENSE"
    }
}
