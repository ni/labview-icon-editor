# Tools

## Scope

This procedure is used to verify the functionality of the tools on the Icon Editor.

This procedure was derived from the following NI tests:

    - 1692480: Tools test
    - 1692488: CTRL and CTRL-Shift actions

Unless otherwise stated, each section of the Main may be ran independently of the other sections. The Setup and Cleanup must be performed.

## Setup

1. Open a new VI.
2. Double-click on the icon to open the Icon Editor.
3. Under the Layers tab, delete all layers.
4. Set the Line Color to black (text).
5. Set the Fill Color to red (Thermometer Fill).

## Main

### 1. Pencil

1. Click on the Pencil tool.
2. Move the cursor to the top-left corner of the icon preview.
3. Verify the cursor is a pencil.
4. Left click and drag to the bottom-right corner of the icon preview. Release the mouse button.
5. Verify a black line, following the path you used, was drawn.
6. Verify a new User Layer was created named "Tool" and showing the line drawn.
7. Move the cursor to the top-right corner of the icon preview.
8. Right click and drag to the bottom-left corner of the icon preview. Release the mouse button.
9. Verify a red line, following the path you used, was drawn.
10. Verify the red line was added to the Tool layer.
11. Set the Line Color to green (LED On) and the Fill Color to blue (Slide Fill).
12. Move the cursor to the top-left corner of the icon preview.
13. Left click and drag to the bottom-left corner of the icon preview. Release the mouse button.
14. Verify a green line, following the path you used, was drawn.
15. Verify the green line was added to the Tool layer.
16. Move the cursor to the top-right corner of the icon preview.
17. Right click and drag to the bottom-right corner of the icon preview. Release the mouse button.
18. Verify a blue line, following the path you used, was drawn.
19. Verify the blue line was added to the Tool layer.
20. Move the cursor to the top-left corner of the icon preview.
21. Left click and drag to the bottom-right corner of the icon preview. Release the mouse button.
22. Verify a blue line, following the path you used, was drawn.
23. Move the cursor to the top-right corner of the icon preview.
24. Right click and drag to the bottom-left corner of the icon preview. Release the mouse button.
25. Verify a green line, following the path you used, was drawn.
26. Set the Line Color to black (text) and the Fill Color to red (Thermometer Fill).
27. Delete the Tool layer.
28. Move the cursor to the top-left corner of the icon preview.
29. Left click and drag to the bottom-right corner of the icon preview. Do NOT release the mouse button.
30. Verify a black line, following the path you used, is being drawn.
31. Press the ESC button to cancel the operation.
32. Release the mouse button.
33. Verify the line was cleared.
34. Verify a new layer was not created.

### 2. Line

1. Click on the Line tool.
2. Move the cursor to the top-left corner of the icon preview.
3. Verify the cursor is a crosshair.
4. Left click and drag to the bottom-right corner of the icon preview. Release the mouse button.
5. Verify a straight black line was drawn connecting the corners.
6. Verify a new User Layer was created named "Tool" and showing the line drawn.
7. Move the cursor to the top-right corner of the icon preview.
8. Right click and drag to the bottom-left corner of the icon preview. Release the mouse button.
9. Verify a straight red line was drawn connecting the corners.
10. Verify the red line was added to the Tool layer.
11. Set the Line Color to green (LED On) and the Fill Color to blue (Slide Fill).
12. Move the cursor to the top-left corner of the icon preview.
13. Left click and drag to the bottom-left corner of the icon preview. Release the mouse button.
14. Verify a green line was drawn connecting the corners.
15. Verify the green line was added to the Tool layer.
16. Move the cursor to the top-right corner of the icon preview.
17. Right click and drag to the bottom-right corner of the icon preview. Release the mouse button.
18. Verify a blue line was drawn connecting the corners.
19. Verify the blue line was added to the Tool layer.
20. Set the Line Color to black (text) and the Fill Color to red (Thermometer Fill).
21. Delete the Tool layer.
22. Move the cursor to the top-left corner of the icon preview.
23. Left click and drag to the bottom-right corner of the icon preview. Do NOT release the mouse button.
24. Verify a straight black line is being drawn.
25. Press the ESC button to cancel the operation.
26. Release the mouse button.
27. Verify the line was cleared.
28. Verify a new layer was not created.

### 3. Fill

1. Using the Line tool, draw a black line from the top-left corner to the bottom-right corner and a second line from the top-right corner to the bottom-left corner.  **NOTE:** This is used to create four areas that can be filled and create a Tool layer.

