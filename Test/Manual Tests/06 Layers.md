# Scope
This procedure is used to verify the functionality of the Layers tab on the Icon Editor.

This procedure was derived from the following NI tests:
- 1692496: Layers Tab


# Setup
1. Open the Icon Editor Manual Tests project.
2. Open Many Layers.vi

# Main
1. Double-click on the icon to open the Icon Editor.
2. Select the Layers tab.
3. Verify the following layers are in order. The User Layers scroll bar will be required as only 4 user layers are visible at a time.
    - document
    - file2
    - home2
    - monitor_angled
    - window_16
    - Block Box
4. Select the Black Box layer. Verify the Move Up button is enabled.
5. Click the Move Up button to move the Black Box layer.
6. Verify the Black Box layer is now above the window_16 layer.
7. Verify the Move Up and Move Down buttons are enabled.
8. Click the Move Down button.
9. Verify the Black Box layer is now below the window_16 layer.
10. Verify the Move Down button is disabled.
11. Click the Move Up button 5 times to move the Black Box layer to the top.
12. Verify the Black Box layer is now the top layer.
13. Verify the Move Up button is disabled.
14. Verify the icon image is all black.
15. Click the visible button associated with the Black Box layer.
16. Verify the icon image shows all of the other layers (ie the icon is no longer all black).
17. Click the visible button associated with the Black Box layer.
18. Verify the icon image is all black.
19. Change the opacity of the Black Box layer to ~50%.
20. Verify the icon image shows all of the other layers in a muted tint.
21. Select the Black Box layer.
22. Click the Remove Layer button.
23. Verify the Black Box layer is no longer in the list of layers.
24. Verify the icon image shows all of the other layers.
25. Click the Add Layer button.
26. Verify an empty layer was created at the top of the User Layers list.
27. Name the new layer "New Layer".
28. Select New Layer.
29. Click the Move Down button.
30. Verify New Layer was moved below the document layer.
31. Select the Layers->Delete Select Layers menu item.
32. Verify New Layer was removed.
33. Select the Layers->Create New Layer menu item.
34. Verify an empty layer was created at the top of the User Layers list.
35. Select the document and file2 layers.
36. Select the Layers->Merge Selected Layers menu item.
37. Verify the two layers were merged into a single layer named "Merged Layers".
38. Select the Layers->Merge All User Layers menu item.
39. Verify the all layers were merged into a single layer named "Merged Layers".

# Cleanup
1. Click "Cancel" to close the Icon Editor, discarding any changes.
2. Close the Icon Editor Manual Tests project and any associated files, discarding any changes.