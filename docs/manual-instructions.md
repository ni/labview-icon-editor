# Manual Setup & Editing Instructions

This document provides **manual** steps to configure, edit, and distribute the LabVIEW Icon Editor source code, including local container parity prerequisites.

---

## Table of Contents

1. [Version Contracts (`.lvversion` and `.lvcontainer`)](#version-contracts-lvversion-and-lvcontainer)
2. [Compatible LabVIEW Installs](#compatible-labview-installs)
3. [Docker Desktop (Container Parity)](#docker-desktop-container-parity)
4. [Editing Guide (Manual)](#editing-guide-manual)
5. [Distribution Guide (Manual)](#distribution-guide-manual)

---

<a name="version-contracts-lvversion-and-lvcontainer"></a>
## 1. Version Contracts (`.lvversion` and `.lvcontainer`)

- `.lvversion` is the canonical **source/runtime version contract**.
  - Local and CI version gates validate inputs against this file.
  - Current value in this repository: `20.0` (LabVIEW 2020).
- `.lvcontainer` is the canonical **container parity contract**.
  - Container parity (including merged Linux VI Analyzer responsibilities) resolves image metadata from this tag.
  - Current value in this repository: `2026q1-linux`.
- Relationship between the two contracts:
  - They are related but intentionally not identical.
  - `.lvversion` controls source compatibility.
  - `.lvcontainer` controls containerized parity runtime selection.
  - A newer container release can be used to validate an older source baseline.

When changing these files:
- Change `.lvversion` when the source baseline changes.
- Change `.lvcontainer` when container parity baseline changes.
- Validate changes with local parity and CI parity workflows.

---

<a name="compatible-labview-installs"></a>
## 2. Compatible LabVIEW Installs

- Source is saved in LabVIEW 2020 (`20.0`) format.
- CI/build baseline is resolved from `.lvversion`.
- For full parity/build/distribution work, keep both 32-bit and 64-bit installs for the `.lvversion` target.
- For edit-only workflows, one install may be enough, but CI parity still validates both lanes.

---

<a name="docker-desktop-container-parity"></a>
## 3. Docker Desktop (Container Parity)

Use Docker Desktop when you want local parity behavior aligned with container lanes.

1. Install Docker Desktop on Windows and enable WSL 2 integration.
2. Confirm Docker is available:

   ```powershell
   docker --version
   docker info --format "{{.OSType}}/{{.Architecture}}"
   ```

3. Resolve the repository container tags:

   ```powershell
   $linuxTag = (Get-Content .\.lvcontainer -Raw).Trim()
   $windowsTag = if ($linuxTag -match '-linux$') { $linuxTag -replace '-linux$', '-windows' } else { $linuxTag }
   $linuxTag
   $windowsTag
   ```

4. Pull images you plan to use:

   ```powershell
   docker pull "nationalinstruments/labview:$linuxTag"
   docker pull "nationalinstruments/labview:$windowsTag"
   ```

5. Keep Docker in the correct mode for the lane:
   - Linux parity lanes require Linux containers.
   - Windows parity lanes require Windows containers.

Recommended local preflight (Linux parity with merged VI Analyzer responsibilities):

```powershell
pwsh -NoProfile -File .\Tooling\Invoke-LinuxContainerPreflight.ps1 -RepoRoot .
```

For detailed parity behavior, see `docs/labview-container-parity.md`.

---

<a name="editing-guide-manual"></a>
## 4. Editing Guide (Manual)

1. **Clone** this repository to a development location, for example:

   ```
   C:\labview-icon-editor
   ```

2. **Open** the project file:

   ```
   lv_icon_editor.lvproj
   ```

3. **Locate** the top-level VI inside the project:

   ```
   My Computer » resource/plugins » lv_icon.lvlib » lv_icon.vi
   ```

   You can now edit and develop the Icon Editor as needed.

---

<a name="distribution-guide-manual"></a>
## 5. Distribution Guide (Manual)

To **manually distribute** your custom Icon Editor:

1. **Build** the Packed Project Library (or .lvlibp):
   - In LabVIEW, compile your top-level `lv_icon.lvlib` into a `.lvlibp` for deployment.

2. **On the target machine**:
   - Rename the default:

     ```
     <LabVIEW>\resource\plugins\lv_icon.lvlibp
     ```
     to:
     ```
     lv_icon.lvlibp.ship
     ```
   - Similarly archive or rename:
     ```
     <LabVIEW>\vi.lib\LabVIEW Icon API
     ```
   - **Copy** your newly built `lv_icon.lvlibp` and `vi.lib\LabVIEW Icon API\*` into the corresponding LabVIEW folders on the target machine.