2. Click on the Fill tool.
3. Move the mouse into the top area of the icon preview.
4. Verify the cursor is the fill icon.
5. Left click.
6. Verify the top section of the icon is black.
7. Verify the Tool layer is now labeled "Fill" and has the proper area filled.
8. Move the mouse into the bottom area of the icon preview.
9. Right click.
10. Verify the bottom area is red.
11. Verify the Fill layer has the bottom area red.
12. Set the Line Color to green (LED On) and the Fill Color to blue (Slide Fill).
13. Move the mouse into the left area of the icon preview.
14. Left click.
15. Verify the left area of the icon is green.
16. Move the mouse into the right area of the icon preview.
17. Right click.
18. Verify the right area of the icon is blue.

**NOTE:** No cleanup is required here as this setup will be used for the Dropper tool.

### 4. Dropper

**NOTE:** The Fill tool test must be completed to do this test.

1. Click on the Dropper tool.
2. Move the mouse into the bottom area of the icon preview.
3. Verify the cursor is the dropper icon.
4. Left click.
5. Verify the Line Color is now red.
6. Move the mouse into the top area of the icon preview.
7. Right click.
8. Verify the Fill Color is now black.
9. Click on the Pencil tool.
10. Move the mouse into the left area of the icon preview.
11. Verify the cursor is the pencil icon.
12. Hold the CTRL key.
13. Verify the cursor is the dropper icon.
14. Left click.
15. Release the CTRL key.
16. Verify the Line Color is now green.
17. Move the mouse into the right area of the icon preview.
18. Hold the CTRL key.
19. Verify the cursor is the dropper icon.
20. Right click.
21. Release the CTRL key.
22. Verify the Fill Color is now blue.
23. Move the mouse into the bottom area of the icon preview.
24. Hold the CTRL and Shift keys.
25. Verify the cursor is the dropper icon.
26. Left click.
27. Release the CTRL and Shift keys.
28. Verify the Fill Color is now red.
29. Set the Line Color to black (text).
30. Repeat steps 9 through 29 for each of the following tools:
    - Line
    - Paint
    - Rectangle
    - Filled Rectangle
    - Ellipse
    - Filled Ellipse
    - Eraser
    - Text
    - Select
    - Move
31. Delete the Fill layer.

### 5. Rectangle

1. Click on the Rectangle tool.
2. Move the cursor to the top-left corner of the icon preview.
3. Verify the cursor is a crosshair.
4. Left click and drag to the bottom-right corner of the icon preview. Release the mouse button.
5. Verify a black rectangle was drawn outlining the icon.
6. Verify a new User Layer was created named "Tool" and showing the rectangle drawn.
7. Delete the Tool layer.
8. Move the cursor to the top-left corner of the icon preview.
9. Right click and drag to the bottom-right corner of the icon preview. Release the mouse button.
10. Verify a red rectangle was drawn outlining the icon.
11. Verify a new User Layer was created named "Tool" and showing the rectangle drawn.
12. Delete the Tool layer.
13. Set the Line Color to green (LED On) and the Fill Color to blue (Slide Fill).
14. Move the cursor to the top-left corner of the icon preview inside of the red rectangle.
15. Left click and drag to the bottom-right corner of the icon preview. Release the mouse button.
16. Verify a green rectangle was drawn outlining the icon.
17. Verify a new User Layer was created named "Tool" and showing the rectangle drawn.
18. Delete the Tool layer.
19. Move the cursor to the top-left corner of the icon preview.
20. Right click and drag to the bottom-right corner of the icon preview. Release the mouse button.
21. Verify a blue rectangle was drawn outlining the icon.
22. Verify a new User Layer was created named "Tool" and showing the rectangle drawn.
23. Delete the Tool layer.
24. Set the Line Color to black (text) and the Fill Color to red (Thermometer Fill).
25. Move the cursor to the top-left corner of the icon preview.
26. Left click and drag to the bottom-right corner of the icon preview. Do NOT release the mouse button.
27. Verify a black rectangle is being drawn.
28. Press the ESC button to cancel the operation.
29. Release the mouse button.
30. Verify the rectangle was cleared.
31. Verify a new layer was not created.
32. Double-click on the Rectangle tool.
33. Verify a black rectangle outlining the icon preview was created.
34. Verify a new layer named "Border" was created.
35. Delete the Border layer.

### 6. Filled Rectangle

