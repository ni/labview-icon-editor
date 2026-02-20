#Requires -Version 7.0
#Requires -Modules Pester

$ErrorActionPreference = 'Stop'

Describe 'CI workflow verify-iepaths contract' {
    BeforeAll {
        $script:repoRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
        $script:workflowPath = Join-Path $script:repoRoot '.github/workflows/ci.yml'
        $script:workflowContent = Get-Content -Path $script:workflowPath -Raw
        $script:verifyIePathsSection = [regex]::Match(
            $script:workflowContent,
            '(?ms)^  verify-iepaths:\r?\n(?<body>.*?)(?=^  [a-zA-Z0-9_-]+:\r?\n|\z)'
        ).Groups['body'].Value
    }

    It 'defines verify-iepaths job with expected name and profile gating' {
        $script:workflowContent | Should -Match '(?ms)^  verify-iepaths:\s*$'
        $script:verifyIePathsSection | Should -Not -BeNullOrEmpty
        $script:verifyIePathsSection | Should -Match 'name:\s*verify-iepaths-\$\{\{\s*matrix\.bitness\s*\}\}-bit'
        $script:verifyIePathsSection | Should -Match 'if:\s*\$\{\{\s*needs\.prerelease-context\.outputs\.ci_profile != ''release-priority''\s*\}\}'
    }

    It 'wires verify-iepaths dependencies and bitness runner matrix' {
        $script:verifyIePathsSection | Should -Match 'needs:\s*\[\s*run-metadata,\s*prerelease-context,\s*version-gate,\s*apply-deps-64,\s*apply-deps-32\s*\]'
        $script:verifyIePathsSection | Should -Match 'runs-on:\s*\$\{\{\s*matrix\.runner_label\s*\}\}'
        $script:verifyIePathsSection | Should -Match 'fail-fast:\s*false'
        $script:verifyIePathsSection | Should -Match 'max-parallel:\s*2'
        $script:verifyIePathsSection | Should -Match 'bitness:\s*''64'''
        $script:verifyIePathsSection | Should -Match 'bitness:\s*''32'''
        $script:verifyIePathsSection | Should -Match 'runner_label:\s*\$\{\{\s*vars\.LVIE_RUNNER_LABEL_64 \|\| format\(''self-hosted-windows-lv\{0\}x64'', needs\.version-gate\.outputs\.year\)\s*\}\}'
        $script:verifyIePathsSection | Should -Match 'runner_label:\s*\$\{\{\s*vars\.LVIE_RUNNER_LABEL_32 \|\| format\(''self-hosted-windows-lv\{0\}x86'', needs\.version-gate\.outputs\.year\)\s*\}\}'
    }

    It 'uses lvie-job-setup with worktree short-path mode' {
        $script:verifyIePathsSection | Should -Match 'uses:\s*\./\.github/actions/lvie-job-setup'
        $script:verifyIePathsSection | Should -Match 'checkout:\s*''false'''
        $script:verifyIePathsSection | Should -Match 'bitness:\s*\$\{\{\s*matrix\.bitness\s*\}\}'
        $script:verifyIePathsSection | Should -Match 'create_worktree:\s*''true'''
        $script:verifyIePathsSection | Should -Match 'worktree_root_mode:\s*runner_temp'
    }

    It 'invokes Verify IE Paths script with required arguments and fallback behavior' {
        $script:verifyIePathsSection | Should -Match 'Tooling\\Invoke-MissingIEFilesFromLVInstall\.ps1'
        $script:verifyIePathsSection | Should -Match '-RepoRoot'',\s*\$resolvedRepoRoot'
        $script:verifyIePathsSection | Should -Match '-LabVIEWVersion'',\s*\$env:LVIE_REQUIRED_LABVIEW_VERSION'
        $script:verifyIePathsSection | Should -Match '-SupportedBitness'',\s*\$bitness'
        $script:verifyIePathsSection | Should -Match '-StatusFileArchiveDirectory'',\s*\$statusArchiveDir'
        $script:verifyIePathsSection | Should -Match '-IgnoreGcliExitCode'
        $script:verifyIePathsSection | Should -Match '-IgnoreStatusFailure'
        $script:verifyIePathsSection | Should -Match '\$resolvedRepoRoot = if \(-not \[string\]::IsNullOrWhiteSpace\(\$env:REPO_ROOT\)'
        $script:verifyIePathsSection | Should -Match 'Resolve-Path -Path \$env:GITHUB_WORKSPACE'
    }

    It 'implements canary and enforce wiring through LVIE_VERIFY_IEPATHS_ENFORCE' {
        $script:workflowContent | Should -Match 'LVIE_VERIFY_IEPATHS_ENFORCE:\s*\$\{\{\s*vars\.LVIE_VERIFY_IEPATHS_ENFORCE \|\| ''0''\s*\}\}'
        $script:verifyIePathsSection | Should -Match 'continue-on-error:\s*\$\{\{\s*env\.LVIE_VERIFY_IEPATHS_ENFORCE != ''1'''
        $script:verifyIePathsSection | Should -Match 'Convert-ToBool'
        $script:verifyIePathsSection | Should -Match 'verify_iepaths_verdict='
        $script:verifyIePathsSection | Should -Match 'verify_iepaths_classification='
        $script:verifyIePathsSection | Should -Match 'Canary mode active; continuing with warning'
        $script:verifyIePathsSection | Should -Match 'if \(\$enforceMode\) \{'
    }

    It 'writes evidence with the required key contract' {
        foreach ($key in @(
                'timestamp_utc',
                'bitness',
                'repo_root',
                'lvversion_raw',
                'enforce_mode',
                'setup_outcome',
                'script_exit_code',
                'verdict',
                'classification',
                'status_archive_dir',
                'status_files',
                'missing_paths',
                'error')) {
            $script:verifyIePathsSection | Should -Match ("{0}\s*=" -f [regex]::Escape($key))
        }
    }

    It 'uploads verify-iepaths status and evidence artifacts on always()' {
        $script:verifyIePathsSection | Should -Match 'Upload verify-iepaths status archive'
        $script:verifyIePathsSection | Should -Match 'if:\s*always\(\)'
        $script:verifyIePathsSection | Should -Match 'verify-iepaths-status-\$\{\{ runner\.os \}\}-\$\{\{ matrix\.bitness \}\}-bit'
        $script:verifyIePathsSection | Should -Match 'path:\s*\$\{\{\s*env\.VERIFY_IEPATHS_STATUS_DIR\s*\}\}'
        $script:verifyIePathsSection | Should -Match 'Upload verify-iepaths evidence'
        $script:verifyIePathsSection | Should -Match 'verify-iepaths-evidence-\$\{\{ runner\.os \}\}-\$\{\{ matrix\.bitness \}\}-bit'
        $script:verifyIePathsSection | Should -Match 'path:\s*\$\{\{\s*env\.VERIFY_IEPATHS_EVIDENCE_PATH\s*\}\}'
    }
}
