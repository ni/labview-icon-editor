<#
.SYNOPSIS
    Updates display information in a VIPB file without launching LabVIEW.

.DESCRIPTION
    Resolves paths, merges version data into the DisplayInformation JSON, loads
    the VIPB XML, and updates the metadata fields in-place. This replaces the
    previous LabVIEW VI + g-cli approach so the metadata update can run entirely
    from PowerShell.

.PARAMETER SupportedBitness
    LabVIEW bitness for the build ("32" or "64").

.PARAMETER RepositoryPath
    Path to the repository root.

.PARAMETER VIPBPath
    Relative path to the VIPB file to modify.

.PARAMETER Package_LabVIEW_Version
    Minimum LabVIEW version supported by the package.

.PARAMETER LabVIEWMinorRevision
    Minor revision number of LabVIEW (0 or 3).

.PARAMETER Major
    Major version component for the package.

.PARAMETER Minor
    Minor version component for the package.

.PARAMETER Patch
    Patch version component for the package.

.PARAMETER Build
    Build number component for the package.

.PARAMETER Commit
    Commit identifier embedded in the package metadata.

.PARAMETER ReleaseNotesFile
    Path to a release notes file injected into the build.

.PARAMETER DisplayInformationJSON
    JSON string representing the VIPB display information to update.

.EXAMPLE
    .\ModifyVIPBDisplayInfo.ps1 -SupportedBitness "64" -RepositoryPath "C:\repo" -VIPBPath "Tooling\deployment\seed.vipb" -Package_LabVIEW_Version 2023 -LabVIEWMinorRevision 3 -Major 1 -Minor 0 -Patch 0 -Build 2 -Commit "abcd123" -ReleaseNotesFile "Tooling\deployment\release_notes.md" -DisplayInformationJSON '{"Package Version":{"major":1,"minor":0,"patch":0,"build":2}}'
#>
[CmdletBinding(SupportsShouldProcess = $true)]
param (
    [string]$SupportedBitness,
    [string]$RepositoryPath,
    [string]$VIPBPath,

[Alias('MinimumSupportedLVVersion')]
[int]$Package_LabVIEW_Version,

    [ValidateSet("0","3")]
    [string]$LabVIEWMinorRevision = "0",

    [int]$Major,
    [int]$Minor,
    [int]$Patch,
    [int]$Build,
    [string]$Commit,
    [string]$ReleaseNotesFile,

    [Parameter(Mandatory=$true)]
    [string]$DisplayInformationJSON,

    [string]$ErrorLog,
    [switch]$QuietErrors
)

$ErrorLogPath = if ($ErrorLog) {
    if ([System.IO.Path]::IsPathRooted($ErrorLog)) {
        $ErrorLog
    }
    else {
        Join-Path -Path (Get-Location).Path -ChildPath $ErrorLog
    }
} else {
    Join-Path $PSScriptRoot 'error.json'
}

# Ensure log directory exists and clear prior log
try {
    $logDir = Split-Path -Path $ErrorLogPath -Parent
    if ($logDir -and -not (Test-Path -LiteralPath $logDir)) {
        New-Item -ItemType Directory -Path $logDir -Force | Out-Null
    }
}
catch {
    if (-not $QuietErrors) {
        Write-Warning ("Failed to ensure error log directory for {0}: {1}" -f $ErrorLogPath, $_.Exception.Message)
    }
}
Remove-Item -LiteralPath $ErrorLogPath -ErrorAction SilentlyContinue

$ErrorPrefix = "VIPB_UPDATE_"

function Out-JsonSafe {
    param(
        [Parameter(Mandatory)]$Object,
        [int]$Depth = 4
    )
    $Object | ConvertTo-Json -Depth $Depth -WarningAction SilentlyContinue
}

