$ErrorActionPreference = 'Stop'

Describe 'VerifyIEPaths status helpers' {
    BeforeAll {
        $script:repoRoot = Resolve-Path -Path (Join-Path $PSScriptRoot '..\..')
        $script:helperPath = Join-Path $script:repoRoot 'Tooling\support\VerifyIEPathsStatus.ps1'
        if (-not (Test-Path -Path $script:helperPath)) {
            throw "Status helper not found at $script:helperPath"
        }
        . $script:helperPath
    }

    It 'resolves an explicit status file path relative to repo root' {
        $resolved = Resolve-VerifyIEPathsStatusFile -RepoRoot $script:repoRoot -StatusFileName 'status.txt'
        $resolved | Should -Be (Join-Path $script:repoRoot 'status.txt')
    }

    It 'detects the newest status file created after the start time' {
        $tempDir = Join-Path $env:TEMP ([guid]::NewGuid())
        $null = New-Item -Path $tempDir -ItemType Directory -Force
        try {
            $oldFile = Join-Path $tempDir 'old.txt'
            Set-Content -Path $oldFile -Value 'old' -Encoding ascii
            $oldItem = Get-Item -Path $oldFile
            $oldItem.LastWriteTimeUtc = (Get-Date).ToUniversalTime().AddMinutes(-10)

            $start = (Get-Date).ToUniversalTime()
            Start-Sleep -Milliseconds 20
            $newFile = Join-Path $tempDir 'new.txt'
            Set-Content -Path $newFile -Value 'new' -Encoding ascii

            $resolved = Resolve-VerifyIEPathsStatusFile -RepoRoot $tempDir -StartTimeUtc $start
            $resolved | Should -Be $newFile
        } finally {
            Remove-Item -Path $tempDir -Recurse -Force -ErrorAction SilentlyContinue
        }
    }

    It 'classifies success and failure status values' {
        $tempDir = Join-Path $env:TEMP ([guid]::NewGuid())
        $null = New-Item -Path $tempDir -ItemType Directory -Force
        try {
            $file = Join-Path $tempDir 'status.txt'
            Set-Content -Path $file -Value '' -Encoding ascii
            $result = Get-VerifyIEPathsStatus -StatusFilePath $file
            $result.IsSuccess | Should -BeTrue
            $result.IsFailure | Should -BeFalse
            $result.MissingPaths | Should -HaveCount 0

            Set-Content -Path $file -Value 'file1.vi, file2.vi' -Encoding ascii
            $result = Get-VerifyIEPathsStatus -StatusFilePath $file
            $result.IsSuccess | Should -BeFalse
            $result.IsFailure | Should -BeTrue
            $result.MissingPaths | Should -Be @('file1.vi', 'file2.vi')
        } finally {
            Remove-Item -Path $tempDir -Recurse -Force -ErrorAction SilentlyContinue
        }
    }
}
