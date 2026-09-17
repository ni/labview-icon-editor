# Scope

This procedure is used to verify the undo/redo states are properly stored and applied appropriately.

Unless otherwise stated, each section of the Main may be ran independently of the other sections. The Setup and Cleanup must be performed.

An Undo action can be done through either the Edit menu or by pressing Ctrl+z.
A Redo action can be done through either the Edit menu or by pressing Ctrl+Shift+z.

# Setup

1. Open VI Template.vi.
**NOTE:** This will add IE_Test.png to your list of templates.

# Main

## 1. Templates Tab

1. Double-click on the icon on VI Template.vi to open the Icon Editor.
2. Open the Templates tab
3. Verify the Undo and Redo items in the Edit menu are disabled.
4. In the Filter Templates by Keyword control, type "ie".
5. Verify the Undo item in the Edit menu is enabled.
6. Verify the Redo item in the Edit menu is disabled.
7. Verify the "_blank.png" templates are removed from the list.
8. Perform an undo.
9. Verify the string in Filter Templates by Keyword is now "i".
10. Verify the Undo item in the Edit menu is enabled.
11. Verify the Redo item in the Edit menu is enabled.
12. Verify the "_blank.png" templates are still removed from the list.
13. Perform an undo.
14. Verify the string in the Filter Templates by Keyword is now empty.
15. Verify the Undo item in the Edit menu is disabled.
16. Verify the Redo item in the Edit menu is enabled.
17. Verify the "_blank.png" templates are back in the list.
18. Perform a redo.
19. Verify the string in Filter Templates by Keyword is now "i".
20. Verify the Undo item in the Edit menu is enabled.
21. Verify the Redo item in the Edit menu is enabled.
22. Verify the "_blank.png" templates are removed from the list.
23. Perform a redo.
24. Verify the Undo item in the Edit menu is enabled.
25. Verify the Redo item in the Edit menu is disabled.
26. Verify the "_blank.png" templates are still removed from the list.
27. Perform 2 undo actions to return to the default state.
28. Select the "VI\Frameworkds\_blank.png" template.
29. Verify the Undo item in the Edit menu is enabled.
30. Verify the Redo item in the Edit menu is disabled.
31. Perform an Undo.
32. Verify the used template is now "IE_Test.png".
33. Verify the Undo item in the Edit menu is disabled.
34. Verify the Redo item in the Edit menu is enabled.
35. Perform a Redo.
36. Verify the used template is now "_blank.png".
37. Verify the Undo item in the Edit menu is enabled.
38. Verify the Redo item in the Edit menu is disabled.
39. Close the Icon Editor, discarding any changes.

## 2. Icon Text Tab

