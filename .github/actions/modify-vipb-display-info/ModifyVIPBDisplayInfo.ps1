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

.PARAMETER RepoRoot
    Path to the repository root.

.PARAMETER VIPBPath
    Relative path to the VIPB file to modify.

.PARAMETER MinimumSupportedLVVersion
    LabVIEW major version (2021 only; 21.0).

.PARAMETER LabVIEWMinorRevision
    Minor revision number of LabVIEW (0 for 21.0).

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
    .\ModifyVIPBDisplayInfo.ps1 -SupportedBitness "64" -RepoRoot "C:\repo" -VIPBPath "Tooling\deployment\NI Icon editor.vipb" -MinimumSupportedLVVersion 2021 -LabVIEWMinorRevision 0 -Major 1 -Minor 0 -Patch 0 -Build 2 -Commit "abcd123" -ReleaseNotesFile "Tooling\deployment\release_notes.md" -DisplayInformationJSON '{"Package Version":{"major":1,"minor":0,"patch":0,"build":2}}'
#>
param (
    [string]$SupportedBitness,
    [string]$RepoRoot,
    [string]$VIPBPath,

    [ValidateSet(2021)]
    [int]$MinimumSupportedLVVersion,

    [ValidateSet("0")]
    [string]$LabVIEWMinorRevision = "0",

    [int]$Major,
    [int]$Minor,
    [int]$Patch,
    [int]$Build,
    [string]$Commit,
    [string]$ReleaseNotesFile,

    [Parameter(Mandatory=$true)]
    [string]$DisplayInformationJSON
)

# 1) Resolve paths
try {
    $ResolvedRepoRoot = Resolve-Path -Path $RepoRoot -ErrorAction Stop
    $ResolvedVIPBPath = Join-Path -Path $ResolvedRepoRoot -ChildPath $VIPBPath -ErrorAction Stop
}
catch {
    $errorObject = [PSCustomObject]@{
        error      = "Error resolving paths. Ensure RepoRoot and VIPBPath are valid."
        exception  = $_.Exception.Message
        stackTrace = $_.Exception.StackTrace
    }
    $errorObject | ConvertTo-Json -Depth 10
    exit 1
}

# 2) Create release notes if needed
if (-not (Test-Path $ReleaseNotesFile)) {
    Write-Host "Release notes file '$ReleaseNotesFile' does not exist. Creating it..."
    New-Item -ItemType File -Path $ReleaseNotesFile -Force | Out-Null
}

try {
    $ResolvedReleaseNotesFile = Resolve-Path -Path $ReleaseNotesFile -ErrorAction Stop
}
catch {
    $errorObject = [PSCustomObject]@{
        error      = "Error resolving ReleaseNotesFile. Ensure the path exists and is accessible."
        exception  = $_.Exception.Message
        stackTrace = $_.Exception.StackTrace
    }
    $errorObject | ConvertTo-Json -Depth 10
    exit 1
}

# 3) Calculate the LabVIEW version string
$lvNumericMajor    = $MinimumSupportedLVVersion - 2000
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
    $errorObject = [PSCustomObject]@{
        error      = "Failed to parse DisplayInformationJSON into valid JSON."
        exception  = $_.Exception.Message
        stackTrace = $_.Exception.StackTrace
    }
    $errorObject | ConvertTo-Json -Depth 10
    exit 1
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

$missingFields = $requiredFields | Where-Object { [string]::IsNullOrWhiteSpace($jsonObj.PSObject.Properties[$_].Value) }
if ($missingFields.Count -gt 0) {
    $errorObject = [PSCustomObject]@{
        error            = "DisplayInformationJSON is missing required field(s)."
        missing_fields   = $missingFields
        provided_payload = $jsonObj
    }
    $errorObject | ConvertTo-Json -Depth 10
    exit 1
}

# Helper to set or create XML child nodes safely
function Set-VipbElementValue {
    param(
        [System.Xml.XmlNode]$ParentNode,
        [string]$ElementName,
        [string]$Value
    )

    if (-not $ParentNode) { return }

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
    $errorObject = [PSCustomObject]@{
        error      = "Failed to load VIPB file."
        exception  = $_.Exception.Message
        stackTrace = $_.Exception.StackTrace
    }
    $errorObject | ConvertTo-Json -Depth 10
    exit 1
}

