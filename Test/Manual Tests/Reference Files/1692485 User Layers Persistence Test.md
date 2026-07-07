The IE is supposed to store by default all user layers, the icon text and the icon template layer information with the invoker. The option in the IE properties dialog 'Layers:Merge layers on commit' must be disabled by default!
Supported invokers are:- VI- CTRL- LVClass- LVLibrary- XControl
Run the following instructions on ALL of the above mentioned invokers!

1. Create a new project
2. Create a new invoker in the project
3. Launch the icon editor on the invoker
    a) VI, Ctrl: double click on the VI icon
    b) other: Properties - Edit Icon
4. Delete the default icon
5. Choose a template
6. Write some text on the icon text tab
7. Drop some glyphs
8. Hit OK. Make sure that the icon has changed
9. Reopen the icon editor on the same invoker
10. Make sure that all layers, the icon text and the icon template are updated appropriately
11. Hit Cancel. Make sure that the icon has not changed
12. Save the invoker
13. Reopen the IE on the same invokerMake sure that all layers, the icon text and the icon template are updated appropriately
14. Hit CancelMake sure that the icon has not changed
15. Close LabVIEW
16. Reopen LabVIEW
17. Reopen the previously saved invoker
18. Launch the IE and make sure that all layers, the icon text and the icon template are updated appropriately

Link to NITest TPS: http://force.natinst.com:8000/pls/nic3/ni_swt_general.show_test?p_test_id=120005