1. Double-click on the icon on VI Template.vi to open the Icon Editor.
2. Open the Icon Text tab.
3. Verify the Undo and Redo items in the Edit menu are disabled.
4. In Line 1 text, type "ie".
5. Verify the Undo item in the Edit menu is enabled.
6. Verify the Redo item in the Edit menu is disabled.
7. Perform an undo.
8. Verify the string in Line 1 text is now "i".
9. Verify the Undo item in the Edit menu is enabled.
10. Verify the Redo items in the Edit menu is enabled.
11. Perorm an undo.
12. Verify the string in Line 1 text is now empty.
13. Verify the Undo item in the Edit menu is disabled.
14. Verify the Redo items in the Edit menu is enabled.
15. Perform a redo.
16. Verify the string in Line 1 text is now "i".
17. Verify the Undo item in the Edit menu is enabled.
18. Verify the Redo items in the Edit menu is enabled.
19. Perform a redo.
20. Verify the string in Line 1 text is now "ie".
21. Verify the Undo item in the Edit menu is enabled.
22. Verify the Redo items in the Edit menu is disabled.
23. Perform an undo.
24. In Line 2 text, type "a".
25. Verify the Undo item in the Edit menu is enabled.
26. Verify the Redo items in the Edit menu is disabled.
27. Perform an undo.
28. Verify Line 2 text is empty.
29. Perfrom a redo.
30. Verify Line 2 text is "a".
31. In Line 3 text, type "b".
32. Perform an undo.
33. Verify Line 3 text is empty.
34. Perfrom a redo.
35. Verify Line 3 text is "b".
36. In Line 4 text, type "c".
37. Perform an undo.
38. Verify Line 4 text is empty.
39. Perform a redo.
40. Verify Line 4 text is "c".
41. Set Line 1 color to LED On.
42. Perform an undo.
43. Verify Line 1 color is black.
44. Perform a redo.
45. Verify Line 1 color is LED On.
46. Perform an undo.
47. Set Line 2 color to LED On.
48. Perform an undo.
49. Verify Line 2 color is black.
50. Perform a redo.
51. Verify Line 2 color is LED On.
52. Perform an undo.
53. Set Line 3 color to LED On.
54. Perform an undo.
55. Verify Line 3 color is black.
56. Perform a redo.
57. Verify Line 3 color is LED On.
58. Perform an undo.
59. Set Line 4 color to LED On.
60. Perform an undo.
61. Verify Line 4 color is black.
62. Perform a redo.
63. Verify Line 4 color is LED On.
64. Perform an undo.
65. Set the Font to LabVIEW Application.
66. Perform an undo.
67. Verify the Font is Small Fonts.
68. Perform a redo.
69. Verify the Font is LabVIEW Application.
70. Perform an undo.
71. Set Alignment to left.
72. Perform an undo.
73. Verify Alignment is center.
74. Perform a redo.
75. Verify Alignmnet is left.
76. Perform an undo.
77. Set the font size to 10.
78. Perform an undo.
79. Verify the font size is 9.
80. Perform a redo.
81. Verify the font size is 10.
82. Perform an undo.
83. Uncheck Center text vertically.
84. Perform an undo.
85. Verify the Center text vertically is checked.
86. Perform a redo.
87. Verify the Center text vertically is unchecked.
88. Perform an undo.
89. Check the Capitalize text.
90. Perform an undo.
91. Verify the Captialize text is unchecked.
92. Perform a redo.
93. Verify the Capitalize text is checked.
94. Close the Icon Editor, discarding any changes.

## 3. Glyphs Tab

1. Double-click on the icon on VI Template.vi to open the Icon Editor.
2. Open the Glyphs tab.
3. Verify the Undo and Redo items in the Edit menu are disabled.
4. In the Filter glyphs by keyword control, type "xy".
5. Verify the Undo item in the Edit menu is enabled.
6. Verify the Redo item in the Edit menu is disabled.
7. Perform an undo.
8. Verify the string in Filter glyphs by keyword is now "x".
9. Verify the filtered list of glyphs was updated.
10. Verify the Undo item in the Edit menu is enabled.
11. Verify the Redo item in the Edit menu is enabled.
12. Perform an undo.
13. Verify the string in Filter glyphs by keyword is now empty.
14. Verify the filtered list of glyphs was updated.
15. Verify the Undo item in the Edit menu is disabled.
16. Verify the Redo item in the Edit menu is enabled.
17. Perform a redo.
18. Verify the string in Filter glyphs by keyword is now "x".
19. Verify the filtered list of glyphs was updated.
20. Verify the Undo item in the Edit menu is enabled.
21. Verify the Redo item in the Edit menu is enabled.
22. Perform a redo.
23. Verify the string in Filter glyphs by keyword is now "xy".
24. Verify the filtered list of glyphs was updated.
25. Verify the Undo item in the Edit menu is disabled.
26. Verify the Redo item in the Edit menu is enabled.
27. Double-click the xy_graph glyph to place it in the icon.
28. Perform an undo.
29. Verify the glyph was removed from the icon.
30. Perform a redo.
31. Verify the glyph was placed backed in the icon.
32. Close the Icon Editor, discarding any changes.

## 4. Layers Tab

