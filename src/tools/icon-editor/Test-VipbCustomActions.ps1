#Requires -Version 7.0
[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [string]$VipbPath,

    [string]$Workspace = (Get-Location).Path,

    [string[]]$DisallowedActions = @(
        'VIP_Pre-Install Custom Action 2021.vi',
        'VIP_Post-Install Custom Action 2021.vi',
        'VIP_Pre-Uninstall Custom Action 2021.vi',
        'VIP_Post-Uninstall Custom Action 2021.vi'
    )
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$resolvedVipb = (Resolve-Path -LiteralPath $VipbPath -ErrorAction Stop).ProviderPath
$workspaceRoot = (Resolve-Path -LiteralPath $Workspace -ErrorAction Stop).ProviderPath

function Format-WorkspacePath {
    param([string]$Path)

    if (-not $workspaceRoot) { return $Path }
    $comparison = [System.StringComparison]::OrdinalIgnoreCase
    if ($Path.StartsWith($workspaceRoot, $comparison)) {
        $trimmed = $Path.Substring($workspaceRoot.Length).TrimStart('\','/')
        if ($trimmed) {
            return ".\\$trimmed"
        }
    }
    return $Path
}

$seedHelper = Join-Path $PSScriptRoot 'Invoke-SeedVipb.ps1'
if (-not (Test-Path -LiteralPath $seedHelper -PathType Leaf)) {
    throw "Seed helper '$seedHelper' not found."
}

$tempJson = Join-Path ([System.IO.Path]::GetTempPath()) ("vipb-custom-actions-{0}.json" -f [System.Guid]::NewGuid().ToString('N'))
try {
    & $seedHelper -Mode vipb2json -InputPath $resolvedVipb -OutputPath $tempJson | Out-Null
    if (-not (Test-Path -LiteralPath $tempJson -PathType Leaf)) {
        throw "Seed conversion did not produce '$tempJson'."
    }

    $vipbText = Get-Content -LiteralPath $resolvedVipb -Raw
    $tags = @('Pre-Install_VI','Post-Install_VI','Pre-Uninstall_VI','Post-Uninstall_VI')
    $violations = New-Object System.Collections.Generic.List[string]
    foreach ($tag in $tags) {
        $pattern = "<$tag>(?<value>.*?)</$tag>"
        $match = [regex]::Match($vipbText, $pattern, [System.Text.RegularExpressions.RegexOptions]::Singleline)
        if (-not $match.Success) { continue }
        $value = $match.Groups['value'].Value.Trim()
        if ([string]::IsNullOrWhiteSpace($value)) { continue }
        foreach ($disallowed in $DisallowedActions) {
            if ($value -eq $disallowed) {
                $violations.Add("Tag '$tag' references disallowed file '$value'.") | Out-Null
                continue
            }
        }
        if ([System.IO.Path]::IsPathRooted($value)) {
            $resolvedPath = $value
        } else {
            $baseDir = Split-Path -Parent $resolvedVipb
            $resolvedPath = [System.IO.Path]::GetFullPath((Join-Path $baseDir $value))
        }
        if (-not (Test-Path -LiteralPath $resolvedPath -PathType Leaf)) {
            $displayPath = Format-WorkspacePath -Path $resolvedPath
            $violations.Add("Tag '$tag' references missing file '$displayPath'.") | Out-Null
        }
    }
    if ($violations.Count -gt 0) {
        throw "VIPB custom action guard failed:`n - {0}" -f ($violations -join "`n - ")
    }
}
finally {
    if (Test-Path -LiteralPath $tempJson -PathType Leaf) {
        Remove-Item -LiteralPath $tempJson -Force -ErrorAction SilentlyContinue
    }
}
