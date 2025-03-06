# Icon Editor for LabVIEW #

This repo contains the source files and automated build tools for the LabVIEW icon editor.
You can use this code as a starting point for creating a custom icon editor. Refer to the [CONTRIBUTING](CONTRIBUTING.md) document for information about submitting changes for inclusion with future versions of LabVIEW.

## Compatible LabVIEW Versions

LabVIEW source is saved in (__LabVIEW 2021 SP1__) format. Either LabVIEW 2021 or LabVIEW 2024 can be used to do development work, as long as the source remains saved on LabVIEW 2021

## Editing Guide (Manual)

Because the icon editor is part of the LabVIEW development environment, you need to make changes to installed files before editing this project.

Complete the following steps to edit this project:
1. Clone this repo into a development location (e.g., C:\dev).
2. Run __Tooling\Prepare LV to Use Icon Editor Source.vi__.
This will perform the following steps, which you can alternatively perform manually:
   * Delete \<LabVIEW\>\\resource\\plugins\\lv_icon.lvlibp
   * Delete \<LabVIEW\>\\vi.lib\\LabVIEW Icon API
   * Set LocalHost.LibraryPaths in your labview.ini file to the location of this project. For example:*
       *   LocalHost.LibraryPaths="C:\\labview-icon-editor"
3. Open lv_icon_editor.lvproj in LabVIEW.
4. The top-level VI is in the Project Explorer at __My Computer &#x00BB; resource/plugins &#x00BB; lv_icon.lvlib &#x00BB; lv_icon.vi__.

## Editing Guide (Powershell)

This process accomplishes the same as the manual process, but it only uses a powershell command to set labview 32 and 64 bits into editing mode.

Before following this process, create a backup of the following files and folder:
   - \<LabVIEW\>\\resource\\plugins\\lv_icon.lvlibp 
   - \<LabVIEW\>\\vi.lib\\LabVIEW Icon API\\*

Clone the repo into C:\, and apply the dependencies located on *Tooling\deployment\Dependencies.vipc* to LabVIEW 2021 32 and 64 bits, follow this process to use the automation layer.

1. Open Powershell in *Admin* mode and navigate to *.pipeline\scripts* from your github repo.
2. Modify the following command to point to your github repo and run it: 

```bach
.\DevelopmentMode.ps1 -RelativePath "C:\labview-icon-editor"
```
   
3. Open lv_icon_editor.lvproj in LabVIEW.
4. The top-level VI is in the Project Explorer at __My Computer &#x00BB; resource/plugins &#x00BB; lv_icon.lvlib &#x00BB; lv_icon.vi__.

## Distribution Guide (Manual)

Complete the following steps to distribute your custom icon editor to another machine.

First, build the __Editor Packed Library__ build specification in the project to create __lv_icon.lvlibp__.

Then, on the machine where you want to install your custom icon editor:
1. Rename __\<LabVIEW\>\\resource\\plugins\\lv_icon.lvlibp__, the shipping icon editor, to __lv_icon.lvlibp.ship__ to "hide" it.
2. Archive __\<LabVIEW\>\\vi.lib\\LabVIEW Icon API__ to preserve the shipping copy.  Use your archive program of choice (e.g. 7-Zip).
3. Copy the packed library and support files that you developed with this project into the \<LabVIEW\> directory:  
   - \<LabVIEW\>\\resource\\plugins\\lv_icon.lvlibp 
   - \<LabVIEW\>\\vi.lib\\LabVIEW Icon API\\*
   
## Distribution Guide (VI Package using Powershell)

First step before modifying the icon editor source, is to ensure that your build tools work, since those same tools are the ones that will run on the build agent.



Follow these steps to ensure your system is ready to edit the source.


Step 1: Apply dependencies

- Open VIPM, switch to 2021 32-bit and apply \Tooling\deployment\dependencies.vipc
- Switch VIPM to LabVIEW 2021 64-bit and apply the VIPC again

Step 2: Disable security warnings for "Run When Opened" VIs

The alternative to this step is to wait for the popup to occurr, and acknowledge it, this way it gets added to the list of "allowed" VIs. Although this would require you to manually acknowledge the process initially for the VIs to be added to the AllowedList.

In order to disable the warning, enable the following option on both 32 and 64-bit LV2021: 

Tools/Options/Security/Run VI without warning 

Step 3: Open latest pwsh (Powershell) in admin mode, and navigate to

\labview-icon-editor\pipeline\scripts\

Step 4: Copy the following command into Powershell: 

   ```bach
.\Set_Development_Mode.ps1 -RelativePath "C:\labview-icon-editor"
   ```

Followed by

   ```bach
.\Build.ps1 -RelativePath "C:\labview-icon-editor" -AbsolutePathScripts "C:\labview-icon-editor\pipeline\scripts"
   ```
Note: Before pressing enter, make sure that you closed LabVIEW and VI Package manager.

A VI package will be created on the builds folder. Please note that you need to open VI Package manager on Admin mode in order to install the package. A VI package named *ni_icon_editor-x.x.x.x* will be built on *builds\VI Package*.
You can now install this VI package on any LabVIEW version after 2020. 

Once you are done with your change, run Build.ps1 from step 4 again to make a new VI package.

To revert your system back to normal, run the following command:
(you will need to do this in order to install the VI package)

   ```bach
.\RevertDevelopmentMode.ps1 -RelativePath "C:\labview-icon-editor"
   ```
After running the command, you can install the VI package and will have the updated copy of the icon editor.