1. Click on the Filled Rectangle tool.
2. Move the cursor to the top-left corner of the icon preview.
3. Verify the cursor is a crosshair.
4. Left click and drag to the bottom-right corner of the icon preview. Release the mouse button.
5. Verify a black rectangle outline with a red fill was drawn.
6. Verify a new User Layer was created named "Tool" and showing the rectangle drawn.
7. Delete the Tool layer.
8. Move the cursor to the top-left corner of the icon preview.
9. Right click and drag to the bottom-right corner of the icon preview. Release the mouse button.
10. Verify a red rectangle outline with a black fill was drawn.
11. Verify a new User Layer was created named "Tool" and showing the rectangle drawn.
12. Delete the Tool layer.
13. Set the Line Color to green (LED On) and the Fill Color to blue (Slide Fill).
14. Move the cursor to the top-left corner of the icon preview.
15. Left click and drag to the bottom-right corner of the icon preview. Release the mouse button.
16. Verify a green rectangle with a blue fill was drawn.
17. Verify a new User Layer was created named "Tool" and showing the rectangle drawn.
18. Delete the Tool layer.
19. Move the cursor to the top-left corner of the icon preview.
20. Right click and drag to the bottom-right corner of the icon preview. Release the mouse button.
21. Verify a blue rectangle with a green fill was drawn.
22. Verify a new User Layer was created named "Tool" and showing the rectangle drawn.
23. Delete the Tool layer.
24. Set the Line Color to black (text) and the Fill Color to red (Thermometer Fill).
25. Move the cursor to the top-left corner of the icon preview.
26. Left click and drag to the bottom-right corner of the icon preview. Do NOT release the mouse button.
27. Verify a black rectangle with a red fill is being drawn.
28. Press the ESC button to cancel the operation.
29. Release the mouse button.
30. Verify the rectangle was cleared.
31. Verify a new layer was not created.
32. Double-click on the Filled Rectangle tool.
33. Verify a black rectangle filled with red outlining the icon preview was created.
34. Verify a new layer named "Filled" was created.
35. Delete the Filled layer.

### 7. Ellipse

1. Click on the Ellipse tool.
2. Move the cursor to the top-left corner of the icon preview.
3. Verify the cursor is a crosshair.
4. Left click and drag to the bottom-right corner of the icon preview. Release the mouse button.
5. Verify a black circle was drawn inscribing the icon.
6. Verify a new User Layer was created named "Tool" and showing the ellipse drawn.
7. Delete the Tool layer.
8. Move the cursor to the top-left corner of the icon preview.
9. Right click and drag to the bottom-right corner of the icon preview. Release the mouse button.
10. Verify a red circle was drawn inscribing the icon.
11. Verify a new User Layer was created named "Tool" and showing the ellipse drawn.
12. Delete the Tool layer.
13. Set the Line Color to green (LED On) and the Fill Color to blue (Slide Fill).
14. Move the cursor to the top-left corner of the icon preview.
15. Left click and drag to the bottom-right corner of the icon preview. Release the mouse button.
16. Verify a green circle was drawn inscribing the icon.
17. Verify a new User Layer was created named "Tool" and showing the ellipse drawn.
18. Delete the Tool layer.
19. Move the cursor to the top-left corner of the icon preview.
20. Right click and drag to the bottom-right corner of the icon preview. Release the mouse button.
21. Verify a blue circle was drawn inscribing the icon.
22. Verify a new User Layer was created named "Tool" and showing the ellipse drawn.
23. Delete the Tool layer.
24. Set the Line Color to black (text) and the Fill Color to red (Thermometer Fill).
25. Move the cursor to the top-left corner of the icon preview.
26. Left click and drag to the bottom-right corner of the icon preview. Do NOT release the mouse button.
27. Verify a black circle is being drawn.
28. Press the ESC button to cancel the operation.
29. Release the mouse button.
30. Verify the ellipse was cleared.
31. Verify a new layer was not created.

### 8. Filled Ellipse

1. Click on the Filled Ellipse tool.
2. Move the cursor to the top-left corner of the icon preview.
3. Verify the cursor is a crosshair.
4. Left click and drag to the bottom-right corner of the icon preview. Release the mouse button.
5. Verify a black circle outline with a red fill was drawn.
6. Verify a new User Layer was created named "Tool" and showing the ellipse drawn.
7. Delete the Tool layer.
8. Move the cursor to the top-left corner of the icon preview.
9. Right click and drag to the bottom-right corner of the icon preview. Release the mouse button.
10. Verify a red circle outline with a black fill was drawn.
11. Verify a new User Layer was created named "Tool" and showing the ellipse drawn.
12. Delete the Tool layer.
13. Set the Line Color to green (LED On) and the Fill Color to blue (Slide Fill).
14. Move the cursor to the top-left corner of the icon preview.
15. Left click and drag to the bottom-right corner of the icon preview. Release the mouse button.
16. Verify a green circle with a blue fill was drawn.
17. Verify a new User Layer was created named "Tool" and showing the ellipse drawn.
18. Delete the Tool layer.
19. Move the cursor to the top-left corner of the icon preview.
20. Right click and drag to the bottom-right corner of the icon preview. Release the mouse button.
21. Verify a blue circle with a green fill was drawn.
22. Verify a new User Layer was created named "Tool" and showing the ellipse drawn.
23. Delete the Tool layer.
24. Set the Line Color to black (text) and the Fill Color to red (Thermometer Fill).
25. Move the cursor to the top-left corner of the icon preview.
26. Left click and drag to the bottom-right corner of the icon preview. Do NOT release the mouse button.
27. Verify a black circle with a red fill is being drawn.
28. Press the ESC button to cancel the operation.
29. Release the mouse button.
30. Verify the ellipse was cleared.
31. Verify a new layer was not created.

