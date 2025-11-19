IE launch and properties
    Launch IE and check the preferences from Tools>> Icon editor properties. Check the tab looks similar to below images on the first launch.
    Also check if Tools> List of Glyphs and Icon templates shows a html page with all installed glyphs and icon templates

Layers Tab
    Move to the layers tab in IE now and create multiple layers using + symbol.
    Now drop multiple glyphs from the Glyph tab and check if each layer has got only one glyph on them.
    Change the visibility/ Hidden on of one the Layers and check if the same reflects in the final icon.
    Check if you can delete a layer of icon using the Delete icon.
    If you have additional time, play around with the tools to check for bugs/issues.
    Now check “merge all layers in commit” from tools> icon editor properties as shown above.
    Drop multiple glyphs on the IE which will be present at diff layers in layers tab.
    Select OK to dismiss IE window. Relaunch IE and check in the layers tab that there is only one user defined layer present.

Classes
    Create a class and drop some controls
    Create a new VI on the class and make sure that this VI has a NI_Library layer as well as a VI Icon layer. Create a control and check the same things.
    Hit ok. Notice everything looks proper.
    Now change the icon of class itself from Class property window. Rt click on LVClass > Property.
    Hit OK when you get ask to update each member of the class. Check every member and make sure that the NI_Library layer got updated
    Now inherit a class from the prev built class.. Create a VI to override. Check if the Icon makes proper adjustment. (the NI_Library layer has to be a merge of both class icons)
    Please repeat the above steps (classes section) multiple times to check its consistency.
