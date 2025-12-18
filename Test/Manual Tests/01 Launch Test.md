# Scope
This procedure is used to verify the Icon Editor properly launches from the various entry points in the LabVIEW IDE.

This procedure was dirived from the following NI tests:
- 1692477: Launch Test.
- 1692478: Launch Stress Test

# Setup
Open the Icon Editor Manual Tests project.

# Tests
## 1. Launching from a VI
1. Open Pyramid Icon Template.vi.
2. From the Front Panel, double-click on the VI Icon.
3. Verify the Icon Editor opens.
4. Use the Pencil tool to draw on the icon and verify proper operation.
5. Press the OK button to close the Icon Editor.
6. Verify the VI Icon was updated to match the updates.
7. From the Front Panel, right-click on the VI Icon and choose "Edit Icon...".
8. Verify the Icon Editor opens.
9. Use the Pencil tool to draw on the icon and verify proper operation.
10. Press the OK button to close the Icon Editor.
11. Verify the VI Icon was updated to match the updates.
12. Repeat step 2 through step 11 15 times to stress test launching the Icon Editor.
13. Open the VI Properties dialog (Ctrl+I or File->VI Properties).
14. Set the Category to "General".
15. Click Edit Icon.
16. Verify the Icon Edior opens.
17. Use the Pencil tool to draw on the icon and verify proper operation.
18. Press the OK button to close the Icon Editor.

**NOTE:** Should the icon in the VI Properties update when the editor closes? It does not since at least 8.2

19. Close the VI Properties window.
20. Verify the VI Icon was updated to match the updates.
21. Close Pyramid Icon Template.vi, do not save the edits.

**NOTE:** Consider adding launching from Block Diagram as well

## 2. Launching from a Control
1. Open Control Template.ctl.
2. From the Front Panel, double-click on the Control Icon.
3. Verify the Icon Editor opens.
4. Use the Pencil tool to draw on the icon and verify proper operation.
5. Press the OK button to close the Icon Editor.
6. Verify the Control Icon was updated to match the updates.
7. From the Front Panel, right-click on the Control Icon and choose "Edit Icon...".
8. Verify the Icon Editor opens.
9. Use the Pencil tool to draw on the icon and verify proper operation.
10. Press the OK button to close the Icon Editor.
11. Verify the Control Icon was updated to match the updates.
12. Open the Control Properties dialog (Ctrl+I or File->Control Properties).
13. Set the Category to "General".
14. Click Edit Icon.
15. Verify the Icon Edior opens.
16. Use the Pencil tool to draw on the icon and verify proper operation.
17. Press the OK button to close the Icon Editor.

**NOTE:** Should the icon in the Control Properties update when the editor closes? It does not since at least 8.2

18. Close the Control Properties window.
19. Verify the Control Icon was updated to match the updates.
20. Close Control Template.ctl, do not save the edits.

## 3. Launching from a Polymorphic VI
1. Open Polymorphic Template.vi.
2. Click the "Edit Icon..." button.
3. Verify the Icon Editor opens.
4. Use the Pencil tool to draw on the icon and verify proper operation.
5. Press the OK button to close the Icon Editor.
6. Verify the VI Icon was updated to match the updates.
7. Double-Click the VI Icon.
8. Verify the Icon Editor opens.
9. Use the Pencil tool to draw on the icon and verify proper operation.
10. Press the OK button to close the Icon Editor.
11. Verify the VI Icon was updated to match the updates.

**NOTE:** Double-clicking on the icon will cause the Icon Editor to open twice in a serial fashion

12. Close Polymorphic Template.vi, do not save the edits.

## 4. Launching from a Library
1. Open the properties of Library Template.lvlib.
2. In the General Settings category, click "Edit Icon...".
3. Verify the Icon Editor opens.
4. Use the Pencil tool to draw on the icon and verify proper operation.
5. Press the OK button to close the Icon Editor.
6. Verify the VI Icon Template was updated to match the updates.
7. Click "Cancel" to close the Library Properties window without saving the changes.

## 5. Launching from a Class
1. Open the properties of Class Template.lvclass.
2. In the General Settings category, click "Edit Icon...".
3. Verify the Icon Editor opens.
4. Use the Pencil tool to draw on the icon and verify proper operation.
5. Press the OK button to close the Icon Editor.
6. Verify the VI Icon Template was updated to match the updates.
7. Click "Cancel" to close the Class Properties window without saving the changes.

## 6. Palette Icon
**Note:** This also verifies a partially transparent icon can be created.
1. In the project window menu bar, choose to Tools->Advanced->Edit Palette Set...
2. In the Functions palette window, right-click on the User Libraries palette and choose "Edit Subpalette Icon".
6. Verify the Icon Editor opens.
7. Select all layers and delete them.
8. Add the library.png glyph to the middle of the icon.
9. Press the OK button to close the Icon Editor.
10. Verify the subpalette Icon was updated to match the updates.
11. Click Cancel on the Edit Controls and Functions Palette Set dialog to discard the changes made.

# Close Up
Close the Icon Editor Manual Tests project, discarding any changes.