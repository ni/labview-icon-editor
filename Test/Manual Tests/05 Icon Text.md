# Scope
This procedure is used to verify the functionality of the Icon Text tab on the Icon Editor.

This procedure was not derived from any NI tests.

# Setup
1. Open and run Remove Icon Editor Settings.vi. This ensures there are no Icon Editor keys in the LabVIEW.ini file. All of the key names start with "IconEditor."

# Main
1. Open a new VI from the Getting Started Window.
2. From the Front Panel, double-click on the VI Icon to open the Icon Editor.
3. In the Layers tab, delete all user layers.
4. In the Templates tab, select the \_blank.png template.
5. Select the Icon Text tab.
6. Ensure the following settings are set correctly:
- All line colors: black
- Center text vertically: Checked
- Capitalize text: Checked
- Font:
    - If Small Fonts is installed, "Small Fonts"
    - Else "LabVIEW Application"
- Alignment: center
- Size: 9
7. Enter the following strings in their respective entries:
- Line 1 text: "line 1"
- Line 2 text: "line 2"
8. Verify the two lines of text are:
- in all caps
- horizontally centered
- vertically centered in the body part of the icon
9. Uncheck "Center text vertically".
10. Verify the two lines are aligned to the top of the body.
11. Enter "Line 4" in Line 4 text.
12. Verify the third line is empty while the fourth line is added to icon.
13. Check "Center text vertically".
14. Verify the three lines are vertically centered in the body.
15. Enter "Line 3" in the Line 3 text.
16. Verify the four lines of text are in their proper order and cenetered in the body.
17. Uncheck Capitalize text.
18. Verify all of the lines are now lower case.
19. Set the alignment to "left".
20. Verify the text is now aligned to the left edge of the body with 1 white space.
21. Set the alignment to "right".
22. Verify the text is now aligned to the right edge of the body with 1 white space.
23. Set the alignment to "center".
24. Increase the font size to 12.
25. Verify the text is larger.
26. Decreaes the font size to 6.
27. Verify the text is smaller.
28. Set the font size to 9.

# Cleanup
1. Click "Cancel" to close the Icon Editor, discarding any changes.
2. Close the VI, discarding any changes.