### 9. Eraser

1. Double-click the Filled Rectangle tool to fill the icon.
2. Click on the Eraser tool.
3. Move the cursor to near the middle of the icon preview.
4. Verify the cursor is a circle.
5. Left click.
6. Verify the pixel the cursor was over is erased.
7. Move the cursor to another pixel in the icon preview.
8. Right click.
9. Verify the pixel the cursor was over is erased.
10. Move the cursor to the top-left corner of the icon preview.
11. Left click and drag to the bottom-right corner of the icon preview. Release the mouse button.
12. Verify the pixels the cursor passed over were erased.
13. Delete the Filled layer.

### 10. Text

**NOTE:** It is recommended to use a keyboard layout that has the AltGr key. For those using an "US" keyboard layout, it is recommended to use the "United States-International" keyboard layout. This layout will make the right Alt key be AltGR.

1. Double-click the Text tool.
2. Verify the Icon Editor Properties window is opened up with the Text Tool category selected.
3. Ensure the following settings:
    - Font = Small Fonts
    - Alignment = center
    - Size = 9
4. Click OK to save the settings and close the dialog.
5. Click on the Text tool.
6. Move the cursor to near the middle of the icon preview.
7. Verify the cursor is I shaped.
8. Left click.
9. Verify a small carrot was placed in the icon preview where you clicked.
10. Type "asdf".
11. Verify "asdf" was placed in the icon preview.
12. Verify the text is black and centered around where you clicked.
13. Verify the small carrot is at the end of the text.
14. Left click to finalize the text entry.
15. Verify a new User Layer was created named "Tool" and showing the text entered.
16. Remove the Tool layer.
17. Set the Line Color to green (LED On).
18. Move the cursor to near the middle of the icon preview.
19. Left click.
20. Verify a small carrot was placed in the icon preview where you clicked.
21. Type "asdf".
22. Verify "asdf" was placed in the icon preview.
23. Verify the text is green and centered around where you clicked.
24. Verify the small carrot is at the end of the text.
25. Left click to finalize the text entry.
26. Verify a new User Layer was created named "Tool" and showing the text entered.
27. Remove the Tool layer.
28. Set the Line Color to black (text).
29. Move the cursor to near the middle of the icon preview.
30. Left click.
31. Type "asdf".
32. Press the ESC button to cancel the operation.
33. Verify the text was cleared.
34. Verify a new layer was not created.
35. Move the cursor to near the middle of the icon preview.
36. Left click.
37. Type a character that requires the AltGr key. If using the "United States-International" layout, it is recommended to use "µ" (AltGR+m).
38. Verify the character was placed in the icon preview.
39. Press the ESC button to cancel the operation.
40. Double-click the Text tool to open the Icon Editor Properties.
41. Change the Font to LabVIEW Application and click OK.
42. Click in the icon preview and type "asdf".
43. Verify the font of the typed characters has changed.
44. Double-click the Text tool to open the Icon Editor Properties.
45. Change the Font to Small Fonts and the size to 15. Click OK.
46. Click in the icon preview and type "asdf".
47. Verify the font of the typed characters is larger than before.
48. Double-click the Text tool to open the Icon Editor Properties.
49. Change the size to 9 and the alignment to left. Click OK.
50. Click in the icon preview and type "asdf".
51. Verify the typed characters is left aligned to where the mouse was clicked.
52. Double-click the Text tool to open the Icon Editor Properties.
53. Change the alignment to right. Click OK.
54. Click in the icon preview and type "asdf".
55. Verify the typed characters is right aligned to where the mouse was clicked.
56. Double-click the Text tool to open the Icon Editor Properties.
57. Change the alignment to center. Click OK.
58. Remove any created User Layers.

###

## Cleanup

1. Click "Cancel" to close the Icon Editor, discarding any changes.
2. Close the Icon Editor Manual Tests project and any associated files, discarding any changes.
