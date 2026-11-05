#Requires -Version 7.0
#Requires -Modules Pester

Describe 'Windows LUnit container contract' {
    BeforeAll {
        $repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
        $script:workflow = Get-Content (Join-Path $repoRoot '.github\workflows\lunit-windows-container-tests.yml') -Raw
        $match = [regex]::Match($script:workflow, '(?ms)      - name: Validate JUnit report and test discovery\s+run: \|\r?\n(?<code>.*?)(?=      - name:)')
        if (-not $match.Success) { throw 'JUnit validation step not found.' }
        $script:validate = [scriptblock]::Create(($match.Groups['code'].Value -replace '(?m)^          ', ''))
        $match = [regex]::Match($script:workflow, '(?ms)      - name: Summarize unit test failures\s+if: [^\r\n]+\r?\n\s+run: \|\r?\n(?<code>.*?)(?=      - name:)')
        if (-not $match.Success) { throw 'JUnit diagnostics step not found.' }
        $script:summarize = [scriptblock]::Create(($match.Groups['code'].Value -replace '(?m)^          ', ''))
        $script:oldWorkspace = $env:GITHUB_WORKSPACE
        $script:oldSummary = $env:GITHUB_STEP_SUMMARY
        $env:GITHUB_WORKSPACE = $TestDrive
        $env:GITHUB_STEP_SUMMARY = Join-Path $TestDrive 'summary.txt'
        New-Item -ItemType Directory -Path (Join-Path $TestDrive 'lunit-results') -Force | Out-Null
        $script:reportPath = [System.IO.Path]::Combine($TestDrive, 'lunit-results', 'lunit.xml')
    }

    Describe 'LUnit package file deployment' {
        BeforeAll {
            $path = Join-Path $PSScriptRoot '..\Run-LUnitWindowsContainer.ps1'
            $tokens = $null
            $errors = $null
            $ast = [System.Management.Automation.Language.Parser]::ParseFile(
                (Resolve-Path $path).Path, [ref]$tokens, [ref]$errors)
            if ($errors.Count) { throw ($errors | Out-String) }
            $function = $ast.Find({
                param($node)
                $node -is [System.Management.Automation.Language.FunctionDefinitionAst] -and
                $node.Name -eq 'Install-LUnitPackageFiles'
            }, $true)
            . ([scriptblock]::Create($function.Extent.Text))
            function Get-LUnitPackageFile { param($Package, [string]$Directory) }
            Add-Type -AssemblyName System.IO.Compression.FileSystem

            function New-TestPackage {
                param([string]$Name, [string[]]$Files)
                $root = Join-Path $TestDrive "src-$Name"
                foreach ($file in $Files) {
                    $full = Join-Path $root $file
                    New-Item -ItemType Directory -Path (Split-Path $full) -Force | Out-Null
                    Set-Content -LiteralPath $full -Value $file
                }
                $zip = Join-Path $TestDrive "$Name.vip"
                if (Test-Path $zip) { Remove-Item $zip }
                [System.IO.Compression.ZipFile]::CreateFromDirectory($root, $zip)
                $zip
            }
        }

        BeforeEach {
            $script:LUnitPackages = @(
                [ordered]@{ Name = 'astemes_lib_lunit'; Version = '1'; MD5 = 'x'; Folder = 'LUnit' }
                [ordered]@{ Name = 'astemes_lib_lunit_cli'; Version = '1'; MD5 = 'x'; Folder = 'LUnit CLI' }
            )
            $script:destination = Join-Path $TestDrive ('lv-' + [guid]::NewGuid().ToString('N'))
            $script:work = Join-Path $TestDrive ('work-' + [guid]::NewGuid().ToString('N'))
            $script:framework = New-TestPackage 'framework' @(
                'File Group 0\vi.lib\Astemes\LUnit\LUnit.lvlib',
                'File Group 0\resource\Framework\Providers\provider.ini',
                'PostInstall.vi')
            $script:cliPackage = New-TestPackage 'cli' @('File Group 0\vi.lib\Astemes\LUnit CLI\LUnitCLI\RunOperation.vi')
            Mock Get-LUnitPackageFile {
                if ($Package.Name -eq 'astemes_lib_lunit') { $script:framework } else { $script:cliPackage }
            }
        }

        It 'copies only each package vi.lib\Astemes tree into LabVIEW' {
            Install-LUnitPackageFiles -Destination $script:destination -WorkDirectory $script:work
            Join-Path $script:destination 'vi.lib\Astemes\LUnit\LUnit.lvlib' | Should -Exist
            Join-Path $script:destination 'vi.lib\Astemes\LUnit CLI\LUnitCLI\RunOperation.vi' | Should -Exist
            Join-Path $script:destination 'resource' | Should -Not -Exist
            Join-Path $script:destination 'PostInstall.vi' | Should -Not -Exist
            Should -Invoke Get-LUnitPackageFile -Times 2 -Exactly
        }

        It 'replaces an existing deployment instead of nesting it' {
            Install-LUnitPackageFiles -Destination $script:destination -WorkDirectory $script:work
            Install-LUnitPackageFiles -Destination $script:destination -WorkDirectory $script:work
            Join-Path $script:destination 'vi.lib\Astemes\LUnit\LUnit' | Should -Not -Exist
        }

        It 'fails when a package lacks its expected vi.lib folder' {
            $script:cliPackage = New-TestPackage 'cli-bad' @('File Group 0\examples\readme.txt')
            { Install-LUnitPackageFiles -Destination $script:destination -WorkDirectory $script:work } |
                Should -Throw '*does not contain vi.lib\Astemes\LUnit CLI*'
        }

        It 'fails when the CLI operation entry point is missing' {
            $script:cliPackage = New-TestPackage 'cli-noop' @('File Group 0\vi.lib\Astemes\LUnit CLI\readme.txt')
            { Install-LUnitPackageFiles -Destination $script:destination -WorkDirectory $script:work } |
                Should -Throw '*RunOperation.vi*'
        }

        It 'surfaces download or checksum failures' {
            Mock Get-LUnitPackageFile { throw 'Publisher checksum mismatch' }
            { Install-LUnitPackageFiles -Destination $script:destination -WorkDirectory $script:work } |
                Should -Throw '*checksum mismatch*'
        }
    }

    BeforeEach {
        Set-Content -LiteralPath $env:GITHUB_STEP_SUMMARY -Value ''
        $cases = (1..10 | ForEach-Object { "<testcase name='test$_'/>" }) -join ''
        "<testsuites><testsuite tests='10' failures='0'>$cases</testsuite></testsuites>" |
            Set-Content -LiteralPath $script:reportPath
    }

    AfterAll {
        $env:GITHUB_WORKSPACE = $script:oldWorkspace
        $env:GITHUB_STEP_SUMMARY = $script:oldSummary
    }

    It 'builds and reuses a VIPM-free Windows dependency image and native LUnit CLI' {
        $script:workflow | Should -Match 'runs-on: windows-2022'
        $dockerfile = Get-Content (Join-Path $repoRoot 'Tooling\containers\lunit-windows.Dockerfile') -Raw
        $dockerfile | Should -Match 'FROM nationalinstruments/labview:2026q1-windows'
        $dockerfile | Should -Match '-Stage Setup;'
        $dockerfile | Should -Match 'dependency-manifest.json'
        $dockerfile | Should -Not -Match '(?i)vipm-setup|installers/|PUBLIC_REPOSITORY_URL|VIPM_SERIAL_NUMBER|activate'
        $build = Get-Content (Join-Path $repoRoot 'Tooling\Build-LUnitWindowsImage.ps1') -Raw
        $build | Should -Not -Match '(?i)vipm|mingit|PublicRepositoryUrl'
        $script:workflow | Should -Match 'Get-FileHash'
        $script:workflow | Should -Match 'Build-LUnitWindowsImage.ps1 -Image \$env:LABVIEW_IMAGE'
        $script:workflow | Should -Not -Match 'PublicRepositoryUrl'
        $script:workflow | Should -Match 'docker push'
        $script:workflow | Should -Match "github.event_name != 'pull_request'"
        $script:workflow | Should -Not -Match 'secrets\.VIPM_|-Stage Setup'
        $script:workflow | Should -Match '-Stage Test'
        $helper = Get-Content (Join-Path $repoRoot 'Tooling\Run-LUnitWindowsContainer.ps1') -Raw
        $helper | Should -Not -Match '(?i)vipm\.exe|& \$vipm|VIPM_|git init|mingit'
        $helper | Should -Match "Name = 'astemes_lib_lunit'; Version = '2\.0\.13\.6'; MD5 = '57bc42bcfdfcf898ef5e00651992a015'"
        $helper | Should -Match "Name = 'astemes_lib_lunit_cli'; Version = '1\.7\.1\.32'; MD5 = '1d82a4f44e0fdb257b048e80ed2de254'"
        $helper | Should -Match 'https://www\.jkisoft\.com/packages/packages/'
        $helper | Should -Match 'Get-FileHash -LiteralPath \$path -Algorithm MD5'
        $helper | Should -Match 'Install-LUnitPackageFiles -Destination \$labviewRoot'
        $helper | Should -Match "installMethod = 'verified-vip-file-copy'"
        $helper | Should -Match "Set-Location 'C:\\workspace'"
        $helper | Should -Match 'Start-TestLabVIEW -Project \$project'
        $helper | Should -Match '-OperationName LUnit'
        $helper | Should -Match "-AdditionalOperationDirectory \(Join-Path \`$labviewRoot 'vi\.lib\\Astemes\\LUnit CLI'\)"
        $helper | Should -Match '-LogToConsole TRUE -Headless'
        $helper | Should -Not -Match 'g-cli'
    }

    It 'accepts ten passing tests' {
        { & $script:validate } | Should -Not -Throw
    }

    It 'reads the native report path when summarizing passing tests' {
        { & $script:summarize } | Should -Not -Throw
        Get-Content $env:GITHUB_STEP_SUMMARY -Raw |
            Should -Match 'No failed test cases were recorded'
    }

    It 'reads and summarizes failure details from the native report path' {
        (Get-Content $script:reportPath -Raw).Replace("<testcase name='test10'/>",
            "<testcase name='test10'><failure message='Assertion mismatch'>Failure details</failure></testcase>") |
            Set-Content $script:reportPath
        { & $script:summarize } | Should -Not -Throw
        $summary = Get-Content $env:GITHUB_STEP_SUMMARY -Raw
        $summary | Should -Match 'Assertion mismatch'
        $summary | Should -Match 'Failure details'
    }

    It 'rejects fewer than ten executed tests' {
        (Get-Content $script:reportPath -Raw).Replace("<testcase name='test10'/>", '') |
            Set-Content $script:reportPath
        { & $script:validate } | Should -Throw '*expected at least 10*'
    }

    It 'does not count skipped tests as executed' {
        (Get-Content $script:reportPath -Raw).Replace("<testcase name='test10'/>", "<testcase name='test10'><skipped/></testcase>") |
            Set-Content $script:reportPath
        { & $script:validate } | Should -Throw '*expected at least 10*'
    }

    It 'rejects <Element> elements' -ForEach @(@{ Element = 'failure' }, @{ Element = 'error' }) {
        (Get-Content $script:reportPath -Raw).Replace("<testcase name='test10'/>", "<testcase name='test10'><$Element/></testcase>") |
            Set-Content $script:reportPath
        { & $script:validate } | Should -Throw '*test failures or errors*'
    }

    It 'rejects nonzero suite failure counts' {
        (Get-Content $script:reportPath -Raw).Replace("failures='0'", "failures='1'") |
            Set-Content $script:reportPath
        { & $script:validate } | Should -Throw '*failures count*'
    }

    Context 'temporary known tag failure' {
        BeforeAll {
            function Set-KnownTestCase {
                param([string]$Name = 'Test Write Read Library Icon Data.vi', [string]$Body)
                $case = "<testcase classname='Library Icon Data' name='$Name'>$Body</testcase>"
                (Get-Content $script:reportPath -Raw).Replace("<testcase name='test10'/>", $case).Replace("failures='0'", "failures='1'") |
                    Set-Content $script:reportPath
            }
            $script:tagFailure = "<failure message='Expected:NI.Lib.VIIconTemplate(String)&#xA;Actual:  NI_IconEditor(String)' type='Pass if Equal'>Tag Used (26.0)</failure>"
            $script:summaryFailure = "<failure message='' type='Test Case'>Passed:&#xA;Library Write and Read Match&#xA;Failed:&#xA;Tag Used (26.0)</failure>"
        }

        It 'tolerates the exact tag mismatch and reports it' {
            Set-KnownTestCase -Body ($script:tagFailure + $script:summaryFailure)
            { & $script:validate } | Should -Not -Throw
            Get-Content $env:GITHUB_STEP_SUMMARY -Raw | Should -Match 'Known failure tolerated temporarily'
        }

        It 'rejects a different assertion failure in the same test' {
            $other = "<failure message='Expected:1(I32)&#xA;Actual:  2(I32)' type='Pass if Equal'>Library Write and Read Match</failure>"
            Set-KnownTestCase -Body ($script:tagFailure + $other + $script:summaryFailure)
            { & $script:validate } | Should -Throw '*test failures or errors*'
        }

        It 'rejects an error in the same test' {
            Set-KnownTestCase -Body ($script:tagFailure + "<error message='Error 7'/>")
            { & $script:validate } | Should -Throw '*test failures or errors*'
        }

        It 'rejects the same tag mismatch in another test' {
            Set-KnownTestCase -Name 'Test Library Icon Tag.vi' -Body $script:tagFailure
            { & $script:validate } | Should -Throw '*test failures or errors*'
        }
    }

    It 'rejects a missing report' {
        Remove-Item -LiteralPath $script:reportPath
        { & $script:validate } | Should -Throw
    }

    It 'rejects invalid XML and DTDs' -ForEach @(
        @{ Xml = '<testsuites>' },
        @{ Xml = '<!DOCTYPE testsuites [<!ENTITY x "test">]><testsuites/>' }
    ) {
        $Xml | Set-Content $script:reportPath
        { & $script:validate } | Should -Throw
    }
}
