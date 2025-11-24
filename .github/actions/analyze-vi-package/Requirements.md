
# Policy Requirements for LabVIEW VI Packages (VIP)
*Aligned with ISO/IEC/IEEE 29148 guidance for well-formed, verifiable requirements.*

Each requirement below is **singular**, **unambiguous**, **verifiable**, and **consistent** with the Pester policy suite. IDs are stable across package versions.

## Package metadata
- **VIP-PKG-001** — *Name format*: The package **Name** SHALL be non-empty and use only lowercase letters, digits, and underscores (`^[a-z0-9_]+$`).  
  **Verification**: Regex match on `[Package] Name` in the VIP `spec`.
- **VIP-PKG-002** — *Version format*: The package **Version** SHALL consist of four dot-separated integers (`major.minor.patch.build`).  
  **Verification**: Regex match on `[Package] Version`.
- **VIP-PKG-003** — *Identifier format*: The package **ID** SHALL be a 32-character hexadecimal string.  
  **Verification**: Regex match on `[Package] ID`.
- **VIP-PKG-004** — *File format constant*: **File Format** SHALL equal `vip`.  
  **Verification**: Exact match on `[Package] File Format`.
- **VIP-PKG-005** — *Minimum format version*: **Format Version** SHALL be a four-digit number not earlier than `2017`.  
  **Verification**: Numeric compare on `[Package] Format Version`.
- **VIP-PKG-006** — *Display name present*: **Display Name** SHALL be present and non-empty.  
  **Verification**: Non-empty check on `[Package] Display Name`.

## Descriptive metadata
- **VIP-DESC-001** — *Approved license*: **License** SHALL be one of the approved identifiers: {MIT, BSD-3, Apache-2.0, GPL-3.0-only, Proprietary}.  
  **Verification**: Membership check on `[Description] License`.
- **VIP-DESC-002** — *Copyright*: **Copyright** SHALL be present.  
  **Verification**: Non-empty check on `[Description] Copyright`.
- **VIP-DESC-003** — *Vendor*: **Vendor** SHALL be present.  
  **Verification**: Non-empty check on `[Description] Vendor`.
- **VIP-DESC-004** — *Packager*: **Packager** SHALL be present.  
  **Verification**: Non-empty check on `[Description] Packager`.
- **VIP-DESC-005** — *Project URL*: If **URL** is provided, it SHALL be a valid HTTP(S) URL.  
  **Verification**: Conditional regex match on `[Description] URL`.

## LabVIEW installation behavior
- **VIP-LV-001** — *Close LabVIEW*: **close labview before install** SHALL be `TRUE`.  
  **Verification**: Exact match in `[LabVIEW]`.
- **VIP-LV-002** — *Restart after install*: **restart labview after install** SHALL be `TRUE`.  
  **Verification**: Exact match in `[LabVIEW]`.
- **VIP-LV-003** — *Skip mass compile*: **skip mass compile after install** SHALL be `TRUE`.  
  **Verification**: Exact match in `[LabVIEW]`.
- **VIP-LV-004** — *Global environment*: **install into global environment** SHALL be `FALSE`.  
  **Verification**: Exact match in `[LabVIEW]`.

## Platform constraints
- **VIP-PLAT-001** — *Minimum LabVIEW version*: **Exclusive_LabVIEW_Version** SHALL be expressed as `LabVIEW>=X.Y` and SHALL be **≥** a policy-defined minimum (default `21.0`).  
  **Verification**: Regex extract then numeric compare of major.minor.
- **VIP-PLAT-002** — *LabVIEW system scope*: **Exclusive_LabVIEW_System** SHALL be `ALL`, unless a variance is approved.  
  **Verification**: Exact match on `[Platform] Exclusive_LabVIEW_System`.
- **VIP-PLAT-003** — *Operating system*: **Exclusive_OS** SHALL be `Windows NT`.  
  **Verification**: Exact match on `[Platform] Exclusive_OS`.

## Scripted actions
- **VIP-SCRIPT-001** — *Pre-install script presence*: If **PreInstall** is specified, it SHALL reference a file included in the VIP.  
  **Verification**: File name exists among ZIP entries.
- **VIP-SCRIPT-002** — *Post-install script presence*: If **PostInstall** is specified, it SHALL reference a file included in the VIP.  
  **Verification**: File name exists among ZIP entries.
- **VIP-SCRIPT-003** — *Pre-uninstall script presence*: If **PreUninstall** is specified, it SHALL reference a file included in the VIP.  
  **Verification**: File name exists among ZIP entries.
- **VIP-SCRIPT-004** — *Post-uninstall script presence*: If **PostUninstall** is specified, it SHALL reference a file included in the VIP.  
  **Verification**: File name exists among ZIP entries.

## Dependencies and activation
- **VIP-DEPS-001** — *No automatic dependency provisioning*: **AutoReqProv** SHALL be `FALSE`.  
  **Verification**: Exact match on `[Dependencies] AutoReqProv`.
- **VIP-DEPS-002** — *System sub-package pin*: **Requires** SHALL include an exact version pin for the `<Name>_system=<Version>` that matches the parent package.  
  **Verification**: String match against `[Dependencies] Requires` after whitespace removal.
- **VIP-DEPS-003** — *No activation file*: **License File** SHALL be empty for open-source packages.  
  **Verification**: Empty check on `[Activation] License File`.
- **VIP-DEPS-004** — *No licensed library*: **Licensed Library** SHALL be empty for open-source packages.  
  **Verification**: Empty check on `[Activation] Licensed Library`.

## File layout
- **VIP-FILE-001** — *Single file group*: **Num File Groups** SHALL equal `1`.  
  **Verification**: Exact match on `[Files]` field.
- **VIP-FILE-002** — *Sub-package naming*: **Sub-Packages** SHALL include `<Name>_system-<Version>`.  
  **Verification**: String match against `[Files] Sub-Packages` after whitespace removal.
- **VIP-FILE-003** — *Target directory*: **File Group 0.Target Dir** SHALL be `<application>`.  
  **Verification**: Exact match.
- **VIP-FILE-004** — *Replace mode*: **File Group 0.Replace Mode** SHALL be `Always`.  
  **Verification**: Exact match.

---

## Notes on requirement quality (ISO/IEC/IEEE 29148)
- Each statement above is **necessary, verifiable, and achievable**; word choices like “SHALL” indicate binding requirements. 
- Each is **singular** (one subject, one predicate), **unambiguous** (objective predicates like regex matches), and **bounded** (explicit thresholds or enumerations). 
- Traceability is provided via stable IDs (e.g., `VIP-PKG-002`) mapped one-to-one with Pester tests of the same name.
