param(
    [string]$Version
)

$root = Split-Path -Parent $MyInvocation.MyCommand.Path
$proj = Join-Path $root '..\src\XCli\XCli.csproj'
$distRoot = Join-Path $root '..\dist'
$artifactRoot = Join-Path $root '..\artifacts\release'
$stream = Join-Path $root 'stream-output.ps1'

$targets = @(
    @{ Rid = 'win-x64'; DistName = 'x-cli-win-x64'; Candidates = @('XCli.exe', 'XCli'); },
    @{ Rid = 'linux-x64'; DistName = 'x-cli-linux-x64'; Candidates = @('XCli', 'XCli.dll'); }
)

foreach ($path in @($distRoot, $artifactRoot)) {
    if (Test-Path $path) {
        Remove-Item $path -Recurse -Force
    }
    New-Item -ItemType Directory -Path $path -Force | Out-Null
}

$wasWindows = [System.Runtime.InteropServices.RuntimeInformation]::IsOSPlatform([System.Runtime.InteropServices.OSPlatform]::Windows)

foreach ($target in $targets) {
    $rid = $target.Rid
    $publishDir = Join-Path $artifactRoot $rid
    $distRidDir = Join-Path $distRoot $rid
    New-Item -ItemType Directory -Path $publishDir -Force | Out-Null
    New-Item -ItemType Directory -Path $distRidDir -Force | Out-Null

    $args = @('publish', $proj, '-c', 'Release', '-r', $rid, '-p:PublishSingleFile=true', '-p:SelfContained=true', '-o', $publishDir)
    if ($Version) {
        $args += "-p:Version=$Version"
    }

    & $stream -Command dotnet -Args $args
    if ($LASTEXITCODE -ne 0) {
        exit $LASTEXITCODE
    }

    $binaryPath = $null
    foreach ($candidate in $target.Candidates) {
        $candidatePath = Join-Path $publishDir $candidate
        if (Test-Path $candidatePath) {
            $binaryPath = $candidatePath
            break
        }
    }

    if (-not $binaryPath) {
        Write-Error "Failed to locate published binary for $rid in $publishDir"
        exit 1
    }

    Get-ChildItem -Path $publishDir -File | ForEach-Object {
        Copy-Item $_.FullName (Join-Path $distRidDir $_.Name) -Force
    }

    $normalizedPath = Join-Path $distRoot $target.DistName
    Copy-Item $binaryPath $normalizedPath -Force

    if (-not $wasWindows -and $rid -eq 'linux-x64') {
        chmod +x $normalizedPath 2>$null
    }

    if (-not (Test-Path $normalizedPath)) {
        Write-Error "$rid artifact not normalized to dist/$($target.DistName)"
        exit 1
    }
}

