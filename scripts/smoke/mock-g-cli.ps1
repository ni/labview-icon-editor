[CmdletBinding()]
param(
    [Parameter(ValueFromRemainingArguments = $true)]
    [string[]]$Args
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$parsed = @{ repo = $null; dist = $null; lvver = $null; bitness = $null; name = $null }
for ($i = 0; $i -lt $Args.Length; $i++) {
    switch ($Args[$i]) {
        '--repo'    { if ($i + 1 -ge $Args.Length) { throw "Missing value for --repo" }    $parsed.repo = $Args[++$i]; continue }
        '--dist'    { if ($i + 1 -ge $Args.Length) { throw "Missing value for --dist" }    $parsed.dist = $Args[++$i]; continue }
        '--lv-ver'  { if ($i + 1 -ge $Args.Length) { throw "Missing value for --lv-ver" }  $parsed.lvver = $Args[++$i]; continue }
        '--bitness' { if ($i + 1 -ge $Args.Length) { throw "Missing value for --bitness" } $parsed.bitness = $Args[++$i]; continue }
        '--name'    { if ($i + 1 -ge $Args.Length) { throw "Missing value for --name" }    $parsed.name = $Args[++$i]; continue }
        default { continue }
    }
}

if (-not $parsed.dist) { throw "Mock g-cli requires --dist" }
$distRoot = Resolve-Path -LiteralPath $parsed.dist -ErrorAction SilentlyContinue
if (-not $distRoot) {
    $distRoot = New-Item -ItemType Directory -Force -Path $parsed.dist | Select-Object -ExpandProperty FullName
} else {
    $distRoot = $distRoot.ProviderPath
}

$files = @(
    @{ Rel = 'mock.txt'; Content = "mock source distribution for $($parsed.name ?? 'unknown') lv=$($parsed.lvver ?? 'unknown') bitness=$($parsed.bitness ?? 'unknown')" },
    @{ Rel = 'data/mock-data.txt'; Content = 'mock payload' }
)

foreach ($f in $files) {
    $target = Join-Path $distRoot $f.Rel
    $parent = Split-Path -Parent $target
    if (-not (Test-Path -LiteralPath $parent)) {
        New-Item -ItemType Directory -Force -Path $parent | Out-Null
    }
    Set-Content -LiteralPath $target -Value $f.Content -Encoding UTF8
}

Write-Host ("[mock-g-cli] wrote {0} file(s) under {1}" -f $files.Count, $distRoot)
exit 0
