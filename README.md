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


## Distribution Guide ##
Complete the following steps to distribute your custom icon editor to another machine.

First, build the __Editor Packed Library__ build specification in the project to create __lv_icon.lvlibp__.

Then, on the machine where you want to install your custom icon editor:
1. Rename __\<LabVIEW\>\\resource\\plugins\\lv_icon.lvlibp__, the shipping icon editor, to __lv_icon.lvlibp.ship__ to "hide" it.
2. Archive __\<LabVIEW\>\\vi.lib\\LabVIEW Icon API__ to preserve the shipping copy.  Use your archive program of choice (e.g. 7-Zip).
3. Copy the packed library and support files that you developed with this project into the \<LabVIEW\> directory:  
   - \<LabVIEW\>\\resource\\plugins\\lv_icon.lvlibp 
   - \<LabVIEW\>\\vi.lib\\LabVIEW Icon API\\*
  
## Creating a VI Package ##
A .bat file located on *\Tooling\deployment\Build.bat* automates the process described by the *Editing Guide* and *Distribution guide*. 

azure_pipeline.yml can also automate the process. 

Running the .bat file will run the unit tests contained on tooling\unit tests

*LabVIEW 2021 and 2022:* lv_icon.lvlibp will replace lv_icon.lvlibp from resources/plugin (normal process).
*LabVIEW > 2022:* lv_icon.lvlibp will be installed on C:\Program Files\NI\LVAddons\niiconeditor(bitness)

**Prerequisites:** 
 
  * LV2021 
  * Latest VI Package Builder
  * Latest VIPM 
  * Manually Applying dependencies located on *Tooling\deployment\Dependencies.vipc*
  * (Other LabVIEW versions you want to build the package on, LV2021 is mandatory since the PPL gets built on 2021)
 
**Process:**

  1. Edit variables on .bat file *\Tooling\deployment\Build.bat*.
     Example: Batch file variables for lv_icon.lvlibp built on LV2021 x64, on a VI Package for LabVIEW 2024 x64

     set "MinimumSupportedLVVersion=2021"
     
     set "VIP_LVVersion=2024"
     
     set "SupportedBitness=64"
        
  3. Run the .bat file with admin rights (inspect it first).
  4. A VI package named *ni_icon_editor-x.x.x.x* will be built on *builds\VI Package*.

