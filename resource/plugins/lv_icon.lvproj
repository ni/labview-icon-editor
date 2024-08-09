<?xml version='1.0' encoding='UTF-8'?>
<Project Type="Project" LVVersion="13008000">
	<Property Name="NI.LV.All.SaveVersion" Type="Str">Editor version</Property>
	<Item Name="My Computer" Type="My Computer">
		<Property Name="IOScan.Faults" Type="Str"></Property>
		<Property Name="IOScan.NetVarPeriod" Type="UInt">100</Property>
		<Property Name="IOScan.NetWatchdogEnabled" Type="Bool">false</Property>
		<Property Name="IOScan.Period" Type="UInt">10000</Property>
		<Property Name="IOScan.PowerupMode" Type="UInt">0</Property>
		<Property Name="IOScan.Priority" Type="UInt">9</Property>
		<Property Name="IOScan.ReportModeConflict" Type="Bool">true</Property>
		<Property Name="IOScan.StartEngineOnDeploy" Type="Bool">false</Property>
		<Property Name="server.app.propertiesEnabled" Type="Bool">true</Property>
		<Property Name="server.control.propertiesEnabled" Type="Bool">true</Property>
		<Property Name="server.tcp.enabled" Type="Bool">false</Property>
		<Property Name="server.tcp.port" Type="Int">0</Property>
		<Property Name="server.tcp.serviceName" Type="Str">My Computer/VI Server</Property>
		<Property Name="server.tcp.serviceName.default" Type="Str">My Computer/VI Server</Property>
		<Property Name="server.vi.callsEnabled" Type="Bool">true</Property>
		<Property Name="server.vi.propertiesEnabled" Type="Bool">true</Property>
		<Property Name="specify.custom.address" Type="Bool">false</Property>
		<Item Name="API" Type="Folder">
			<Item Name="LabVIEW Icon API.lvlib" Type="Library" URL="/&lt;vilib&gt;/LabVIEW Icon API/LabVIEW Icon API.lvlib"/>
		</Item>
		<Item Name="Classes" Type="Folder">
			<Item Name="Icon Framework.lvclass" Type="LVClass" URL="/&lt;vilib&gt;/LabVIEW Icon API/lv_icon/Classes/Icon Framework/Icon Framework.lvclass"/>
			<Item Name="Icon.lvclass" Type="LVClass" URL="/&lt;vilib&gt;/LabVIEW Icon API/lv_icon/Classes/Icon/Icon.lvclass"/>
			<Item Name="Layer.lvclass" Type="LVClass" URL="/&lt;vilib&gt;/LabVIEW Icon API/lv_icon/Classes/Layer/Layer.lvclass"/>
			<Item Name="Load &amp; Unload.lvclass" Type="LVClass" URL="/&lt;vilib&gt;/LabVIEW Icon API/lv_icon/Classes/Load_Unload/Load &amp; Unload.lvclass"/>
		</Item>
		<Item Name="Flatten Unflatten Packed to UnPacked" Type="Folder">
			<Item Name="Flatten Icon.vi" Type="VI" URL="/&lt;resource&gt;/plugins/NIIconEditor/Miscellaneous/Load Unload/Flatten Icon.vi"/>
			<Item Name="Flatten Layers.vi" Type="VI" URL="/&lt;resource&gt;/plugins/NIIconEditor/Miscellaneous/Load Unload/Flatten Layers.vi"/>
			<Item Name="Unflatten Icon.vi" Type="VI" URL="/&lt;resource&gt;/plugins/NIIconEditor/Miscellaneous/Load Unload/Unflatten Icon.vi"/>
			<Item Name="Unflatten Layers.vi" Type="VI" URL="/&lt;resource&gt;/plugins/NIIconEditor/Miscellaneous/Load Unload/Unflatten Layers.vi"/>
		</Item>
		<Item Name="Other" Type="Folder">
			<Item Name="ApplyLibIconOverlayToVIIcon.vi" Type="VI" URL="/&lt;resource&gt;/plugins/NIIconEditor/Support/ApplyLibIconOverlayToVIIcon.vi"/>
			<Item Name="ChangeRefreshGraphicsState.vi" Type="VI" URL="/&lt;resource&gt;/plugins/NIIconEditor/Miscellaneous/Graphics/ChangeRefreshGraphicsState.vi"/>
			<Item Name="CorruptIconErrorMessage.vi" Type="VI" URL="/&lt;resource&gt;/plugins/NIIconEditor/Miscellaneous/Graphics/CorruptIconErrorMessage.vi"/>
			<Item Name="Create new class icon user layers.vi" Type="VI" URL="/&lt;resource&gt;/plugins/NIIconEditor/Miscellaneous/Create new class icon user layers.vi"/>
			<Item Name="GetOffsetRWIcon.vi" Type="VI" URL="/&lt;resource&gt;/plugins/NIIconEditor/Support/GetOffsetRWIcon.vi"/>
			<Item Name="Keep IE in Memory.vi" Type="VI" URL="/&lt;resource&gt;/plugins/NIIconEditor/Miscellaneous/Icon Editor/Keep IE in Memory.vi"/>
			<Item Name="Launch Icon Editor From String.vi" Type="VI" URL="/&lt;resource&gt;/plugins/NIIconEditor/Launch Icon Editor From String.vi"/>
			<Item Name="LoadGraphics.vi" Type="VI" URL="/&lt;resource&gt;/plugins/NIIconEditor/Miscellaneous/Graphics/LoadGraphics.vi"/>
			<Item Name="lv_icon.lvlib" Type="Library" URL="/&lt;vilib&gt;/LabVIEW Icon API/lv_icon/lv_icon.lvlib"/>
			<Item Name="lv_IconEditor.lvlib" Type="Library" URL="/&lt;resource&gt;/plugins/lv_IconEditor.lvlib"/>
			<Item Name="Post Build Icon Editor PPL.vi" Type="VI" URL="/&lt;resource&gt;/plugins/NIIconEditor/Post Build Icon Editor PPL.vi"/>
			<Item Name="Pre Build Icon Editor PPL.vi" Type="VI" URL="/&lt;resource&gt;/plugins/NIIconEditor/Pre Build Icon Editor PPL.vi"/>
		</Item>
		<Item Name="Pull data from disc.vi" Type="VI" URL="/&lt;resource&gt;/plugins/NIIconEditor/Miscellaneous/Graphics/Pull data from disc.vi"/>
		<Item Name="Dependencies" Type="Dependencies">
			<Item Name="vi.lib" Type="Folder">
				<Item Name="Alignment.ctl" Type="VI" URL="/&lt;vilib&gt;/LabVIEW Icon API/lv_icon/Controls/Alignment.ctl"/>
				<Item Name="Bit-array To Byte-array.vi" Type="VI" URL="/&lt;vilib&gt;/picture/pictutil.llb/Bit-array To Byte-array.vi"/>
				<Item Name="BodyText.ctl" Type="VI" URL="/&lt;vilib&gt;/LabVIEW Icon API/lv_icon/Controls/BodyText.ctl"/>
				<Item Name="BodyTextPosition.ctl" Type="VI" URL="/&lt;vilib&gt;/LabVIEW Icon API/lv_icon/Controls/BodyTextPosition.ctl"/>
				<Item Name="BuildHelpPath.vi" Type="VI" URL="/&lt;vilib&gt;/Utility/error.llb/BuildHelpPath.vi"/>
				<Item Name="Calc Long Word Padded Width.vi" Type="VI" URL="/&lt;vilib&gt;/picture/bmp.llb/Calc Long Word Padded Width.vi"/>
				<Item Name="Check Color Table Size.vi" Type="VI" URL="/&lt;vilib&gt;/picture/jpeg.llb/Check Color Table Size.vi"/>
				<Item Name="Check Data Size.vi" Type="VI" URL="/&lt;vilib&gt;/picture/jpeg.llb/Check Data Size.vi"/>
				<Item Name="Check File Permissions.vi" Type="VI" URL="/&lt;vilib&gt;/picture/jpeg.llb/Check File Permissions.vi"/>
				<Item Name="Check if File or Folder Exists.vi" Type="VI" URL="/&lt;vilib&gt;/Utility/libraryn.llb/Check if File or Folder Exists.vi"/>
				<Item Name="Check Path.vi" Type="VI" URL="/&lt;vilib&gt;/picture/jpeg.llb/Check Path.vi"/>
				<Item Name="Check Special Tags.vi" Type="VI" URL="/&lt;vilib&gt;/Utility/error.llb/Check Special Tags.vi"/>
				<Item Name="Clear Errors.vi" Type="VI" URL="/&lt;vilib&gt;/Utility/error.llb/Clear Errors.vi"/>
				<Item Name="Close Registry Key.vi" Type="VI" URL="/&lt;vilib&gt;/registry/registry.llb/Close Registry Key.vi"/>
				<Item Name="Coerce Bad Rect.vi" Type="VI" URL="/&lt;vilib&gt;/picture/pictutil.llb/Coerce Bad Rect.vi"/>
				<Item Name="Color to RGB.vi" Type="VI" URL="/&lt;vilib&gt;/Utility/colorconv.llb/Color to RGB.vi"/>
				<Item Name="Compare Src And Dst Simple.vi" Type="VI" URL="/&lt;vilib&gt;/Utility/libraryn.llb/Compare Src And Dst Simple.vi"/>
				<Item Name="Compare Two Paths.vi" Type="VI" URL="/&lt;vilib&gt;/Utility/libraryn.llb/Compare Two Paths.vi"/>
				<Item Name="compatOverwrite.vi" Type="VI" URL="/&lt;vilib&gt;/_oldvers/_oldvers.llb/compatOverwrite.vi"/>
				<Item Name="Convert property node font to graphics font.vi" Type="VI" URL="/&lt;vilib&gt;/Utility/error.llb/Convert property node font to graphics font.vi"/>
				<Item Name="Create Directory Recursive.vi" Type="VI" URL="/&lt;vilib&gt;/Utility/libraryn.llb/Create Directory Recursive.vi"/>
				<Item Name="Create Mask By Alpha.vi" Type="VI" URL="/&lt;vilib&gt;/picture/picture.llb/Create Mask By Alpha.vi"/>
				<Item Name="Create Mask.vi" Type="VI" URL="/&lt;vilib&gt;/picture/pictutil.llb/Create Mask.vi"/>
				<Item Name="Delete Directory Recursive.vi" Type="VI" URL="/&lt;vilib&gt;/Utility/libraryn.llb/Delete Directory Recursive.vi"/>
				<Item Name="Delete From VI Library.vi" Type="VI" URL="/&lt;vilib&gt;/Utility/libraryn.llb/Delete From VI Library.vi"/>
				<Item Name="Details Display Dialog.vi" Type="VI" URL="/&lt;vilib&gt;/Utility/error.llb/Details Display Dialog.vi"/>
				<Item Name="Dflt Data Dir.vi" Type="VI" URL="/&lt;vilib&gt;/Utility/file.llb/Dflt Data Dir.vi"/>
				<Item Name="DialogType.ctl" Type="VI" URL="/&lt;vilib&gt;/Utility/error.llb/DialogType.ctl"/>
				<Item Name="DialogTypeEnum.ctl" Type="VI" URL="/&lt;vilib&gt;/Utility/error.llb/DialogTypeEnum.ctl"/>
				<Item Name="Directory of Top Level VI.vi" Type="VI" URL="/&lt;vilib&gt;/picture/jpeg.llb/Directory of Top Level VI.vi"/>
				<Item Name="Draw 1-Bit Pixmap.vi" Type="VI" URL="/&lt;vilib&gt;/picture/picture.llb/Draw 1-Bit Pixmap.vi"/>
				<Item Name="Draw 4-Bit Pixmap.vi" Type="VI" URL="/&lt;vilib&gt;/picture/picture.llb/Draw 4-Bit Pixmap.vi"/>
				<Item Name="Draw 8-Bit Pixmap.vi" Type="VI" URL="/&lt;vilib&gt;/picture/picture.llb/Draw 8-Bit Pixmap.vi"/>
				<Item Name="Draw Flattened Pixmap.vi" Type="VI" URL="/&lt;vilib&gt;/picture/picture.llb/Draw Flattened Pixmap.vi"/>
				<Item Name="Draw Line.vi" Type="VI" URL="/&lt;vilib&gt;/picture/picture.llb/Draw Line.vi"/>
				<Item Name="Draw Oval.vi" Type="VI" URL="/&lt;vilib&gt;/picture/picture.llb/Draw Oval.vi"/>
				<Item Name="Draw Point.vi" Type="VI" URL="/&lt;vilib&gt;/picture/picture.llb/Draw Point.vi"/>
				<Item Name="Draw Rect.vi" Type="VI" URL="/&lt;vilib&gt;/picture/picture.llb/Draw Rect.vi"/>
				<Item Name="Draw Text at Point.vi" Type="VI" URL="/&lt;vilib&gt;/picture/picture.llb/Draw Text at Point.vi"/>
				<Item Name="Draw Text in Rect.vi" Type="VI" URL="/&lt;vilib&gt;/picture/picture.llb/Draw Text in Rect.vi"/>
				<Item Name="Draw True-Color Pixmap.vi" Type="VI" URL="/&lt;vilib&gt;/picture/picture.llb/Draw True-Color Pixmap.vi"/>
				<Item Name="Draw Unflattened Pixmap.vi" Type="VI" URL="/&lt;vilib&gt;/picture/picture.llb/Draw Unflattened Pixmap.vi"/>
				<Item Name="Empty Picture" Type="VI" URL="/&lt;vilib&gt;/picture/picture.llb/Empty Picture"/>
				<Item Name="Enum Registry Values Simple.vi" Type="VI" URL="/&lt;vilib&gt;/registry/registry.llb/Enum Registry Values Simple.vi"/>
				<Item Name="Enum Registry Values.vi" Type="VI" URL="/&lt;vilib&gt;/registry/registry.llb/Enum Registry Values.vi"/>
				<Item Name="Error Cluster From Error Code.vi" Type="VI" URL="/&lt;vilib&gt;/Utility/error.llb/Error Cluster From Error Code.vi"/>
				<Item Name="Error Code Database.vi" Type="VI" URL="/&lt;vilib&gt;/Utility/error.llb/Error Code Database.vi"/>
				<Item Name="ErrWarn.ctl" Type="VI" URL="/&lt;vilib&gt;/Utility/error.llb/ErrWarn.ctl"/>
				<Item Name="eventvkey.ctl" Type="VI" URL="/&lt;vilib&gt;/event_ctls.llb/eventvkey.ctl"/>
				<Item Name="ex_CorrectErrorChain.vi" Type="VI" URL="/&lt;vilib&gt;/express/express shared/ex_CorrectErrorChain.vi"/>
				<Item Name="Find Tag.vi" Type="VI" URL="/&lt;vilib&gt;/Utility/error.llb/Find Tag.vi"/>
				<Item Name="FixBadRect.vi" Type="VI" URL="/&lt;vilib&gt;/picture/pictutil.llb/FixBadRect.vi"/>
				<Item Name="Flatten Pixmap.vi" Type="VI" URL="/&lt;vilib&gt;/picture/pixmap.llb/Flatten Pixmap.vi"/>
				<Item Name="Flip and Pad for Picture Control.vi" Type="VI" URL="/&lt;vilib&gt;/picture/bmp.llb/Flip and Pad for Picture Control.vi"/>
				<Item Name="Font.ctl" Type="VI" URL="/&lt;vilib&gt;/LabVIEW Icon API/lv_icon/Controls/Font.ctl"/>
				<Item Name="Format Message String.vi" Type="VI" URL="/&lt;vilib&gt;/Utility/error.llb/Format Message String.vi"/>
				<Item Name="General Error Handler CORE.vi" Type="VI" URL="/&lt;vilib&gt;/Utility/error.llb/General Error Handler CORE.vi"/>
				<Item Name="General Error Handler.vi" Type="VI" URL="/&lt;vilib&gt;/Utility/error.llb/General Error Handler.vi"/>
				<Item Name="Generate Temporary File Path.vi" Type="VI" URL="/&lt;vilib&gt;/Utility/libraryn.llb/Generate Temporary File Path.vi"/>
				<Item Name="Get File Extension.vi" Type="VI" URL="/&lt;vilib&gt;/Utility/libraryn.llb/Get File Extension.vi"/>
				<Item Name="Get File System Separator.vi" Type="VI" URL="/&lt;vilib&gt;/Utility/sysinfo.llb/Get File System Separator.vi"/>
				<Item Name="Get File System.vi" Type="VI" URL="/&lt;vilib&gt;/Utility/sysinfo.llb/Get File System.vi"/>
				<Item Name="Get Image Subset.vi" Type="VI" URL="/&lt;vilib&gt;/picture/pictutil.llb/Get Image Subset.vi"/>
				<Item Name="Get String Text Bounds.vi" Type="VI" URL="/&lt;vilib&gt;/Utility/error.llb/Get String Text Bounds.vi"/>
				<Item Name="Get Text Rect.vi" Type="VI" URL="/&lt;vilib&gt;/picture/picture.llb/Get Text Rect.vi"/>
				<Item Name="GetHelpDir.vi" Type="VI" URL="/&lt;vilib&gt;/Utility/error.llb/GetHelpDir.vi"/>
				<Item Name="GetRTHostConnectedProp.vi" Type="VI" URL="/&lt;vilib&gt;/Utility/error.llb/GetRTHostConnectedProp.vi"/>
				<Item Name="Graphic.ctl" Type="VI" URL="/&lt;vilib&gt;/LabVIEW Icon API/lv_icon/Controls/Graphic.ctl"/>
				<Item Name="Has LLB Extension.vi" Type="VI" URL="/&lt;vilib&gt;/Utility/libraryn.llb/Has LLB Extension.vi"/>
				<Item Name="IEColor.ctl" Type="VI" URL="/&lt;vilib&gt;/LabVIEW Icon API/lv_icon/Controls/IEColor.ctl"/>
				<Item Name="imagedata.ctl" Type="VI" URL="/&lt;vilib&gt;/picture/picture.llb/imagedata.ctl"/>
				<Item Name="Is Name Multiplatform.vi" Type="VI" URL="/&lt;vilib&gt;/Utility/libraryn.llb/Is Name Multiplatform.vi"/>
				<Item Name="LabVIEW Icon Stored Information.ctl" Type="VI" URL="/&lt;vilib&gt;/LabVIEW Icon API/lv_icon/Controls/LabVIEW Icon Stored Information.ctl"/>
				<Item Name="Layer.ctl" Type="VI" URL="/&lt;vilib&gt;/LabVIEW Icon API/lv_icon/Controls/Layer.ctl"/>
				<Item Name="LayerType.ctl" Type="VI" URL="/&lt;vilib&gt;/LabVIEW Icon API/lv_icon/Controls/LayerType.ctl"/>
				<Item Name="Librarian Delete Dialog.vi" Type="VI" URL="/&lt;vilib&gt;/Utility/libraryn.llb/Librarian Delete Dialog.vi"/>
				<Item Name="Librarian Delete.vi" Type="VI" URL="/&lt;vilib&gt;/Utility/libraryn.llb/Librarian Delete.vi"/>
				<Item Name="Librarian File Info In.ctl" Type="VI" URL="/&lt;vilib&gt;/Utility/libraryn.llb/Librarian File Info In.ctl"/>
				<Item Name="Librarian File Info Out.ctl" Type="VI" URL="/&lt;vilib&gt;/Utility/libraryn.llb/Librarian File Info Out.ctl"/>
				<Item Name="Librarian File List.ctl" Type="VI" URL="/&lt;vilib&gt;/Utility/libraryn.llb/Librarian File List.ctl"/>
				<Item Name="Librarian OK to Delete.vi" Type="VI" URL="/&lt;vilib&gt;/Utility/libraryn.llb/Librarian OK to Delete.vi"/>
				<Item Name="Librarian Path Location.vi" Type="VI" URL="/&lt;vilib&gt;/Utility/libraryn.llb/Librarian Path Location.vi"/>
				<Item Name="Librarian Rename.vi" Type="VI" URL="/&lt;vilib&gt;/Utility/libraryn.llb/Librarian Rename.vi"/>
				<Item Name="Librarian.vi" Type="VI" URL="/&lt;vilib&gt;/Utility/libraryn.llb/Librarian.vi"/>
				<Item Name="List Directory and LLBs.vi" Type="VI" URL="/&lt;vilib&gt;/Utility/libraryn.llb/List Directory and LLBs.vi"/>
				<Item Name="Longest Line Length in Pixels.vi" Type="VI" URL="/&lt;vilib&gt;/Utility/error.llb/Longest Line Length in Pixels.vi"/>
				<Item Name="LVBoundsTypeDef.ctl" Type="VI" URL="/&lt;vilib&gt;/Utility/miscctls.llb/LVBoundsTypeDef.ctl"/>
				<Item Name="lveventtype.ctl" Type="VI" URL="/&lt;vilib&gt;/event_ctls.llb/lveventtype.ctl"/>
				<Item Name="LVKeyNavTypeDef.ctl" Type="VI" URL="/&lt;vilib&gt;/Utility/miscctls.llb/LVKeyNavTypeDef.ctl"/>
				<Item Name="LVPoint32TypeDef.ctl" Type="VI" URL="/&lt;vilib&gt;/Utility/miscctls.llb/LVPoint32TypeDef.ctl"/>
				<Item Name="LVPositionTypeDef.ctl" Type="VI" URL="/&lt;vilib&gt;/Utility/miscctls.llb/LVPositionTypeDef.ctl"/>
				<Item Name="LVRectTypeDef.ctl" Type="VI" URL="/&lt;vilib&gt;/Utility/miscctls.llb/LVRectTypeDef.ctl"/>
				<Item Name="LVRowAndColumnTypeDef.ctl" Type="VI" URL="/&lt;vilib&gt;/Utility/miscctls.llb/LVRowAndColumnTypeDef.ctl"/>
				<Item Name="Move Pen.vi" Type="VI" URL="/&lt;vilib&gt;/picture/picture.llb/Move Pen.vi"/>
				<Item Name="NI_FileType.lvlib" Type="Library" URL="/&lt;vilib&gt;/Utility/lvfile.llb/NI_FileType.lvlib"/>
				<Item Name="NI_PackedLibraryUtility.lvlib" Type="Library" URL="/&lt;vilib&gt;/Utility/LVLibp/NI_PackedLibraryUtility.lvlib"/>
				<Item Name="NI_Unzip.lvlib" Type="Library" URL="/&lt;vilib&gt;/zip/NI_Unzip.lvlib"/>
				<Item Name="NI_XML.lvlib" Type="Library" URL="/&lt;vilib&gt;/xml/NI_XML.lvlib"/>
				<Item Name="Not Found Dialog.vi" Type="VI" URL="/&lt;vilib&gt;/Utility/error.llb/Not Found Dialog.vi"/>
				<Item Name="OffsetRect.vi" Type="VI" URL="/&lt;vilib&gt;/picture/PictureSupport.llb/OffsetRect.vi"/>
				<Item Name="Open Registry Key.vi" Type="VI" URL="/&lt;vilib&gt;/registry/registry.llb/Open Registry Key.vi"/>
				<Item Name="Open URL in Default Browser core.vi" Type="VI" URL="/&lt;vilib&gt;/Platform/browser.llb/Open URL in Default Browser core.vi"/>
				<Item Name="Path To Command Line String.vi" Type="VI" URL="/&lt;vilib&gt;/AdvancedString/Path To Command Line String.vi"/>
				<Item Name="Pathes.ctl" Type="VI" URL="/&lt;vilib&gt;/LabVIEW Icon API/lv_icon/Controls/Pathes.ctl"/>
				<Item Name="PathToUNIXPathString.vi" Type="VI" URL="/&lt;vilib&gt;/Platform/CFURL.llb/PathToUNIXPathString.vi"/>
				<Item Name="PCT Pad String.vi" Type="VI" URL="/&lt;vilib&gt;/picture/picture.llb/PCT Pad String.vi"/>
				<Item Name="Picture to Pixmap.vi" Type="VI" URL="/&lt;vilib&gt;/picture/pictutil.llb/Picture to Pixmap.vi"/>
				<Item Name="Qualified Name Array To Single String.vi" Type="VI" URL="/&lt;vilib&gt;/Utility/LVClass/Qualified Name Array To Single String.vi"/>
				<Item Name="Query Registry Key Info.vi" Type="VI" URL="/&lt;vilib&gt;/registry/registry.llb/Query Registry Key Info.vi"/>
				<Item Name="Read BMP File Data.vi" Type="VI" URL="/&lt;vilib&gt;/picture/bmp.llb/Read BMP File Data.vi"/>
				<Item Name="Read BMP File.vi" Type="VI" URL="/&lt;vilib&gt;/picture/bmp.llb/Read BMP File.vi"/>
				<Item Name="Read BMP Header Info.vi" Type="VI" URL="/&lt;vilib&gt;/picture/bmp.llb/Read BMP Header Info.vi"/>
				<Item Name="Read JPEG File.vi" Type="VI" URL="/&lt;vilib&gt;/picture/jpeg.llb/Read JPEG File.vi"/>
				<Item Name="Read PNG File.vi" Type="VI" URL="/&lt;vilib&gt;/picture/png.llb/Read PNG File.vi"/>
				<Item Name="RectSize.vi" Type="VI" URL="/&lt;vilib&gt;/picture/PictureSupport.llb/RectSize.vi"/>
				<Item Name="Recursive File List.vi" Type="VI" URL="/&lt;vilib&gt;/Utility/libraryn.llb/Recursive File List.vi"/>
				<Item Name="Registry Handle Master.vi" Type="VI" URL="/&lt;vilib&gt;/registry/registry.llb/Registry Handle Master.vi"/>
				<Item Name="Registry refnum.ctl" Type="VI" URL="/&lt;vilib&gt;/registry/registry.llb/Registry refnum.ctl"/>
				<Item Name="Registry RtKey.ctl" Type="VI" URL="/&lt;vilib&gt;/registry/registry.llb/Registry RtKey.ctl"/>
				<Item Name="Registry SAM.ctl" Type="VI" URL="/&lt;vilib&gt;/registry/registry.llb/Registry SAM.ctl"/>
				<Item Name="Registry Simplify Data Type.vi" Type="VI" URL="/&lt;vilib&gt;/registry/registry.llb/Registry Simplify Data Type.vi"/>
				<Item Name="Registry View.ctl" Type="VI" URL="/&lt;vilib&gt;/registry/registry.llb/Registry View.ctl"/>
				<Item Name="Registry WinErr-LVErr.vi" Type="VI" URL="/&lt;vilib&gt;/registry/registry.llb/Registry WinErr-LVErr.vi"/>
				<Item Name="RGB to Color.vi" Type="VI" URL="/&lt;vilib&gt;/Utility/colorconv.llb/RGB to Color.vi"/>
				<Item Name="Search and Replace Pattern.vi" Type="VI" URL="/&lt;vilib&gt;/Utility/error.llb/Search and Replace Pattern.vi"/>
				<Item Name="Set Bold Text.vi" Type="VI" URL="/&lt;vilib&gt;/Utility/error.llb/Set Bold Text.vi"/>
				<Item Name="Set Busy.vi" Type="VI" URL="/&lt;vilib&gt;/Utility/cursorutil.llb/Set Busy.vi"/>
				<Item Name="Set Cursor (Cursor ID).vi" Type="VI" URL="/&lt;vilib&gt;/Utility/cursorutil.llb/Set Cursor (Cursor ID).vi"/>
				<Item Name="Set Cursor (Icon Pict).vi" Type="VI" URL="/&lt;vilib&gt;/Utility/cursorutil.llb/Set Cursor (Icon Pict).vi"/>
				<Item Name="Set Cursor.vi" Type="VI" URL="/&lt;vilib&gt;/Utility/cursorutil.llb/Set Cursor.vi"/>
				<Item Name="Set Pen State.vi" Type="VI" URL="/&lt;vilib&gt;/picture/picture.llb/Set Pen State.vi"/>
				<Item Name="Set String Value.vi" Type="VI" URL="/&lt;vilib&gt;/Utility/error.llb/Set String Value.vi"/>
				<Item Name="Simple Error Handler.vi" Type="VI" URL="/&lt;vilib&gt;/Utility/error.llb/Simple Error Handler.vi"/>
				<Item Name="Single String To Qualified Name Array.vi" Type="VI" URL="/&lt;vilib&gt;/Utility/LVClass/Single String To Qualified Name Array.vi"/>
				<Item Name="Space Constant.vi" Type="VI" URL="/&lt;vilib&gt;/dlg_ctls.llb/Space Constant.vi"/>
				<Item Name="STR_ASCII-Unicode.vi" Type="VI" URL="/&lt;vilib&gt;/registry/registry.llb/STR_ASCII-Unicode.vi"/>
				<Item Name="subFile Dialog.vi" Type="VI" URL="/&lt;vilib&gt;/express/express input/FileDialogBlock.llb/subFile Dialog.vi"/>
				<Item Name="System Exec.vi" Type="VI" URL="/&lt;vilib&gt;/Platform/system.llb/System Exec.vi"/>
				<Item Name="TagReturnType.ctl" Type="VI" URL="/&lt;vilib&gt;/Utility/error.llb/TagReturnType.ctl"/>
				<Item Name="Three Button Dialog CORE.vi" Type="VI" URL="/&lt;vilib&gt;/Utility/error.llb/Three Button Dialog CORE.vi"/>
				<Item Name="Three Button Dialog.vi" Type="VI" URL="/&lt;vilib&gt;/Utility/error.llb/Three Button Dialog.vi"/>
				<Item Name="Trim Whitespace.vi" Type="VI" URL="/&lt;vilib&gt;/Utility/error.llb/Trim Whitespace.vi"/>
				<Item Name="Unflatten Pixmap.vi" Type="VI" URL="/&lt;vilib&gt;/picture/pixmap.llb/Unflatten Pixmap.vi"/>
				<Item Name="Unset Busy.vi" Type="VI" URL="/&lt;vilib&gt;/Utility/cursorutil.llb/Unset Busy.vi"/>
				<Item Name="whitespace.ctl" Type="VI" URL="/&lt;vilib&gt;/Utility/error.llb/whitespace.ctl"/>
				<Item Name="Write BMP Data To Buffer.vi" Type="VI" URL="/&lt;vilib&gt;/picture/bmp.llb/Write BMP Data To Buffer.vi"/>
				<Item Name="Write BMP Data.vi" Type="VI" URL="/&lt;vilib&gt;/picture/bmp.llb/Write BMP Data.vi"/>
				<Item Name="Write BMP File.vi" Type="VI" URL="/&lt;vilib&gt;/picture/bmp.llb/Write BMP File.vi"/>
				<Item Name="Write JPEG File.vi" Type="VI" URL="/&lt;vilib&gt;/picture/jpeg.llb/Write JPEG File.vi"/>
				<Item Name="Write PNG File.vi" Type="VI" URL="/&lt;vilib&gt;/picture/png.llb/Write PNG File.vi"/>
			</Item>
			<Item Name="Add Data to History.vi" Type="VI" URL="/&lt;resource&gt;/plugins/NIIconEditor/Miscellaneous/Undo Redo/Add Data to History.vi"/>
			<Item Name="Add new Layer.vi" Type="VI" URL="/&lt;resource&gt;/plugins/NIIconEditor/Miscellaneous/Icon Editor/Add new Layer.vi"/>
			<Item Name="Advapi32.dll" Type="Document" URL="Advapi32.dll">
				<Property Name="NI.PreserveRelativePath" Type="Bool">true</Property>
			</Item>
			<Item Name="Alignment Value Change.vi" Type="VI" URL="/&lt;resource&gt;/plugins/NIIconEditor/Miscellaneous/Icon Editor/Alignment Value Change.vi"/>
			<Item Name="Analyze XML stream.vi" Type="VI" URL="/&lt;resource&gt;/plugins/NIIconEditor/Miscellaneous/ni.com_iconlibrary/Analyze XML stream.vi"/>
			<Item Name="Ants.lvclass" Type="LVClass" URL="/&lt;resource&gt;/plugins/NIIconEditor/Class/Ants/Ants.lvclass"/>
			<Item Name="Arrow Down.ctl" Type="VI" URL="/&lt;resource&gt;/plugins/NIIconEditor/Controls/Arrow Down.ctl"/>
			<Item Name="Arrow Up.ctl" Type="VI" URL="/&lt;resource&gt;/plugins/NIIconEditor/Controls/Arrow Up.ctl"/>
			<Item Name="AssessRectangle.vi" Type="VI" URL="/&lt;resource&gt;/plugins/NIIconEditor/Miscellaneous/AssessRectangle.vi"/>
			<Item Name="Buffer for lossless tracking.vi" Type="VI" URL="/&lt;resource&gt;/plugins/NIIconEditor/Miscellaneous/Buffer for lossless tracking.vi"/>
			<Item Name="BuildCategories.vi" Type="VI" URL="/&lt;resource&gt;/plugins/NIIconEditor/Miscellaneous/Graphics/BuildCategories.vi"/>
			<Item Name="CalculateAntsRect.vi" Type="VI" URL="/&lt;resource&gt;/plugins/NIIconEditor/Miscellaneous/CalculateAntsRect.vi"/>
			<Item Name="Call Keep ApplyLib in Memory.vi" Type="VI" URL="/&lt;resource&gt;/plugins/NIIconEditor/Support/Call Keep ApplyLib in Memory.vi"/>
			<Item Name="Call Keep IE in Memory.vi" Type="VI" URL="/&lt;resource&gt;/plugins/NIIconEditor/Miscellaneous/Icon Editor/Call Keep IE in Memory.vi"/>
			<Item Name="Change Mouse Cursor.vi" Type="VI" URL="/&lt;resource&gt;/plugins/NIIconEditor/Miscellaneous/Icon Editor/Change Mouse Cursor.vi"/>
			<Item Name="Check whether installed.vi" Type="VI" URL="/&lt;resource&gt;/plugins/NIIconEditor/Miscellaneous/ni.com_iconlibrary/Check whether installed.vi"/>
			<Item Name="Circle.ctl" Type="VI" URL="/&lt;resource&gt;/plugins/NIIconEditor/Controls/Circle.ctl"/>
			<Item Name="Classes Initialization.vi" Type="VI" URL="/&lt;resource&gt;/plugins/NIIconEditor/Miscellaneous/Classes Initialization.vi"/>
			<Item Name="Clear User Layers.vi" Type="VI" URL="/&lt;resource&gt;/plugins/NIIconEditor/Miscellaneous/Icon Editor/Clear User Layers.vi"/>
			<Item Name="ColorChange.ctl" Type="VI" URL="/&lt;resource&gt;/plugins/NIIconEditor/Controls/ColorChange.ctl"/>
			<Item Name="Connector Pane Initialization.vi" Type="VI" URL="/&lt;resource&gt;/plugins/NIIconEditor/Miscellaneous/Connector Pane Initialization.vi"/>
			<Item Name="Const Temp Coordinate 2 points.vi" Type="VI" URL="/&lt;resource&gt;/plugins/NIIconEditor/Miscellaneous/Draw/Const Temp Coordinate 2 points.vi"/>
			<Item Name="Const Temp Coordinate 4 points.vi" Type="VI" URL="/&lt;resource&gt;/plugins/NIIconEditor/Miscellaneous/Draw/Const Temp Coordinate 4 points.vi"/>
			<Item Name="CoordinatesCorrection.vi" Type="VI" URL="/&lt;resource&gt;/plugins/NIIconEditor/Miscellaneous/CoordinatesCorrection.vi"/>
			<Item Name="Create new layer_LayerName_Picture.vi" Type="VI" URL="/&lt;resource&gt;/plugins/NIIconEditor/Miscellaneous/Create new layer_LayerName_Picture.vi"/>
			<Item Name="Create or Substitute NI_Layer layer.vi" Type="VI" URL="/&lt;resource&gt;/plugins/NIIconEditor/Support/Create or Substitute NI_Layer layer.vi"/>
			<Item Name="Data.vi" Type="VI" URL="/&lt;resource&gt;/plugins/NIIconEditor/Global Variables/Data.vi"/>
			<Item Name="DealWithScrollbars.vi" Type="VI" URL="/&lt;resource&gt;/plugins/NIIconEditor/Miscellaneous/DealWithScrollbars.vi"/>
			<Item Name="DefaultIconGlyphData.vi" Type="VI" URL="/&lt;resource&gt;/plugins/NIIconEditor/Support/DefaultIconGlyphData.vi"/>
			<Item Name="Defer_FP_Updates.vi" Type="VI" URL="/&lt;resource&gt;/plugins/NIIconEditor/Miscellaneous/Def FP Updates/Defer_FP_Updates.vi"/>
			<Item Name="Delete Icon Editor Source Files.vi" Type="VI" URL="/&lt;resource&gt;/plugins/NIIconEditor/Delete Icon Editor Source Files.vi"/>
			<Item Name="Delete Selected Layers.vi" Type="VI" URL="/&lt;resource&gt;/plugins/NIIconEditor/Miscellaneous/Icon Editor/Delete Selected Layers.vi"/>
			<Item Name="DeleteLayer.ctl" Type="VI" URL="/&lt;resource&gt;/plugins/NIIconEditor/Controls/DeleteLayer.ctl"/>
			<Item Name="DeleteLayer.vi" Type="VI" URL="/&lt;resource&gt;/plugins/NIIconEditor/Miscellaneous/Layer/DeleteLayer.vi"/>
			<Item Name="DeselectLayer.vi" Type="VI" URL="/&lt;resource&gt;/plugins/NIIconEditor/Miscellaneous/Layer/DeselectLayer.vi"/>
			<Item Name="Discover Who Invoked The Icon Editor.vi" Type="VI" URL="/&lt;resource&gt;/plugins/IconEditor/Discover Who Invoked The Icon Editor.vi"/>
			<Item Name="DOMUserDefRef.dll" Type="Document" URL="DOMUserDefRef.dll">
				<Property Name="NI.PreserveRelativePath" Type="Bool">true</Property>
			</Item>
			<Item Name="DownloadFileType.ctl" Type="VI" URL="/&lt;resource&gt;/plugins/NIIconEditor/Controls/DownloadFileType.ctl"/>
			<Item Name="DrawIcon.vi" Type="VI" URL="/&lt;resource&gt;/plugins/NIIconEditor/Miscellaneous/Draw/DrawIcon.vi"/>
			<Item Name="Dropper.ctl" Type="VI" URL="/&lt;resource&gt;/plugins/NIIconEditor/Controls/Dropper.ctl"/>
			<Item Name="EnableDisable Combine Layers.vi" Type="VI" URL="/&lt;resource&gt;/plugins/NIIconEditor/Miscellaneous/Menubar/EnableDisable Combine Layers.vi"/>
			<Item Name="Escape.vi" Type="VI" URL="/&lt;resource&gt;/plugins/NIIconEditor/Miscellaneous/Icon Editor/Escape.vi"/>
			<Item Name="Export_Clipboard.vi" Type="VI" URL="/&lt;resource&gt;/plugins/NIIconEditor/Miscellaneous/Load Unload/Export_Clipboard.vi"/>
			<Item Name="Extract LV Icon Data.vi" Type="VI" URL="/&lt;resource&gt;/plugins/NIIconEditor/Miscellaneous/Extract LV Icon Data.vi"/>
			<Item Name="ExtractDataFromXML.vi" Type="VI" URL="/&lt;resource&gt;/plugins/NIIconEditor/Miscellaneous/ni.com_iconlibrary/ExtractDataFromXML.vi"/>
			<Item Name="FakedArray.lvclass" Type="LVClass" URL="/&lt;resource&gt;/plugins/NIIconEditor/Class/FakedArray/FakedArray.lvclass"/>
			<Item Name="FCircle.ctl" Type="VI" URL="/&lt;resource&gt;/plugins/NIIconEditor/Controls/FCircle.ctl"/>
			<Item Name="FGV_Undo Redo.vi" Type="VI" URL="/&lt;resource&gt;/plugins/NIIconEditor/Miscellaneous/Undo Redo/FGV_Undo Redo.vi"/>
			<Item Name="Fill.ctl" Type="VI" URL="/&lt;resource&gt;/plugins/NIIconEditor/Controls/Fill.ctl"/>
			<Item Name="Filter Graphics by File Name.vi" Type="VI" URL="/&lt;resource&gt;/plugins/NIIconEditor/Miscellaneous/Graphics/Filter Graphics by File Name.vi"/>
			<Item Name="Finalize Movement.vi" Type="VI" URL="/&lt;resource&gt;/plugins/NIIconEditor/Miscellaneous/Finalize Movement.vi"/>
			<Item Name="Finalize Text.vi" Type="VI" URL="/&lt;resource&gt;/plugins/NIIconEditor/Miscellaneous/Finalize Text.vi"/>
			<Item Name="Fire Body Text Change event.vi" Type="VI" URL="/&lt;resource&gt;/plugins/NIIconEditor/Miscellaneous/Icon Editor/Fire Body Text Change event.vi"/>
			<Item Name="Flip color refs.vi" Type="VI" URL="/&lt;resource&gt;/plugins/NIIconEditor/Miscellaneous/Flip color refs.vi"/>
			<Item Name="Flip.ctl" Type="VI" URL="/&lt;resource&gt;/plugins/NIIconEditor/Controls/Flip.ctl"/>
			<Item Name="Font Size.ctl" Type="VI" URL="/&lt;resource&gt;/plugins/NIIconEditor/Controls/Font Size.ctl"/>
			<Item Name="Framework Templates.ctl" Type="VI" URL="/&lt;resource&gt;/plugins/NIIconEditor/Controls/Framework Templates.ctl"/>
			<Item Name="FRect.ctl" Type="VI" URL="/&lt;resource&gt;/plugins/NIIconEditor/Controls/FRect.ctl"/>
			<Item Name="Get 32x32 Image Data.vi" Type="VI" URL="/&lt;resource&gt;/plugins/NIIconEditor/Support/Get 32x32 Image Data.vi"/>
			<Item Name="Get Callers of Icon Editor Packed Library.vi" Type="VI" URL="/&lt;resource&gt;/plugins/NIIconEditor/Get Callers of Icon Editor Packed Library.vi"/>
			<Item Name="Get Callers of Icon Editor Source Files.vi" Type="VI" URL="/&lt;resource&gt;/plugins/NIIconEditor/Get Callers of Icon Editor Source Files.vi"/>
			<Item Name="Get Color Icon from Caller.vi" Type="VI" URL="/&lt;resource&gt;/plugins/NIIconEditor/Miscellaneous/Load Unload/Get Color Icon from Caller.vi"/>
			<Item Name="Get Icon Editor Source Paths.vi" Type="VI" URL="/&lt;resource&gt;/plugins/NIIconEditor/Get Icon Editor Source Paths.vi"/>
			<Item Name="Get Monochrome Icon from Caller.vi" Type="VI" URL="/&lt;resource&gt;/plugins/NIIconEditor/Miscellaneous/Get Monochrome Icon from Caller.vi"/>
			<Item Name="GetComparisonResult4Graphis.vi" Type="VI" URL="/&lt;resource&gt;/plugins/NIIconEditor/Miscellaneous/GetComparisonResult4Graphis.vi"/>
			<Item Name="GetLibIconForVIIconOverlay.vi" Type="VI" URL="/&lt;resource&gt;/plugins/NIIconEditor/Support/GetLibIconForVIIconOverlay.vi"/>
			<Item Name="GetLibIconForVIIconOverlayFromVI.vi" Type="VI" URL="/&lt;resource&gt;/plugins/NIIconEditor/Support/GetLibIconForVIIconOverlayFromVI.vi"/>
			<Item Name="Glyph.lvclass" Type="LVClass" URL="/&lt;resource&gt;/plugins/NIIconEditor/Class/Icon Library/Glyph.lvclass"/>
			<Item Name="Glyph_MouseDown.vi" Type="VI" URL="/&lt;resource&gt;/plugins/NIIconEditor/Miscellaneous/Glyphs/Glyph_MouseDown.vi"/>
			<Item Name="Icon Editor First Call.vi" Type="VI" URL="/&lt;resource&gt;/plugins/NIIconEditor/Support/Icon Editor First Call.vi"/>
			<Item Name="Icon Editor Help.vi" Type="VI" URL="/&lt;resource&gt;/plugins/NIIconEditor/Miscellaneous/Icon Editor/Icon Editor Help.vi"/>
			<Item Name="Icon Editor Init Refs.vi" Type="VI" URL="/&lt;resource&gt;/plugins/NIIconEditor/Miscellaneous/Icon Editor/Icon Editor Init Refs.vi"/>
			<Item Name="Icon Editor Invoker Type.ctl" Type="VI" URL="/&lt;resource&gt;/plugins/IconEditor/Icon Editor Invoker Type.ctl"/>
			<Item Name="Icon Editor Properties Help.vi" Type="VI" URL="/&lt;resource&gt;/plugins/NIIconEditor/Miscellaneous/Icon Editor/Icon Editor Properties Help.vi"/>
			<Item Name="Icon Initialization.vi" Type="VI" URL="/&lt;resource&gt;/plugins/NIIconEditor/Miscellaneous/Icon Editor/Icon Initialization.vi"/>
			<Item Name="IconEditorSettings.vi" Type="VI" URL="/&lt;resource&gt;/plugins/NIIconEditor/User Dialogs/IconEditorSettings.vi"/>
			<Item Name="IconFilename.ctl" Type="VI" URL="/&lt;resource&gt;/plugins/NIIconEditor/Controls/IconFilename.ctl"/>
			<Item Name="IconLibraryList.ctl" Type="VI" URL="/&lt;resource&gt;/plugins/NIIconEditor/Controls/IconLibraryList.ctl"/>
			<Item Name="IconlibraryStuffInProgress.vi" Type="VI" URL="/&lt;resource&gt;/plugins/NIIconEditor/Miscellaneous/ni.com_iconlibrary/IconlibraryStuffInProgress.vi"/>
			<Item Name="IE Classes.ctl" Type="VI" URL="/&lt;resource&gt;/plugins/NIIconEditor/Controls/IE Classes.ctl"/>
			<Item Name="IE Data.ctl" Type="VI" URL="/&lt;resource&gt;/plugins/NIIconEditor/Controls/IE Data.ctl"/>
			<Item Name="IE Read from Clipboard.vi" Type="VI" URL="/&lt;resource&gt;/plugins/NIIconEditor/Miscellaneous/Clipboard/IE Read from Clipboard.vi"/>
			<Item Name="IE Save dialog build path.vi" Type="VI" URL="/&lt;resource&gt;/plugins/NIIconEditor/Miscellaneous/Icon Editor/IE Save dialog build path.vi"/>
			<Item Name="IE Symbols.ctl" Type="VI" URL="/&lt;resource&gt;/plugins/NIIconEditor/Controls/IE Symbols.ctl"/>
			<Item Name="IE Write to Clipboard.vi" Type="VI" URL="/&lt;resource&gt;/plugins/NIIconEditor/Miscellaneous/Clipboard/IE Write to Clipboard.vi"/>
			<Item Name="IERect.ctl" Type="VI" URL="/&lt;resource&gt;/plugins/NIIconEditor/Controls/IERect.ctl"/>
			<Item Name="ImageDataToIconPreview.vi" Type="VI" URL="/&lt;resource&gt;/plugins/NIIconEditor/Miscellaneous/ImageDataToIconPreview.vi"/>
			<Item Name="Import_Clipboard.vi" Type="VI" URL="/&lt;resource&gt;/plugins/NIIconEditor/Miscellaneous/Load Unload/Import_Clipboard.vi"/>
			<Item Name="INI.ctl" Type="VI" URL="/&lt;resource&gt;/plugins/NIIconEditor/Controls/INI.ctl"/>
			<Item Name="Initialization_UserEvents.vi" Type="VI" URL="/&lt;resource&gt;/plugins/NIIconEditor/Miscellaneous/User Events/Initialization_UserEvents.vi"/>
			<Item Name="Install Glyphs.vi" Type="VI" URL="/&lt;resource&gt;/plugins/NIIconEditor/Miscellaneous/ni.com_iconlibrary/Install Glyphs.vi"/>
			<Item Name="IsAntsRectValid.vi" Type="VI" URL="/&lt;resource&gt;/plugins/NIIconEditor/Miscellaneous/IsAntsRectValid.vi"/>
			<Item Name="IsCoordinateConstant.vi" Type="VI" URL="/&lt;resource&gt;/plugins/NIIconEditor/Miscellaneous/Draw/IsCoordinateConstant.vi"/>
			<Item Name="kernel32.dll" Type="Document" URL="kernel32.dll">
				<Property Name="NI.PreserveRelativePath" Type="Bool">true</Property>
			</Item>
			<Item Name="Key Down Up Layers.vi" Type="VI" URL="/&lt;resource&gt;/plugins/NIIconEditor/Miscellaneous/Key Down Up/Key Down Up Layers.vi"/>
			<Item Name="KeyDown.vi" Type="VI" URL="/&lt;resource&gt;/plugins/NIIconEditor/Miscellaneous/Key Down Up/KeyDown.vi"/>
			<Item Name="KeyUp.vi" Type="VI" URL="/&lt;resource&gt;/plugins/NIIconEditor/Miscellaneous/Key Down Up/KeyUp.vi"/>
			<Item Name="Launch Dynamically Load Graphics.vi" Type="VI" URL="/&lt;resource&gt;/plugins/NIIconEditor/Miscellaneous/Graphics/Launch Dynamically Load Graphics.vi"/>
			<Item Name="LayerCluster_ValueChange.vi" Type="VI" URL="/&lt;resource&gt;/plugins/NIIconEditor/Miscellaneous/Icon Editor/LayerCluster_ValueChange.vi"/>
			<Item Name="LayerList.ctl" Type="VI" URL="/&lt;resource&gt;/plugins/NIIconEditor/Controls/LayerList.ctl"/>
			<Item Name="Limit value.vi" Type="VI" URL="/&lt;resource&gt;/plugins/NIIconEditor/Miscellaneous/Undo Redo/Limit value.vi"/>
			<Item Name="Line.ctl" Type="VI" URL="/&lt;resource&gt;/plugins/NIIconEditor/Controls/Line.ctl"/>
			<Item Name="Linux.vi" Type="VI" URL="/&lt;resource&gt;/plugins/NIIconEditor/Miscellaneous/Font/Linux.vi"/>
			<Item Name="ListGlyphsAndTemplates.vi" Type="VI" URL="/&lt;resource&gt;/plugins/NIIconEditor/Miscellaneous/ListGlyphsAndTemplates.vi"/>
			<Item Name="Load Glyph from File.vi" Type="VI" URL="/&lt;resource&gt;/plugins/NIIconEditor/Miscellaneous/Load Glyph from File.vi"/>
			<Item Name="Load.vi" Type="VI" URL="/&lt;resource&gt;/plugins/NIIconEditor/Miscellaneous/Load Unload/Load.vi"/>
			<Item Name="LoadTemplates.vi" Type="VI" URL="/&lt;resource&gt;/plugins/NIIconEditor/Miscellaneous/Graphics/LoadTemplates.vi"/>
			<Item Name="LV Config Read Boolean.vi" Type="VI" URL="/&lt;resource&gt;/dialog/lvconfig.llb/LV Config Read Boolean.vi"/>
			<Item Name="LV Config Read Color.vi" Type="VI" URL="/&lt;resource&gt;/dialog/lvconfig.llb/LV Config Read Color.vi"/>
			<Item Name="LV Config Read Numeric (I32).vi" Type="VI" URL="/&lt;resource&gt;/dialog/lvconfig.llb/LV Config Read Numeric (I32).vi"/>
			<Item Name="LV Config Read Pathlist.vi" Type="VI" URL="/&lt;resource&gt;/dialog/lvconfig.llb/LV Config Read Pathlist.vi"/>
			<Item Name="LV Config Read String.vi" Type="VI" URL="/&lt;resource&gt;/dialog/lvconfig.llb/LV Config Read String.vi"/>
			<Item Name="LV Config Read.vi" Type="VI" URL="/&lt;resource&gt;/dialog/lvconfig.llb/LV Config Read.vi"/>
			<Item Name="LV Config Write Boolean.vi" Type="VI" URL="/&lt;resource&gt;/dialog/lvconfig.llb/LV Config Write Boolean.vi"/>
			<Item Name="LV Config Write Color.vi" Type="VI" URL="/&lt;resource&gt;/dialog/lvconfig.llb/LV Config Write Color.vi"/>
			<Item Name="LV Config Write Numeric (I32).vi" Type="VI" URL="/&lt;resource&gt;/dialog/lvconfig.llb/LV Config Write Numeric (I32).vi"/>
			<Item Name="LV Config Write Pathlist.vi" Type="VI" URL="/&lt;resource&gt;/dialog/lvconfig.llb/LV Config Write Pathlist.vi"/>
			<Item Name="LV Config Write String.vi" Type="VI" URL="/&lt;resource&gt;/dialog/lvconfig.llb/LV Config Write String.vi"/>
			<Item Name="LV Config Write.vi" Type="VI" URL="/&lt;resource&gt;/dialog/lvconfig.llb/LV Config Write.vi"/>
			<Item Name="lv_icon.rtm" Type="Document" URL="/&lt;resource&gt;/plugins/NIIconEditor/Support/lv_icon.rtm"/>
			<Item Name="Mac.vi" Type="VI" URL="/&lt;resource&gt;/plugins/NIIconEditor/Miscellaneous/Font/Mac.vi"/>
			<Item Name="Magic Active Layer Constant.vi" Type="VI" URL="/&lt;resource&gt;/plugins/NIIconEditor/Miscellaneous/Magic Active Layer Constant.vi"/>
			<Item Name="Manual User Input.vi" Type="VI" URL="/&lt;resource&gt;/plugins/NIIconEditor/Miscellaneous/ni.com_iconlibrary/Manual User Input.vi"/>
			<Item Name="MenuSelection(User).vi" Type="VI" URL="/&lt;resource&gt;/plugins/NIIconEditor/Miscellaneous/Icon Editor/MenuSelection(User).vi"/>
			<Item Name="Mouse Down.vi" Type="VI" URL="/&lt;resource&gt;/plugins/NIIconEditor/Miscellaneous/Tools/Mouse Down.vi"/>
			<Item Name="Mouse Down_Glyphs.vi" Type="VI" URL="/&lt;resource&gt;/plugins/NIIconEditor/Miscellaneous/Icon Editor/Mouse Down_Glyphs.vi"/>
			<Item Name="Mouse Down_Templates.vi" Type="VI" URL="/&lt;resource&gt;/plugins/NIIconEditor/Miscellaneous/Icon Editor/Mouse Down_Templates.vi"/>
			<Item Name="Mouse Down_Tree.vi" Type="VI" URL="/&lt;resource&gt;/plugins/NIIconEditor/Miscellaneous/Icon Editor/Mouse Down_Tree.vi"/>
			<Item Name="Mouse Down_User Layers.vi" Type="VI" URL="/&lt;resource&gt;/plugins/NIIconEditor/Miscellaneous/Icon Editor/Mouse Down_User Layers.vi"/>
			<Item Name="MouseDown.vi" Type="VI" URL="/&lt;resource&gt;/plugins/NIIconEditor/Miscellaneous/Icon Editor/MouseDown.vi"/>
			<Item Name="MouseDown_Body Text.vi" Type="VI" URL="/&lt;resource&gt;/plugins/NIIconEditor/Miscellaneous/Icon Editor/MouseDown_Body Text.vi"/>
			<Item Name="MouseMove.vi" Type="VI" URL="/&lt;resource&gt;/plugins/NIIconEditor/Miscellaneous/Icon Editor/MouseMove.vi"/>
			<Item Name="Move Selected Layers.vi" Type="VI" URL="/&lt;resource&gt;/plugins/NIIconEditor/Miscellaneous/Key Down Up/Move Selected Layers.vi"/>
			<Item Name="Move.ctl" Type="VI" URL="/&lt;resource&gt;/plugins/NIIconEditor/Controls/Move.ctl"/>
			<Item Name="MoveLayers.vi" Type="VI" URL="/&lt;resource&gt;/plugins/NIIconEditor/Miscellaneous/MoveLayers.vi"/>
			<Item Name="NewLayer.ctl" Type="VI" URL="/&lt;resource&gt;/plugins/NIIconEditor/Controls/NewLayer.ctl"/>
			<Item Name="ni.com_iconlibrary.vi" Type="VI" URL="/&lt;resource&gt;/plugins/NIIconEditor/Miscellaneous/ni.com_iconlibrary/ni.com_iconlibrary.vi"/>
			<Item Name="Origin_or_TempCoordinate.vi" Type="VI" URL="/&lt;resource&gt;/plugins/NIIconEditor/Miscellaneous/Draw/Origin_or_TempCoordinate.vi"/>
			<Item Name="Path&amp;Icon.ctl" Type="VI" URL="/&lt;resource&gt;/plugins/NIIconEditor/Controls/Path&amp;Icon.ctl"/>
			<Item Name="Pen.ctl" Type="VI" URL="/&lt;resource&gt;/plugins/NIIconEditor/Controls/Pen.ctl"/>
			<Item Name="PictureControl_MouseUp.vi" Type="VI" URL="/&lt;resource&gt;/plugins/NIIconEditor/Miscellaneous/Icon Editor/PictureControl_MouseUp.vi"/>
			<Item Name="PixelValue.vi" Type="VI" URL="/&lt;resource&gt;/plugins/NIIconEditor/Miscellaneous/Draw/PixelValue.vi"/>
			<Item Name="Populate Font ComboBox.vi" Type="VI" URL="/&lt;resource&gt;/plugins/NIIconEditor/Miscellaneous/Populate Font ComboBox.vi"/>
			<Item Name="Populate Font Control.vi" Type="VI" URL="/&lt;resource&gt;/plugins/NIIconEditor/Miscellaneous/Font/Populate Font Control.vi"/>
			<Item Name="Populate Graphics.vi" Type="VI" URL="/&lt;resource&gt;/plugins/NIIconEditor/Miscellaneous/Glyphs/Populate Graphics.vi"/>
			<Item Name="Populate Tree with Categories.vi" Type="VI" URL="/&lt;resource&gt;/plugins/NIIconEditor/Miscellaneous/Graphics/Populate Tree with Categories.vi"/>
			<Item Name="populate tree.vi" Type="VI" URL="/&lt;resource&gt;/plugins/NIIconEditor/Miscellaneous/Icon Editor/populate tree.vi"/>
			<Item Name="Prepare Glyphs for Display.vi" Type="VI" URL="/&lt;resource&gt;/plugins/NIIconEditor/Miscellaneous/Glyphs/Prepare Glyphs for Display.vi"/>
			<Item Name="PrepareData4HTML.vi" Type="VI" URL="/&lt;resource&gt;/plugins/NIIconEditor/Miscellaneous/PrepareData4HTML.vi"/>
			<Item Name="PrepareTemporaryView.vi" Type="VI" URL="/&lt;resource&gt;/plugins/NIIconEditor/Miscellaneous/PrepareTemporaryView.vi"/>
			<Item Name="Process Active Data Shift Key.vi" Type="VI" URL="/&lt;resource&gt;/plugins/NIIconEditor/Miscellaneous/Key Down Up/Process Active Data Shift Key.vi"/>
			<Item Name="Process Temporary View Layers.vi" Type="VI" URL="/&lt;resource&gt;/plugins/NIIconEditor/Miscellaneous/Process Temporary View Layers.vi"/>
			<Item Name="Read Data from Caller.vi" Type="VI" URL="/&lt;resource&gt;/plugins/NIIconEditor/Miscellaneous/Load Unload/Read Data from Caller.vi"/>
			<Item Name="Read Glyphs from  File.vi" Type="VI" URL="/&lt;resource&gt;/plugins/NIIconEditor/Miscellaneous/Load Unload/Read Glyphs from  File.vi"/>
			<Item Name="ReadDataFromLabVIEWINI.vi" Type="VI" URL="/&lt;resource&gt;/plugins/NIIconEditor/Miscellaneous/Load Unload/ReadDataFromLabVIEWINI.vi"/>
			<Item Name="References Cluster.ctl" Type="VI" URL="/&lt;resource&gt;/plugins/NIIconEditor/Controls/References Cluster.ctl"/>
			<Item Name="Refresh.ctl" Type="VI" URL="/&lt;resource&gt;/plugins/NIIconEditor/Controls/Refresh.ctl"/>
			<Item Name="Remove invalid characters.vi" Type="VI" URL="/&lt;resource&gt;/plugins/NIIconEditor/Miscellaneous/Remove invalid characters.vi"/>
			<Item Name="Replay Data from History.vi" Type="VI" URL="/&lt;resource&gt;/plugins/NIIconEditor/Miscellaneous/Undo Redo/Replay Data from History.vi"/>
			<Item Name="Reset layer template selection.vi" Type="VI" URL="/&lt;resource&gt;/plugins/NIIconEditor/Miscellaneous/Icon Editor/Reset layer template selection.vi"/>
			<Item Name="Reset Layer VI.vi" Type="VI" URL="/&lt;resource&gt;/plugins/NIIconEditor/Miscellaneous/Load Unload/Reset Layer VI.vi"/>
			<Item Name="ResolveURLbyUsingInfoCode.vi" Type="VI" URL="/&lt;resource&gt;/plugins/NIIconEditor/Miscellaneous/ni.com_iconlibrary/ResolveURLbyUsingInfoCode.vi"/>
			<Item Name="Rotate.ctl" Type="VI" URL="/&lt;resource&gt;/plugins/NIIconEditor/Controls/Rotate.ctl"/>
			<Item Name="RotateFlip.vi" Type="VI" URL="/&lt;resource&gt;/plugins/NIIconEditor/Miscellaneous/Icon Editor/RotateFlip.vi"/>
			<Item Name="Rubber.ctl" Type="VI" URL="/&lt;resource&gt;/plugins/NIIconEditor/Controls/Rubber.ctl"/>
			<Item Name="Save Graphic Overwrite.vi" Type="VI" URL="/&lt;resource&gt;/plugins/NIIconEditor/Miscellaneous/Icon Editor/Save Graphic Overwrite.vi"/>
			<Item Name="Save Graphic.vi" Type="VI" URL="/&lt;resource&gt;/plugins/NIIconEditor/Miscellaneous/Icon Editor/Save Graphic.vi"/>
			<Item Name="Selection.ctl" Type="VI" URL="/&lt;resource&gt;/plugins/NIIconEditor/Controls/Selection.ctl"/>
			<Item Name="Selection_PrepareIcon.vi" Type="VI" URL="/&lt;resource&gt;/plugins/NIIconEditor/Miscellaneous/Tools/Selection_PrepareIcon.vi"/>
			<Item Name="Selection_SetNewData.vi" Type="VI" URL="/&lt;resource&gt;/plugins/NIIconEditor/Miscellaneous/Tools/Selection_SetNewData.vi"/>
			<Item Name="Separate Selected Layers.vi" Type="VI" URL="/&lt;resource&gt;/plugins/NIIconEditor/Miscellaneous/Layer/Separate Selected Layers.vi"/>
			<Item Name="Set active Layer programmatically.vi" Type="VI" URL="/&lt;resource&gt;/plugins/NIIconEditor/Class/FakedArray/Misc/Set active Layer programmatically.vi"/>
			<Item Name="SET_Glyph.vi" Type="VI" URL="/&lt;resource&gt;/plugins/NIIconEditor/Miscellaneous/Glyphs/SET_Glyph.vi"/>
			<Item Name="SET_ToolGraphic.vi" Type="VI" URL="/&lt;resource&gt;/plugins/NIIconEditor/Miscellaneous/Glyphs/SET_ToolGraphic.vi"/>
			<Item Name="SetCursor.vi" Type="VI" URL="/&lt;resource&gt;/plugins/NIIconEditor/Miscellaneous/SetCursor.vi"/>
			<Item Name="Settings Init.vi" Type="VI" URL="/&lt;resource&gt;/plugins/NIIconEditor/Miscellaneous/Settings Init.vi"/>
			<Item Name="Settings Requested Path.vi" Type="VI" URL="/&lt;resource&gt;/plugins/NIIconEditor/Miscellaneous/Settings Requested Path.vi"/>
			<Item Name="Settings Shutdown.vi" Type="VI" URL="/&lt;resource&gt;/plugins/NIIconEditor/Miscellaneous/Settings Shutdown.vi"/>
			<Item Name="Settings.ctl" Type="VI" URL="/&lt;resource&gt;/plugins/NIIconEditor/Controls/Settings.ctl"/>
			<Item Name="Settings.lvclass" Type="LVClass" URL="/&lt;resource&gt;/plugins/NIIconEditor/Class/Settings/Settings.lvclass"/>
			<Item Name="ShowLayersPalette.vi" Type="VI" URL="/&lt;resource&gt;/plugins/NIIconEditor/Miscellaneous/Menubar/ShowLayersPalette.vi"/>
			<Item Name="ShowTerminals.vi" Type="VI" URL="/&lt;resource&gt;/plugins/NIIconEditor/Miscellaneous/Menubar/ShowTerminals.vi"/>
			<Item Name="Specify Path Enum.vi" Type="VI" URL="/&lt;resource&gt;/plugins/NIIconEditor/Miscellaneous/Specify Path Enum.vi"/>
			<Item Name="Split_Layers.vi" Type="VI" URL="/&lt;resource&gt;/plugins/NIIconEditor/Miscellaneous/Layer/Split_Layers.vi"/>
			<Item Name="SupportClass.ctl" Type="VI" URL="/&lt;resource&gt;/plugins/NIIconEditor/Controls/SupportClass.ctl"/>
			<Item Name="SupportClass_Action.ctl" Type="VI" URL="/&lt;resource&gt;/plugins/NIIconEditor/Controls/SupportClass_Action.ctl"/>
			<Item Name="Template_MouseDown.vi" Type="VI" URL="/&lt;resource&gt;/plugins/NIIconEditor/Miscellaneous/Icon Editor/Template_MouseDown.vi"/>
			<Item Name="TemporaryGlyphView.vi" Type="VI" URL="/&lt;resource&gt;/plugins/NIIconEditor/Miscellaneous/Glyphs/TemporaryGlyphView.vi"/>
			<Item Name="Text.ctl" Type="VI" URL="/&lt;resource&gt;/plugins/NIIconEditor/Controls/Text.ctl"/>
			<Item Name="TextMarker.ctl" Type="VI" URL="/&lt;resource&gt;/plugins/NIIconEditor/Controls/TextMarker.ctl"/>
			<Item Name="ToMoreSpecific_Faked2DArray.ctl" Type="VI" URL="/&lt;resource&gt;/plugins/NIIconEditor/Controls/ToMoreSpecific_Faked2DArray.ctl"/>
			<Item Name="Tools Paint.lvclass" Type="LVClass" URL="/&lt;resource&gt;/plugins/NIIconEditor/Class/Tools/Tools Paint.lvclass"/>
			<Item Name="Tools.ctl" Type="VI" URL="/&lt;resource&gt;/plugins/NIIconEditor/Controls/Tools.ctl"/>
			<Item Name="Truncate string.vi" Type="VI" URL="/&lt;resource&gt;/plugins/NIIconEditor/Miscellaneous/Truncate string.vi"/>
			<Item Name="Undo Redo Action.ctl" Type="VI" URL="/&lt;resource&gt;/plugins/NIIconEditor/Controls/Undo Redo Action.ctl"/>
			<Item Name="Update glyph path string.vi" Type="VI" URL="/&lt;resource&gt;/plugins/NIIconEditor/Miscellaneous/Icon Editor/Update glyph path string.vi"/>
			<Item Name="UpdateLayerView_ScrollbarChanged.vi" Type="VI" URL="/&lt;resource&gt;/plugins/NIIconEditor/Miscellaneous/Icon Editor/UpdateLayerView_ScrollbarChanged.vi"/>
			<Item Name="Value Change_Body Text.vi" Type="VI" URL="/&lt;resource&gt;/plugins/NIIconEditor/Miscellaneous/Icon Editor/Value Change_Body Text.vi"/>
			<Item Name="Value Change_Tools.vi" Type="VI" URL="/&lt;resource&gt;/plugins/NIIconEditor/Miscellaneous/Tools/Value Change_Tools.vi"/>
			<Item Name="Value Change_Top or Bottom Layer.vi" Type="VI" URL="/&lt;resource&gt;/plugins/NIIconEditor/Miscellaneous/Icon Editor/Value Change_Top or Bottom Layer.vi"/>
			<Item Name="ValueSignalingTool.vi" Type="VI" URL="/&lt;resource&gt;/plugins/NIIconEditor/Miscellaneous/Tools/ValueSignalingTool.vi"/>
			<Item Name="ViewLayer.vi" Type="VI" URL="/&lt;resource&gt;/plugins/NIIconEditor/Miscellaneous/Layer/ViewLayer.vi"/>
			<Item Name="VisibleTextMarker.vi" Type="VI" URL="/&lt;resource&gt;/plugins/NIIconEditor/Miscellaneous/Tools/VisibleTextMarker.vi"/>
			<Item Name="Who Invoked Icon Editor.ctl" Type="VI" URL="/&lt;resource&gt;/plugins/IconEditor/Who Invoked Icon Editor.ctl"/>
			<Item Name="Windows.vi" Type="VI" URL="/&lt;resource&gt;/plugins/NIIconEditor/Miscellaneous/Font/Windows.vi"/>
			<Item Name="Wrap.vi" Type="VI" URL="/&lt;resource&gt;/plugins/NIIconEditor/Miscellaneous/Undo Redo/Wrap.vi"/>
			<Item Name="Write Data to Caller.vi" Type="VI" URL="/&lt;resource&gt;/plugins/NIIconEditor/Miscellaneous/Load Unload/Write Data to Caller.vi"/>
			<Item Name="Write Glyphs to  File.vi" Type="VI" URL="/&lt;resource&gt;/plugins/NIIconEditor/Miscellaneous/Load Unload/Write Glyphs to  File.vi"/>
			<Item Name="Write INI Tokens and VI Tags.vi" Type="VI" URL="/&lt;resource&gt;/plugins/NIIconEditor/Miscellaneous/Load Unload/Write INI Tokens and VI Tags.vi"/>
			<Item Name="WriteDataToLabVIEWINI.vi" Type="VI" URL="/&lt;resource&gt;/plugins/NIIconEditor/Miscellaneous/Load Unload/WriteDataToLabVIEWINI.vi"/>
			<Item Name="WriteText.vi" Type="VI" URL="/&lt;resource&gt;/plugins/NIIconEditor/Miscellaneous/Tools/WriteText.vi"/>
			<Item Name="XMLDataStructureIconLibrary.ctl" Type="VI" URL="/&lt;resource&gt;/plugins/NIIconEditor/Controls/XMLDataStructureIconLibrary.ctl"/>
		</Item>
		<Item Name="Build Specifications" Type="Build">
			<Item Name="My Packed Library" Type="Packed Library">
				<Property Name="Bld_autoIncrement" Type="Bool">true</Property>
				<Property Name="Bld_buildCacheID" Type="Str">{A1577CA5-EAFC-4DB5-990D-D681954FAB47}</Property>
				<Property Name="Bld_buildSpecName" Type="Str">My Packed Library</Property>
				<Property Name="Bld_compilerOptLevel" Type="Int">0</Property>
				<Property Name="Bld_excludeInlineSubVIs" Type="Bool">true</Property>
				<Property Name="Bld_excludeLibraryItems" Type="Bool">true</Property>
				<Property Name="Bld_excludePolymorphicVIs" Type="Bool">true</Property>
				<Property Name="Bld_excludeTypedefs" Type="Bool">true</Property>
				<Property Name="Bld_localDestDir" Type="Path">..</Property>
				<Property Name="Bld_localDestDirType" Type="Str">relativeToProject</Property>
				<Property Name="Bld_modifyLibraryFile" Type="Bool">true</Property>
				<Property Name="Bld_postActionVIID" Type="Ref">/My Computer/Other/Post Build Icon Editor PPL.vi</Property>
				<Property Name="Bld_preActionVIID" Type="Ref">/My Computer/Other/Pre Build Icon Editor PPL.vi</Property>
				<Property Name="Bld_previewCacheID" Type="Str">{DA64E4A1-F9D9-4E84-A033-A9D0A9E50639}</Property>
				<Property Name="Bld_version.build" Type="Int">3</Property>
				<Property Name="Bld_version.major" Type="Int">1</Property>
				<Property Name="Destination[0].destName" Type="Str">lv_icon.lvlibp</Property>
				<Property Name="Destination[0].path" Type="Path">../NI_AB_PROJECTNAME.lvlibp</Property>
				<Property Name="Destination[0].path.type" Type="Str">relativeToProject</Property>
				<Property Name="Destination[0].preserveHierarchy" Type="Bool">true</Property>
				<Property Name="Destination[0].type" Type="Str">App</Property>
				<Property Name="Destination[1].destName" Type="Str">Support Directory</Property>
				<Property Name="Destination[1].path" Type="Path">..</Property>
				<Property Name="Destination[1].path.type" Type="Str">relativeToProject</Property>
				<Property Name="DestinationCount" Type="Int">2</Property>
				<Property Name="PackedLib_callersAdapt" Type="Bool">true</Property>
				<Property Name="Source[0].itemID" Type="Str">{2DB62997-2C6E-4076-93BC-D16B9F119E6C}</Property>
				<Property Name="Source[0].type" Type="Str">Container</Property>
				<Property Name="Source[1].destinationIndex" Type="Int">0</Property>
				<Property Name="Source[1].itemID" Type="Ref">/My Computer/Other/lv_IconEditor.lvlib</Property>
				<Property Name="Source[1].Library.allowMissingMembers" Type="Bool">true</Property>
				<Property Name="Source[1].sourceInclusion" Type="Str">Include</Property>
				<Property Name="Source[1].type" Type="Str">Library</Property>
				<Property Name="Source[10].destinationIndex" Type="Int">0</Property>
				<Property Name="Source[10].itemID" Type="Ref">/My Computer/API/LabVIEW Icon API.lvlib/Get Library Icon.vi</Property>
				<Property Name="Source[10].sourceInclusion" Type="Str">Include</Property>
				<Property Name="Source[10].type" Type="Str">VI</Property>
				<Property Name="Source[11].destinationIndex" Type="Int">0</Property>
				<Property Name="Source[11].itemID" Type="Ref">/My Computer/Other/ApplyLibIconOverlayToVIIcon.vi</Property>
				<Property Name="Source[11].sourceInclusion" Type="Str">Include</Property>
				<Property Name="Source[11].type" Type="Str">VI</Property>
				<Property Name="Source[12].destinationIndex" Type="Int">0</Property>
				<Property Name="Source[12].itemID" Type="Ref">/My Computer/Other/LoadGraphics.vi</Property>
				<Property Name="Source[12].sourceInclusion" Type="Str">Include</Property>
				<Property Name="Source[12].type" Type="Str">VI</Property>
				<Property Name="Source[13].destinationIndex" Type="Int">0</Property>
				<Property Name="Source[13].itemID" Type="Ref">/My Computer/Other/Launch Icon Editor From String.vi</Property>
				<Property Name="Source[13].sourceInclusion" Type="Str">Include</Property>
				<Property Name="Source[13].type" Type="Str">VI</Property>
				<Property Name="Source[14].destinationIndex" Type="Int">0</Property>
				<Property Name="Source[14].itemID" Type="Ref">/My Computer/Other/Create new class icon user layers.vi</Property>
				<Property Name="Source[14].sourceInclusion" Type="Str">Include</Property>
				<Property Name="Source[14].type" Type="Str">VI</Property>
				<Property Name="Source[15].destinationIndex" Type="Int">0</Property>
				<Property Name="Source[15].itemID" Type="Ref">/My Computer/Other/GetOffsetRWIcon.vi</Property>
				<Property Name="Source[15].sourceInclusion" Type="Str">Include</Property>
				<Property Name="Source[15].type" Type="Str">VI</Property>
				<Property Name="Source[16].Container.applyInclusion" Type="Bool">true</Property>
				<Property Name="Source[16].Container.applyProperties" Type="Bool">true</Property>
				<Property Name="Source[16].destinationIndex" Type="Int">0</Property>
				<Property Name="Source[16].itemID" Type="Ref">/My Computer/Classes</Property>
				<Property Name="Source[16].properties[0].type" Type="Str">Allow debugging</Property>
				<Property Name="Source[16].properties[0].value" Type="Bool">false</Property>
				<Property Name="Source[16].propertiesCount" Type="Int">1</Property>
				<Property Name="Source[16].sourceInclusion" Type="Str">Include</Property>
				<Property Name="Source[16].type" Type="Str">Container</Property>
				<Property Name="Source[17].Container.applyInclusion" Type="Bool">true</Property>
				<Property Name="Source[17].Container.applyProperties" Type="Bool">true</Property>
				<Property Name="Source[17].destinationIndex" Type="Int">0</Property>
				<Property Name="Source[17].itemID" Type="Ref">/My Computer/Flatten Unflatten Packed to UnPacked</Property>
				<Property Name="Source[17].properties[0].type" Type="Str">Allow debugging</Property>
				<Property Name="Source[17].properties[0].value" Type="Bool">false</Property>
				<Property Name="Source[17].propertiesCount" Type="Int">1</Property>
				<Property Name="Source[17].sourceInclusion" Type="Str">Include</Property>
				<Property Name="Source[17].type" Type="Str">Container</Property>
				<Property Name="Source[18].Container.applyProperties" Type="Bool">true</Property>
				<Property Name="Source[18].itemID" Type="Ref">/My Computer/API</Property>
				<Property Name="Source[18].properties[0].type" Type="Str">Allow debugging</Property>
				<Property Name="Source[18].properties[0].value" Type="Bool">false</Property>
				<Property Name="Source[18].propertiesCount" Type="Int">1</Property>
				<Property Name="Source[18].type" Type="Str">Container</Property>
				<Property Name="Source[19].Container.applyProperties" Type="Bool">true</Property>
				<Property Name="Source[19].itemID" Type="Ref">/My Computer/Other</Property>
				<Property Name="Source[19].properties[0].type" Type="Str">Allow debugging</Property>
				<Property Name="Source[19].properties[0].value" Type="Bool">false</Property>
				<Property Name="Source[19].propertiesCount" Type="Int">1</Property>
				<Property Name="Source[19].type" Type="Str">Container</Property>
				<Property Name="Source[2].destinationIndex" Type="Int">0</Property>
				<Property Name="Source[2].itemID" Type="Ref">/My Computer/Other/lv_icon.lvlib</Property>
				<Property Name="Source[2].Library.allowMissingMembers" Type="Bool">true</Property>
				<Property Name="Source[2].Library.atomicCopy" Type="Bool">true</Property>
				<Property Name="Source[2].Library.LVLIBPtopLevel" Type="Bool">true</Property>
				<Property Name="Source[2].preventRename" Type="Bool">true</Property>
				<Property Name="Source[2].sourceInclusion" Type="Str">TopLevel</Property>
				<Property Name="Source[2].type" Type="Str">Library</Property>
				<Property Name="Source[20].destinationIndex" Type="Int">0</Property>
				<Property Name="Source[20].itemID" Type="Ref">/My Computer/Other/Keep IE in Memory.vi</Property>
				<Property Name="Source[20].sourceInclusion" Type="Str">Include</Property>
				<Property Name="Source[20].type" Type="Str">VI</Property>
				<Property Name="Source[3].destinationIndex" Type="Int">0</Property>
				<Property Name="Source[3].itemID" Type="Ref">/My Computer/API/LabVIEW Icon API.lvlib</Property>
				<Property Name="Source[3].Library.allowMissingMembers" Type="Bool">true</Property>
				<Property Name="Source[3].sourceInclusion" Type="Str">Include</Property>
				<Property Name="Source[3].type" Type="Str">Library</Property>
				<Property Name="Source[4].Container.applyInclusion" Type="Bool">true</Property>
				<Property Name="Source[4].destinationIndex" Type="Int">0</Property>
				<Property Name="Source[4].itemID" Type="Ref">/My Computer/API/LabVIEW Icon API.lvlib/Controls</Property>
				<Property Name="Source[4].sourceInclusion" Type="Str">Include</Property>
				<Property Name="Source[4].type" Type="Str">Container</Property>
				<Property Name="Source[5].Container.applyInclusion" Type="Bool">true</Property>
				<Property Name="Source[5].destinationIndex" Type="Int">0</Property>
				<Property Name="Source[5].itemID" Type="Ref">/My Computer/API/LabVIEW Icon API.lvlib/Low Level Functions</Property>
				<Property Name="Source[5].sourceInclusion" Type="Str">Include</Property>
				<Property Name="Source[5].type" Type="Str">Container</Property>
				<Property Name="Source[6].Container.applyInclusion" Type="Bool">true</Property>
				<Property Name="Source[6].destinationIndex" Type="Int">0</Property>
				<Property Name="Source[6].itemID" Type="Ref">/My Computer/API/LabVIEW Icon API.lvlib/Support</Property>
				<Property Name="Source[6].sourceInclusion" Type="Str">Include</Property>
				<Property Name="Source[6].type" Type="Str">Container</Property>
				<Property Name="Source[7].destinationIndex" Type="Int">0</Property>
				<Property Name="Source[7].itemID" Type="Ref">/My Computer/API/LabVIEW Icon API.lvlib/Set VI Icon.vi</Property>
				<Property Name="Source[7].sourceInclusion" Type="Str">Include</Property>
				<Property Name="Source[7].type" Type="Str">VI</Property>
				<Property Name="Source[8].destinationIndex" Type="Int">0</Property>
				<Property Name="Source[8].itemID" Type="Ref">/My Computer/API/LabVIEW Icon API.lvlib/Set Library Icon.vi</Property>
				<Property Name="Source[8].sourceInclusion" Type="Str">Include</Property>
				<Property Name="Source[8].type" Type="Str">VI</Property>
				<Property Name="Source[9].destinationIndex" Type="Int">0</Property>
				<Property Name="Source[9].itemID" Type="Ref">/My Computer/API/LabVIEW Icon API.lvlib/Get VI Icon.vi</Property>
				<Property Name="Source[9].sourceInclusion" Type="Str">Include</Property>
				<Property Name="Source[9].type" Type="Str">VI</Property>
				<Property Name="SourceCount" Type="Int">21</Property>
				<Property Name="TgtF_companyName" Type="Str">NI</Property>
				<Property Name="TgtF_fileDescription" Type="Str">My Packed Library</Property>
				<Property Name="TgtF_internalName" Type="Str">My Packed Library</Property>
				<Property Name="TgtF_legalCopyright" Type="Str">Copyright © 2010 NI</Property>
				<Property Name="TgtF_productName" Type="Str">My Packed Library</Property>
				<Property Name="TgtF_targetfileGUID" Type="Str">{D0A948EC-2F66-4AE5-9E1F-4124E2910ECE}</Property>
				<Property Name="TgtF_targetfileName" Type="Str">lv_icon.lvlibp</Property>
			</Item>
		</Item>
	</Item>
</Project>
