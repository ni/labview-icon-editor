# Scope
This procedure is used to verify the functionality of the Templates tab on the Icon Editor.

This procedure was derived from the following NI tests:
- 1692479: Population of Glyphs and Templates
- 1692483: Template and Glyph Names
- 1692493: Keywords

# Setup
1. Remove all 3rd party templates from the \<LabVIEW Data\>\\Icon Templates folder and subfolders.
2. Remove all Templates.\<LabVIEW Version\>.bin files from the \<LabVIEW Data\>\\Icon Templates folder.

    **NOTE:** \<LabVIEW Data\> is an option in LabVIEW. By default, it is located at:
- Windows: \<My Documents\>\\LabVIEW Data\\Icon Templates
- **To Do:** Add other OS versions to this note

3. Open the Icon Editor Manual Tests project.

# Main
1. Open Pyramid Icon Template.vi.
2. From the Front Panel, double-click on the VI Icon to open the Icon Editor.
3. Verify the file \<LabVIEW Data\>\\Icon Templates\\Templates.\<LabVIEW Version\>.bin file was created.
4. Save the current icon as a template using the File->Save As...->Template menu item. Save the template in the VI\\test subdirectory and name it Pyramid.png.
5. Verify the image was created at \<LabVIEW Data\>\\Icon Templates\\VI\\test\\Pyramid.png.
6. Verify the Pyramid.png image is in the list of templates.
7. Verify there is a "VI->test" in the Category tree.
8. Click "VI" in the Category tree and verify the list no longer contains the library template.
9. Click "VI->Frameworks" in the Category tree and verify the list no longer contains the Pyramid.png template.
10. Click on the available template and verify the path listed below is "... Templates\VI\Frameworks\_blank.png".
11. Click "All Templates" in the Category tree.
12. Click on the Pyramid template.
13. Verify the path listed below is "... Data\Icon Templates\VI\Pyramid".
14. In the "Filter templates by keyword", enter "\_".
15. Verify only the "\_blank" templates are listed.
16. In the "Filter templates by keyword", enter "p".
17. Verify the Pyramid template is the only listed template.
18. Select the Pyramid template.
19. In the Layers tab, verify the Icon Template matches the Pyramid image.
20. Click "OK" to close the Icon Editor.
21. Remove the Pyramid.png file and the Templates.bin file from the Icon Templates folder.
22. From the Front Panel, double-click on the VI Icon to open the Icon Editor.
23. Verify the file \<LabVIEW Data\>\\Icon Templates\\Templates.\<LabVIEW Version\>.bin file was created. 
24. Verify the Pyramid.png was saved to \<LabVIEW Data\>\\Icon Templates\\VI\\3rd party\\Pyramid.png.
25. On the Icon Editor, click the Refresh button in the Templates tab.
26. Verify the Pyramid.png template is when VI->3rd party is selected in the Category tree.
27. Click "OK" to close the Icon Editor.
28. Close Pyramid Icon Template.vi, discarding changes.
29. From the project window, right-click on Library Template.lvlib and select "Properties".
30. Click "Edit Icon..." to open the Icon Editor.
31. Save the current icon as a template using the File->Save As...->Template menu item. Save the template in the Library\\test subdirectory and name it Library.png.
32. Select the new Library.png template from the template list.
33. Click "OK" to close the Icon Editor.
34. Remove the Library.png file and the Templates.bin file from the Icon Templates folder.
35. Click "Edit Icon..." to open the Icon Editor.
36. Verify the file \<LabVIEW Data\>\\Icon Templates\\Templates.\<LabVIEW Version\>.bin file was created. 
37. Verify the Library.png was saved to \<LabVIEW Data\>\\Icon Templates\\Library\\3rd party\\Library.png.
38. On the Icon Editor, click the Refresh button in the Templates tab.
39. Verify the Pyramid.png template is when Library->3rd party is selected in the Category tree.
40. Click "OK" to close the Icon Editor.
41. Click "Cancel" to close the Library Properties window.

# Cleanup
1. Close the Icon Editor Manual Tests project and any associated files, discarding any changes.
2. If necessary, remove the Pyramid.png file from the Icon Templates folder and restore previously used template files.