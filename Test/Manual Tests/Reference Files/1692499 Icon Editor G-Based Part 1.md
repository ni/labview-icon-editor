Ways to launch IE
    IE can be launched for these items : VI. Library, Class, Ctl files, Poly VI.
    IE can be called by either: double clicking on the icon (for VIs,classes,ctl)
    Property page of items.
    Rt click on the icon of item and selecting edit icon.
    Try to launch IE using diff ways if you have extra time. (stress test)

Tool test: (All the steps below should be performed on the Icon of the VI from Icon editor)
    Ensure that the mouse cursor updates appropriately when hovering over the icon. Eg: changes to pen, eraser etc.
    Every drawing tool may be either used with the right or the left mouse button. The left mouse button uses always the colors as displayed in the UI. If the right mouse button is used, the secondary colors swap internally with the primary color.
    Start drawing a line (elipse, rectangle etc) till some extend and then press esc . The drawing must be discarded.
    A double click on the selection tool must select the entire icon. Hit delete key and make sure that all the layers are deleted. Double click the rectangle tool -> the icon must get a border in the edge color.
    Draw something sensible using the IE and do some FFT around with the tool.
    Hold the Ctrl/Ctrl+Shift key to change the mouse cursor to dropper tool. Left mouse click->Edge color selection. Right click-> fill color selection

Population of glyphs and template
The new icon which you designed should now be saved using save as menu item.
Make sure the start folder is Icon Templates/VI. (you can save it in nested folder too). After save make sure that newly created template shows in the template list.
Check if a bin file got created with your template/Glyph name in Icon Template/Glyphs folder.
