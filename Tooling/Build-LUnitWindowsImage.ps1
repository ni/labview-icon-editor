[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [string]$Image,

    [string]$Network = 'nat'
)

$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'
$context = Join-Path ([IO.Path]::GetTempPath()) ('lvie-lunit-image-' + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path (Join-Path $context 'Tooling') -Force | Out-Null
try {
    # Stage only the setup helper and Dockerfile, never the worktree's .git or credentials.
    Copy-Item (Join-Path $PSScriptRoot 'Run-LUnitWindowsContainer.ps1') (Join-Path $context 'Tooling')
    Copy-Item (Join-Path $PSScriptRoot 'containers\lunit-windows.Dockerfile') (Join-Path $context 'Dockerfile')
    docker build --network $Network --tag $Image $context
    if ($LASTEXITCODE -ne 0) { throw "Required LUnit image build failed: $LASTEXITCODE" }
}
finally {
    Remove-Item -LiteralPath $context -Recurse -Force
}
