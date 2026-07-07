At the very first launch of the IE, make sure that:
    1) The new IE does load without relinking to any VIs. Everything should be compiled. In other words, make sure that now silly dialog is shown that is searching for VIs or Controls.
    2) That the font list is populated accordingly the installed fonts on the system**
    3) The active font is present on the system (if not, the first font in the pull-down list should be active). The alignment has to be set to center and the font size has to be 9
    4) Launch the Icon Editor Properties (menu: Tools), ensure that:
        a) The first item in the list is active
        b) That Merger layers on commit is disabled
        c) That save 3rd party Templates is enabled and that the folder name is '3rd Party'
        d) That the fonts pull-down list is populated accordingly the installed fonts on the system. That the size is set to 9 and the alignment is left
        e) Close the IE and relaunch it. During the first launch everything is initialized and therefore it takes longer than every consecutive launch. Make sure that the launch time on the 2nd and every following launch is little compared to the first launch.
        
**On Windows, you can find the installed fonts here - C:\Windows\Fonts