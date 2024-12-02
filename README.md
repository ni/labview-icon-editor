# Icon Editor for LabVIEW
This repo contains the source files and build tools for the LabVIEW icon editor.
You can use this code as a starting point for creating a custom icon editor. Refer to the [CONTRIBUTING](CONTRIBUTING.md) document for information about submitting changes for inclusion with future versions of LabVIEW.

## Minimum Compatible LabVIEW Version
LabVIEW source is saved in 21.0 (__LabVIEW 2021__) format.

The packed project library has to be built on __LabVIEW 2021__, the VI Package can be be built for any version using the packed project library built on __LabVIEW 2021__

## Editing Guide ##
Because the icon editor is part of the LabVIEW development environment, you need to make changes to installed files before editing this project.

Complete the following steps to edit this project:
1. Clone this repo into a development location (e.g., C:\dev).
2. Run __Tooling\Prepare LV to Use Icon Editor Source.vi__.
This will perform the following steps, which you can alternatively perform manually:
   * Delete \<LabVIEW\>\\resource\\plugins\\lv_icon.lvlipb
   * Delete \<LabVIEW\>\\vi.lib\\LabVIEW Icon API
   * Set LocalHost.LibraryPaths in your labview.ini file to the location of this project. For example:
      * LocalHost.LibraryPaths="C:\\dev\\labview-icon-editor"
3. Open lv_icon_editor.lvproj in LabVIEW.
4. The top-level VI is in the Project Explorer at __My Computer &#x00BB; resource/plugins &#x00BB; lv_icon.lvlib &#x00BB; lv_icon.vi__.

Complete the following steps to automate __step 2__ from above:
1. Open powershell in *Admin* mode and navigate to pipeline\scripts from your github repo
2. Modify the following command to point to your github repo .\DevelopmentMode.ps1 -RelativePath "C:\labview-icon-editor" and run it.



## Distribution Guide ##
Complete the following steps to distribute your custom icon editor to another machine.

First, build the __Editor Packed Library__ build specification in the project to create __lv_icon.lvlibp__.

Then, on the machine where you want to install your custom icon editor:
1. Rename __\<LabVIEW\>\\resource\\plugins\\lv_icon.lvlibp__, the shipping icon editor, to __lv_icon.lvlibp.ship__ to "hide" it.
2. Archive __\<LabVIEW\>\\vi.lib\\LabVIEW Icon API__ to preserve the shipping copy.  Use your archive program of choice (e.g. 7-Zip).
3. Copy the packed library and support files that you developed with this project into the \<LabVIEW\> directory:  
   - \<LabVIEW\>\\resource\\plugins\\lv_icon.lvlibp 
   - \<LabVIEW\>\\vi.lib\\LabVIEW Icon API\\*
  
## Build automation ##

# Release Notes: Icon Editor Build Tools for LabVIEW

This release introduces tools for building and deploying custom LabVIEW Icon Editors, enabling streamlined distribution through automated pipelines. These tools provide support for both 32-bit and 64-bit environments, packaged into a VI package for easy restoration and deployment.

## Key Features

### Restore Point Functionality
- The VI package serves as a restore point for the LabVIEW Icon Editor. Installing or uninstalling the package reverts the editor to its original state.

### Automation Options
- Three automation tools are available:
  - Azure DevOps pipeline
  - GitHub Action
  - PowerShell script

### Flexible Deployment
- **For LabVIEW 2021 and 2022**: Replaces `lv_icon.lvlibp` in the `resource/plugins` folder.
- **For LabVIEW 2023 and later**: Installs the library to `C:\Program Files\NI\LVAddons\niiconeditor(bitness)`.

## Prerequisites
- LabVIEW 2021 (32-bit and 64-bit)
- Latest VIPM version
- Dependencies located in `Tooling\deployment\Dependencies.vipc` (to be applied manually for both 32-bit and 64-bit LabVIEW)

Before following this process, create a backup of the following files and folder:
   - \<LabVIEW\>\\resource\\plugins\\lv_icon.lvlibp 
   - \<LabVIEW\>\\vi.lib\\LabVIEW Icon API\\*

**Process (Powershell):**

Complete the following steps to build a VI package

1. Open powershell in *Admin* mode and navigate to .pipeline\scripts from your github repo
2. Modify the following command to point to your github repo .\DevelopmentMode.ps1 -RelativePath "C:\labview-icon-editor" and run it.
3. A VI package named *ni_icon_editor-x.x.x.x* will be built on *builds\VI Package*.

Complete the following steps to build an NI package

Soon :)
