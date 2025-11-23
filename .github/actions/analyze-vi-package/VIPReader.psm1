# VIPReader.psm1
# Helper functions to read a VI Package (.vip) directly (as a ZIP) and parse its 'spec' file.
# No external tools required.

<#
.SYNOPSIS
Reads a .vip file and returns parsed spec metadata plus entry list.
#>
function Read-VipSpec {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory, Position=0)]
        [ValidateScript({ Test-Path $_ -PathType Leaf })]
        [string]$Path
    )
    # Open the .vip as a ZIP and read the 'spec' file
    Add-Type -AssemblyName System.IO.Compression.FileSystem | Out-Null
    $fs = [System.IO.File]::OpenRead((Resolve-Path $Path))
    try {
        $zip = New-Object System.IO.Compression.ZipArchive($fs, [System.IO.Compression.ZipArchiveMode]::Read, $false)
        $specEntry = $zip.Entries | Where-Object { $_.FullName -eq 'spec' } | Select-Object -First 1
        if (-not $specEntry) {
            throw "spec not found in VIP: $Path"
        }
        $reader = New-Object System.IO.StreamReader($specEntry.Open(), [System.Text.Encoding]::UTF8, $true)
        $text = $reader.ReadToEnd()
        $reader.Dispose()
    }
    finally {
        $zip.Dispose()
        $fs.Dispose()
    }

    # Parse into a nested OrderedDictionary: @{ SectionName = @{ Key = Value; ... }; ... }
    $sections = [System.Collections.Specialized.OrderedDictionary]::new()
    $current = $null

    $lines = $text -split "`r?`n"
    foreach ($line in $lines) {
        $trim = $line.Trim()
        if (-not $trim) { continue }
        if ($trim.StartsWith(';')) { continue }
        if ($trim -match '^\[(.+?)\]\s*$') {
            $current = $matches[1]
            if (-not $sections.Contains($current)) {
                $sections[$current] = [System.Collections.Specialized.OrderedDictionary]::new()
            }
            continue
        }
        if (-not $current) { continue }

        if ($trim -match '^(?<k>[^=]+)=(?<v>.*)$') {
            $k = $matches['k'].Trim()
            $v = $matches['v'].Trim()
            # Remove surrounding quotes if present
            if ($v.StartsWith('"') -and $v.EndsWith('"')) {
                $v = $v.Substring(1, $v.Length-2)
            }
            $sections[$current][$k] = $v
        }
    }

    # Add the raw text and list of entries for convenience
    [pscustomobject]@{
        Path       = (Resolve-Path $Path).Path
        Text       = $text
        Sections   = $sections
        ZipEntries = (Get-VipEntryList -Path $Path)
    }
}

<#
.SYNOPSIS
Lists all entries inside a .vip archive (zip).
#>
function Get-VipEntryList {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory, Position=0)]
        [ValidateScript({ Test-Path $_ -PathType Leaf })]
        [string]$Path
    )
    Add-Type -AssemblyName System.IO.Compression.FileSystem | Out-Null
    $fs = [System.IO.File]::OpenRead((Resolve-Path $Path))
    try {
        $zip = New-Object System.IO.Compression.ZipArchive($fs, [System.IO.Compression.ZipArchiveMode]::Read, $false)
        $zip.Entries | ForEach-Object { $_.FullName }
    }
    finally {
        $zip.Dispose()
        $fs.Dispose()
    }
}

<#
.SYNOPSIS
Retrieves a specific field from the parsed spec sections.
#>
function Get-VipField {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [hashtable]$Sections,
        [Parameter(Mandatory)]
        [string]$Section,
        [Parameter(Mandatory)]
        [string]$Key
    )
    if (-not $Sections.Contains($Section)) { return $null }
    $sec = $Sections[$Section]
    if ($sec -isnot [System.Collections.IDictionary]) { return $null }
    if (-not $sec.Contains($Key)) { return $null }
    return $sec[$Key]
}

Export-ModuleMember -Function Read-VipSpec, Get-VipEntryList, Get-VipField
