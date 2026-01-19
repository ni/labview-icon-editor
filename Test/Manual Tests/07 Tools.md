# Scope
This procedure is used to verify the functionality of the tools on the Icon Editor.

This procedure was derived from the following NI tests:
- 1692480: Tools test
- 1692488: CTRL and CTRL-Shift actions

Unless otherwise stated, each section of the Main may be ran independently of the other sections. The Setup and Cleanup must be performed.

# Setup
1. Open a new VI.
2. Double-click on the icon to open the Icon Editor.
3. Under the Layers tab, delete all layers.
4. Set the Line Color to black (text).
5. Set the Fill Color to red (Thermometer Fill).

# Main
## 1. Pencil
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

## 2. Line
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

## 3. Fill
1. Using the Line tool, draw a black line from the top-left corner to the bottom-right corner and a second line from the top-right corner to the bottom-left corner.

**NOTE:** This is used to create four areas that can be filled and create a Tool layer.

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

## 4. Dropper
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
30. Delete the Fill layer.

## 5. Rectangle
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

## 6. Filled Rectangle
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

## 7. Ellipse
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

## 8. Filled Ellipse
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

## 9. Eraser
1. Double-click the Filled Rectangle tool to fill the icon.
2. Click on the Eraser tool.
3. Move the cursor to near the middle of the icon preview.
4. Left click.
5. Verify the pixel the cursor was over is erased.
6. Move the cursor to another pixel in the icon preview.
7. Right click.
8. Verify the pixel the cursor was over is erased.
9. Move the cursor to the top-left corner of the icon preview.
10. Left click and drag to the bottom-right corner of the icon preview. Release the mouse button.
11. Verify the pixels the cursor passed over were erased.
12. Delete the Filled layer.

## 10. Text
1. 

# Cleanup
1. Click "Cancel" to close the Icon Editor, discarding any changes.
2. Close the Icon Editor Manual Tests project and any associated files, discarding any changes.