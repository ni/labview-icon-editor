[CmdletBinding()]
param(
    [string]$RepositoryPath = (Get-Location).Path
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$repo = (Resolve-Path -LiteralPath $RepositoryPath).Path
$bindScript = Join-Path $PSScriptRoot '..\.github\actions\bind-development-mode\BindDevelopmentMode.ps1'

Write-Host "Dev Mode Bind (force clean): removing LocalHost.LibraryPaths entries from the LabVIEW INIs and unbinding both bitnesses (Force)"
& $bindScript -RepositoryPath $repo -Mode unbind -Bitness both -Force

Write-Host "Dev Mode Bind (force clean): writing this repo into LocalHost.LibraryPaths for both bitnesses and prepping sources (Force)"
& $bindScript -RepositoryPath $repo -Mode bind -Bitness both -Force
