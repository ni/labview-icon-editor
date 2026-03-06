# Manual Setup & Editing Instructions

This document provides **manual** steps to configure, edit, and distribute the LabVIEW Icon Editor source code without using PowerShell automation.

---

## Table of Contents

1. [Compatible LabVIEW Versions](#compatible-labview-versions)
2. [Editing Guide (Manual)](#editing-guide-manual)
3. [Distribution Guide (Manual)](#distribution-guide-manual)

---

<a name="compatible-labview-versions"></a>
## 1. Compatible LabVIEW Versions

- Source is saved in **LabVIEW 2020 (20.0)** format.  
- Both **LabVIEW 2020 (20.0), 32-bit and 64-bit** are typically required if you plan to build or distribute for both architectures.
- Editing can be done on any LabVIEW version that can preserve the **2020** file format. It is recommended to use LabVIEW 2025 (25.0) or newer.

---

<a name="editing-guide-manual"></a>
## 2. Editing Guide (Manual)

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

<a name="Testing"></a>
## 3. Testing Guide

There are four ways to test the GUI.

1. Run the lv_icon.vi directly.
   - There will be no data in the icon, but you can still build up an icon using the full functionality.
2. Configure LabVIEW to use the source code for the Icon Editor
 
   **NOTE:** The API is not tested using this method. It is only for the editor GUI.
   - Run Tools\Set Run Icon Editor from Source.vi.  This VI will create a launcher VI that points to the lv_icon.vi in the project.
   - This allows testing using the launching paths from the LabVIEW IDE.
   - Run Tools\Unset Run Icon Editor from Source.vi to restore the default editor.
3. Build the PPL and install in the lvaddons directory.

   **NOTE:** This does require administrative rights
   **NOTE:** This is only valid for LabVIEW 2023 or newer
   - Run the Editor Packed Library build specification from the project. This will create a PPL for the editor.
   - Run Tools\Install to LVAddons.vi. This VI will copy the built lv_icon.lvlibp and all of the VIs in the vi.lib\LabVIEW Icon API folder to the proper locations in C:\Program Files\NI\LVAddons\labview-icon-editor as well as the infrastructure required for an LVAddon.
4. Manually copy the files into the <LabVIEW 20xx> installation folders.
   - See [Distribution Guide (Manual)](#distribution-guide-manual) for instructions on building and copying the files.

---

<a name="distribution-guide-manual"></a>
## 4. Distribution Guide (Manual)

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

   You now have a custom, manually distributed Icon Editor that can support any LabVIEW version available up until the creation of this document.
