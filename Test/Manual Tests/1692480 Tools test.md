Make sure that every single tool of the icon editor is working accordingly to its nature.

During switching through the tools change also the edge and fill color and check that these changes are considered accordingly.
Also ensure that the mouse cursor updates appropriately when hovering over the icon.
Make sure that the following tool actions can be canceled by pressing ESC on your keyboard:
    Line, Ellipse, Filled Ellipse, Rectangle, Filled Rectangle, Move and Select
Start drawing a line (or any of the other tools mentioned above) and press the ESC button. The drawing action must be discarded.
A double click on the selection tool must select the entire icon
    hit the delete key and make sure that all user layers are deleted -> Switch to the layers tab to check that the user layers section is empty and all buttons (except for the new layer button) are disabled and grayed out.
Draw something and/or drop a few glyphs, select the area and move it around. The selection should stick with the original selected area while following the mouse pointer.
Double click the text tool -> the icon editor properties dialog must open
Double click the rectangle tool -> the icon must get a border in the edge color
Double click the filled rectangle tool -> the icon must get a border in the edge color and the inside must get filled with the fill color
Every drawing tool may be either used with the right or the left mouse button.
    The left mouse button uses always the colors as displayed in the UI.
    If the right mouse button is used, the secondary color swap internally with the primary color.
    Special case: Draw some points with the pencil (left and/or right mouse button). Hoover over an most recently drawn point and press the left mouse button. If the current pixel value is the secondary color, the pixel value must change to the primary color (and vice versa of course). Release the mouse button and hover over another most recently drawn pixel that has either the value of the primary or secondary color. Press the left mouse button and hold it pressed. Move the mouse around and make sure that the first pixel changes its value to the opposite color AND that all further drawn pixels do have the same color regardless of their original color.
