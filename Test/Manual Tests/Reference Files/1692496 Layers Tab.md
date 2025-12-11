This test should prove the functionality of the icon layers itself
1) Launch the icon editor on a VI
2) Drop multiple glyphs and make sure that each glyph got its own layer. Also write some text on the text tab and pick a template on the template tab.
3) Use one of the drawing tools and execute multiple drawings (release the mouse in between in order to commit the drawing). Make sure that all the drawings got placed in the same layer
4) Drop another glyph and ensure that this glyph got a new layer assigned
5) Use onf of the drawing tools and make sure that a new layer is created.
6) Select one of the earlier created layers (click on the icon on the layers tab) and start drawing. Ensure that in this case everything is applied on the selected layer
7) Change the opacity of random layers and ensure that the new settings are reflected in the icon. (reset the opacity once the functionality has been verified).
8) Hide random layers and make sure that they are really hidden (un-hide all of them once the functionality has been verified)
9) Select a single layer and use the arrow up/down buttons to change the order. Ensure that the new position of the layer is reflected in the icon accordingly. Move the selected layer all the way to the top as well as all the way to the bottom and ensure that the associated arrow button is disabled and grayed out once the boundaries are reached.
10) Repeat 9 but this time select multiple layers.
11) Use the create new layer and delete layer button and ensure that layers get created/deleted

Link to NITest TPS: http://force.natinst.com:8000/pls/nic3/ni_swt_general.show_test?p_test_id=140272