function Write-ErrorPayload {
    param(
        [string]$Error,
        [string]$Details = "",
        [string]$Context = "",
        [string]$Path = ""
    )
    $payload = [ordered]@{
        error   = $Error
        details = $Details
        context = $Context
        path    = $Path
    }
    $json = $payload | ConvertTo-Json -Depth 4 -WarningAction SilentlyContinue

    try {
        $json | Set-Content -Path $ErrorLogPath -Encoding utf8
    }
    catch {
        # Best effort; still emit to stdout if file write fails
        if (-not $QuietErrors) {
            Write-Warning ("Failed to write error log to {0}: {1}" -f $ErrorLogPath, $_.Exception.Message)
        }
    }

    if (-not $QuietErrors) {
        Write-Error ("{0}{1}: See error log: {2}" -f $ErrorPrefix, $Error, $ErrorLogPath)
        $json
    }
    exit 1
}

function Resolve-VipbPath {
    param(
        [string]$RepositoryPath,
        [string]$VIPBPath
    )

    $repoPath = $RepositoryPath
    if ($RepositoryPath -is [System.Management.Automation.PathInfo]) {
        $repoPath = $RepositoryPath.ProviderPath
    }

    if ([string]::IsNullOrWhiteSpace($repoPath) -or -not (Test-Path -LiteralPath $repoPath)) {
        Write-ErrorPayload -Error "RepositoryPath is missing or invalid." -Path $RepositoryPath
    }

    # Prefer an explicitly provided path when it exists
    if (-not [string]::IsNullOrWhiteSpace($VIPBPath)) {
        try {
            $candidate = $VIPBPath
            if (-not [System.IO.Path]::IsPathRooted($candidate)) {
                $candidate = Join-Path -Path $repoPath -ChildPath $candidate -ErrorAction Stop
            }
            $resolved = Resolve-Path -LiteralPath $candidate -ErrorAction Stop
            return $resolved.ProviderPath
        }
        catch {
            Write-Information ("VIPBPath '{0}' not found; attempting discovery under {1}" -f $VIPBPath, $repoPath) -InformationAction Continue
        }
    }

    # Auto-discover a single VIPB in the repository
    $vipbFiles = Get-ChildItem -Path $repoPath -Filter *.vipb -File -Recurse
    if (-not $vipbFiles -or $vipbFiles.Count -eq 0) {
        Write-ErrorPayload -Error "No VIPB file found under repository." -Path $repoPath
    }
    if ($vipbFiles.Count -gt 1) {
        $paths = $vipbFiles | ForEach-Object { $_.FullName }
        Write-ErrorPayload -Error "Multiple VIPB files found; specify VIPBPath to disambiguate." -Details ($paths -join '; ') -Path $repoPath
    }

    Write-Information ("Auto-discovered VIPB at {0}" -f $vipbFiles[0].FullName) -InformationAction Continue
    return $vipbFiles[0].FullName
}

# 1) Resolve paths
try {
    $ResolvedRepositoryPath = Resolve-Path -Path $RepositoryPath -ErrorAction Stop
}
catch {
    Write-ErrorPayload -Error "Error resolving RepositoryPath." `
        -Details $_.Exception.Message `
        -Context "RepositoryPath=$RepositoryPath"
}

# Early validation: verify inputs exist and required JSON keys are present before heavy work
if (-not $RepositoryPath -or -not (Test-Path -LiteralPath $RepositoryPath)) {
    Write-ErrorPayload -Error "RepositoryPath is missing or invalid." -Path $RepositoryPath
}

$ResolvedVIPBPath = Resolve-VipbPath -RepositoryPath $ResolvedRepositoryPath -VIPBPath $VIPBPath
if (-not $ReleaseNotesFile) {
    Write-ErrorPayload -Error "ReleaseNotesFile path is required." -Context "ReleaseNotesFile not provided"
}

