# Scope
This procedure is used to verify the Icon Editor properly launches from a fresh install with no saved settings.

This procedure was dirived from the following NI tests:
- 1692474: First launch IE Icon Editor

# Setup
**NOTE:** It is preferable to perform this test with a fresh LabVIEW install.

1. Install the Icon Editor.
2. Open Icon Editor Manual Tests.lvproj.
3. Open and run Remove Icon Editor Settings.vi. This ensures there are no Icon Editor keys in the LabVIEW.ini file. All of the key names start with "IconEditor."
4. Close the VI and project when complete.

# Tests
## 1. Launching from a VI
1. Open a new VI from the Getting Started Window.
2. From the Front Panel, double-click on the VI Icon.
3. Verify the Icon Editor opens without seeing the loading dialog.
4. Verify the Icon Text->Font combobox is properly populated based on fonts installed on the system.
5. If Small Fonts is installed, verify Small Fonts is selected in the Font combobox. If not installed, verify "LabVIEW Application" is selected.
6. Verify the font alignment is "center" and the font size is 9.
7. Launch the Icon Editor Properties via the tools menu.
8. Verify the Templates category is selected.
9. Verify the following settings in the Templates category:
- "Save third-party icon templates?" is unchecked.
- "Third-party template directory" is set to "\<LabVIEW Data>\\Icon Templates\\3rd party".
10. Verify the following settings in the Layers category:
- "Merge all layers on commit" is unchecked.
11. Verify the following settings in the Text Tool category:
- Font combobox is properly populated based on fonts installed on the system.
- Font value is:
    - If Small Fonts is installed, "Small Fonts"
    - Else "LabVIEW Application"
- Alignment is "center"
- Size is 9
12. Close the Icon Editor Properties dialog.
13. Close the Icon Editor.
14. From the VI Front Panel, double-click on the VI Icon.
15. Verify the Icon Editor launched at least as fast as the first time opening it.
**NOTE:** Because the Icon Editor is left in memory, it should load faster than the first run.

# Close Up
1. Close the Icon Editor.
2. Close the VI.