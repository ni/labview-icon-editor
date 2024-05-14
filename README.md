# Icon Editor for LabVIEW
This repo contains the source files for the LabVIEW icon editor.
You can use this code as a starting point for creating a custom icon editor. Refer to the CONTRIBUTING document for information about submitting changes for inclusion with future versions of LabVIEW.

## Minimum Compatible LabVIEW Version
LabVIEW source is saved in 21.0 (__LabVIEW 2021__) format.

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
Complete the following steps on another machine where you want to install your custom icon editor:
1. Rename __\<LabVIEW\>\\resource\\plugins\\lv_icon.lvlibp__, the shipping icon editor, to __lv_icon.lvlibp.ship__ to "hide" it.
2. Archive __\<LabVIEW\>\\vi.lib\\LabVIEW Icon API__ to preserve the shipping copy.  Use your archive program of choice (e.g. 7-Zip).
3. Copy the files you developed with this project into the \<LabVIEW\> directory:  
   - \<LabVIEW\>\resource\plugins\lv_icon.vi 
   - Associated support files such as
      - \<LabVIEW\>\\resource\\plugins\\lv_IconEditor.lvlib
      - \<LabVIEW\>\\resource\\plugins\\NIIconEditor\\*
      - \<LabVIEW\>\\vi.lib\\LabVIEW Icon API\\*