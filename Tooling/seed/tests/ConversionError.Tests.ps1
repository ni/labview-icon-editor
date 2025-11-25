Describe "Conversion failure cases" {

    BeforeAll {
        # Define file paths for tests
        $script:vipbFile   = "tests/Samples/seed.vipb"
        $script:lvprojFile = "tests/Samples/seed.lvproj"
        $script:tempDir    = "tests/Temp"
        if (Test-Path $script:tempDir) { Remove-Item $script:tempDir -Recurse -Force }
        New-Item $script:tempDir -ItemType Directory | Out-Null

        # Path for a synthetic bad JSON file
        $script:badJsonPath = Join-Path $script:tempDir "bad.json"
        # Prepare an invalid JSON (root element not "Project")
        $badJsonContent = '{ "Package": { "Fake": 123 } }'
        Set-Content -Path $script:badJsonPath -Value $badJsonContent -Encoding UTF8
    }

    It "should error when the input file does not exist" {
        $fakeInput = Join-Path $script:tempDir "nonexistent.lvproj"
        $fakeOutput = Join-Path $script:tempDir "dummy.json"
        if (Test-Path $fakeInput) { Remove-Item $fakeInput -Force }

        $output = & dotnet run --project src/VipbJsonTool/VipbJsonTool.csproj `
                               -c Release -- lvproj2json `
                               $fakeInput $fakeOutput 2>&1 | Out-String
        $LASTEXITCODE | Should -Not -Be 0
        $output | Should -Match "Input file not found"
    }

    It "should error on invalid .lvproj XML (wrong root element)" {
        # Using a VIPB file as input to lvproj2json to trigger root element mismatch
        $outputJson = Join-Path $script:tempDir "vipb_as_lvproj.json"
        $output = & dotnet run --project src/VipbJsonTool/VipbJsonTool.csproj `
                               -c Release -- lvproj2json `
                               $script:vipbFile $outputJson 2>&1 | Out-String
        $LASTEXITCODE | Should -Not -Be 0
        $output | Should -Match "Expected 'Project'"
    }

    It "should error on invalid JSON input for json2lvproj" {
        $badOutputLvproj = Join-Path $script:tempDir "bad_output.lvproj"
        $output = & dotnet run --project src/VipbJsonTool/VipbJsonTool.csproj `
                               -c Release -- json2lvproj `
                               $script:badJsonPath $badOutputLvproj 2>&1 | Out-String
        $LASTEXITCODE | Should -Not -Be 0
        $output | Should -Match "Expected 'Project'"
    }

    It "should error when output path is not writable" {
        # Create a directory and remove write permission
        $lockedDir = Join-Path $script:tempDir "no_write_dir"
        New-Item $lockedDir -ItemType Directory | Out-Null
        & chmod a-w $lockedDir    # revoke write permission for all users

        $lockedOutput = Join-Path $lockedDir "out.json"
        $output = & dotnet run --project src/VipbJsonTool/VipbJsonTool.csproj `
                               -c Release -- lvproj2json `
                               $script:lvprojFile $lockedOutput 2>&1 | Out-String
        $LASTEXITCODE | Should -Not -Be 0
        $output | Should -Match "denied"

        # Clean up: restore permission and remove the directory
        & chmod u+w $lockedDir
        Remove-Item $lockedDir -Recurse -Force
    }

    AfterAll {
        # Cleanup temporary files
        if (Test-Path $script:tempDir) {
            Remove-Item $script:tempDir -Recurse -Force
        }
    }
}