# 2) Create release notes if needed
if (-not (Test-Path $ReleaseNotesFile)) {
    if ($PSCmdlet.ShouldProcess($ReleaseNotesFile, "Create release notes file placeholder")) {
        Write-Information "Release notes file '$ReleaseNotesFile' does not exist. Creating it..." -InformationAction Continue
        New-Item -ItemType File -Path $ReleaseNotesFile -Force | Out-Null
    }
}

try {
    $ResolvedReleaseNotesFile = Resolve-Path -Path $ReleaseNotesFile -ErrorAction Stop
}
catch {
    Write-ErrorPayload -Error "Error resolving ReleaseNotesFile. Ensure the path exists and is accessible." `
        -Details $_.Exception.Message `
        -Path $ReleaseNotesFile
}

# 3) Resolve LabVIEW version from VIPB to ensure determinism and calculate the LabVIEW version string
$versionScriptCandidates = @(
    (Join-Path $RepositoryPath 'scripts/get-package-lv-version.ps1'),
    (Join-Path $PSScriptRoot '..\..\scripts\get-package-lv-version.ps1'),
    (Join-Path $PSScriptRoot '..\..\..\scripts\get-package-lv-version.ps1')
) | Where-Object { Test-Path -LiteralPath $_ }
if (-not $versionScriptCandidates -or $versionScriptCandidates.Count -eq 0) {
    Write-ErrorPayload -Error "Unable to locate get-package-lv-version.ps1 to resolve LabVIEW version." -Context ("PSScriptRoot={0}" -f $PSScriptRoot)
}

$Package_LabVIEW_Version = & ($versionScriptCandidates | Select-Object -First 1) -RepositoryPath $RepositoryPath
$lvNumericMajor    = $Package_LabVIEW_Version - 2000
$lvNumericVersion  = "$($lvNumericMajor).$LabVIEWMinorRevision"
if ($SupportedBitness -eq "64") {
    $VIP_LVVersion_A = "$lvNumericVersion (64-bit)"
}
else {
    $VIP_LVVersion_A = $lvNumericVersion
}
Write-Output "Modifying VI Package Information metadata (no LabVIEW dependency)..."

# 4) Parse and update the DisplayInformationJSON
try {
    $jsonObj = $DisplayInformationJSON | ConvertFrom-Json
}
catch {
    Write-ErrorPayload -Error "Failed to parse DisplayInformationJSON into valid JSON." `
        -Details $_.Exception.Message `
        -Context ("DisplayInformationJSON length: {0}" -f ($DisplayInformationJSON.Length))
}

# If "Package Version" doesn't exist, create it as a subobject
if (-not $jsonObj.'Package Version') {
    $jsonObj | Add-Member -MemberType NoteProperty -Name 'Package Version' -Value ([PSCustomObject]@{
        major = $Major
        minor = $Minor
        patch = $Patch
        build = $Build
    })
}
else {
    # "Package Version" exists, so just overwrite its fields
    $jsonObj.'Package Version'.major = $Major
    $jsonObj.'Package Version'.minor = $Minor
    $jsonObj.'Package Version'.patch = $Patch
    $jsonObj.'Package Version'.build = $Build
}

# Ensure required fields exist before modifying the VIPB
$requiredFields = @(
    'Company Name',
    'Product Name',
    'Product Description Summary',
    'Product Description'
)

# Ensure we always have an array even when zero/one items to avoid StrictMode Count errors
$missingFields = @($requiredFields | Where-Object { [string]::IsNullOrWhiteSpace($jsonObj.PSObject.Properties[$_].Value) })
if ($missingFields.Count -gt 0) {
    $providedKeys = ($jsonObj.PSObject.Properties.Name -join ', ')
    $inputHash    = [System.BitConverter]::ToString((New-Object System.Security.Cryptography.SHA256Managed).ComputeHash([System.Text.Encoding]::UTF8.GetBytes($DisplayInformationJSON))).Replace("-", "")
    Write-ErrorPayload -Error "DisplayInformationJSON is missing required field(s)." `
        -Details ("Missing: {0}" -f ($missingFields -join ', ')) `
        -Context ("Provided keys: {0}; payload hash: {1}" -f $providedKeys, $inputHash)
}