1. Double-click on the icon on VI Template.vi to open the Icon Editor.
2. Open the Layers tab.
3. Verify the Undo and Redo items in the Edit menu are disabled.
4. Click the + button twice to add two layers.
5. Verify the Undo item in the Edit menu is enabled.
6. Verify the Redo item in the Edit menu is disabled.
7. Perform an undo.
8. Verify one of the added layers was removed.
9. Verify the Undo item in the Edit menu is enabled.
10. Verify the Redo item in the Edit menu is enabled.
11. Perform an undo.
12. Verify the other added layer was removed.
13. Verify the Undo item in the Edit menu is disabled.
14. Verify the Redo item in the Edit menu is enabled.
15. Perform a redo.
16. Verify a layer was added.
17. Verify the Undo item in the Edit menu is enabled.
18. Verify the Redo item in the Edit menu is enabled.
19. Perform a redo.
20. Verify the second layer was added.
21. Verify the Undo item in the Edit menu is enabled.
22. Verify the Redo item in the Edit menu is disabled.
23. Perform an undo.
24. Select the empty user layer and click the X button to delete it.
25. Verify the Undo item in the Edit menu is enabled.
26. Verify the Redo item in the Edit menu is disabled.
27. Perform an undo.
28. Verify the empty user layer was restored.
29. Select the emtpy user layer.
30. Click the down arrow button to move it below the Colors layer.
31. Perform an undo.
32. Verify the empty layer was moved back to the top.
33. Perform a redo.
34. Verify the empty layer is below the Colors layer.
35. Click the up arrow button to move the empty layer above the Colors layer.
36. Perform an undo.
37. Verify the empty layer was moved below the Colors layer.
38. Perform a redo.
39. Verify the empty layer was moved back to the top.
40. Set the Icon Text layer's visibility off.
41. Perform an undo.
42. Verify the Icon Text layer's visibility is on.
43. Perform a redo.
44. Verify the Icon Text layer's visibility is off.
45. Perform an undo to restore the visibility.
46. Click and hold on the Icon Text layer transparency.
47. Adjust the transparency to 50 and release the mouse button.
48. Perform an undo.
49. Verify the Icon Text layer transparency is 100.
50. Perform a redo.
51. Verify the Icon Text layer transparency is 50.
52. Perform an undo to restore the layer transparency.
53. Set the Icon Template layer's visibility off.
54. Perform an undo.
55. Verify the Icon Template layer's visibility is on.
56. Perform a redo.
57. Verify the Icon Template layer's visibility is off.
58. Perform an undo to restore the visibility.
59. Click and hold on the Icon Template layer transparency.
60. Adjust the transparency to 50 and release the mouse button.
61. Perform an undo.
62. Verify the Icon Template layer transparency is 100.
63. Perform a redo.
64. Verify the Icon Template layer transparency is 50.
65. Perform an undo to restore the layer transparency.
66. Set the Colors layer's visibility off.
67. Perform an undo.
68. Verify the Colors layer's visibility is on.
69. Perform a redo.
70. Verify the Colors layer's visibility is off.
71. Perform an undo to restore the visibility.
72. Click and hold on the Colors layer transparency.
73. Adjust the transparency to 50 and release the mouse button.
74. Perform an undo.
75. Verify the Colors layer transparency is 100.
76. Perform a redo.
77. Verify the Colors layer transparency is 50.
78. Perform an undo to restore the layer transparency.
79. Close the Icon Editor, discarding any changes.

## 5. Menu Items

1. Double-click on the icon on VI Template.vi to open the Icon Editor.
2. Open the Icon Text tab.
3. Type "asd" in the Line 1 text.
4. Open the Layers tab.
5. Select the Edit->Clear User Layers menu item to remove the Colors layer.
6. Perform an undo.
7. Verify the Colors layer was restored.
8. Perform a redo.
9. Verify the Colors layer was removed.
10. Perform an undo to restore the layer.
11. Select the Edit->Clear All menu item to remove all of the layers.
12. Perform an undo.
13. Verify all layers were restored.
14. Perform a redo.
15. Verify all layers were removed.
16. Perform an undo to restore the layers.
17. Select the Edit->Import Glyph From File menu item.
18. Browse to the Templates folder and selct the Pyramid.png file.
19. Perform an undo.
20. Verify the Pyramid layer was removed.
21. Perform a redo.
22. Verify the Pryamid layer was restored.
23. Select the Edit->Import From Owning Library menu item.
24. Perform an undo.
25. Verify the NI_Library layer was removed.
26. Perform a redo.
27. Verify the NI_Library layer was restored.
28. Select the Layers->Create New Layer menu item.
29. Perform an undo.
30. Verify the empty layer was removed.
31. Perform a redo.
32. Verify the empty layer was restored.
33. Select the empty layer.
34. Select the Layers->Delete Selected Layers menu item.
35. Perform an undo.
36. Verify the empty layer was restored.
37. Perform a redo.
38. Verify the empty layer was removed.
39. Select the Pyramid and Colors layers.
40. Select the Layers->Merge Selected Layers menu item.
41. Perform an undo.
42. Verify the Merged Layers layer is removed and the Pyramid and Colors layers are restored.
43. Perform a redo.
44. Verify the Merged Layers layer is restored and the Pryamid and Colors layers are removed.
45. Perform an undo.
46. Select the Layers->Merge All User Layers menu item.
47. Perform an undo.
48. Verify the Merged Layers layer is removed and the NI_Library, Pyramid, and Colors layers are restored.
49. Perform a redo.
50. Verify the Merged Layers layer is restored and the NI_Library,Pryamid, and Colors layers are removed.
51. Close the Icon Editor, discarding any changes.

