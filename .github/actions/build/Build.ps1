<#
.SYNOPSIS
  This script automates the build process for the LabVIEW Icon Editor project.
  It performs the following tasks:
    1. Cleans up old .lvlibp files in the plugins folder.
    2. Applies VIPC (32-bit and 64-bit).
    3. Builds the LabVIEW library (32-bit and 64-bit).
    4. Closes LabVIEW (32-bit and 64-bit).
    5. Renames the built files.
    6. Builds the VI package (64-bit) with DisplayInformationJSON fields.
    7. Closes LabVIEW (64-bit).

  Example usage:
    .\Build.ps1 `
      -RepositoryPath "C:\release\labview-icon-editor-fork" `
      -Major 1 -Minor 0 -Patch 0 -Build 3 -Commit "Placeholder" `
      -CompanyName "Acme Corporation" `
      -AuthorName "John Doe (Acme Corp)" `
      -Verbose
#>

[CmdletBinding()]  # Enables -Verbose, -Debug, etc.
param(
    [Parameter(Mandatory = $true)]
    [string]$RepositoryPath,

    [int]$Major = 1,
    [int]$Minor = 0,
    [int]$Patch = 0,
    [int]$Build = 1,
    [string]$Commit,
    # LabVIEW "minor" revision (0 or 3)
    [Parameter(Mandatory = $false)]
    [int]$LabVIEWMinorRevision = 3,

    [ValidateSet('both','64')]
    [string]$LvlibpBitness = 'both',

    [string]$VIPBPath = 'Tooling\deployment\NI Icon editor.vipb',

    # New parameters that will populate the JSON fields
    [Parameter(Mandatory = $true)]
    [string]$CompanyName,

    [Parameter(Mandatory = $true)]
    [string]$AuthorName
)

$ReleaseNotesFile = Join-Path $RepositoryPath 'Tooling\deployment\release_notes.md'

# Helper function to verify a file/folder path exists
function Test-PathExistence {
    param(
        [string]$Path,
        [string]$Description
    )
    Write-Verbose "Checking if '$Description' exists at path: $Path"
    if (-not (Test-Path -Path $Path)) {
        Write-Error "The '$Description' does not exist: $Path"
        exit 1
    }
    Write-Verbose "Confirmed '$Description' exists at path: $Path"
}

# Helper function to run another script with arguments safely
function Invoke-ScriptSafe {
    param(
        [string]$ScriptPath,
        [hashtable]$ArgumentMap,
        [string[]]$ArgumentList
    )
    if (-not $ScriptPath) { throw "ScriptPath is required" }
    if (-not (Test-Path -LiteralPath $ScriptPath)) { throw "ScriptPath '$ScriptPath' not found" }

    $render = if ($ArgumentMap) {
        ($ArgumentMap.GetEnumerator() | ForEach-Object { "-$($_.Key) $($_.Value)" }) -join ' '
    } else {
        ($ArgumentList -join ' ')
    }
    Write-Information ("Executing: {0} {1}" -f $ScriptPath, $render) -InformationAction Continue
    try {
        if ($ArgumentMap) {
            & $ScriptPath @ArgumentMap
        } elseif ($ArgumentList) {
            & $ScriptPath @ArgumentList
        } else {
            & $ScriptPath
        }
        Write-Verbose "Command completed. Checking exit code..."
        if ($LASTEXITCODE -ne 0) {
            Write-Error "Error occurred while executing `"$ScriptPath`" with arguments: $render. Exit code: $LASTEXITCODE"
            exit $LASTEXITCODE
        }
    }
    catch {
        Write-Error "Error occurred while executing `"$ScriptPath`" with arguments: $render. Exiting. Details: $($_.Exception.Message)"
        exit 1
    }
}

function Write-ReleaseNotesFromGit {
    param(
        [string]$RepoPath,
        [string]$DestinationPath
    )

    if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
        Write-Verbose "git not found; skipping release notes generation from git."
        return
    }

    try {
        $lastTag = git -C $RepoPath describe --tags --abbrev=0 2>$null
    }
    catch {
        $lastTag = $null
    }

    if (-not $lastTag) {
        Write-Verbose "No tags found; using HEAD for release notes."
        $range  = 'HEAD'
        $header = 'Release Notes'
    }
    else {
        Write-Verbose ("Last tag detected: {0}" -f $lastTag)
        $range  = "$lastTag..HEAD"
        $header = "Release Notes (since $lastTag)"
    }

    $log = git -C $RepoPath log $range --pretty='- %h %s' --no-merges
    if (-not $log) {
        $log = if ($lastTag) { 'No commits since last tag.' } else { 'No commits found.' }
    }

    $body = "$header`n`n$log`n"
    $destDir = Split-Path -Path $DestinationPath -Parent
    if ($destDir -and -not (Test-Path -LiteralPath $destDir)) {
        New-Item -ItemType Directory -Path $destDir -Force | Out-Null
    }
    Set-Content -Path $DestinationPath -Value $body -Encoding utf8
    Write-Information "Generated release notes from git into $DestinationPath" -InformationAction Continue
}