# Helper to set or create XML child nodes safely
function Set-VipbElementValue {
    [CmdletBinding(SupportsShouldProcess = $true)]
    param(
        [System.Xml.XmlNode]$ParentNode,
        [string]$ElementName,
        [string]$Value
    )

    if (-not $ParentNode) { return }

    if (-not $PSCmdlet.ShouldProcess($ElementName, "Set VIPB element value")) {
        return
    }

    $element = $ParentNode.SelectSingleNode($ElementName)
    if (-not $element) {
        $element = $ParentNode.OwnerDocument.CreateElement($ElementName)
        [void]$ParentNode.AppendChild($element)
    }

    $element.InnerText = $Value
}

# 5) Load and update the VIPB XML directly
try {
    [xml]$vipbXml = Get-Content -Raw -Path $ResolvedVIPBPath
}
catch {
    Write-ErrorPayload -Error "Failed to load VIPB file." `
        -Details $_.Exception.Message `
        -Path $ResolvedVIPBPath
}

$generalSettings     = $vipbXml.VI_Package_Builder_Settings.Library_General_Settings
$advancedSettings    = $vipbXml.VI_Package_Builder_Settings.Advanced_Settings
$descriptionSettings = $advancedSettings.Description

if (-not $generalSettings -or -not $descriptionSettings) {
    Write-ErrorPayload -Error "VIPB file is missing expected sections (Library_General_Settings or Description)." `
        -Path $ResolvedVIPBPath
}

# Update high-level metadata
Set-VipbElementValue -ParentNode $generalSettings -ElementName "Library_Version" -Value "$Major.$Minor.$Patch.$Build"
Set-VipbElementValue -ParentNode $generalSettings -ElementName "Package_LabVIEW_Version" -Value $VIP_LVVersion_A

# Update metadata based on known DisplayInformation keys
$metadataMap = @(
    @{ Key = 'Company Name';                 Parent = $generalSettings;     Element = 'Company_Name' },
    @{ Key = 'Product Name';                 Parent = $generalSettings;     Element = 'Product_Name' },
    @{ Key = 'Product Description Summary';  Parent = $descriptionSettings; Element = 'One_Line_Description_Summary' },
    @{ Key = 'Author Name (Person or Company)'; Parent = $descriptionSettings; Element = 'Packager' },
    @{ Key = 'Product Homepage (URL)';       Parent = $descriptionSettings; Element = 'URL' },
    @{ Key = 'Legal Copyright';              Parent = $descriptionSettings; Element = 'Copyright' }
)

foreach ($mapping in $metadataMap) {
    $value = $jsonObj.PSObject.Properties[$mapping.Key].Value
    if ($null -ne $value) {
        Set-VipbElementValue -ParentNode $mapping.Parent -ElementName $mapping.Element -Value $value
    }
}

# Handle release notes: ReleaseNotesFile is the source of truth
$releaseNotesFromFile = $null
try {
    if (Test-Path $ResolvedReleaseNotesFile) {
        $releaseNotesFromFile = Get-Content -Raw -Path $ResolvedReleaseNotesFile -ErrorAction Stop
    }
}
catch {
    Write-ErrorPayload -Error "Failed to read release notes file." `
        -Details $_.Exception.Message `
        -Path $ResolvedReleaseNotesFile
}

if ([string]::IsNullOrWhiteSpace($releaseNotesFromFile)) {
    # Attempt to pull content from git if available
    $fallbackContent = $null
    $repoRoot = $ResolvedRepositoryPath.ProviderPath
    $relPath  = $ResolvedReleaseNotesFile.ProviderPath
    if ($relPath.StartsWith($repoRoot, [System.StringComparison]::OrdinalIgnoreCase)) {
        $relPath = $relPath.Substring($repoRoot.Length).TrimStart('\','/')
    }

    if (Get-Command git -ErrorAction SilentlyContinue) {
        try {
            $fallbackContent = git -C $repoRoot show ("HEAD:{0}" -f $relPath) 2>$null
        }
        catch {
            # ignore; handled below
        }
    }

    if (-not [string]::IsNullOrWhiteSpace($fallbackContent)) {
        try {
            $fallbackContent | Set-Content -Path $ResolvedReleaseNotesFile -Encoding utf8
            $releaseNotesFromFile = $fallbackContent
            Write-Information "Release notes were empty; populated from git HEAD:$relPath" -InformationAction Continue
        }
        catch {
            Write-ErrorPayload -Error "Release notes file is empty and could not be populated." `
                -Details $_.Exception.Message `
                -Path $ResolvedReleaseNotesFile
        }
    }
    elseif (-not [string]::IsNullOrWhiteSpace($jsonObj.'Release Notes - Change Log')) {
        try {
            $jsonObj.'Release Notes - Change Log' | Set-Content -Path $ResolvedReleaseNotesFile -Encoding utf8
            $releaseNotesFromFile = $jsonObj.'Release Notes - Change Log'
            Write-Information "Release notes were empty; populated from DisplayInformationJSON." -InformationAction Continue
        }
        catch {
            Write-ErrorPayload -Error "Release notes file is empty and could not be populated from DisplayInformationJSON." `
                -Details $_.Exception.Message `
                -Path $ResolvedReleaseNotesFile
        }
    }
    else {
        $defaultNotes = "Release notes were not provided; generated placeholder."
        try {
            $defaultNotes | Set-Content -Path $ResolvedReleaseNotesFile -Encoding utf8
            $releaseNotesFromFile = $defaultNotes
            Write-Information "Release notes were empty; populated with placeholder content." -InformationAction Continue
        }
        catch {
            Write-ErrorPayload -Error "Release notes file is empty. Populate it or provide valid content before running this action." `
                -Path $ResolvedReleaseNotesFile
        }
    }
}