$generalSettings     = $vipbXml.VI_Package_Builder_Settings.Library_General_Settings
$advancedSettings    = $vipbXml.VI_Package_Builder_Settings.Advanced_Settings
$descriptionSettings = $advancedSettings.Description

if (-not $generalSettings -or -not $descriptionSettings) {
    $errorObject = [PSCustomObject]@{
        error     = "VIPB file is missing expected sections (Library_General_Settings or Description)."
        vipb_path = $ResolvedVIPBPath
    }
    $errorObject | ConvertTo-Json -Depth 10
    exit 1
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
    $errorObject = [PSCustomObject]@{
        error      = "Failed to read release notes file."
        path       = $ResolvedReleaseNotesFile
        exception  = $_.Exception.Message
    }
    $errorObject | ConvertTo-Json -Depth 10
    exit 1
}

if ([string]::IsNullOrWhiteSpace($releaseNotesFromFile)) {
    $errorObject = [PSCustomObject]@{
        error = "Release notes file is empty. Populate it or provide valid content before running this action."
        path  = $ResolvedReleaseNotesFile
    }
    $errorObject | ConvertTo-Json -Depth 10
    exit 1
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
    $resolvedLicensePath = $null

    if (-not [System.IO.Path]::IsPathRooted($candidatePath)) {
        $candidatePath = Join-Path -Path $ResolvedRepoRoot -ChildPath $licenseAgreementInput
    }

    if (Test-Path $candidatePath) {
        try {
            $resolvedLicensePath = (Resolve-Path -Path $candidatePath -ErrorAction Stop).Path
        }
        catch {
            Write-Warning "Unable to resolve license file path '$candidatePath'. Using literal value instead."
        }
    }
    else {
        Write-Warning "License agreement path '$licenseAgreementInput' does not exist relative to the repository. Skipping license assignment."
    }

    if ($resolvedLicensePath) {
        try {
            $vipbDirectory = Split-Path -Parent $ResolvedVIPBPath
            $relativePath = [System.IO.Path]::GetRelativePath($vipbDirectory, $resolvedLicensePath)
        }
        catch {
            Write-Warning "Unable to compute a relative license path from '$ResolvedVIPBPath'. Using absolute path instead."
            $relativePath = $resolvedLicensePath
        }
        Set-VipbElementValue -ParentNode $advancedSettings -ElementName "License_Agreement_Filepath" -Value $relativePath
    }
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

$unhandledKeys = $jsonObj.PSObject.Properties | Where-Object { $_.Name -notin $recognizedKeys }
if ($unhandledKeys.Count -gt 0) {
    $details = $unhandledKeys | ForEach-Object {
        [PSCustomObject]@{
            key   = $_.Name
            value = $_.Value
        }
    }

    $errorObject = [PSCustomObject]@{
        error              = "DisplayInformationJSON contains unhandled field(s). Update the mapping to keep metadata in sync."
        unhandled_fields   = $details
        recognized_fields  = $recognizedKeys
    }
    $errorObject | ConvertTo-Json -Depth 10
    exit 1
}

try {
    $writerSettings = New-Object System.Xml.XmlWriterSettings
    $writerSettings.Indent = $true
    $writerSettings.IndentChars = "  "
    $writerSettings.NewLineHandling = [System.Xml.NewLineHandling]::Replace
    $writerSettings.NewLineChars = "`n"

    $xmlWriter = [System.Xml.XmlWriter]::Create($ResolvedVIPBPath, $writerSettings)
    $vipbXml.Save($xmlWriter)
    $xmlWriter.Close()

    Write-Host "Successfully updated VIPB metadata: $ResolvedVIPBPath"
}
catch {
    $errorObject = [PSCustomObject]@{
        error      = "Failed to save updated VIPB metadata."
        exception  = $_.Exception.Message
        stackTrace = $_.Exception.StackTrace
    }
    $errorObject | ConvertTo-Json -Depth 10
    exit 1
}
