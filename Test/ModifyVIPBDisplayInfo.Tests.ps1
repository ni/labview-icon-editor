Describe "ModifyVIPBDisplayInfo.ps1" {
    BeforeAll {
        # Pester runs discovery and execution in separate scopes; compute paths at execution time.
        function Find-RepoRoot {
            param([string]$StartPath)

            $dir = $StartPath
            while ($dir -and (Test-Path -Path $dir)) {
                if ((Test-Path (Join-Path $dir ".git")) -or (Test-Path (Join-Path $dir ".lvversion"))) {
                    return (Resolve-Path -Path $dir).Path
                }

                $parent = Split-Path -Parent $dir
                if ($parent -eq $dir) {
                    break
                }
                $dir = $parent
            }

            throw "Unable to locate repository root from '$StartPath'."
        }

        $startPath = $PSScriptRoot
        if ([string]::IsNullOrWhiteSpace($startPath)) {
            $startPath = (Get-Location).Path
        }

        $script:repoRoot = Find-RepoRoot -StartPath $startPath
        $script:scriptPath = Join-Path $script:repoRoot ".github/actions/modify-vipb-display-info/ModifyVIPBDisplayInfo.ps1"
        # Use the repository VIPB as the fixture source; copy into a temp file per test.
        $script:fixtureSource = Join-Path $script:repoRoot "Tooling/deployment/NI Icon editor.vipb"
        $script:tempRoot = Join-Path $script:repoRoot "Test/tmp"

        New-Item -ItemType Directory -Path $script:tempRoot -Force | Out-Null
    }

    AfterAll {
        if ($script:tempRoot -and (Test-Path $script:tempRoot)) {
            Remove-Item -Path $script:tempRoot -Recurse -Force
        }
    }

    It "updates VIPB metadata according to DisplayInformation JSON" {
        $vipbPath = Join-Path $script:tempRoot ("fixture_{0}.vipb" -f ([guid]::NewGuid().ToString("N")))
        Copy-Item -Path $script:fixtureSource -Destination $vipbPath

        $releaseNotesPath = Join-Path $script:tempRoot ("release_notes_{0}.md" -f ([guid]::NewGuid().ToString("N")))
        $releaseNotesContent = "Release notes content from file"
        Set-Content -Path $releaseNotesPath -Value $releaseNotesContent -NoNewline

        $displayInformation = [ordered]@{
            "Company Name"                 = "svelderrainruiz"
            "Product Name"                 = "labview-icon-editor"
            "Product Description Summary"  = "Source for LabVIEW's icon editor"
            "Product Description"          = "Source for LabVIEW's icon editor"
            "Author Name (Person or Company)" = "svelderrainruiz/labview-icon-editor"
            "Product Homepage (URL)"       = "https://github.com/svelderrainruiz/labview-icon-editor"
            "Legal Copyright"              = "© 2025 svelderrainruiz"
            "Release Notes - Change Log"   = $releaseNotesContent
            "Package Version"              = @{ major = 1; minor = 4; patch = 1; build = 1194 }
        }

        $displayInformationJson = $displayInformation | ConvertTo-Json -Depth 5
        $relativeVipbPath = [System.IO.Path]::GetRelativePath($script:repoRoot, $vipbPath)

        & $script:scriptPath `
            -SupportedBitness 64 `
            -RepoRoot $script:repoRoot `
            -VIPBPath $relativeVipbPath `
            -LabVIEWVersion 2021 `
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
        $sourceFiles = $vipbXml.VI_Package_Builder_Settings.Advanced_Settings.Source_Files
        $exclusionPaths = @($sourceFiles.Exclusions) | ForEach-Object { $_.Path }

        $generalSettings.Company_Name | Should -Be $displayInformation."Company Name"
        $generalSettings.Product_Name | Should -Be $displayInformation."Product Name"
        $descriptionSettings.One_Line_Description_Summary | Should -Be $displayInformation."Product Description Summary"
        $descriptionSettings.Packager | Should -Be $displayInformation."Author Name (Person or Company)"
        $descriptionSettings.URL | Should -Be $displayInformation."Product Homepage (URL)"
        $descriptionSettings.Release_Notes | Should -Be $releaseNotesContent
        $descriptionSettings.Description | Should -Match "Commit: deadbeef"
        $licenseSetting | Should -Be ''
        $exclusionPaths | Should -Contain 'TestResults'
    }
}

