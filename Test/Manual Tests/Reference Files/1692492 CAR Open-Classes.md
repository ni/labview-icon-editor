NOTE: You can remove the above tag once the related CAR is closed or fixed or deferred.This test is used to ensure that class members are treated correctly.
Make sure that you relaunch LabVIEW and that the option show numbers (1-9) in the VI icon is enabled in the options before you run this test.

1. Create a class and drop some controls
2. Create a new VI on the class and make sure that this VI has a NI_Library layer as well as a VI Icon layer. Create a control and check the same things.
3. Cancel the IE (Icon Editor)
4. Create some data access member VIs on the class. Make sure that each of them has a VI Icon layer (white with black border), a Read/Write layer (glasses or pen) and an NI_Library layer. Customize the icon a little bit.
5. Hit OK.
6. Change the icon of the class itself
7. Hit OK when you get ask to update each member of the class.
8. Check every member and make sure that the NI_Library layer got updated
9. Create another class
10. Inherit from the previously created class
11. Launch the icon editor on the class (properties dialog - edit icon...), delete the current icon and drop a single element somewhere
12. Create an override VI and make sure that the layer information is appropriate (the NI_Library layer has to be a merge of both class icons)
13. Change the icon of the first created class. Check if every member of both classes got updated (Each member still has to have its individual layer information though in the IE, a merged icon is not acceptable!)
14. Create new VIs and data access members in both classes and make sure that the layer information is correctRepeat the steps where the icon is modified at least 5 times and check if the members are updated appropriately (it is not enough to make only a visual inspection of the icon itself - please launch the IE on every member and check the layer information!)

Link to NITest TPS: http://force.natinst.com:8000/pls/nic3/ni_swt_general.show_test?p_test_id=121934
