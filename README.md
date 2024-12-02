# Icon Editor for LabVIEW #

This repo contains the source files and automated build tools for the LabVIEW icon editor.
You can use this code as a starting point for creating a custom icon editor. Refer to the [CONTRIBUTING](CONTRIBUTING.md) document for information about submitting changes for inclusion with future versions of LabVIEW.

## Compatible LabVIEW Versions

LabVIEW source is saved in 21.0 (__LabVIEW 2021__) format. Either LabVIEW 2021 or LabVIEW 2024 can be used to do development work.

To build using the automated build process,  ensure you have LabVIEW 2021 *both 32 and 64 bits* installed, latest VIPM, and apply the dependencies located on *Tooling\deployment\Dependencies.vipc* to both LabVIEW versions.

## Editing Guide 

Because the icon editor is part of the LabVIEW development environment, you need to make changes to installed files before editing this project. There is an manual process, and an automated process made following it for ease of use.

### Automated process 

Before following this process, create a backup of the following files and folder:
   - \<LabVIEW\>\\resource\\plugins\\lv_icon.lvlibp 
   - \<LabVIEW\>\\vi.lib\\LabVIEW Icon API\\*

After cloning the repo into a development location, and applying the dependencies located on *Tooling\deployment\Dependencies.vipc* to LabVIEW 2021 32 and 64 bits, follow this process to use the automation layer.

1. Open Powershell in *Admin* mode and navigate to *.pipeline\scripts* from your github repo.
2. Modify the following command to point to your github repo and run it: *.\DevelopmentMode.ps1 -RelativePath "C:\labview-icon-editor"*
3. Open lv_icon_editor.lvproj in LabVIEW.
4. The top-level VI is in the Project Explorer at __My Computer &#x00BB; resource/plugins &#x00BB; lv_icon.lvlib &#x00BB; lv_icon.vi__.

### Manual process  

Complete the following steps to edit this project:
1. Clone this repo into a development location (e.g., C:\dev).
2. Run __Tooling\Prepare LV to Use Icon Editor Source.vi__.
This will perform the following steps, which you can alternatively perform manually:
   * Delete \<LabVIEW\>\\resource\\plugins\\lv_icon.lvlipb
   * Delete \<LabVIEW\>\\vi.lib\\LabVIEW Icon API
   * Set LocalHost.LibraryPaths in your labview.ini file to the location of this project. For example:*
       *   LocalHost.LibraryPaths="C:\\dev\\labview-icon-editor"
3. Open lv_icon_editor.lvproj in LabVIEW.
4. The top-level VI is in the Project Explorer at __My Computer &#x00BB; resource/plugins &#x00BB; lv_icon.lvlib &#x00BB; lv_icon.vi__.

## Distribution Guide

Complete the following steps to distribute your custom icon editor to another machine.

### Automated process 

This automated build process will follow these steps: 

1. Apply the dependencies
2. Run the unit test, 
build the icon editor packed project library

1. Open powershell in *Admin* mode and navigate to *.pipeline\scripts* from your github repo.
2. Modify the following command to point to your github repo and run it: *.\build.ps1 -RelativePath "C:\labview-icon-editor"*
3. A VI package named *ni_icon_editor-x.x.x.x* will be built on *builds\VI Package*.
4. You can now install this VI package on any LabVIEW version after 2020. 

*NOTE: The VI package makes no backup of your current lv_icon.lvlibp because the VI Package itself contains a zip file with all combinations of lv_icon.lvlibp for all LabVIEW versions and bitnesses, which gets deployed to your LabVIEW application files on uninstall. This ensures that a user doesnt get locked out of his icon editor and having to copy it from another LabVIEW installation if somehow he deletes the backup he did manually.*

### Manual process  

First, build the __Editor Packed Library__ build specification in the project to create __lv_icon.lvlibp__.

Then, on the machine where you want to install your custom icon editor:
1. Rename __\<LabVIEW\>\\resource\\plugins\\lv_icon.lvlibp__, the shipping icon editor, to __lv_icon.lvlibp.ship__ to "hide" it.
2. Archive __\<LabVIEW\>\\vi.lib\\LabVIEW Icon API__ to preserve the shipping copy.  Use your archive program of choice (e.g. 7-Zip).
3. Copy the packed library and support files that you developed with this project into the \<LabVIEW\> directory:  
   - \<LabVIEW\>\\resource\\plugins\\lv_icon.lvlibp 
   - \<LabVIEW\>\\vi.lib\\LabVIEW Icon API\\*

## CI using an Azure DevOps pipeline

An Azure Devops pipeline is used as an additional check to approve pull requests from *feature* to *development* branches. This pipeline runs the unit tests, builds the packed project libraries for both 32 and 64 bit LabVIEW, and builds the VI Package.

## CI using github actions

An example of a github action that can manually trigger a CI/CD workflow is located at "C:\labview-icon-editor\.github\workflows\Build VI packages.yml"


