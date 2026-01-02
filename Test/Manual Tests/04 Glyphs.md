# Scope
This procedure is used to verify the functionality of the Glyphs tab on the Icon Editor.

This procedure was derived from the following NI tests:
- 1692479: Population of Glyphs and Templates
- 1692481: Drop glyphs - Glyph in icon editor
- 1692483: Template and Glyph Names
- 1692490: List Glyphs and Icon Templates
- 1692493: Keywords
- 1692503: Synchronize with ni.com Icon Library

# Setup
1. Remove all glyphs from the \<LabVIEW Data\>\\Glyphs folder and subfolders.
**NOTE:** It is recommended to backup all third-party glyphs before performing this step.
2. Remove all Glyphs.\<LabVIEW Version\>.bin files from the \<LabVIEW Data\>\\Glyphs folder.

    **NOTE:** \<LabVIEW Data\> is an option in LabVIEW. By default, it is located at:
- Windows: \<My Documents\>\\LabVIEW Data
- **To Do:** Add other OS versions to this note

3. Open the Icon Editor Manual Tests project.

# Main
1. Open Pyramid Icon Template.vi.
2. From the Front Panel, double-click on the VI Icon to open the Icon Editor.
3. In the Glyphs tab, verify the available glyphs is empty.
4. Save the current icon as a glyph using the File->Save As...->Glyph menu item. Save the glyph in the _test subdirectory and name it Pyramid.png.
5. Verify the image was created at \<LabVIEW Data\>\\Glyphs\\_test\\Pyramid.png.
6. Verify the Pyramid.png image is in the list of glyphs.
7. Verify there is a "_test" in the Category tree.
8. In the menu, choose Tools->List Glyphs and Icon Templates.
9. Verify an HTML report is displayed in the system's default web browser.
10. Verify the Icon Templates section displays the currently installed templates.
11. Verify the Glyphs section displays the Glyphs\\_test\\Pyramid.png.
12. Close the web broswer tab with the report.
13. Import glyphs using Tools->Synchronize with ni.com Icon Library.
14. Wait for the icons to download.
15. Click "OK" to install all of the glyphs.
16. In the Glyphs tab, verify the Category tree and list of icons are filled.
17. Click on the _test category and verify only the Pyramid.png glyph is listed.
18. Click on the Time category and verify only time related glyphs are listed.
19. Click on the All Glyphs category.
20. In the filter, type "py" and verify the Pyramid.png glyph is listed.
21. Go into the Layers tab and delete all of the layers.
22. Go back into the Glyphs tab. 
23. Double click on the Pryamid glyph.
24. Verify the Pyramid glyph is in the Icon Preview.
25. Go into the Layers tab and verify there is a Pyramid layer matching the image.
26. Delete the Pyramid layer.
27. Go into the Glyphs tab.
28. Drag the Pyramid glyph over the preview section and verify the Pyramid glyph is moving with the mouse.
29. Release the mouse to drop the glyph.
30. Verify the path listed below the Glyph list is "...bVIEW Data\\Glyphs\\_test\\Pyramid.png".
31. Go into the Layers tab and verify there is a Pyramid layer matching the image.
32. Delete the Pyramid layer.
33. Go back into the Glyphs tab.
34. Change the glyph filter to arrow and click on the Right_Arrow.png.
35. Hover over the preview section.
36. Press "f" and verify the arrow flips across the vertical axis.
37. Press "r" and verify the arrow rotates clockwise.
38. Click to set the glyph in the icon.
39. Go into the Layers tab and verify there is a Arrow_Right layer with the glyph as you placed it.
40. Remove the \<LabVIEW Data\>\\Glyphs\\_test folder.
41. In the Glyphs tab, click the Refresh button.
42. Verify the _test category was removed.
43. Type "py" in the filter and verify the Pyramid.png glyph is not listed.
44. In the menu, choose Edit->Import Glyph From File.
45. Browse to the \<repo folder\>\\Test folder and select Pyramid.png
46. Go into the Layers tab and verify there is a Pyramid layer matching the image.
47. Click "Cancel" to close the Icon Editor. Discard any changes.

# Cleanup
1. Close the Icon Editor Manual Tests project and any associated files, discarding any changes.
2. If necessary, remove the Pyramid.png file from the Glyphs folder and restore previously used glyph files.