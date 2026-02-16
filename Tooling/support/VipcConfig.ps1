#Requires -Version 7.0
<#
.SYNOPSIS
    Reads target metadata from a VIPC file.

.DESCRIPTION
    Opens a .vipc archive, parses config.xml, and returns core target fields
    used by automation guards.
#>

function Get-VipcConfigInfo {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$VipcPath
    )

    if (-not (Test-Path -Path $VipcPath -PathType Leaf)) {
        throw "VIPC file not found at '$VipcPath'."
    }

    Add-Type -AssemblyName System.IO.Compression.FileSystem

    $resolvedVipcPath = (Resolve-Path -Path $VipcPath -ErrorAction Stop).Path
    $zip = $null
    try {
        $zip = [System.IO.Compression.ZipFile]::OpenRead($resolvedVipcPath)
        $configEntry = $zip.Entries | Where-Object { $_.FullName -eq 'config.xml' } | Select-Object -First 1
        if (-not $configEntry) {
            throw "config.xml was not found inside VIPC '$resolvedVipcPath'."
        }

        $reader = New-Object System.IO.StreamReader($configEntry.Open())
        try {
            $configText = $reader.ReadToEnd()
        }
        finally {
            $reader.Close()
        }

        [xml]$configXml = $configText
        $targetNode = $configXml.SelectSingleNode('/VI_Package_Configuration/Target')
        if (-not $targetNode) {
            throw "Target metadata was not found in VIPC config.xml."
        }

        $targetName = [string]$targetNode.Name
        $targetVersionRaw = [string]$targetNode.Version
        if ([string]::IsNullOrWhiteSpace($targetVersionRaw)) {
            throw "Target version was empty in VIPC config.xml."
        }

        $versionMatch = [regex]::Match($targetVersionRaw, '(?<major>\d+)(?:\.(?<minor>\d+))?')
        if (-not $versionMatch.Success) {
            throw "Could not parse target version '$targetVersionRaw' from VIPC config.xml."
        }

        $major = $versionMatch.Groups['major'].Value
        $minor = if ($versionMatch.Groups['minor'].Success) { $versionMatch.Groups['minor'].Value } else { '0' }
        $targetVersionNumeric = '{0}.{1}' -f $major, $minor

        $packageNames = @(
            $targetNode.Package |
                ForEach-Object { [string]$_.Name } |
                Where-Object { -not [string]::IsNullOrWhiteSpace($_) }
        )

        return [pscustomobject]@{
            VipcPath             = $resolvedVipcPath
            TargetName           = $targetName
            TargetVersionRaw     = $targetVersionRaw
            TargetVersionNumeric = $targetVersionNumeric
            PackageCount         = $packageNames.Count
        }
    }
    finally {
        if ($zip) {
            $zip.Dispose()
        }
    }
}
