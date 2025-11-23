# Mock helpers for build task wiring tests

function Initialize-BuildTaskMocks {
    param(
        [string]$RepoPath
    )

    # Create a temp bin dir to shadow git and g-cli
    $tempBin = Join-Path -Path ([System.IO.Path]::GetTempPath()) -ChildPath ("buildtask-mocks-{0}" -f ([guid]::NewGuid().ToString("N")))
    New-Item -ItemType Directory -Path $tempBin -Force | Out-Null

    $logPath = Join-Path $tempBin "gcli.log"
    # initialize log so file exists even if nothing runs
    Set-Content -Path $logPath -Value "mock-start" -Encoding UTF8

    # Mock git to emit a stable commit hash
    $gitMock = @"
#!/usr/bin/env pwsh
Write-Output 'deadbeefdeadbeefdeadbeefdeadbeefdeadbeef'
"@
    $gitPath = Join-Path $tempBin "git"
    Set-Content -Path $gitPath -Value $gitMock -Encoding UTF8

    # Mock g-cli to record invocations without executing LabVIEW
    $gcliMock = @"
#!/usr/bin/env pwsh
param()
Add-Content -Path \"$logPath\" -Value (\$args -join ' ')
exit 0
"@
    $gcliPath = Join-Path $tempBin "g-cli"
    Set-Content -Path $gcliPath -Value $gcliMock -Encoding UTF8

    if (-not $IsWindows) {
        chmod +x $gitPath $gcliPath
    }

    # Prepend to PATH
    $env:PATH = "$tempBin$([IO.Path]::PathSeparator)$env:PATH"

    return @{
        TempBin  = $tempBin
        GitPath  = $gitPath
        GcliPath = $gcliPath
        LogPath  = $logPath
    }
}

Export-ModuleMember -Function Initialize-BuildTaskMocks
