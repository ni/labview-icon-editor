[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [ValidateSet('Setup', 'Test')]
    [string]$Stage
)

$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'
$labviewRoot = 'C:\Program Files\National Instruments\LabVIEW 2026'
$labview = Join-Path $labviewRoot 'LabVIEW.exe'
$results = 'C:\workspace\lunit-results'
New-Item -ItemType Directory -Path $results -Force | Out-Null
Start-Transcript -Path (Join-Path $results "$Stage.log") -Force
$script:labviewProcess = $null

# Versions and publisher MD5 checksums from the public JKI package index.
$script:LUnitPackages = @(
    [ordered]@{ Name = 'astemes_lib_lunit'; Version = '2.0.13.6'; MD5 = '57bc42bcfdfcf898ef5e00651992a015'; Folder = 'LUnit' }
    [ordered]@{ Name = 'astemes_lib_lunit_cli'; Version = '1.7.1.32'; MD5 = '1d82a4f44e0fdb257b048e80ed2de254'; Folder = 'LUnit CLI' }
)

function Start-TestLabVIEW {
    param([string]$Project)

    $arguments = @('--headless')
    if ($Project) {
        $arguments += "`"$Project`""
    }
    $process = Start-Process -FilePath $labview -ArgumentList $arguments -PassThru `
        -RedirectStandardOutput (Join-Path $results "labview-$Stage.log") `
        -RedirectStandardError (Join-Path $results "labview-$Stage.stderr.log")
    $script:labviewProcess = $process
    $deadline = (Get-Date).AddMinutes(3)
    while ((Get-Date) -lt $deadline) {
        if ($process.HasExited) {
            throw "LabVIEW exited with code $($process.ExitCode). See labview-$Stage logs."
        }
        $client = [System.Net.Sockets.TcpClient]::new()
        try {
            $connection = $client.ConnectAsync('127.0.0.1', 3363)
            if ($connection.Wait(1000) -and $client.Connected) {
                return
            }
        }
        catch [System.AggregateException] {
            if ($_.Exception.GetBaseException() -isnot [System.Net.Sockets.SocketException]) {
                throw
            }
        }
        finally {
            $client.Dispose()
        }
        Start-Sleep -Seconds 2
    }
    throw 'LabVIEW VI Server did not become ready on port 3363 within 3 minutes.'
}

function Stop-TestLabVIEW {
    if ($script:labviewProcess -and -not $script:labviewProcess.HasExited) {
        Stop-Process -Id $script:labviewProcess.Id -Force
        $script:labviewProcess.WaitForExit()
    }
    $script:labviewProcess = $null
}

function Get-LUnitPackageFile {
    param(
        [Parameter(Mandatory)] $Package,
        [Parameter(Mandatory)] [string]$Directory
    )

    $filename = '{0}-{1}.vip' -f $Package.Name, $Package.Version
    $path = Join-Path $Directory $filename
    $url = "https://www.jkisoft.com/packages/packages/$($Package.Name)/$filename"
    Write-Host "Downloading required public package: $filename"
    Invoke-WebRequest -UseBasicParsing -Uri $url -OutFile $path -TimeoutSec 120
    $header = Get-Content -LiteralPath $path -Encoding Byte -TotalCount 4
    if ($header.Count -lt 4 -or $header[0] -ne 0x50 -or $header[1] -ne 0x4b) {
        throw "Downloaded package is not a VIP/ZIP archive: $filename"
    }
    # MD5 matches publisher metadata; HTTPS provides transport security.
    $hash = (Get-FileHash -LiteralPath $path -Algorithm MD5).Hash
    if ($hash -ne $Package.MD5) { throw "Publisher checksum mismatch: $filename" }
    $path
}

# VIPM install stalls in Windows containers, so deploy the package files directly. Only each package's
# vi.lib\Astemes tree is copied; the packages' post-install actions (menus, global CLI registration) are skipped,
# which is why the Test stage passes -AdditionalOperationDirectory to LabVIEWCLI.
function Install-LUnitPackageFiles {
    param(
        [Parameter(Mandatory)] [string]$Destination,
        [Parameter(Mandatory)] [string]$WorkDirectory
    )

    Add-Type -AssemblyName System.IO.Compression.FileSystem
    New-Item -ItemType Directory -Path $WorkDirectory -Force | Out-Null
    foreach ($package in $script:LUnitPackages) {
        $file = Get-LUnitPackageFile -Package $package -Directory $WorkDirectory
        $extracted = Join-Path $WorkDirectory $package.Name
        if (Test-Path -LiteralPath $extracted) { Remove-Item -LiteralPath $extracted -Recurse -Force }
        [System.IO.Compression.ZipFile]::ExtractToDirectory($file, $extracted)
        $source = Join-Path $extracted "File Group 0\vi.lib\Astemes\$($package.Folder)"
        if (-not (Test-Path -LiteralPath $source -PathType Container)) {
            throw "Package $($package.Name) does not contain vi.lib\Astemes\$($package.Folder)."
        }
        $target = Join-Path $Destination "vi.lib\Astemes\$($package.Folder)"
        if (Test-Path -LiteralPath $target) { Remove-Item -LiteralPath $target -Recurse -Force }
        New-Item -ItemType Directory -Path (Split-Path $target) -Force | Out-Null
        Copy-Item -LiteralPath $source -Destination $target -Recurse
        Write-Host "Deployed $($package.Name) $($package.Version) to $target"
    }
    foreach ($relative in @('vi.lib\Astemes\LUnit', 'vi.lib\Astemes\LUnit CLI\LUnitCLI\RunOperation.vi')) {
        if (-not (Test-Path -LiteralPath (Join-Path $Destination $relative))) {
            throw "LUnit deployment missing: $relative"
        }
    }
}

try {
    if (-not (Test-Path -LiteralPath $labview -PathType Leaf)) {
        throw "LabVIEW executable not found: $labview"
    }
    if ($Stage -eq 'Setup') {
        $ini = Join-Path $labviewRoot 'LabVIEW.ini'
        $lines = @(Get-Content -LiteralPath $ini)
        foreach ($setting in @('server.tcp.enabled=True', 'server.tcp.port=3363', 'server.tcp.access=+127.0.0.1', 'server.vi.access=+*')) {
            $key = $setting.Split('=')[0]
            $lines = @($lines | Where-Object { $_ -notmatch ('^\s*' + [regex]::Escape($key) + '\s*=') })
            $lines += $setting
        }
        $lines | Set-Content -LiteralPath $ini -Encoding Ascii
        [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

        $work = Join-Path $env:TEMP 'lvie-lunit-packages'
        try {
            Install-LUnitPackageFiles -Destination $labviewRoot -WorkDirectory $work
        }
        finally {
            if (Test-Path -LiteralPath $work) { Remove-Item -LiteralPath $work -Recurse -Force }
        }
        [ordered]@{
            labviewVersion = (Get-Item -LiteralPath $labview).VersionInfo.FileVersion
            installMethod = 'verified-vip-file-copy'
            frameworkPath = Join-Path $labviewRoot 'vi.lib\Astemes\LUnit'
            operationPath = Join-Path $labviewRoot 'vi.lib\Astemes\LUnit CLI\LUnitCLI'
            packages = @($script:LUnitPackages | ForEach-Object {
                [ordered]@{ name = $_.Name; version = $_.Version; md5 = $_.MD5 }
            })
        } | ConvertTo-Json -Depth 4 | Set-Content -LiteralPath (Join-Path $results 'dependency-manifest.json') -Encoding UTF8
    }
    else {
        $project = 'C:\workspace\lv_icon_editor.lvproj'
        if (-not (Test-Path -LiteralPath $project -PathType Leaf)) {
            throw "Project not found: $project"
        }
        $cli = 'C:\Program Files (x86)\National Instruments\Shared\LabVIEW CLI\LabVIEWCLI.exe'
        if (-not (Test-Path -LiteralPath $cli -PathType Leaf)) {
            throw "LabVIEW CLI executable not found: $cli"
        }
        $report = Join-Path $results 'lunit.xml'
        if (Test-Path -LiteralPath $report) { Remove-Item -LiteralPath $report -Force }
        Set-Location 'C:\workspace'
        Start-TestLabVIEW -Project $project
        & $cli -OperationName LUnit -LabVIEWPath $labview -PortNumber 3363 `
            -AdditionalOperationDirectory (Join-Path $labviewRoot 'vi.lib\Astemes\LUnit CLI') `
            -Path $project -ReportPath $report -LogToConsole TRUE -Headless
        if ($LASTEXITCODE -ne 0) { throw "LUnit CLI failed with exit code $LASTEXITCODE." }
    }
}
finally {
    Stop-TestLabVIEW
    Get-ChildItem -LiteralPath $env:TEMP -Filter 'lvtemporary_*.log' -File |
        Copy-Item -Destination $results -Force
    Stop-Transcript
}
