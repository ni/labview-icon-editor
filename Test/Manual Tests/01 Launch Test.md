# Scope


# Notes
This procedure was dirived from NI test 1692477: Launch Test.

# Tests
## Launching from a VI
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
12. Open the VI Properties dialog (Ctrl+I or File->VI Properties).
13. Set the Category to "General".
14. Click Edit Icon.
15. Verify the Icon Edior opens.
16. Use the Pencil tool to draw on the icon and verify proper operation.
17. Press the OK button to close the Icon Editor.
- **Should the icon in the VI Properties update when the editor closes?**
18. Close the VI Properties window.
19. Verify the VI Icon was updated to match the updates.
20. Close Pyramid Icon Template.vi, do not save the edits.
- **Consider adding launching from Block Diagram as well**

## Launching from a Control
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
- **Should the icon in the Control Properties update when the editor closes?**
18. Close the Control Properties window.
19. Verify the Control Icon was updated to match the updates.
20. Close Control Template.ctl, do not save the edits.

## Launching from a Library


## Launching from a Class


## Launching from a Polymorphic VI


## Palette Icon


Launch the IE from the following locations and make sure that it works properly (drop some glyphs, write some text and press OK).
    - VI by double clicking on the icon
    - VI by right clicking on the icon - Edit Icon
    - VI by launching the preferences dialog and pressing - Edit Icon
    - Control by double clicking on the icon
    - Control by right clicking on the icon - Edit Icon
    - Control by launching the preferences dialog and pressing - Edit Icon
    - Library
    - Class
    - Polymorphic VI
    - Palette icon (Tools - Options - Advanced - Edit palette set).
        Additionally to the default test make sure that it's possible to create a partially transparent icon.
            Use the clear tool to clear everything, afterwards drop only one glyph right in the center. Press enter. Ensure that everything looks fine and that nothing but the before dropped glyph is visible on the palette icon.