function Get-LabVIEWVersionFromVipb {
    param([Parameter(Mandatory)][string]$RootPath)
    $vipb = Get-ChildItem -Path $RootPath -Filter *.vipb -File -Recurse | Select-Object -First 1
    if (-not $vipb) { throw "No .vipb file found under $RootPath" }
    $text = Get-Content -LiteralPath $vipb.FullName -Raw
    $match = [regex]::Match($text, '<Package_LabVIEW_Version>(?<ver>[^<]+)</Package_LabVIEW_Version>', 'IgnoreCase')
    if (-not $match.Success) { throw "Unable to locate Package_LabVIEW_Version in $($vipb.FullName)" }
    $raw = $match.Groups['ver'].Value
    $verMatch = [regex]::Match($raw, '^(?<majmin>\d{2}\.\d)')
    if (-not $verMatch.Success) { throw "Unable to parse LabVIEW version from '$raw' in $($vipb.FullName)" }
    $maj = [int]($verMatch.Groups['majmin'].Value.Split('.')[0])
    $computed = if ($maj -ge 20) { "20$maj" } else { $maj.ToString() }
    return $computed
}

try {
    Write-Verbose "Script: Build.ps1 starting."
    Write-Verbose "Parameters received:"
    Write-Verbose " - RepositoryPath: $RepositoryPath"
    Write-Verbose " - Major: $Major"
    Write-Verbose " - Minor: $Minor"
    Write-Verbose " - Patch: $Patch"
    Write-Verbose " - Build: $Build"
    Write-Verbose " - Commit: $Commit"
    Write-Verbose " - LabVIEWMinorRevision: $LabVIEWMinorRevision"
    Write-Verbose " - LvlibpBitness: $LvlibpBitness"
    Write-Verbose " - CompanyName: $CompanyName"
    Write-Verbose " - AuthorName: $AuthorName"

    # Ensure the repo root exists before reading the VIPB version
    if (-not (Test-Path -LiteralPath $RepositoryPath)) {
        Write-Error "RepositoryPath does not exist: $RepositoryPath"
        exit 1
    }

    # Derive build number from total commits when available
    try {
        git -C $RepositoryPath fetch --unshallow 2>$null | Out-Null
    }
    catch {
        $global:LASTEXITCODE = 0
    }
    try {
        $commitCount = git -C $RepositoryPath rev-list --count HEAD 2>$null
        if ($LASTEXITCODE -eq 0 -and $commitCount) {
            $Build = [int]$commitCount
            Write-Information ("Using commit count for build number: {0}" -f $Build) -InformationAction Continue
        }
    }
    catch {
        Write-Verbose "Commit count unavailable; using provided build number." -Verbose
        $global:LASTEXITCODE = 0
    }

    # Derive LabVIEW version from VIPB as the first consumer step
    $lvVersion = Get-LabVIEWVersionFromVipb -RootPath $RepositoryPath
    Write-Information ("Using LabVIEW version from VIPB: {0}" -f $lvVersion) -InformationAction Continue

    # Validate needed folders after version is known
    Test-PathExistence $RepositoryPath "RepositoryPath"
    Test-PathExistence "$RepositoryPath\resource\plugins" "Plugins folder"
    Test-PathExistence "$RepositoryPath\lv_icon_editor.lvproj" "LabVIEW project"

    $ActionsPath = Split-Path -Parent $PSScriptRoot
    Test-PathExistence $ActionsPath "Actions folder"

    # Ensure VIPC dependencies exist (mirrors CI prep)
    $vipcPath = Join-Path $RepositoryPath "Tooling\deployment\runner_dependencies.vipc"
    if (-not (Test-Path -LiteralPath $vipcPath)) {
        Write-Error "Missing runner_dependencies.vipc at $vipcPath. Cannot apply dependencies; run packaging prep or fetch the VIPC."
        exit 1
    }

    # 1) Clean up old .lvlibp in the plugins folder
    Write-Information "Cleaning up old .lvlibp files in plugins folder..." -InformationAction Continue
    Write-Verbose "Looking for .lvlibp files in $($RepositoryPath)\resource\plugins..."
    try {
        $PluginFiles = @(Get-ChildItem -Path "$RepositoryPath\resource\plugins" -Filter '*.lvlibp' -ErrorAction Stop)
        if ($PluginFiles) {
            $pluginNames = $PluginFiles | ForEach-Object { $_.Name }
            Write-Verbose "Found $($PluginFiles.Count) file(s): $($pluginNames -join ', ')"
            $PluginFiles | Remove-Item -Force -Recurse -Confirm:$false
            Write-Information "Deleted .lvlibp files from plugins folder." -InformationAction Continue
        }
        else {
            Write-Information "No .lvlibp files found to delete." -InformationAction Continue
        }
    }
    catch {
        Write-Error "Error occurred while retrieving .lvlibp files: $($_.Exception.Message)"
        Write-Verbose "Stack Trace: $($_.Exception.StackTrace)"
    }

    $ApplyVIPC = Join-Path $ActionsPath "apply-vipc/ApplyVIPC.ps1"
    $MissingHelper = Join-Path $ActionsPath "missing-in-project/Invoke-MissingInProjectCLI.ps1"
    $BuildLvlibp = Join-Path $ActionsPath "build-lvlibp/Build_lvlibp.ps1"
    $CloseLabVIEW = Join-Path $ActionsPath "close-labview/Close_LabVIEW.ps1"
    $RenameFile = Join-Path $ActionsPath "rename-file/Rename-file.ps1"

    if ($LvlibpBitness -eq 'both') {
        # 2) Apply VIPC (32-bit)
        Write-Information "Applying VIPC (dependencies) for 32-bit..." -InformationAction Continue
        Invoke-ScriptSafe -ScriptPath $ApplyVIPC -ArgumentMap @{
            Package_LabVIEW_Version   = $lvVersion
            SupportedBitness          = '32'
            RepositoryPath            = $RepositoryPath
            VIPCPath                  = 'Tooling\deployment\runner_dependencies.vipc'
        }

        # 2.1) Preflight missing items using existing missing-in-project helper (32-bit)
        Write-Information "Preflight: checking for missing project items via missing-in-project..." -InformationAction Continue
        Invoke-ScriptSafe -ScriptPath $MissingHelper -ArgumentMap @{
            LVVersion   = $lvVersion
            Arch        = '32'
            ProjectFile = (Join-Path $RepositoryPath 'lv_icon_editor.lvproj')
        }

        # 3) Build LV Library (32-bit)
        Write-Verbose "Building LV library (32-bit)..."
        $argsLvlibp32 = @{
            Package_LabVIEW_Version   = $lvVersion
            SupportedBitness          = '32'
            RepositoryPath            = $RepositoryPath
            Major                     = $Major
            Minor                     = $Minor
            Patch                     = $Patch
            Build                     = $Build
            Commit                    = $Commit
        }
        & $BuildLvlibp @argsLvlibp32

        # 4) Close LabVIEW (32-bit)
        Write-Verbose "Closing LabVIEW (32-bit)..."
        Invoke-ScriptSafe -ScriptPath $CloseLabVIEW -ArgumentMap @{
            Package_LabVIEW_Version = $lvVersion
            SupportedBitness        = '32'
        }

        # 5) Rename .lvlibp -> lv_icon_x86.lvlibp
        Write-Verbose "Renaming .lvlibp file to lv_icon_x86.lvlibp..."
        Invoke-ScriptSafe -ScriptPath $RenameFile -ArgumentMap @{
            CurrentFilename = "$RepositoryPath\resource\plugins\lv_icon.lvlibp"
            NewFilename     = 'lv_icon_x86.lvlibp'
        }

        # 5.1) Restore project to avoid cross-bitness saves before 64-bit build
        if (Get-Command git -ErrorAction SilentlyContinue) {
            Write-Verbose "Restoring lv_icon_editor.lvproj from source control before 64-bit build..."
            $restore = & git -C $RepositoryPath checkout -- "lv_icon_editor.lvproj" 2>&1
            if ($LASTEXITCODE -ne 0) {
                Write-Warning "Failed to restore lv_icon_editor.lvproj: $($restore -join '; ')"
            }
        } else {
            Write-Warning "git not found; skipping lvproj restore before 64-bit build."
        }
    }
    else {
        Write-Information "Skipping 32-bit dependency/apply/build steps (LvlibpBitness=$LvlibpBitness)." -InformationAction Continue
    }

    # 6) Apply VIPC (64-bit)
    Write-Information "Applying VIPC (dependencies) for 64-bit..." -InformationAction Continue
    Invoke-ScriptSafe -ScriptPath $ApplyVIPC -ArgumentMap @{
        Package_LabVIEW_Version   = $lvVersion
        SupportedBitness          = '64'
        RepositoryPath            = $RepositoryPath
        VIPCPath                  = 'Tooling\deployment\runner_dependencies.vipc'
    }

    # 6.1) Ensure LabVIEW 64-bit is closed before building to avoid loaded NIIconEditor collisions
    Write-Verbose "Pre-build: closing LabVIEW (64-bit) to ensure a clean session..."
    Invoke-ScriptSafe -ScriptPath $CloseLabVIEW -ArgumentMap @{
        Package_LabVIEW_Version = $lvVersion
        SupportedBitness        = '64'
    }

    # 7) Build LV Library (64-bit)
    Write-Verbose "Building LV library (64-bit)..."
    $argsLvlibp64 = @{
        Package_LabVIEW_Version   = $lvVersion
        SupportedBitness          = '64'
        RepositoryPath            = $RepositoryPath
        Major                     = $Major
        Minor                     = $Minor
        Patch                     = $Patch
        Build                     = $Build
        Commit                    = $Commit
    }
    & $BuildLvlibp @argsLvlibp64

    # 7.1) Close LabVIEW (64-bit)
    Write-Verbose "Closing LabVIEW (64-bit)..."
    Invoke-ScriptSafe -ScriptPath $CloseLabVIEW -ArgumentMap @{
        Package_LabVIEW_Version = $lvVersion
        SupportedBitness        = '64'
    }

    # Rename .lvlibp -> lv_icon_x64.lvlibp
    Write-Verbose "Renaming .lvlibp file to lv_icon_x64.lvlibp..."
    Invoke-ScriptSafe -ScriptPath $RenameFile -ArgumentMap @{
        CurrentFilename = "$RepositoryPath\resource\plugins\lv_icon.lvlibp"
        NewFilename     = 'lv_icon_x64.lvlibp'
    }

    # -------------------------------------------------------------------------
    # 8) Construct the JSON for "Company Name" & "Author Name", plus version
    # -------------------------------------------------------------------------
    # We include "Package Version" with your script parameters.
    # The rest of the fields remain empty or default as needed.
    Write-Verbose "Generating release notes from git..."
    Write-ReleaseNotesFromGit -RepoPath $RepositoryPath -DestinationPath $ReleaseNotesFile

    $jsonObject = @{
        "Package Version" = @{
            "major" = $Major
            "minor" = $Minor
            "patch" = $Patch
            "build" = $Build
        }
        "Product Name"                    = "LabVIEW Icon Editor"
        "Company Name"                    = $CompanyName
        "Author Name (Person or Company)" = $AuthorName
        "Product Homepage (URL)"          = "https://github.com/LabVIEW-Community-CI-CD/labview-icon-editor"
        "Legal Copyright"                 = "LabVIEW-Community-CI-CD"
        "License Agreement Name"          = ""
        "Product Description Summary"     = "Community icon editor for LabVIEW"
        "Product Description"             = "Community-driven icon editor for LabVIEW including custom icon APIs."
        "Release Notes - Change Log"      = ""
    }

    $DisplayInformationJSON = $jsonObject | ConvertTo-Json -Depth 3

    # 9) Modify VIPB Display Information
    Write-Verbose "Modify VIPB Display Information (64-bit)..."
    $ModifyVIPB = Join-Path $ActionsPath "modify-vipb-display-info/ModifyVIPBDisplayInfo.ps1"
    Invoke-ScriptSafe -ScriptPath $ModifyVIPB -ArgumentMap @{
        SupportedBitness         = '64'
        RepositoryPath           = $RepositoryPath
        VIPBPath                 = 'Tooling\deployment\NI Icon editor.vipb'
        Package_LabVIEW_Version  = $lvVersion
        LabVIEWMinorRevision     = $LabVIEWMinorRevision
        Major                    = $Major
        Minor                    = $Minor
        Patch                    = $Patch
        Build                    = $Build
        Commit                   = $Commit
        ReleaseNotesFile         = $ReleaseNotesFile
        DisplayInformationJSON   = $DisplayInformationJSON
        Verbose                  = $true
    }

    # 11) Build VI Package (64-bit) 2023
    Write-Verbose "Building VI Package (64-bit)..."
    $BuildVip = Join-Path $ActionsPath "build-vip/build_vip.ps1"
    Invoke-ScriptSafe -ScriptPath $BuildVip -ArgumentMap @{
        SupportedBitness         = '64'
        RepositoryPath           = $RepositoryPath
        VIPBPath                 = 'Tooling\deployment\NI Icon editor.vipb'
        Package_LabVIEW_Version  = $lvVersion
        LabVIEWMinorRevision     = $LabVIEWMinorRevision
        Major                    = $Major
        Minor                    = $Minor
        Patch                    = $Patch
        Build                    = $Build
        Commit                   = $Commit
        ReleaseNotesFile         = $ReleaseNotesFile
        DisplayInformationJSON   = $DisplayInformationJSON
        Verbose                  = $true
    }

    # 12) Close LabVIEW (64-bit)
    Write-Verbose "Closing LabVIEW (64-bit)..."
    Invoke-ScriptSafe -ScriptPath $CloseLabVIEW -ArgumentMap @{
        Package_LabVIEW_Version = $lvVersion
        SupportedBitness        = '64'
    }

    Write-Information "All scripts executed successfully!" -InformationAction Continue
    Write-Verbose "Script: Build.ps1 completed without errors."
}
catch {
    Write-Error "An unexpected error occurred during script execution: $($_.Exception.Message)"
    Write-Verbose "Stack Trace: $($_.Exception.StackTrace)"
    exit 1
}
