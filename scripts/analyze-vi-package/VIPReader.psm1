# Simple VIP reader for Analyze-VIP tests. Parses the `spec` entry inside a
# .vip (zip) to expose sections/keys and the list of archive entries.

function Get-CaseInsensitiveTable {
    return New-Object System.Collections.Hashtable ([System.StringComparer]::InvariantCultureIgnoreCase)
}

function Normalize-VipValue {
    param([string]$Value)

    if ($null -eq $Value) { return $null }
    $trimmed = $Value.Trim()
    # Strip a single layer of surrounding quotes that VIPM emits for string fields.
    if ($trimmed.Length -ge 2 -and $trimmed.StartsWith('"') -and $trimmed.EndsWith('"')) {
        $trimmed = $trimmed.Substring(1, $trimmed.Length - 2)
    }
    return $trimmed
}

function Read-VipSpec {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$Path
    )

    $resolved = (Resolve-Path -LiteralPath $Path -ErrorAction Stop).Path
    $zip = [System.IO.Compression.ZipFile]::OpenRead($resolved)
    $entries = @($zip.Entries | ForEach-Object { $_.FullName })

    $specEntry = $zip.Entries | Where-Object { $_.FullName -eq 'spec' } | Select-Object -First 1
    if (-not $specEntry) {
        $zip.Dispose()
        throw "Spec entry not found in VIP: $resolved"
    }

    $content = $null
    try {
        $reader = New-Object System.IO.StreamReader($specEntry.Open())
        $content = $reader.ReadToEnd()
    }
    finally {
        if ($reader) { $reader.Dispose() }
        $zip.Dispose()
    }

    $sections = Get-CaseInsensitiveTable
    $current = $null
    foreach ($line in ($content -split "`r?`n")) {
        $trim = $line.Trim()
        if ([string]::IsNullOrWhiteSpace($trim)) { continue }
        if ($trim -match '^\s*#') { continue }
        $sectionMatch = [regex]::Match($trim, '^\s*\[(?<name>.+?)\]\s*$')
        if ($sectionMatch.Success) {
            $name = $sectionMatch.Groups['name'].Value.Trim()
            $current = Get-CaseInsensitiveTable
            $sections[$name] = $current
            continue
        }
        $kv = [regex]::Match($trim, '^(?<key>[^=]+)=(?<val>.*)$')
        if ($kv.Success -and $current) {
            $key = $kv.Groups['key'].Value.Trim()
            $val = Normalize-VipValue -Value $kv.Groups['val'].Value
            $current[$key] = $val
        }
    }

    return [pscustomobject]@{
        Sections   = $sections
        ZipEntries = $entries
    }
}

function Get-VipField {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]$Sections,
        [Parameter(Mandatory)][string]$Section,
        [Parameter(Mandatory)][string]$Key
    )

    if (-not $Sections) { return $null }
    try {
        $sec = $Sections[$Section]
        if (-not $sec) { return $null }
        return $sec[$Key]
    }
    catch {
        return $null
    }
}

Export-ModuleMember -Function Read-VipSpec, Get-VipField