$releaseNotesJsonValue = $jsonObj.'Release Notes - Change Log'
if (-not [string]::IsNullOrWhiteSpace($releaseNotesJsonValue) -and ($releaseNotesJsonValue -ne $releaseNotesFromFile)) {
    Write-Warning "Release notes JSON differs from the contents of '$ResolvedReleaseNotesFile'. The file content will be used."
}

Set-VipbElementValue -ParentNode $descriptionSettings -ElementName "Release_Notes" -Value $releaseNotesFromFile

# Update long description and embed commit fingerprint
$descriptionValue = $jsonObj.'Product Description'
if (-not [string]::IsNullOrWhiteSpace($Commit)) {
    $descriptionValue = "{0}`n`nCommit: {1}" -f $descriptionValue, $Commit
}
Set-VipbElementValue -ParentNode $descriptionSettings -ElementName "Description" -Value $descriptionValue

# Update optional license reference (resolve to an actual file path when possible)
$licenseAgreementInput = $jsonObj.'License Agreement Name'
if (-not [string]::IsNullOrWhiteSpace($licenseAgreementInput)) {
    $candidatePath = $licenseAgreementInput
    $relativePath  = $licenseAgreementInput

    if (-not [System.IO.Path]::IsPathRooted($candidatePath)) {
        $candidatePath = Join-Path -Path $ResolvedRepositoryPath -ChildPath $licenseAgreementInput
    }

    if (Test-Path $candidatePath) {
        try {
            $resolvedLicensePath = (Resolve-Path -Path $candidatePath -ErrorAction Stop).Path

            if ($resolvedLicensePath.StartsWith($ResolvedRepositoryPath, [System.StringComparison]::OrdinalIgnoreCase)) {
                $relativePath = $resolvedLicensePath.Substring($ResolvedRepositoryPath.Length).TrimStart('\','/')
            }
        }
        catch {
            Write-Warning "Unable to resolve license file path '$candidatePath'. Using literal value instead."
        }
    }
    else {
        Write-Warning "License agreement path '$licenseAgreementInput' does not exist relative to the repository."
    }

    Set-VipbElementValue -ParentNode $advancedSettings -ElementName "License_Agreement_Filepath" -Value $relativePath
}

# Warn about any DisplayInformation JSON keys we don't yet handle
$recognizedKeys = @(
    'Company Name',
    'Product Name',
    'Product Description Summary',
    'Product Description',
    'License Agreement Name',
    'Author Name (Person or Company)',
    'Product Homepage (URL)',
    'Legal Copyright',
    'Release Notes - Change Log',
    'Package Version'
)

$unhandledKeys = @($jsonObj.PSObject.Properties | Where-Object { $_.Name -notin $recognizedKeys })
if ($unhandledKeys.Count -gt 0) {
    $detailKeys = $unhandledKeys | ForEach-Object { $_.Name }
    Write-ErrorPayload -Error "DisplayInformationJSON contains unhandled field(s). Update the mapping to keep metadata in sync." `
        -Details ("Unhandled: {0}" -f ($detailKeys -join ', ')) `
        -Context ("Recognized: {0}" -f ($recognizedKeys -join ', '))
}

try {
    $writerSettings = New-Object System.Xml.XmlWriterSettings
    $writerSettings.Indent = $true
    $writerSettings.IndentChars = "  "
    $writerSettings.NewLineHandling = [System.Xml.NewLineHandling]::Replace
    $writerSettings.NewLineChars = "`n"

    $vipbDir   = Split-Path -Parent $ResolvedVIPBPath
    $vipbLeaf  = Split-Path -Leaf   $ResolvedVIPBPath
    $backupPath = Join-Path $vipbDir ($vipbLeaf + ".bak")
    $tempPath   = Join-Path $vipbDir ($vipbLeaf + ".tmp")

    if ($PSCmdlet.ShouldProcess($ResolvedVIPBPath, "Save updated VIPB metadata (with backup)")) {
        Copy-Item -LiteralPath $ResolvedVIPBPath -Destination $backupPath -Force

        $xmlWriter = [System.Xml.XmlWriter]::Create($tempPath, $writerSettings)
        $vipbXml.Save($xmlWriter)
        $xmlWriter.Close()

        try {
            [xml]$postSave = Get-Content -LiteralPath $tempPath -Raw
        }
        catch {
            if (Test-Path -LiteralPath $backupPath) {
                Copy-Item -LiteralPath $backupPath -Destination $ResolvedVIPBPath -Force
            }
            throw "VIPB became unreadable after save: $($_.Exception.Message)"
        }

        if (-not $postSave.VI_Package_Builder_Settings -or -not $postSave.VI_Package_Builder_Settings.Library_General_Settings) {
            if (Test-Path -LiteralPath $backupPath) {
                Copy-Item -LiteralPath $backupPath -Destination $ResolvedVIPBPath -Force
            }
            throw "VIPB validation failed after save; restoring backup from $backupPath."
        }

        Move-Item -LiteralPath $tempPath -Destination $ResolvedVIPBPath -Force
        if (Test-Path -LiteralPath $backupPath) {
            Remove-Item -LiteralPath $backupPath -Force -ErrorAction SilentlyContinue
        }
    }

    Write-Information "Successfully updated VIPB metadata: $ResolvedVIPBPath" -InformationAction Continue
}
catch {
    Write-ErrorPayload -Error "Failed to save updated VIPB metadata." `
        -Details $_.Exception.Message `
        -Path $ResolvedVIPBPath
}

# Avoid leaking a non-zero $LASTEXITCODE from any auxiliary git/lookups that ran successfully
$global:LASTEXITCODE = 0
