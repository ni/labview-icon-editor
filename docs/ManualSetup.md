# Manual Setup & Distribution

This document details how to manually configure LabVIEW for using and editing the Icon Editor source code, as well as how to distribute a customized editor.

## Table of Contents

1. Compatible LabVIEW Versions  
2. Editing Guide (Manual)  
3. Editing Guide (PowerShell)  
4. Distribution Guide (Manual)  
5. Distribution Guide (VI Package via PowerShell)

---

## 1. Compatible LabVIEW Versions

- Source is saved in **LabVIEW 2021 SP1** format.  
- You can develop in **LabVIEW 2021** or **LabVIEW 2024**, as long as you preserve the **2021** file format.

---

## 2. Editing Guide (Manual)

1. **Clone** this repository to a development location, for example:
   
       C:\dev\labview-icon-editor

2. **Run** the following VI to prepare your environment:
   
       Tooling\Prepare LV to Use Icon Editor Source.vi
   
   This script will:
   - Remove `<LabVIEW>\resource\plugins\lv_icon.lvlibp`
   - Remove `<LabVIEW>\vi.lib\LabVIEW Icon API`
   - Update `LocalHost.LibraryPaths` in your **labview.ini** with the base path where the custom VI is located

3. **Open** the project file:
   
       lv_icon_editor.lvproj

4. **Locate** the top-level VI inside the project:
   
       My Computer » resource/plugins » lv_icon.lvlib » lv_icon.vi

---

## 3. Editing Guide (PowerShell)

Use the provided scripts to **automate** the same setup steps across both 32-bit and 64-bit LabVIEW.

1. **Back Up** your LabVIEW files (just in case):
   
       <LabVIEW>\resource\plugins\lv_icon.lvlibp
       <LabVIEW>\vi.lib\LabVIEW Icon API

2. **Clone** this repo (example location):
   
       C:\labview-icon-editor

3. **Apply** the dependencies in:
   
       Tooling\deployment\Dependencies.vipc
   
   to both **LabVIEW 2021 (32-bit)** and **LabVIEW 2021 (64-bit)** installations.

4. **Open** the latest version of PowerShell (https://github.com/PowerShell/PowerShell/releases/latest) **as Administrator** and navigate to:
   
       pipeline\scripts

5. **Run** the development mode script:

        
       .\Set_Development_Mode.ps1 -RelativePath "C:\labview-icon-editor"
        
        
   This will:
   - Remove the default `lv_icon.lvlibp` and Icon API  
   - Update `labview.ini` to point to your local repo

6. **Open**:
   
       lv_icon_editor.lvproj
   
   to modify or extend the Icon Editor source code.

---

## 4. Distribution Guide (Manual)

Use this process to **manually distribute** the custom icon editor:

1. **Build** the Packed Project Library
   


2. **On the target machine**:
   - Rename the default:
     
         <LabVIEW>\resource\plugins\lv_icon.lvlibp
      
     to:
     
         lv_icon.lvlibp.ship

   - Archive:
     
         <LabVIEW>\vi.lib\LabVIEW Icon API

   - **Copy** your **custom** `lv_icon.lvlibp` and the new `vi.lib\LabVIEW Icon API\*` into the target machine

---

## 5. Distribution Guide (VI Package via PowerShell)

This process leverages the **VI Package Manager (VIPM)** to build and install a package for your icon editor.

1. **Apply Dependencies**  
   - In VIPM, set the active LabVIEW version to **2021 (32-bit)** and apply:
     
         \Tooling\deployment\Dependencies.vipc
     
     Repeat for **2021 (64-bit)**.

2. Disable LabVIEW security warnings: In LabVIEW **(32-bit & 64-bit)**, go to:
   
       Tools » Options » Security
   
   and enable **Run VI Without Warnings** to skip manual prompts. Not enabling it will make the CI tooling fail in random places.

3. **Open** the latest version of PowerShell (https://github.com/PowerShell/PowerShell/releases/latest) **as Administrator** and navigate to:
   
       pipeline\scripts

4. **Build** the VI Package:

        
       .\Build_all.ps1 -RelativePath "C:\labview-icon-editor" -AbsolutePathScripts "C:\labview-icon-editor\pipeline\scripts"
        
   
   After about **15 minutes**, a `.vip` file appears in:
   
       builds\VI Package

5. **Revert** the environment to default LabVIEW settings:

        
       .\RevertDevelopmentMode.ps1 -RelativePath "C:\labview-icon-editor"
        

   This removes custom paths from `labview.ini` and restores the shipping LabVIEW Icon API.


6. **Install** that `.vip` in VIPM (run VIPM **as Administrator**).

    - Test your change before distributing it.


