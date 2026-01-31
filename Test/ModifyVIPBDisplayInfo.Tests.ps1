$PSScriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$repoRoot = Resolve-Path (Join-Path $PSScriptRoot "..")
$scriptPath = Join-Path $repoRoot ".github/actions/modify-vipb-display-info/ModifyVIPBDisplayInfo.ps1"
$fixtureSource = Join-Path $repoRoot "Test/fixtures/modify-vipb/fixture.vipb"
$tempRoot = Join-Path $repoRoot "Test/tmp"

Describe "ModifyVIPBDisplayInfo.ps1" {
    BeforeAll {
        New-Item -ItemType Directory -Path $tempRoot -Force | Out-Null
    }

    AfterAll {
        if (Test-Path $tempRoot) {
            Remove-Item -Path $tempRoot -Recurse -Force
        }
    }

    It "updates VIPB metadata according to DisplayInformation JSON" {
        $vipbPath = Join-Path $tempRoot ("fixture_{0}.vipb" -f ([guid]::NewGuid().ToString("N")))
        Copy-Item -Path $fixtureSource -Destination $vipbPath

        $releaseNotesPath = Join-Path $tempRoot ("release_notes_{0}.md" -f ([guid]::NewGuid().ToString("N")))
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
        $relativeVipbPath = [System.IO.Path]::GetRepoRoot($repoRoot, $vipbPath)

        & $scriptPath `
            -SupportedBitness 64 `
            -RepoRoot $repoRoot `
            -VIPBPath $relativeVipbPath `
            -MinimumSupportedLVVersion 2021 `
            -LabVIEWMinorRevision 0 `
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
        $expectedLicensePath = [System.IO.Path]::GetRelativePath((Split-Path -Parent $vipbPath), (Join-Path $repoRoot "LICENSE"))

        $generalSettings.Company_Name | Should -Be $displayInformation."Company Name"
        $generalSettings.Product_Name | Should -Be $displayInformation."Product Name"
        $descriptionSettings.One_Line_Description_Summary | Should -Be $displayInformation."Product Description Summary"
        $descriptionSettings.Packager | Should -Be $displayInformation."Author Name (Person or Company)"
        $descriptionSettings.URL | Should -Be $displayInformation."Product Homepage (URL)"
        $descriptionSettings.Release_Notes | Should -Be $releaseNotesContent
        $descriptionSettings.Description | Should -Match "Commit: deadbeef"
        $licenseSetting | Should -Be $expectedLicensePath
    }
}
