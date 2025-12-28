1. Navigate to vi.lib\LabVIEW Icon API\Examples. Please repeat the step where you are required to launch the icon editor to compare the glyph from the picture control with the glyph that the icon editor actually displays at least once to ensure that all information is preserved! The reason being here is that this should ensure that the Icon Editor doesn't change the settings of the glyph of the qualified invoker of the icon editor.
2. Run Basic Generate LV Icon Text Layer.vi and ensure that the displayed glyph in the picture control on the front panel has
    1. A black border
    2. A black horizontal line at the top quarter of the glyph
    3. A text within this box that says 'Example'
    4. A green circle in the center of the bottom part (underneath the black horizonatl line)
3. Run Basic Generate LV Icon Template Layer.vi andensure that the displayed glyph in the picture control on the front panel has
    1. A black border
    2. A black horizontal line at the top quarter of the glyph
    3. A green circle in the center of the bottom part (underneath the black horizonatl line)
4. A text that says 'Example' which is on top of the green circle (the text has to be centered within the black). Run Modify VI Icon Template Layer.vi. Invoke the icon editor on the created VI and make sure that:
    1. Templates tab: the propper template is selected
    2. Icon Text tab: "Example" appears in the first line
    3. Layers tab: there is one user layer in the list (green circle)
5. Run Modify VI Icon Text Layer.vi1. Invoke the icon editor on the created VI and make sure that:
    1. Templates tab: Click in the Category listbox on 'LabVIEW Icon API'' and make sure that this one template is selected
    2. Icon Text tab: "Example" appears in the first line
    3. Layers tab: there is two user layers in the list (green circle and black border)
6. Run Advanced Generate LV Icon.vi1. Invoke the icon editor on the created library (right click in the LabVIEW project on the library item -> Properties) and ensure that:
    1. Templates tab: Click in the Category listbox on 'LabVIEW Icon API'' and make sure that this one template is selected
    2. Icon Text tab: "Example" appears in the first line
    3. Layers tab: no user layers are in the list2. Invoke the icon editor on the created VI and ensure that:
        1. Templates tab: nothing is selected
        2. Icon Text tab: no text
        3. Layers tab: 3 user layers
            1. one that is called NI_Library (which has to match exactly the icon of the owning library)
            2. one that is a black border
            3. one that is a green circle
7. Open the Blockdiagram of Basic Generate LV Icon Text Layer.vi and compare it to the displayed glyph on the FP
8. Drop the following VI Launch Icon Editor.vi on the blockdiagram (can be found in vi.lib\LabVIEW Icon API)
9. Wire the Icon.lvclass out wire to the Icon in input of the Launch Icon Editor.vi
10. Run Basic Generate LV Icon Text Layer.vi and ensure that the icon data is launched and that all the information (text, template, user layers) is preserved