## 6. Tools

1. Double-click on the icon on VI Template.vi to open the Icon Editor.
2. Open the Layers tab.
3. Select the Pencil tool.
4. With a single click and drag (do not lift the mouse button until you are done drawing), draw on the Icon Preview.
5. Perform an undo.
6. Verify the pencil drawing was removed.
7. Perform a redo.
8. Verify the pencil drawing was restored.
9. Perform an undo.
10. Select the Line tool.
11. Draw a line on the Icon Preview.
12. Perform an undo.
13. Verify the line was removed.
14. Perform a redo.
15. Verify the line was restored.
16. Perform an undo.
17. Select the Paint tool.
18. Paint in the open area in the bottom half of the icon.
19. Perform an undo.
20. Verify the painted area was cleared.
21. Perform a redo.
22. Verify the painted area was restored.
23. Perform an undo.
24. Select the Rectangle tool.
25. Draw a rectangle on the Icon Preview.
26. Perform an undo.
27. Verify the rectangle was cleared.
28. Perfrom a redo.
29. Verify the rectangle was restored.
30. Perform an undo.
31. Select the Filled Rectangle tool.
32. Draw a rectangle on the Icon Preview.
33. Perform an undo.
34. Verify the rectangle was cleared.
35. Perfrom a redo.
36. Verify the rectangle was restored.
37. Perform an undo.
38. Select the elipse tool.
39. Draw an elipse on the Icon Preview.
40. Perform an undo.
41. Verify the elipse was cleared.
42. Perfrom a redo.
43. Verify the elipse was restored.
44. Perform an undo.
45. Select the Filled Elipse tool.
46. Draw an elipse on the Icon Preview.
47. Perform an undo.
48. Verify the elipse was cleared.
49. Perfrom a redo.
50. Verify the elipse was restored.
51. Perform an undo.
52. Select the Eraser tool.
53. Erase parts of the colored boxes in the icon using a single click and drag action.
54. Perform an undo.
55. Verify the erased parts were restored.
56. Perform a redo.
57. Verify the previously erased parts were removed again.
58. Perform an undo.
59. Select the Text tool.
60. Click in the bottom half of the icon and type "asd".
61. Click in another place in the Icon Preview and type "zxc".
62. Click in another place in the Icon Preview and do not type anything.
63. Click outside of the Icon Preview to finalize the text.
64. Perform an undo.
65. Verify the "zxc" text was removed. The "asd" should remain.
66. Perform an undo.
67. Verify the "asd" text was removed.
68. Perform a redo.
69. Verify the "asd" text was restored.
70. Perform a redo.
71. Verify the "zxc" text was restored.
72. Verify the Redo item in the Edit menu is disabled.
73. Perform two undos.
74. Select the Move tool.
75. Drag the color boxes to the bottom of the icon.
76. Perform an undo.
77. Verify the color boxes were returned to the top of the icon.
78. Perform a redo.
79. Verify the color boxes were moved to the bottom of the icon.
80. Perform an undo.
81. Select the Colors layer.
82. Click the Horizontal Flip button.
83. Perform an undo.
84. Verify the color boxes were returned to the original order.
85. Perform a redo.
86. Verify the color boxes were flipped again.
87. Perform an undo.
88. Click the Clockwise Rotate button.
89. Perform an undo.
90. Verify the color boxes were returned to their original location.
91. Perform a redo.
92. Verify the color boxes were rotated again.
93. Close the Icon Editor, discarding any changes.

# Cleanup

1. If necessary, click "Cancel" to close the Icon Editor, discarding any changes.
2. Close the VI Template.vi, discarding any changes.
