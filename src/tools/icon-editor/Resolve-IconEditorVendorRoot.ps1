#Requires -Version 7.0
[CmdletBinding()]
param(
    [string]$Workspace = (Get-Location).Path
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$resolvedWorkspace = (Resolve-Path -LiteralPath $Workspace -ErrorAction Stop).ProviderPath
$configPath = Join-Path $resolvedWorkspace 'configs\icon-editor-vendor.json'

if (Test-Path -LiteralPath $configPath -PathType Leaf) {
    try {
        $config = Get-Content -LiteralPath $configPath -Raw | ConvertFrom-Json -Depth 5
        if ($config -and $config.PSObject.Properties['vendorRoot']) {
            $rawPath = [string]$config.vendorRoot
            if (-not [string]::IsNullOrWhiteSpace($rawPath)) {
                $expanded = $rawPath.Replace('${workspaceFolder}', $resolvedWorkspace)
                if ($expanded) {
                    $resolvedCandidate = [System.IO.Path]::GetFullPath($expanded)
                    if (Test-Path -LiteralPath $resolvedCandidate -PathType Container) {
                        return $resolvedCandidate
                    }
                }
            }
        }
    } catch {
        throw "Failed to parse icon-editor vendor config at '$configPath': $($_.Exception.Message)"
    }
}

$vendorRoot = Join-Path $resolvedWorkspace 'vendor'
if (Test-Path -LiteralPath $vendorRoot -PathType Container) {
    foreach ($dir in Get-ChildItem -LiteralPath $vendorRoot -Directory) {
        $vipbPath = Join-Path $dir.FullName 'Tooling\deployment\NI_Icon_editor.vipb'
        if (Test-Path -LiteralPath $vipbPath -PathType Leaf) {
            return $dir.FullName
        }
    }
}

throw "Unable to resolve icon editor vendor root. Update configs/icon-editor-vendor.json or vendor the LabVIEW icon editor repo."
