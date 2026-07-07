1. Make sure that LabVIEW data folder contains an Icon template and Glyphs folder containing multiple icons.
2. Launch Icon editor by double clicking/ Right clicking on the Icon of the VI. Notice Icon editor window opens now.
3. Move to the Glyph tab and template tab and check if it shows all the icons as in the labview data folder.
4. As you click a icon on IE (icon editor), the path should be updated at the bottom of the window.
5. Also try to use the Filter glyphs by keyword text bar to search icons.
6. Check the UI of window on selecting Tools>> Synchronize with Icon Library. Select one/more of the items from list and select ok. Check if the same icon is now available in the glyph/icon template layer.
7. In the Edit menubar is a new option called 'Import glyph from File'.Check that option with various glyphs (download glyphs from the internet, use your own glyphs, etc.)
8. Open the one of the VIs attached to this test in previous version of LV under test. Open IE for each VI and check the settings. Now open the same Vis in LV under test and check all settings in IE are persistent.
9. Drop a glyph from the Glyph tab. Ways to drop and interact with glyphs are:
    Left click on a glyph and hold the mouse button pressed and move it to big preview area. (Notice the glyphs consistently follow the mouse pointer on the drawing area)
    Left click and release immediately.
    Double click on a glyph. It should be dropped to top left hand corner.
10. Save all the work you have done on the IE by saving the items (VI, Ctls, Classes etc) and quit LV. Re-launch LV and check if IE is persistent with all the changes you made in the Items
