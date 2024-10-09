<?xml version='1.0'?>
<Project Type="Project" LVVersion="0">
	<Property Name="NI.LV.All.SaveVersion" Type="Str">21.0</Property>
	<Property Name="NI.LV.All.SourceOnly" Type="Bool">true</Property>
	<Property Name="NI.Project.Description" Type="Str"></Property>
	<Item Name="My Computer" Type="My Computer">
		<Property Name="server.app.propertiesEnabled" Type="Bool">true</Property>
		<Property Name="server.control.propertiesEnabled" Type="Bool">true</Property>
		<Property Name="server.tcp.enabled" Type="Bool">false</Property>
		<Property Name="server.tcp.port" Type="Int">0</Property>
		<Property Name="server.tcp.serviceName" Type="Str">My Computer/VI Server</Property>
		<Property Name="server.tcp.serviceName.default" Type="Str">My Computer/VI Server</Property>
		<Property Name="server.vi.callsEnabled" Type="Bool">true</Property>
		<Property Name="server.vi.propertiesEnabled" Type="Bool">true</Property>
		<Property Name="specify.custom.address" Type="Bool">false</Property>
		<Item Name="resource/plugins" Type="Folder">
			<Item Name="NIIconEditor" Type="Folder">
				<Item Name="Class" Type="Folder">
					<Item Name="Ants" Type="Folder">
						<Item Name="Ants.lvclass" Type="LVClass" URL="resource/plugins/NIIconEditor/Class/Ants/Ants.lvclass">
							<Item Name="Ants.ctl" Type="Class Private Data" URL="resource/plugins/NIIconEditor/Class/Ants/Ants.lvclass/Ants.ctl"/>
							<Item Name="Misc" Type="Folder">
								<Item Name="RunningAnts.vi" Type="VI" URL="resource/plugins/NIIconEditor/Class/Ants/Misc/RunningAnts.vi"/>
								<Item Name="InsideBoundaries.vi" Type="VI" URL="resource/plugins/NIIconEditor/Class/Ants/Misc/InsideBoundaries.vi"/>
								<Item Name="FireAntsEvent.vi" Type="VI" URL="resource/plugins/NIIconEditor/Class/Ants/Misc/FireAntsEvent.vi"/>
							</Item>
							<Item Name="GET" Type="Folder">
								<Item Name="GET_DelayRestartTL.vi" Type="VI" URL="resource/plugins/NIIconEditor/Class/Ants/GET/GET_DelayRestartTL.vi"/>
								<Item Name="GET_DelayTL.vi" Type="VI" URL="resource/plugins/NIIconEditor/Class/Ants/GET/GET_DelayTL.vi"/>
								<Item Name="GET_Notifier.vi" Type="VI" URL="resource/plugins/NIIconEditor/Class/Ants/GET/GET_Notifier.vi"/>
								<Item Name="GET_AntsLine.vi" Type="VI" URL="resource/plugins/NIIconEditor/Class/Ants/GET/GET_AntsLine.vi"/>
								<Item Name="GET_Picture.vi" Type="VI" URL="resource/plugins/NIIconEditor/Class/Ants/GET/GET_Picture.vi"/>
							</Item>
							<Item Name="Ants Initialization.vi" Type="VI" URL="resource/plugins/NIIconEditor/Class/Ants/Initialization/Ants Initialization.vi"/>
						</Item>
					</Item>
					<Item Name="FakedArray" Type="Folder">
						<Item Name="Misc" Type="Folder">
							<Item Name="Set active Layer programmatically.vi" Type="VI" URL="resource/plugins/NIIconEditor/Class/FakedArray/Misc/Set active Layer programmatically.vi"/>
						</Item>
						<Item Name="FakedArray.lvclass" Type="LVClass" URL="resource/plugins/NIIconEditor/Class/FakedArray/FakedArray.lvclass">
							<Item Name="FakedArray.ctl" Type="Class Private Data" URL="resource/plugins/NIIconEditor/Class/FakedArray/FakedArray.lvclass/FakedArray.ctl"/>
							<Item Name="Initialization" Type="Folder">
								<Item Name="ResetColor.vi" Type="VI" URL="resource/plugins/NIIconEditor/Class/FakedArray/Initialization/ResetColor.vi"/>
								<Item Name="SetActiveData_LoadedFromVI.vi" Type="VI" URL="resource/plugins/NIIconEditor/Class/FakedArray/Initialization/SetActiveData_LoadedFromVI.vi"/>
								<Item Name="Initialize FakedArray.vi" Type="VI" URL="resource/plugins/NIIconEditor/Class/FakedArray/Initialization/Initialize FakedArray.vi"/>
							</Item>
							<Item Name="ToMoreSpecificClass" Type="Folder">
								<Item Name="ClusterRef_2_DisplayTemplatesRef.vi" Type="VI" URL="resource/plugins/NIIconEditor/Class/FakedArray/ToMoreSpecificClass/ClusterRef_2_DisplayTemplatesRef.vi"/>
							</Item>
							<Item Name="Misc" Type="Folder">
								<Item Name="Ensure Visible.vi" Type="VI" URL="resource/plugins/NIIconEditor/Class/FakedArray/Misc/Ensure Visible.vi"/>
								<Item Name="ArrowUpDown.vi" Type="VI" URL="resource/plugins/NIIconEditor/Class/FakedArray/Misc/ArrowUpDown.vi"/>
								<Item Name="Process Template Graphics.vi" Type="VI" URL="resource/plugins/NIIconEditor/Class/FakedArray/Misc/Process Template Graphics.vi"/>
								<Item Name="UpdateSelectedData.vi" Type="VI" URL="resource/plugins/NIIconEditor/Class/FakedArray/Misc/UpdateSelectedData.vi"/>
								<Item Name="SetActiveGraphic.vi" Type="VI" URL="resource/plugins/NIIconEditor/Class/FakedArray/Misc/SetActiveGraphic.vi"/>
								<Item Name="UpdateVisibleData.vi" Type="VI" URL="resource/plugins/NIIconEditor/Class/FakedArray/Misc/UpdateVisibleData.vi"/>
								<Item Name="GetReference.vi" Type="VI" URL="resource/plugins/NIIconEditor/Class/FakedArray/Misc/GetReference.vi"/>
								<Item Name="UpdateScrollbar.vi" Type="VI" URL="resource/plugins/NIIconEditor/Class/FakedArray/Misc/UpdateScrollbar.vi"/>
							</Item>
							<Item Name="SET" Type="Folder">
								<Item Name="SET_Data.vi" Type="VI" URL="resource/plugins/NIIconEditor/Class/FakedArray/SET/SET_Data.vi"/>
								<Item Name="SET_ScrollbarPosition.vi" Type="VI" URL="resource/plugins/NIIconEditor/Class/FakedArray/SET/SET_ScrollbarPosition.vi"/>
								<Item Name="SET_ActiveData.vi" Type="VI" URL="resource/plugins/NIIconEditor/Class/FakedArray/SET/SET_ActiveData.vi"/>
							</Item>
							<Item Name="GET" Type="Folder">
								<Item Name="GET_SupportData.vi" Type="VI" URL="resource/plugins/NIIconEditor/Class/FakedArray/GET/GET_SupportData.vi"/>
								<Item Name="GET_Icon.vi" Type="VI" URL="resource/plugins/NIIconEditor/Class/FakedArray/GET/GET_Icon.vi"/>
								<Item Name="GET_ActiveData.vi" Type="VI" URL="resource/plugins/NIIconEditor/Class/FakedArray/GET/GET_ActiveData.vi"/>
								<Item Name="GET_Scrollbar Position.vi" Type="VI" URL="resource/plugins/NIIconEditor/Class/FakedArray/GET/GET_Scrollbar Position.vi"/>
								<Item Name="Get Pointer From Label.vi" Type="VI" URL="resource/plugins/NIIconEditor/Class/FakedArray/Misc/Get Pointer From Label.vi"/>
								<Item Name="GET_AllData.vi" Type="VI" URL="resource/plugins/NIIconEditor/Class/FakedArray/GET/GET_AllData.vi"/>
								<Item Name="GET_RowsCols.vi" Type="VI" URL="resource/plugins/NIIconEditor/Class/FakedArray/GET/GET_RowsCols.vi"/>
							</Item>
							<Item Name="Templates_Set Active Data BG Color.vi" Type="VI" URL="resource/plugins/NIIconEditor/Class/FakedArray/Misc/Templates_Set Active Data BG Color.vi"/>
							<Item Name="Layer_Set Active Data BG Color.vi" Type="VI" URL="resource/plugins/NIIconEditor/Class/FakedArray/Misc/Layer_Set Active Data BG Color.vi"/>
							<Item Name="Get Cluster Label Number.vi" Type="VI" URL="resource/plugins/NIIconEditor/Class/FakedArray/Misc/Get Cluster Label Number.vi"/>
							<Item Name="Layer_Get Active Clusters.vi" Type="VI" URL="resource/plugins/NIIconEditor/Class/FakedArray/Misc/Layer_Get Active Clusters.vi"/>
						</Item>
					</Item>
					<Item Name="Icon Library" Type="Folder">
						<Item Name="Glyph.lvclass" Type="LVClass" URL="resource/plugins/NIIconEditor/Class/Icon Library/Glyph.lvclass">
							<Item Name="Glyph.ctl" Type="Class Private Data" URL="resource/plugins/NIIconEditor/Class/Icon Library/Glyph.lvclass/Glyph.ctl"/>
							<Item Name="Misc" Type="Folder">
								<Item Name="SearchGlyphs.vi" Type="VI" URL="resource/plugins/NIIconEditor/Class/Icon Library/Misc/SearchGlyphs.vi"/>
								<Item Name="FilterGlyphs.vi" Type="VI" URL="resource/plugins/NIIconEditor/Class/Icon Library/Misc/FilterGlyphs.vi"/>
							</Item>
							<Item Name="SET" Type="Folder">
								<Item Name="SET_ActiveGlyph.vi" Type="VI" URL="resource/plugins/NIIconEditor/Class/Icon Library/SET/SET_ActiveGlyph.vi"/>
								<Item Name="SET_Glyphs [].vi" Type="VI" URL="resource/plugins/NIIconEditor/Class/Icon Library/SET/SET_Glyphs [].vi"/>
							</Item>
							<Item Name="GET" Type="Folder">
								<Item Name="GET_ActiveGlyph.vi" Type="VI" URL="resource/plugins/NIIconEditor/Class/Icon Library/GET/GET_ActiveGlyph.vi"/>
								<Item Name="GET_Glyphs [].vi" Type="VI" URL="resource/plugins/NIIconEditor/Class/Icon Library/GET/GET_Glyphs [].vi"/>
							</Item>
							<Item Name="Filter Graphics by Folder Name.vi" Type="VI" URL="resource/plugins/NIIconEditor/Miscellaneous/Graphics/Filter Graphics by Folder Name.vi"/>
							<Item Name="Glyphs Initialization.vi" Type="VI" URL="resource/plugins/NIIconEditor/Class/Icon Library/Initialization/Glyphs Initialization.vi"/>
						</Item>
					</Item>
					<Item Name="Settings" Type="Folder">
						<Item Name="Settings.lvclass" Type="LVClass" URL="resource/plugins/NIIconEditor/Class/Settings/Settings.lvclass">
							<Item Name="Settings.ctl" Type="Class Private Data" URL="resource/plugins/NIIconEditor/Class/Settings/Settings.lvclass/Settings.ctl"/>
							<Item Name="Initialization" Type="Folder">
								<Item Name="Initialize_IconEditorSettings_Tree.vi" Type="VI" URL="resource/plugins/NIIconEditor/User Dialogs/SubVIs/Initialize_IconEditorSettings_Tree.vi"/>
							</Item>
							<Item Name="GET" Type="Folder">
								<Item Name="GET_Save_Layers_with_VI.vi" Type="VI" URL="resource/plugins/NIIconEditor/Class/Settings/GET/GET_Save_Layers_with_VI.vi"/>
								<Item Name="GET_3rd party Templates.vi" Type="VI" URL="resource/plugins/NIIconEditor/Class/Settings/GET/GET_3rd party Templates.vi"/>
								<Item Name="GET_Text.vi" Type="VI" URL="resource/plugins/NIIconEditor/Class/Settings/GET/GET_Text.vi"/>
								<Item Name="GET_Show.vi" Type="VI" URL="resource/plugins/NIIconEditor/Class/Settings/GET/GET_Show.vi"/>
							</Item>
							<Item Name="SET" Type="Folder">
								<Item Name="SET_Text.vi" Type="VI" URL="resource/plugins/NIIconEditor/Class/Settings/SET/SET_Text.vi"/>
								<Item Name="SET_SaveLayersWithVI.vi" Type="VI" URL="resource/plugins/NIIconEditor/Class/Settings/SET/SET_SaveLayersWithVI.vi"/>
								<Item Name="SET_Show.vi" Type="VI" URL="resource/plugins/NIIconEditor/Class/Settings/SET/SET_Show.vi"/>
								<Item Name="SET_3rdPartyTemplates.vi" Type="VI" URL="resource/plugins/NIIconEditor/Class/Settings/SET/SET_3rdPartyTemplates.vi"/>
							</Item>
							<Item Name="Settings Initialization.vi" Type="VI" URL="resource/plugins/NIIconEditor/Class/Settings/Initialization/Settings Initialization.vi"/>
						</Item>
					</Item>
					<Item Name="Tools" Type="Folder">
						<Item Name="Tools Paint.lvclass" Type="LVClass" URL="resource/plugins/NIIconEditor/Class/Tools/Tools Paint.lvclass">
							<Item Name="Tools Paint.ctl" Type="Class Private Data" URL="resource/plugins/NIIconEditor/Class/Tools/Tools Paint.lvclass/Tools Paint.ctl"/>
							<Item Name="Paint" Type="Folder">
								<Item Name="Selection.vi" Type="VI" URL="resource/plugins/NIIconEditor/Class/Tools/Selection.vi"/>
								<Item Name="Move.vi" Type="VI" URL="resource/plugins/NIIconEditor/Class/Tools/Move.vi"/>
								<Item Name="Pen.vi" Type="VI" URL="resource/plugins/NIIconEditor/Class/Tools/Pen.vi"/>
								<Item Name="Line.vi" Type="VI" URL="resource/plugins/NIIconEditor/Class/Tools/Line.vi"/>
								<Item Name="Circle.vi" Type="VI" URL="resource/plugins/NIIconEditor/Class/Tools/Circle.vi"/>
								<Item Name="Rectangle.vi" Type="VI" URL="resource/plugins/NIIconEditor/Class/Tools/Rectangle.vi"/>
								<Item Name="Dropper.vi" Type="VI" URL="resource/plugins/NIIconEditor/Class/Tools/Dropper.vi"/>
								<Item Name="Eraser.vi" Type="VI" URL="resource/plugins/NIIconEditor/Class/Tools/Eraser.vi"/>
								<Item Name="Fill.vi" Type="VI" URL="resource/plugins/NIIconEditor/Class/Tools/Fill.vi"/>
							</Item>
							<Item Name="SET" Type="Folder">
								<Item Name="SET_ActiveTool.vi" Type="VI" URL="resource/plugins/NIIconEditor/Class/Tools/SET/SET_ActiveTool.vi"/>
							</Item>
							<Item Name="GET" Type="Folder">
								<Item Name="GET_ActiveTool.vi" Type="VI" URL="resource/plugins/NIIconEditor/Class/Tools/GET/GET_ActiveTool.vi"/>
							</Item>
							<Item Name="Misc" Type="Folder">
								<Item Name="DoubleClick.vi" Type="VI" URL="resource/plugins/NIIconEditor/Class/Tools/Misc/DoubleClick.vi"/>
								<Item Name="LayerGraphicManipulation.vi" Type="VI" URL="resource/plugins/NIIconEditor/Miscellaneous/Layer/LayerGraphicManipulation.vi"/>
							</Item>
						</Item>
					</Item>
				</Item>
				<Item Name="Controls" Type="Folder">
					<Item Name="Arrow Down.ctl" Type="VI" URL="resource/plugins/NIIconEditor/Controls/Arrow Down.ctl"/>
					<Item Name="Arrow Up.ctl" Type="VI" URL="resource/plugins/NIIconEditor/Controls/Arrow Up.ctl"/>
					<Item Name="Cancel.ctl" Type="VI" URL="/&lt;resource&gt;/plugins/NIIconEditor/Controls/Cancel.ctl"/>
					<Item Name="Circle.ctl" Type="VI" URL="resource/plugins/NIIconEditor/Controls/Circle.ctl"/>
					<Item Name="Class Pool.ctl" Type="VI" URL="/&lt;resource&gt;/plugins/NIIconEditor/Controls/Class Pool.ctl"/>
					<Item Name="ColorChange.ctl" Type="VI" URL="resource/plugins/NIIconEditor/Controls/ColorChange.ctl"/>
					<Item Name="DeleteLayer.ctl" Type="VI" URL="resource/plugins/NIIconEditor/Controls/DeleteLayer.ctl"/>
					<Item Name="DownloadFileType.ctl" Type="VI" URL="/&lt;resource&gt;/plugins/NIIconEditor/Controls/DownloadFileType.ctl"/>
					<Item Name="Draw.ctl" Type="VI" URL="/&lt;resource&gt;/plugins/NIIconEditor/Controls/Draw.ctl"/>
					<Item Name="DrawAction.ctl" Type="VI" URL="/&lt;resource&gt;/plugins/NIIconEditor/Controls/DrawAction.ctl"/>
					<Item Name="Dropper.ctl" Type="VI" URL="resource/plugins/NIIconEditor/Controls/Dropper.ctl"/>
					<Item Name="FCircle.ctl" Type="VI" URL="resource/plugins/NIIconEditor/Controls/FCircle.ctl"/>
					<Item Name="FGV Action.ctl" Type="VI" URL="/&lt;resource&gt;/plugins/NIIconEditor/Controls/FGV Action.ctl"/>
					<Item Name="Fill.ctl" Type="VI" URL="resource/plugins/NIIconEditor/Controls/Fill.ctl"/>
					<Item Name="Flip.ctl" Type="VI" URL="resource/plugins/NIIconEditor/Controls/Flip.ctl"/>
					<Item Name="Font Size.ctl" Type="VI" URL="resource/plugins/NIIconEditor/Controls/Font Size.ctl"/>
					<Item Name="Framework Templates.ctl" Type="VI" URL="resource/plugins/NIIconEditor/Controls/Framework Templates.ctl"/>
					<Item Name="FRect.ctl" Type="VI" URL="resource/plugins/NIIconEditor/Controls/FRect.ctl"/>
					<Item Name="IconFilename.ctl" Type="VI" URL="resource/plugins/NIIconEditor/Controls/IconFilename.ctl"/>
					<Item Name="IconLibraryList.ctl" Type="VI" URL="resource/plugins/NIIconEditor/Controls/IconLibraryList.ctl"/>
					<Item Name="IE Classes.ctl" Type="VI" URL="resource/plugins/NIIconEditor/Controls/IE Classes.ctl"/>
					<Item Name="IE Data.ctl" Type="VI" URL="resource/plugins/NIIconEditor/Controls/IE Data.ctl"/>
					<Item Name="IE Symbols.ctl" Type="VI" URL="resource/plugins/NIIconEditor/Controls/IE Symbols.ctl"/>
					<Item Name="IERect.ctl" Type="VI" URL="resource/plugins/NIIconEditor/Controls/IERect.ctl"/>
					<Item Name="INI.ctl" Type="VI" URL="resource/plugins/NIIconEditor/Controls/INI.ctl"/>
					<Item Name="LayerList.ctl" Type="VI" URL="resource/plugins/NIIconEditor/Controls/LayerList.ctl"/>
					<Item Name="Line.ctl" Type="VI" URL="resource/plugins/NIIconEditor/Controls/Line.ctl"/>
					<Item Name="Move.ctl" Type="VI" URL="resource/plugins/NIIconEditor/Controls/Move.ctl"/>
					<Item Name="NewLayer.ctl" Type="VI" URL="resource/plugins/NIIconEditor/Controls/NewLayer.ctl"/>
					<Item Name="OK.ctl" Type="VI" URL="/&lt;resource&gt;/plugins/NIIconEditor/Controls/OK.ctl"/>
					<Item Name="OpenLayer.ctl" Type="VI" URL="/&lt;resource&gt;/plugins/NIIconEditor/Controls/OpenLayer.ctl"/>
					<Item Name="Path&amp;Icon.ctl" Type="VI" URL="resource/plugins/NIIconEditor/Controls/Path&amp;Icon.ctl"/>
					<Item Name="Pen.ctl" Type="VI" URL="resource/plugins/NIIconEditor/Controls/Pen.ctl"/>
					<Item Name="References Cluster.ctl" Type="VI" URL="resource/plugins/NIIconEditor/Controls/References Cluster.ctl"/>
					<Item Name="References.ctl" Type="VI" URL="/&lt;resource&gt;/plugins/NIIconEditor/Controls/References.ctl"/>
					<Item Name="Refresh.ctl" Type="VI" URL="resource/plugins/NIIconEditor/Controls/Refresh.ctl"/>
					<Item Name="Rotate.ctl" Type="VI" URL="resource/plugins/NIIconEditor/Controls/Rotate.ctl"/>
					<Item Name="Rotate_Flip.ctl" Type="VI" URL="/&lt;resource&gt;/plugins/NIIconEditor/Controls/Rotate_Flip.ctl"/>
					<Item Name="Rubber.ctl" Type="VI" URL="resource/plugins/NIIconEditor/Controls/Rubber.ctl"/>
					<Item Name="SaveLayer.ctl" Type="VI" URL="/&lt;resource&gt;/plugins/NIIconEditor/Controls/SaveLayer.ctl"/>
					<Item Name="Selection.ctl" Type="VI" URL="resource/plugins/NIIconEditor/Controls/Selection.ctl"/>
					<Item Name="Settings.ctl" Type="VI" URL="resource/plugins/NIIconEditor/Controls/Settings.ctl"/>
					<Item Name="SupportClass.ctl" Type="VI" URL="resource/plugins/NIIconEditor/Controls/SupportClass.ctl"/>
					<Item Name="SupportClass_Action.ctl" Type="VI" URL="resource/plugins/NIIconEditor/Controls/SupportClass_Action.ctl"/>
					<Item Name="Text.ctl" Type="VI" URL="resource/plugins/NIIconEditor/Controls/Text.ctl"/>
					<Item Name="Text_Specification.ctl" Type="VI" URL="/&lt;resource&gt;/plugins/NIIconEditor/Controls/Text_Specification.ctl"/>
					<Item Name="TextMarker.ctl" Type="VI" URL="resource/plugins/NIIconEditor/Controls/TextMarker.ctl"/>
					<Item Name="ToMoreSpecific_Faked2DArray.ctl" Type="VI" URL="resource/plugins/NIIconEditor/Controls/ToMoreSpecific_Faked2DArray.ctl"/>
					<Item Name="Tools.ctl" Type="VI" URL="resource/plugins/NIIconEditor/Controls/Tools.ctl"/>
					<Item Name="Undo Redo Action.ctl" Type="VI" URL="resource/plugins/NIIconEditor/Controls/Undo Redo Action.ctl"/>
					<Item Name="Undo Redo Type.ctl" Type="VI" URL="/&lt;resource&gt;/plugins/NIIconEditor/Controls/Undo Redo Type.ctl"/>
					<Item Name="Undo.ctl" Type="VI" URL="/&lt;resource&gt;/plugins/NIIconEditor/Controls/Undo.ctl"/>
					<Item Name="User Event Communication Enum.ctl" Type="VI" URL="/&lt;resource&gt;/plugins/NIIconEditor/Controls/User Event Communication Enum.ctl"/>
					<Item Name="User Event Communication.ctl" Type="VI" URL="/&lt;resource&gt;/plugins/NIIconEditor/Controls/User Event Communication.ctl"/>
					<Item Name="XMLDataStructureIconLibrary.ctl" Type="VI" URL="resource/plugins/NIIconEditor/Controls/XMLDataStructureIconLibrary.ctl"/>
				</Item>
				<Item Name="Global Variables" Type="Folder">
					<Item Name="Data.vi" Type="VI" URL="resource/plugins/NIIconEditor/Global Variables/Data.vi"/>
				</Item>
				<Item Name="Miscellaneous" Type="Folder">
					<Item Name="Clipboard" Type="Folder">
						<Item Name="IE Read from Clipboard.vi" Type="VI" URL="resource/plugins/NIIconEditor/Miscellaneous/Clipboard/IE Read from Clipboard.vi"/>
						<Item Name="IE Write to Clipboard.vi" Type="VI" URL="resource/plugins/NIIconEditor/Miscellaneous/Clipboard/IE Write to Clipboard.vi"/>
					</Item>
					<Item Name="Def FP Updates" Type="Folder">
						<Item Name="Defer_FP_Updates.vi" Type="VI" URL="resource/plugins/NIIconEditor/Miscellaneous/Def FP Updates/Defer_FP_Updates.vi"/>
					</Item>
					<Item Name="Draw" Type="Folder">
						<Item Name="Const Temp Coordinate 2 points.vi" Type="VI" URL="resource/plugins/NIIconEditor/Miscellaneous/Draw/Const Temp Coordinate 2 points.vi"/>
						<Item Name="Const Temp Coordinate 4 points.vi" Type="VI" URL="resource/plugins/NIIconEditor/Miscellaneous/Draw/Const Temp Coordinate 4 points.vi"/>
						<Item Name="DrawIcon.vi" Type="VI" URL="resource/plugins/NIIconEditor/Miscellaneous/Draw/DrawIcon.vi"/>
						<Item Name="IsCoordinateConstant.vi" Type="VI" URL="resource/plugins/NIIconEditor/Miscellaneous/Draw/IsCoordinateConstant.vi"/>
						<Item Name="Origin_or_TempCoordinate.vi" Type="VI" URL="resource/plugins/NIIconEditor/Miscellaneous/Draw/Origin_or_TempCoordinate.vi"/>
						<Item Name="PixelValue.vi" Type="VI" URL="resource/plugins/NIIconEditor/Miscellaneous/Draw/PixelValue.vi"/>
					</Item>
					<Item Name="Font" Type="Folder">
						<Item Name="Linux.vi" Type="VI" URL="resource/plugins/NIIconEditor/Miscellaneous/Font/Linux.vi"/>
						<Item Name="Mac.vi" Type="VI" URL="resource/plugins/NIIconEditor/Miscellaneous/Font/Mac.vi"/>
						<Item Name="Populate Font Control.vi" Type="VI" URL="resource/plugins/NIIconEditor/Miscellaneous/Font/Populate Font Control.vi"/>
						<Item Name="Windows.vi" Type="VI" URL="resource/plugins/NIIconEditor/Miscellaneous/Font/Windows.vi"/>
					</Item>
					<Item Name="Glyphs" Type="Folder">
						<Item Name="Glyph_MouseDown.vi" Type="VI" URL="resource/plugins/NIIconEditor/Miscellaneous/Glyphs/Glyph_MouseDown.vi"/>
						<Item Name="Populate Graphics.vi" Type="VI" URL="resource/plugins/NIIconEditor/Miscellaneous/Glyphs/Populate Graphics.vi"/>
						<Item Name="Prepare Glyphs for Display.vi" Type="VI" URL="resource/plugins/NIIconEditor/Miscellaneous/Glyphs/Prepare Glyphs for Display.vi"/>
						<Item Name="SET_Glyph.vi" Type="VI" URL="resource/plugins/NIIconEditor/Miscellaneous/Glyphs/SET_Glyph.vi"/>
						<Item Name="SET_ToolGraphic.vi" Type="VI" URL="resource/plugins/NIIconEditor/Miscellaneous/Glyphs/SET_ToolGraphic.vi"/>
						<Item Name="TemporaryGlyphView.vi" Type="VI" URL="resource/plugins/NIIconEditor/Miscellaneous/Glyphs/TemporaryGlyphView.vi"/>
					</Item>
					<Item Name="Graphics" Type="Folder">
						<Item Name="BuildCategories.vi" Type="VI" URL="resource/plugins/NIIconEditor/Miscellaneous/Graphics/BuildCategories.vi"/>
						<Item Name="ChangeRefreshGraphicsState.vi" Type="VI" URL="resource/plugins/NIIconEditor/Miscellaneous/Graphics/ChangeRefreshGraphicsState.vi"/>
						<Item Name="CorruptIconErrorMessage.vi" Type="VI" URL="resource/plugins/NIIconEditor/Miscellaneous/Graphics/CorruptIconErrorMessage.vi"/>
						<Item Name="Filter Graphics by File Name.vi" Type="VI" URL="resource/plugins/NIIconEditor/Miscellaneous/Graphics/Filter Graphics by File Name.vi"/>
						<Item Name="Launch Dynamically Load Graphics.vi" Type="VI" URL="resource/plugins/NIIconEditor/Miscellaneous/Graphics/Launch Dynamically Load Graphics.vi"/>
						<Item Name="LoadGraphics.vi" Type="VI" URL="resource/plugins/NIIconEditor/Miscellaneous/Graphics/LoadGraphics.vi"/>
						<Item Name="LoadTemplates.vi" Type="VI" URL="resource/plugins/NIIconEditor/Miscellaneous/Graphics/LoadTemplates.vi"/>
						<Item Name="Populate Tree with Categories.vi" Type="VI" URL="resource/plugins/NIIconEditor/Miscellaneous/Graphics/Populate Tree with Categories.vi"/>
						<Item Name="Pull data from disc.vi" Type="VI" URL="resource/plugins/NIIconEditor/Miscellaneous/Graphics/Pull data from disc.vi"/>
						<Item Name="RefreshAnimation.mng" Type="Document" URL="/&lt;resource&gt;/plugins/NIIconEditor/Miscellaneous/Graphics/RefreshAnimation.mng"/>
						<Item Name="RefreshAnimation.xcf" Type="Document" URL="/&lt;resource&gt;/plugins/NIIconEditor/Miscellaneous/Graphics/RefreshAnimation.xcf"/>
					</Item>
					<Item Name="Icon Editor" Type="Folder">
						<Item Name="Add new Layer.vi" Type="VI" URL="resource/plugins/NIIconEditor/Miscellaneous/Icon Editor/Add new Layer.vi"/>
						<Item Name="Alignment Value Change.vi" Type="VI" URL="resource/plugins/NIIconEditor/Miscellaneous/Icon Editor/Alignment Value Change.vi"/>
						<Item Name="Call Keep IE in Memory.vi" Type="VI" URL="resource/plugins/NIIconEditor/Miscellaneous/Icon Editor/Call Keep IE in Memory.vi"/>
						<Item Name="Change Behavior IE window.vi" Type="VI" URL="/&lt;resource&gt;/plugins/NIIconEditor/Miscellaneous/Icon Editor/Change Behavior IE window.vi"/>
						<Item Name="Change Mouse Cursor.vi" Type="VI" URL="resource/plugins/NIIconEditor/Miscellaneous/Icon Editor/Change Mouse Cursor.vi"/>
						<Item Name="Clear User Layers.vi" Type="VI" URL="resource/plugins/NIIconEditor/Miscellaneous/Icon Editor/Clear User Layers.vi"/>
						<Item Name="Delete Selected Layers.vi" Type="VI" URL="resource/plugins/NIIconEditor/Miscellaneous/Icon Editor/Delete Selected Layers.vi"/>
						<Item Name="Escape.vi" Type="VI" URL="resource/plugins/NIIconEditor/Miscellaneous/Icon Editor/Escape.vi"/>
						<Item Name="Fire Body Text Change event.vi" Type="VI" URL="resource/plugins/NIIconEditor/Miscellaneous/Icon Editor/Fire Body Text Change event.vi"/>
						<Item Name="Icon Editor Help.vi" Type="VI" URL="/&lt;resource&gt;/plugins/NIIconEditor/Miscellaneous/Icon Editor/Icon Editor Help.vi"/>
						<Item Name="Icon Editor Init Refs.vi" Type="VI" URL="resource/plugins/NIIconEditor/Miscellaneous/Icon Editor/Icon Editor Init Refs.vi"/>
						<Item Name="Icon Editor Properties Help.vi" Type="VI" URL="/&lt;resource&gt;/plugins/NIIconEditor/Miscellaneous/Icon Editor/Icon Editor Properties Help.vi"/>
						<Item Name="Icon Initialization.vi" Type="VI" URL="resource/plugins/NIIconEditor/Miscellaneous/Icon Editor/Icon Initialization.vi"/>
						<Item Name="IE Save dialog build path.vi" Type="VI" URL="resource/plugins/NIIconEditor/Miscellaneous/Icon Editor/IE Save dialog build path.vi"/>
						<Item Name="Keep IE in Memory.vi" Type="VI" URL="/&lt;resource&gt;/plugins/NIIconEditor/Miscellaneous/Icon Editor/Keep IE in Memory.vi"/>
						<Item Name="LayerCluster_ValueChange.vi" Type="VI" URL="resource/plugins/NIIconEditor/Miscellaneous/Icon Editor/LayerCluster_ValueChange.vi"/>
						<Item Name="MenuSelection(User).vi" Type="VI" URL="resource/plugins/NIIconEditor/Miscellaneous/Icon Editor/MenuSelection(User).vi"/>
						<Item Name="Mouse Down_Glyphs.vi" Type="VI" URL="resource/plugins/NIIconEditor/Miscellaneous/Icon Editor/Mouse Down_Glyphs.vi"/>
						<Item Name="Mouse Down_Templates.vi" Type="VI" URL="resource/plugins/NIIconEditor/Miscellaneous/Icon Editor/Mouse Down_Templates.vi"/>
						<Item Name="Mouse Down_Tree.vi" Type="VI" URL="resource/plugins/NIIconEditor/Miscellaneous/Icon Editor/Mouse Down_Tree.vi"/>
						<Item Name="Mouse Down_User Layers.vi" Type="VI" URL="resource/plugins/NIIconEditor/Miscellaneous/Icon Editor/Mouse Down_User Layers.vi"/>
						<Item Name="MouseDown.vi" Type="VI" URL="resource/plugins/NIIconEditor/Miscellaneous/Icon Editor/MouseDown.vi"/>
						<Item Name="MouseDown_Body Text.vi" Type="VI" URL="resource/plugins/NIIconEditor/Miscellaneous/Icon Editor/MouseDown_Body Text.vi"/>
						<Item Name="MouseMove.vi" Type="VI" URL="resource/plugins/NIIconEditor/Miscellaneous/Icon Editor/MouseMove.vi"/>
						<Item Name="PictureControl_MouseUp.vi" Type="VI" URL="resource/plugins/NIIconEditor/Miscellaneous/Icon Editor/PictureControl_MouseUp.vi"/>
						<Item Name="populate tree.vi" Type="VI" URL="resource/plugins/NIIconEditor/Miscellaneous/Icon Editor/populate tree.vi"/>
						<Item Name="Reset layer template selection.vi" Type="VI" URL="resource/plugins/NIIconEditor/Miscellaneous/Icon Editor/Reset layer template selection.vi"/>
						<Item Name="RotateFlip.vi" Type="VI" URL="resource/plugins/NIIconEditor/Miscellaneous/Icon Editor/RotateFlip.vi"/>
						<Item Name="Save Graphic Overwrite.vi" Type="VI" URL="resource/plugins/NIIconEditor/Miscellaneous/Icon Editor/Save Graphic Overwrite.vi"/>
						<Item Name="Save Graphic.vi" Type="VI" URL="resource/plugins/NIIconEditor/Miscellaneous/Icon Editor/Save Graphic.vi"/>
						<Item Name="Template_MouseDown.vi" Type="VI" URL="resource/plugins/NIIconEditor/Miscellaneous/Icon Editor/Template_MouseDown.vi"/>
						<Item Name="Update glyph path string.vi" Type="VI" URL="resource/plugins/NIIconEditor/Miscellaneous/Icon Editor/Update glyph path string.vi"/>
						<Item Name="UpdateLayerView_ScrollbarChanged.vi" Type="VI" URL="resource/plugins/NIIconEditor/Miscellaneous/Icon Editor/UpdateLayerView_ScrollbarChanged.vi"/>
						<Item Name="Value Change_Body Text.vi" Type="VI" URL="resource/plugins/NIIconEditor/Miscellaneous/Icon Editor/Value Change_Body Text.vi"/>
						<Item Name="Value Change_Top or Bottom Layer.vi" Type="VI" URL="resource/plugins/NIIconEditor/Miscellaneous/Icon Editor/Value Change_Top or Bottom Layer.vi"/>
					</Item>
					<Item Name="Key Down Up" Type="Folder">
						<Item Name="Key Down Up Layers.vi" Type="VI" URL="/&lt;resource&gt;/plugins/NIIconEditor/Miscellaneous/Key Down Up/Key Down Up Layers.vi"/>
						<Item Name="KeyDown.vi" Type="VI" URL="resource/plugins/NIIconEditor/Miscellaneous/Key Down Up/KeyDown.vi"/>
						<Item Name="KeyUp.vi" Type="VI" URL="resource/plugins/NIIconEditor/Miscellaneous/Key Down Up/KeyUp.vi"/>
						<Item Name="Move Selected Layers.vi" Type="VI" URL="resource/plugins/NIIconEditor/Miscellaneous/Key Down Up/Move Selected Layers.vi"/>
						<Item Name="Process Active Data Shift Key.vi" Type="VI" URL="/&lt;resource&gt;/plugins/NIIconEditor/Miscellaneous/Key Down Up/Process Active Data Shift Key.vi"/>
					</Item>
					<Item Name="Layer" Type="Folder">
						<Item Name="DeleteLayer.vi" Type="VI" URL="resource/plugins/NIIconEditor/Miscellaneous/Layer/DeleteLayer.vi"/>
						<Item Name="DeselectLayer.vi" Type="VI" URL="resource/plugins/NIIconEditor/Miscellaneous/Layer/DeselectLayer.vi"/>
						<Item Name="Separate Selected Layers.vi" Type="VI" URL="resource/plugins/NIIconEditor/Miscellaneous/Layer/Separate Selected Layers.vi"/>
						<Item Name="Split_Layers.vi" Type="VI" URL="resource/plugins/NIIconEditor/Miscellaneous/Layer/Split_Layers.vi"/>
						<Item Name="ViewLayer.vi" Type="VI" URL="resource/plugins/NIIconEditor/Miscellaneous/Layer/ViewLayer.vi"/>
					</Item>
					<Item Name="Load Unload" Type="Folder">
						<Item Name="Export_Clipboard.vi" Type="VI" URL="resource/plugins/NIIconEditor/Miscellaneous/Load Unload/Export_Clipboard.vi"/>
						<Item Name="Flatten Icon.vi" Type="VI" URL="resource/plugins/NIIconEditor/Miscellaneous/Load Unload/Flatten Icon.vi"/>
						<Item Name="Flatten Layers.vi" Type="VI" URL="resource/plugins/NIIconEditor/Miscellaneous/Load Unload/Flatten Layers.vi"/>
						<Item Name="Get Color Icon from Caller.vi" Type="VI" URL="resource/plugins/NIIconEditor/Miscellaneous/Load Unload/Get Color Icon from Caller.vi"/>
						<Item Name="Import_Clipboard.vi" Type="VI" URL="resource/plugins/NIIconEditor/Miscellaneous/Load Unload/Import_Clipboard.vi"/>
						<Item Name="Load.vi" Type="VI" URL="resource/plugins/NIIconEditor/Miscellaneous/Load Unload/Load.vi"/>
						<Item Name="Read Data from Caller.vi" Type="VI" URL="resource/plugins/NIIconEditor/Miscellaneous/Load Unload/Read Data from Caller.vi"/>
						<Item Name="Read Glyphs from  File.vi" Type="VI" URL="resource/plugins/NIIconEditor/Miscellaneous/Load Unload/Read Glyphs from  File.vi"/>
						<Item Name="ReadDataFromLabVIEWINI.vi" Type="VI" URL="resource/plugins/NIIconEditor/Miscellaneous/Load Unload/ReadDataFromLabVIEWINI.vi"/>
						<Item Name="Reset Layer VI.vi" Type="VI" URL="resource/plugins/NIIconEditor/Miscellaneous/Load Unload/Reset Layer VI.vi"/>
						<Item Name="Return MutationCode Folder.vi" Type="VI" URL="/&lt;resource&gt;/plugins/NIIconEditor/Miscellaneous/Load Unload/Return MutationCode Folder.vi"/>
						<Item Name="Unflatten Icon.vi" Type="VI" URL="resource/plugins/NIIconEditor/Miscellaneous/Load Unload/Unflatten Icon.vi"/>
						<Item Name="Unflatten Layers.vi" Type="VI" URL="resource/plugins/NIIconEditor/Miscellaneous/Load Unload/Unflatten Layers.vi"/>
						<Item Name="Write Data to Caller.vi" Type="VI" URL="resource/plugins/NIIconEditor/Miscellaneous/Load Unload/Write Data to Caller.vi"/>
						<Item Name="Write Glyphs to  File.vi" Type="VI" URL="resource/plugins/NIIconEditor/Miscellaneous/Load Unload/Write Glyphs to  File.vi"/>
						<Item Name="Write INI Tokens and VI Tags.vi" Type="VI" URL="resource/plugins/NIIconEditor/Miscellaneous/Load Unload/Write INI Tokens and VI Tags.vi"/>
						<Item Name="WriteDataToLabVIEWINI.vi" Type="VI" URL="resource/plugins/NIIconEditor/Miscellaneous/Load Unload/WriteDataToLabVIEWINI.vi"/>
					</Item>
					<Item Name="Menubar" Type="Folder">
						<Item Name="EnableDisable Combine Layers.vi" Type="VI" URL="resource/plugins/NIIconEditor/Miscellaneous/Menubar/EnableDisable Combine Layers.vi"/>
						<Item Name="ShowLayersPalette.vi" Type="VI" URL="resource/plugins/NIIconEditor/Miscellaneous/Menubar/ShowLayersPalette.vi"/>
						<Item Name="ShowTerminals.vi" Type="VI" URL="resource/plugins/NIIconEditor/Miscellaneous/Menubar/ShowTerminals.vi"/>
					</Item>
					<Item Name="ni.com_iconlibrary" Type="Folder">
						<Item Name="Analyze XML stream.vi" Type="VI" URL="resource/plugins/NIIconEditor/Miscellaneous/ni.com_iconlibrary/Analyze XML stream.vi"/>
						<Item Name="Check whether installed.vi" Type="VI" URL="resource/plugins/NIIconEditor/Miscellaneous/ni.com_iconlibrary/Check whether installed.vi"/>
						<Item Name="ExtractDataFromXML.vi" Type="VI" URL="resource/plugins/NIIconEditor/Miscellaneous/ni.com_iconlibrary/ExtractDataFromXML.vi"/>
						<Item Name="IconlibraryStuffInProgress.vi" Type="VI" URL="resource/plugins/NIIconEditor/Miscellaneous/ni.com_iconlibrary/IconlibraryStuffInProgress.vi"/>
						<Item Name="Install Glyphs.vi" Type="VI" URL="resource/plugins/NIIconEditor/Miscellaneous/ni.com_iconlibrary/Install Glyphs.vi"/>
						<Item Name="Manual User Input.vi" Type="VI" URL="resource/plugins/NIIconEditor/Miscellaneous/ni.com_iconlibrary/Manual User Input.vi"/>
						<Item Name="ni.com_iconlibrary.vi" Type="VI" URL="resource/plugins/NIIconEditor/Miscellaneous/ni.com_iconlibrary/ni.com_iconlibrary.vi"/>
						<Item Name="ResolveURLbyUsingInfoCode.vi" Type="VI" URL="/&lt;resource&gt;/plugins/NIIconEditor/Miscellaneous/ni.com_iconlibrary/ResolveURLbyUsingInfoCode.vi"/>
					</Item>
					<Item Name="Tools" Type="Folder">
						<Item Name="Get Color Not In Image.vi" Type="VI" URL="/&lt;resource&gt;/plugins/NIIconEditor/Miscellaneous/Tools/Get Color Not In Image.vi"/>
						<Item Name="Mouse Down.vi" Type="VI" URL="resource/plugins/NIIconEditor/Miscellaneous/Tools/Mouse Down.vi"/>
						<Item Name="Selection_PrepareIcon.vi" Type="VI" URL="resource/plugins/NIIconEditor/Miscellaneous/Tools/Selection_PrepareIcon.vi"/>
						<Item Name="Selection_SetNewData.vi" Type="VI" URL="resource/plugins/NIIconEditor/Miscellaneous/Tools/Selection_SetNewData.vi"/>
						<Item Name="Value Change_Tools.vi" Type="VI" URL="resource/plugins/NIIconEditor/Miscellaneous/Tools/Value Change_Tools.vi"/>
						<Item Name="ValueSignalingTool.vi" Type="VI" URL="resource/plugins/NIIconEditor/Miscellaneous/Tools/ValueSignalingTool.vi"/>
						<Item Name="VisibleTextMarker.vi" Type="VI" URL="resource/plugins/NIIconEditor/Miscellaneous/Tools/VisibleTextMarker.vi"/>
						<Item Name="WriteText.vi" Type="VI" URL="resource/plugins/NIIconEditor/Miscellaneous/Tools/WriteText.vi"/>
					</Item>
					<Item Name="Undo Redo" Type="Folder">
						<Item Name="Add Data to History.vi" Type="VI" URL="resource/plugins/NIIconEditor/Miscellaneous/Undo Redo/Add Data to History.vi"/>
						<Item Name="FGV_Undo Redo.vi" Type="VI" URL="resource/plugins/NIIconEditor/Miscellaneous/Undo Redo/FGV_Undo Redo.vi"/>
						<Item Name="Limit value.vi" Type="VI" URL="resource/plugins/NIIconEditor/Miscellaneous/Undo Redo/Limit value.vi"/>
						<Item Name="Replay Data from History.vi" Type="VI" URL="resource/plugins/NIIconEditor/Miscellaneous/Undo Redo/Replay Data from History.vi"/>
						<Item Name="Wrap.vi" Type="VI" URL="resource/plugins/NIIconEditor/Miscellaneous/Undo Redo/Wrap.vi"/>
					</Item>
					<Item Name="User Events" Type="Folder">
						<Item Name="Initialization_UserEvents.vi" Type="VI" URL="resource/plugins/NIIconEditor/Miscellaneous/User Events/Initialization_UserEvents.vi"/>
					</Item>
					<Item Name="AssessRectangle.vi" Type="VI" URL="resource/plugins/NIIconEditor/Miscellaneous/AssessRectangle.vi"/>
					<Item Name="Buffer for lossless tracking.vi" Type="VI" URL="resource/plugins/NIIconEditor/Miscellaneous/Buffer for lossless tracking.vi"/>
					<Item Name="CalculateAntsRect.vi" Type="VI" URL="resource/plugins/NIIconEditor/Miscellaneous/CalculateAntsRect.vi"/>
					<Item Name="Classes Initialization.vi" Type="VI" URL="resource/plugins/NIIconEditor/Miscellaneous/Classes Initialization.vi"/>
					<Item Name="Connector Pane Initialization.vi" Type="VI" URL="resource/plugins/NIIconEditor/Miscellaneous/Connector Pane Initialization.vi"/>
					<Item Name="CoordinatesCorrection.vi" Type="VI" URL="resource/plugins/NIIconEditor/Miscellaneous/CoordinatesCorrection.vi"/>
					<Item Name="Create new class icon user layers.vi" Type="VI" URL="/&lt;resource&gt;/plugins/NIIconEditor/Miscellaneous/Create new class icon user layers.vi"/>
					<Item Name="Create new layer_LayerName_Picture.vi" Type="VI" URL="resource/plugins/NIIconEditor/Miscellaneous/Create new layer_LayerName_Picture.vi"/>
					<Item Name="DealWithScrollbars.vi" Type="VI" URL="resource/plugins/NIIconEditor/Miscellaneous/DealWithScrollbars.vi"/>
					<Item Name="Extract LV Icon Data.vi" Type="VI" URL="resource/plugins/NIIconEditor/Miscellaneous/Extract LV Icon Data.vi"/>
					<Item Name="Finalize Movement.vi" Type="VI" URL="resource/plugins/NIIconEditor/Miscellaneous/Finalize Movement.vi"/>
					<Item Name="Finalize Text.vi" Type="VI" URL="resource/plugins/NIIconEditor/Miscellaneous/Finalize Text.vi"/>
					<Item Name="Flip color refs.vi" Type="VI" URL="resource/plugins/NIIconEditor/Miscellaneous/Flip color refs.vi"/>
					<Item Name="Get Icon Editor Context.vi" Type="VI" URL="resource/plugins/NIIconEditor/Miscellaneous/Icon Editor/Get Icon Editor Context.vi"/>
					<Item Name="Get Monochrome Icon from Caller.vi" Type="VI" URL="resource/plugins/NIIconEditor/Miscellaneous/Get Monochrome Icon from Caller.vi"/>
					<Item Name="GetComparisonResult4Graphis.vi" Type="VI" URL="resource/plugins/NIIconEditor/Miscellaneous/GetComparisonResult4Graphis.vi"/>
					<Item Name="IEGlyphFolderConstant.vi" Type="VI" URL="/&lt;resource&gt;/plugins/NIIconEditor/Miscellaneous/IEGlyphFolderConstant.vi"/>
					<Item Name="IETemplateLibraryFolderConstant.vi" Type="VI" URL="/&lt;resource&gt;/plugins/NIIconEditor/Miscellaneous/IETemplateLibraryFolderConstant.vi"/>
					<Item Name="IETemplateVIFolderConstant.vi" Type="VI" URL="/&lt;resource&gt;/plugins/NIIconEditor/Miscellaneous/IETemplateVIFolderConstant.vi"/>
					<Item Name="ImageDataToIconPreview.vi" Type="VI" URL="resource/plugins/NIIconEditor/Miscellaneous/ImageDataToIconPreview.vi"/>
					<Item Name="IsAntsRectValid.vi" Type="VI" URL="resource/plugins/NIIconEditor/Miscellaneous/IsAntsRectValid.vi"/>
					<Item Name="Launch_VI_Asynchronously.vi" Type="VI" URL="/&lt;resource&gt;/plugins/NIIconEditor/Miscellaneous/Launch_VI_Asynchronously.vi"/>
					<Item Name="ListGlyphsAndTemplates.vi" Type="VI" URL="resource/plugins/NIIconEditor/Miscellaneous/ListGlyphsAndTemplates.vi"/>
					<Item Name="Load Glyph from File.vi" Type="VI" URL="resource/plugins/NIIconEditor/Miscellaneous/Load Glyph from File.vi"/>
					<Item Name="Magic Active Layer Constant.vi" Type="VI" URL="resource/plugins/NIIconEditor/Miscellaneous/Magic Active Layer Constant.vi"/>
					<Item Name="MoveLayers.vi" Type="VI" URL="resource/plugins/NIIconEditor/Miscellaneous/MoveLayers.vi"/>
					<Item Name="Populate Font ComboBox.vi" Type="VI" URL="resource/plugins/NIIconEditor/Miscellaneous/Populate Font ComboBox.vi"/>
					<Item Name="PrepareData4HTML.vi" Type="VI" URL="resource/plugins/NIIconEditor/Miscellaneous/PrepareData4HTML.vi"/>
					<Item Name="PrepareTemporaryView.vi" Type="VI" URL="resource/plugins/NIIconEditor/Miscellaneous/PrepareTemporaryView.vi"/>
					<Item Name="Process Temporary View Layers.vi" Type="VI" URL="resource/plugins/NIIconEditor/Miscellaneous/Process Temporary View Layers.vi"/>
					<Item Name="Remove invalid characters.vi" Type="VI" URL="resource/plugins/NIIconEditor/Miscellaneous/Remove invalid characters.vi"/>
					<Item Name="SetCursor.vi" Type="VI" URL="resource/plugins/NIIconEditor/Miscellaneous/SetCursor.vi"/>
					<Item Name="Settings Init.vi" Type="VI" URL="resource/plugins/NIIconEditor/Miscellaneous/Settings Init.vi"/>
					<Item Name="Settings Requested Path.vi" Type="VI" URL="resource/plugins/NIIconEditor/Miscellaneous/Settings Requested Path.vi"/>
					<Item Name="Settings Shutdown.vi" Type="VI" URL="resource/plugins/NIIconEditor/Miscellaneous/Settings Shutdown.vi"/>
					<Item Name="Specify Path Enum.vi" Type="VI" URL="resource/plugins/NIIconEditor/Miscellaneous/Specify Path Enum.vi"/>
					<Item Name="Truncate string.vi" Type="VI" URL="resource/plugins/NIIconEditor/Miscellaneous/Truncate string.vi"/>
					<Item Name="Write Error to File.vi" Type="VI" URL="/&lt;resource&gt;/plugins/NIIconEditor/Miscellaneous/Write Error to File.vi"/>
				</Item>
				<Item Name="Support" Type="Folder">
					<Item Name="ApplyLibIconOverlayToVIIcon.vi" Type="VI" URL="/&lt;resource&gt;/plugins/NIIconEditor/Support/ApplyLibIconOverlayToVIIcon.vi"/>
					<Item Name="Call Keep ApplyLib in Memory.vi" Type="VI" URL="/&lt;resource&gt;/plugins/NIIconEditor/Support/Call Keep ApplyLib in Memory.vi"/>
					<Item Name="Create or Substitute NI_Layer layer.vi" Type="VI" URL="resource/plugins/NIIconEditor/Support/Create or Substitute NI_Layer layer.vi"/>
					<Item Name="DefaultIconGlyphData.vi" Type="VI" URL="resource/plugins/NIIconEditor/Support/DefaultIconGlyphData.vi"/>
					<Item Name="Get 32x32 Image Data.vi" Type="VI" URL="/&lt;resource&gt;/plugins/NIIconEditor/Support/Get 32x32 Image Data.vi"/>
					<Item Name="Get VI Library.vi" Type="VI" URL="/&lt;resource&gt;/plugins/NIIconEditor/Support/Get VI Library.vi"/>
					<Item Name="GetLibIconForVIIconOverlay.vi" Type="VI" URL="/&lt;resource&gt;/plugins/NIIconEditor/Support/GetLibIconForVIIconOverlay.vi"/>
					<Item Name="GetLibIconForVIIconOverlayFromVI.vi" Type="VI" URL="/&lt;resource&gt;/plugins/NIIconEditor/Support/GetLibIconForVIIconOverlayFromVI.vi"/>
					<Item Name="GetOffsetRWIcon.vi" Type="VI" URL="/&lt;resource&gt;/plugins/NIIconEditor/Support/GetOffsetRWIcon.vi"/>
					<Item Name="Icon Editor First Call.vi" Type="VI" URL="resource/plugins/NIIconEditor/Support/Icon Editor First Call.vi"/>
					<Item Name="IE_Open Help Link.vi" Type="VI" URL="resource/plugins/NIIconEditor/Support/IE_Open Help Link.vi"/>
					<Item Name="IE_Resolve Symbolic Paths.vi" Type="VI" URL="resource/plugins/NIIconEditor/Support/IE_Resolve Symbolic Paths.vi"/>
					<Item Name="Keep ApplyLib in Memory.vi" Type="VI" URL="/&lt;resource&gt;/plugins/NIIconEditor/Support/Keep ApplyLib in Memory.vi"/>
					<Item Name="lv_icon.rtm" Type="Document" URL="/&lt;resource&gt;/plugins/NIIconEditor/Support/lv_icon.rtm"/>
				</Item>
				<Item Name="User Dialogs" Type="Folder">
					<Item Name="IconEditorSettings.vi" Type="VI" URL="resource/plugins/NIIconEditor/User Dialogs/IconEditorSettings.vi"/>
				</Item>
				<Item Name="Delete Icon Editor Source Files.vi" Type="VI" URL="/&lt;resource&gt;/plugins/NIIconEditor/Delete Icon Editor Source Files.vi"/>
				<Item Name="Get Callers of Icon Editor Packed Library.vi" Type="VI" URL="/&lt;resource&gt;/plugins/NIIconEditor/Get Callers of Icon Editor Packed Library.vi"/>
				<Item Name="Get Callers of Icon Editor Source Files.vi" Type="VI" URL="/&lt;resource&gt;/plugins/NIIconEditor/Get Callers of Icon Editor Source Files.vi"/>
				<Item Name="Get Icon Editor Source Paths.vi" Type="VI" URL="/&lt;resource&gt;/plugins/NIIconEditor/Get Icon Editor Source Paths.vi"/>
				<Item Name="Launch Icon Editor From String.vi" Type="VI" URL="/&lt;resource&gt;/plugins/NIIconEditor/Launch Icon Editor From String.vi"/>
			</Item>
			<Item Name="lv_icon.lvlib" Type="Library" URL="vi.lib/LabVIEW Icon API/lv_icon/lv_icon.lvlib">
				<Item Name="Other" Type="Folder">
					<Item Name="Adjust temporary rotate and flip rectangle.vi" Type="VI" URL="/&lt;vilib&gt;/LabVIEW Icon API/lv_icon/Support/Adjust temporary rotate and flip rectangle.vi"/>
					<Item Name="Apply Opacity.vi" Type="VI" URL="vi.lib/LabVIEW Icon API/lv_icon/Support/Apply Opacity.vi"/>
					<Item Name="Apply Transparency.vi" Type="VI" URL="vi.lib/LabVIEW Icon API/lv_icon/Support/Apply Transparency.vi"/>
					<Item Name="ApplyLVClassIconOverlayToVIIcon.vi" Type="VI" URL="/&lt;vilib&gt;/LabVIEW Icon API/lv_icon/Support/ApplyLVClassIconOverlayToVIIcon.vi"/>
					<Item Name="Average Grayscale of Line.vi" Type="VI" URL="vi.lib/LabVIEW Icon API/lv_icon/Support/Average Grayscale of Line.vi"/>
					<Item Name="Calculate Body Text Position.vi" Type="VI" URL="vi.lib/LabVIEW Icon API/lv_icon/Support/Calculate Body Text Position.vi"/>
					<Item Name="Check Color.vi" Type="VI" URL="vi.lib/LabVIEW Icon API/lv_icon/Support/Check Color.vi"/>
					<Item Name="Create Color Array.vi" Type="VI" URL="vi.lib/LabVIEW Icon API/lv_icon/Support/Create Color Array.vi"/>
					<Item Name="Create default Layer.vi" Type="VI" URL="vi.lib/LabVIEW Icon API/lv_icon/Support/Create default Layer.vi"/>
					<Item Name="Create default LV Icon Data.vi" Type="VI" URL="vi.lib/LabVIEW Icon API/lv_icon/Support/Create default LV Icon Data.vi"/>
					<Item Name="Create Layer from Image.vi" Type="VI" URL="vi.lib/LabVIEW Icon API/lv_icon/Support/Create Layer from Image.vi"/>
					<Item Name="Deserialize Picture Control Data.vi" Type="VI" URL="vi.lib/LabVIEW Icon API/lv_icon/Support/Deserialize Picture Control Data.vi"/>
					<Item Name="Draw Layers.vi" Type="VI" URL="vi.lib/LabVIEW Icon API/lv_icon/Support/Draw Layers.vi"/>
					<Item Name="Draw Picture based on Origin.vi" Type="VI" URL="vi.lib/LabVIEW Icon API/lv_icon/Support/Draw Picture based on Origin.vi"/>
					<Item Name="Extract Data.vi" Type="VI" URL="vi.lib/LabVIEW Icon API/lv_icon/Support/Extract Data.vi"/>
					<Item Name="Fill.vi" Type="VI" URL="vi.lib/LabVIEW Icon API/lv_icon/Support/Fill.vi"/>
					<Item Name="FilterEmptyLayerIcons.vi" Type="VI" URL="/&lt;vilib&gt;/LabVIEW Icon API/lv_icon/Support/FilterEmptyLayerIcons.vi"/>
					<Item Name="Find BG Color Peak.vi" Type="VI" URL="/&lt;vilib&gt;/LabVIEW Icon API/lv_icon/Support/Find BG Color Peak.vi"/>
					<Item Name="Find Neighbours.vi" Type="VI" URL="vi.lib/LabVIEW Icon API/lv_icon/Support/Find Neighbours.vi"/>
					<Item Name="Find Start and Endpoint Body Text.vi" Type="VI" URL="vi.lib/LabVIEW Icon API/lv_icon/Support/Find Start and Endpoint Body Text.vi"/>
					<Item Name="Flatten Load &amp; Unload.vi" Type="VI" URL="/&lt;vilib&gt;/LabVIEW Icon API/lv_icon/Support/Flatten Load &amp; Unload.vi"/>
					<Item Name="Flood Glyph.vi" Type="VI" URL="vi.lib/LabVIEW Icon API/lv_icon/Support/Flood Glyph.vi"/>
					<Item Name="Get Grayscale Value.vi" Type="VI" URL="vi.lib/LabVIEW Icon API/lv_icon/Support/Get Grayscale Value.vi"/>
					<Item Name="Get Image Data.vi" Type="VI" URL="/&lt;vilib&gt;/LabVIEW Icon API/lv_icon/Support/Get Image Data.vi"/>
					<Item Name="Get LV Glyph Path.vi" Type="VI" URL="vi.lib/LabVIEW Icon API/lv_icon/Support/Get LV Glyph Path.vi"/>
					<Item Name="Get SubPicture Coordinate.vi" Type="VI" URL="/&lt;vilib&gt;/LabVIEW Icon API/lv_icon/Support/Get SubPicture Coordinate.vi"/>
					<Item Name="Get SubPicture Coordinates.vi" Type="VI" URL="/&lt;vilib&gt;/LabVIEW Icon API/lv_icon/Support/Get SubPicture Coordinates.vi"/>
					<Item Name="Get_VI_Icon.vi" Type="VI" URL="/&lt;vilib&gt;/LabVIEW Icon API/lv_icon/Support/Get_VI_Icon.vi"/>
					<Item Name="Join Layers.vi" Type="VI" URL="vi.lib/LabVIEW Icon API/lv_icon/Support/Join Layers.vi"/>
					<Item Name="LabVIEW Fonts.vi" Type="VI" URL="vi.lib/LabVIEW Icon API/lv_icon/Support/LabVIEW Fonts.vi"/>
					<Item Name="Magic Transparent Color Constant.vi" Type="VI" URL="vi.lib/LabVIEW Icon API/lv_icon/Support/Magic Transparent Color Constant.vi"/>
					<Item Name="Remove Duplicates from Color Array.vi" Type="VI" URL="vi.lib/LabVIEW Icon API/lv_icon/Support/Remove Duplicates from Color Array.vi"/>
					<Item Name="Replace Color.vi" Type="VI" URL="vi.lib/LabVIEW Icon API/lv_icon/Support/Replace Color.vi"/>
					<Item Name="Restore original Coordinates.vi" Type="VI" URL="/&lt;vilib&gt;/LabVIEW Icon API/lv_icon/Support/Restore original Coordinates.vi"/>
					<Item Name="Return MutationCode Folder.vi" Type="VI" URL="vi.lib/LabVIEW Icon API/lv_icon/Support/Return MutationCode Folder.vi"/>
					<Item Name="Rotate Flip Image.vi" Type="VI" URL="/&lt;vilib&gt;/LabVIEW Icon API/lv_icon/Support/Rotate Flip Image.vi"/>
					<Item Name="Serialize Icon Data.vi" Type="VI" URL="/&lt;vilib&gt;/LabVIEW Icon API/lv_icon/Support/Serialize Icon Data.vi"/>
					<Item Name="Text.vi" Type="VI" URL="vi.lib/LabVIEW Icon API/lv_icon/Support/Text.vi"/>
					<Item Name="Unflatten Load &amp; Unload.vi" Type="VI" URL="vi.lib/LabVIEW Icon API/lv_icon/Support/Unflatten Load &amp; Unload.vi"/>
				</Item>
				<Item Name="Read and Write Icon Data" Type="Folder">
					<Item Name="Read Icon Data from Library.vi" Type="VI" URL="vi.lib/LabVIEW Icon API/lv_icon/Support/Read Icon Data from Library.vi"/>
					<Item Name="Read Icon Data from VI.vi" Type="VI" URL="vi.lib/LabVIEW Icon API/lv_icon/Support/Read Icon Data from VI.vi"/>
					<Item Name="Remove Icon Data from VI.vi" Type="VI" URL="/&lt;vilib&gt;/LabVIEW Icon API/lv_icon/Support/Remove Icon Data from VI.vi"/>
					<Item Name="Write Icon Data to Library.vi" Type="VI" URL="/&lt;vilib&gt;/LabVIEW Icon API/lv_icon/Support/Write Icon Data to Library.vi"/>
					<Item Name="Write Icon Data to VI.vi" Type="VI" URL="/&lt;vilib&gt;/LabVIEW Icon API/lv_icon/Support/Write Icon Data to VI.vi"/>
				</Item>
				<Item Name="lv_icon.vi" Type="VI" URL="/&lt;resource&gt;/plugins/lv_icon.vi"/>
			</Item>
			<Item Name="lv_icon.vit" Type="VI" URL="/&lt;resource&gt;/plugins/lv_icon.vit"/>
			<Item Name="lv_IconEditor.lvlib" Type="Library" URL="resource/plugins/lv_IconEditor.lvlib">
				<Item Name="Download iconlibrary files.vi" Type="VI" URL="/&lt;resource&gt;/plugins/NIIconEditor/Miscellaneous/ni.com_iconlibrary/Download iconlibrary files.vi"/>
				<Item Name="GET HTTP.vi" Type="VI" URL="/&lt;resource&gt;/plugins/NIIconEditor/Miscellaneous/ni.com_iconlibrary/GET HTTP.vi"/>
			</Item>
			<Item Name="SAMPLE_lv_icon.vi" Type="VI" URL="/&lt;resource&gt;/plugins/SAMPLE_lv_icon.vi"/>
		</Item>
		<Item Name="Tooling" Type="Folder">
			<Item Name="support" Type="Folder">
				<Item Name="Add Files to Archive.vi" Type="VI" URL="Tooling/support/Add Files to Archive.vi"/>
				<Item Name="Delete Icon Editor from LV Installation.vi" Type="VI" URL="Tooling/support/Delete Icon Editor from LV Installation.vi"/>
				<Item Name="Get Paths to Icon Editor Files in LV Installation.vi" Type="VI" URL="Tooling/support/Get Paths to Icon Editor Files in LV Installation.vi"/>
				<Item Name="Prompt to Confirm Archival.vi" Type="VI" URL="Tooling/support/Prompt to Confirm Archival.vi"/>
				<Item Name="Set LibraryPaths to Include Icon Editor.vi" Type="VI" URL="Tooling/support/Set LibraryPaths to Include Icon Editor.vi"/>
			</Item>
			<Item Name="Unit tests" Type="Folder">
				<Item Name="Missing classes on LV project.vi" Type="VI" URL="Tooling/Unit tests/Missing classes on LV project.vi"/>
				<Item Name="Missing libraries on LV project.vi" Type="VI" URL="Tooling/Unit tests/Missing libraries on LV project.vi"/>
				<Item Name="Missing PPLs on LV project.vi" Type="VI" URL="Tooling/Unit tests/Missing PPLs on LV project.vi"/>
				<Item Name="Missing VIs or controls on LV project.vi" Type="VI" URL="Tooling/Unit tests/Missing VIs or controls on LV project.vi"/>
				<Item Name="Text-Based VI Icon Unit Tests.lvlib" Type="Library" URL="Tooling/Unit tests/Text-Based VI Icon/Text-Based VI Icon Unit Tests.lvlib">
					<Item Name="Test Caller.vi" Type="VI" URL="Tooling/Unit tests/Text-Based VI Icon/Test Caller.vi"/>
					<Item Name="Split Text into Words.vi" Type="VI" URL="Tooling/Unit tests/Text-Based VI Icon/Split Text into Words.vi"/>
				</Item>
			</Item>
			<Item Name="Force Icon Editor to Unload.vi" Type="VI" URL="Tooling/Force Icon Editor to Unload.vi"/>
			<Item Name="Post Build Icon Editor PPL.vi" Type="VI" URL="Tooling/Post Build Icon Editor PPL.vi"/>
			<Item Name="Pre Build Icon Editor PPL.vi" Type="VI" URL="Tooling/Pre Build Icon Editor PPL.vi"/>
			<Item Name="Prepare LV to Use Icon Editor Source.vi" Type="VI" URL="Tooling/Prepare LV to Use Icon Editor Source.vi"/>
			<Item Name="Run all tests.vi" Type="VI" URL="Tooling/Run all tests.vi"/>
		</Item>
		<Item Name="vi.lib/LabVIEW Icon API" Type="Folder">
			<Item Name="lv_icon" Type="Folder">
				<Item Name="Classes" Type="Folder">
					<Item Name="Icon" Type="Folder">
						<Item Name="Icon.lvclass" Type="LVClass" URL="vi.lib/LabVIEW Icon API/lv_icon/Classes/Icon/Icon.lvclass">
							<Item Name="Icon.ctl" Type="Class Private Data" URL="vi.lib/LabVIEW Icon API/lv_icon/Classes/Icon/Icon.lvclass/Icon.ctl"/>
							<Item Name="GET" Type="Folder">
								<Item Name="Get_Active User Layer.vi" Type="VI" URL="vi.lib/LabVIEW Icon API/lv_icon/Classes/Icon/Get_Active User Layer.vi"/>
								<Item Name="GET_All User Layers.vi" Type="VI" URL="vi.lib/LabVIEW Icon API/lv_icon/Classes/Icon/GET_All User Layers.vi"/>
								<Item Name="GET_UserLayers.vi" Type="VI" URL="vi.lib/LabVIEW Icon API/lv_icon/Classes/Icon/GET_UserLayers.vi"/>
								<Item Name="GET_LayersLocked_ActiveLayer.vi" Type="VI" URL="vi.lib/LabVIEW Icon API/lv_icon/Classes/Icon/GET_LayersLocked_ActiveLayer.vi"/>
								<Item Name="GET_IconTextClass.vi" Type="VI" URL="vi.lib/LabVIEW Icon API/lv_icon/Classes/Icon/GET_IconTextClass.vi"/>
								<Item Name="GET_TemplateClass.vi" Type="VI" URL="vi.lib/LabVIEW Icon API/lv_icon/Classes/Icon/GET_TemplateClass.vi"/>
							</Item>
							<Item Name="SET" Type="Folder">
								<Item Name="SET_UserLayers.vi" Type="VI" URL="vi.lib/LabVIEW Icon API/lv_icon/Classes/Icon/SET_UserLayers.vi"/>
								<Item Name="SET_ActiveLayer.vi" Type="VI" URL="vi.lib/LabVIEW Icon API/lv_icon/Classes/Icon/SET_ActiveLayer.vi"/>
								<Item Name="SET_Locked_ActiveLayer.vi" Type="VI" URL="vi.lib/LabVIEW Icon API/lv_icon/Classes/Icon/SET_Locked_ActiveLayer.vi"/>
								<Item Name="SET_IconTextClass.vi" Type="VI" URL="vi.lib/LabVIEW Icon API/lv_icon/Classes/Icon/SET_IconTextClass.vi"/>
								<Item Name="SET_TemplateClass.vi" Type="VI" URL="vi.lib/LabVIEW Icon API/lv_icon/Classes/Icon/SET_TemplateClass.vi"/>
							</Item>
							<Item Name="Misc" Type="Folder">
								<Item Name="CreateNewLayer.vi" Type="VI" URL="vi.lib/LabVIEW Icon API/lv_icon/Classes/Icon/CreateNewLayer.vi"/>
								<Item Name="DeleteLayer.vi" Type="VI" URL="vi.lib/LabVIEW Icon API/lv_icon/Classes/Icon/DeleteLayer.vi"/>
								<Item Name="Apply Body Text.vi" Type="VI" URL="vi.lib/LabVIEW Icon API/lv_icon/Classes/Icon Framework/Apply Body Text.vi"/>
							</Item>
						</Item>
					</Item>
					<Item Name="Icon Framework" Type="Folder">
						<Item Name="Icon Framework.lvclass" Type="LVClass" URL="vi.lib/LabVIEW Icon API/lv_icon/Classes/Icon Framework/Icon Framework.lvclass">
							<Item Name="Icon Framework.ctl" Type="Class Private Data" URL="vi.lib/LabVIEW Icon API/lv_icon/Classes/Icon Framework/Icon Framework.lvclass/Icon Framework.ctl"/>
							<Item Name="SET" Type="Folder">
								<Item Name="SET_BodyText.vi" Type="VI" URL="vi.lib/LabVIEW Icon API/lv_icon/Classes/Icon Framework/SET_BodyText.vi"/>
								<Item Name="SET_Path.vi" Type="VI" URL="vi.lib/LabVIEW Icon API/lv_icon/Classes/Icon Framework/SET_Path.vi"/>
							</Item>
							<Item Name="GET" Type="Folder">
								<Item Name="GET_BodyText.vi" Type="VI" URL="vi.lib/LabVIEW Icon API/lv_icon/Classes/Icon Framework/GET_BodyText.vi"/>
								<Item Name="GET_Path.vi" Type="VI" URL="vi.lib/LabVIEW Icon API/lv_icon/Classes/Icon Framework/GET_Path.vi"/>
							</Item>
							<Item Name="Misc" Type="Folder">
								<Item Name="CreateBodyText.vi" Type="VI" URL="vi.lib/LabVIEW Icon API/lv_icon/Classes/Icon Framework/CreateBodyText.vi"/>
								<Item Name="BodyTextCoordinates.vi" Type="VI" URL="vi.lib/LabVIEW Icon API/lv_icon/Classes/Icon Framework/BodyTextCoordinates.vi"/>
							</Item>
						</Item>
					</Item>
					<Item Name="Layer" Type="Folder">
						<Item Name="Layer.lvclass" Type="LVClass" URL="vi.lib/LabVIEW Icon API/lv_icon/Classes/Layer/Layer.lvclass">
							<Item Name="Layer.ctl" Type="Class Private Data" URL="vi.lib/LabVIEW Icon API/lv_icon/Classes/Layer/Layer.lvclass/Layer.ctl"/>
							<Item Name="GET" Type="Folder">
								<Item Name="GET_LayerData.vi" Type="VI" URL="vi.lib/LabVIEW Icon API/lv_icon/Classes/Layer/GET_LayerData.vi"/>
								<Item Name="GET_Origin.vi" Type="VI" URL="vi.lib/LabVIEW Icon API/lv_icon/Classes/Layer/GET_Origin.vi"/>
							</Item>
							<Item Name="SET" Type="Folder">
								<Item Name="SET_Origin.vi" Type="VI" URL="vi.lib/LabVIEW Icon API/lv_icon/Classes/Layer/SET_Origin.vi"/>
								<Item Name="SET_LayerType.vi" Type="VI" URL="vi.lib/LabVIEW Icon API/lv_icon/Classes/Layer/SET_LayerType.vi"/>
								<Item Name="SET_Layer_Data.vi" Type="VI" URL="vi.lib/LabVIEW Icon API/lv_icon/Classes/Layer/SET_Layer_Data.vi"/>
							</Item>
							<Item Name="Misc" Type="Folder">
								<Item Name="UpdateLayerData.vi" Type="VI" URL="vi.lib/LabVIEW Icon API/lv_icon/Classes/Layer/UpdateLayerData.vi"/>
								<Item Name="Substitute Layer.vi" Type="VI" URL="vi.lib/LabVIEW Icon API/lv_icon/Classes/Layer/Substitute Layer.vi"/>
							</Item>
						</Item>
					</Item>
					<Item Name="Load_Unload" Type="Folder">
						<Item Name="Load &amp; Unload.lvclass" Type="LVClass" URL="vi.lib/LabVIEW Icon API/lv_icon/Classes/Load_Unload/Load &amp; Unload.lvclass">
							<Item Name="Load &amp; Unload.ctl" Type="Class Private Data" URL="vi.lib/LabVIEW Icon API/lv_icon/Classes/Load_Unload/Load &amp; Unload.lvclass/Load &amp; Unload.ctl"/>
							<Item Name="SET" Type="Folder">
								<Item Name="SET Data.vi" Type="VI" URL="vi.lib/LabVIEW Icon API/lv_icon/Classes/Load_Unload/SET Data.vi"/>
							</Item>
							<Item Name="GET" Type="Folder">
								<Item Name="GET Data.vi" Type="VI" URL="vi.lib/LabVIEW Icon API/lv_icon/Classes/Load_Unload/GET Data.vi"/>
							</Item>
						</Item>
					</Item>
				</Item>
				<Item Name="Controls" Type="Folder">
					<Item Name="Alignment.ctl" Type="VI" URL="vi.lib/LabVIEW Icon API/lv_icon/Controls/Alignment.ctl"/>
					<Item Name="BodyText.ctl" Type="VI" URL="vi.lib/LabVIEW Icon API/lv_icon/Controls/BodyText.ctl"/>
					<Item Name="BodyTextPosition.ctl" Type="VI" URL="vi.lib/LabVIEW Icon API/lv_icon/Controls/BodyTextPosition.ctl"/>
					<Item Name="Font.ctl" Type="VI" URL="vi.lib/LabVIEW Icon API/lv_icon/Controls/Font.ctl"/>
					<Item Name="Graphic.ctl" Type="VI" URL="vi.lib/LabVIEW Icon API/lv_icon/Controls/Graphic.ctl"/>
					<Item Name="IEColor.ctl" Type="VI" URL="vi.lib/LabVIEW Icon API/lv_icon/Controls/IEColor.ctl"/>
					<Item Name="LabVIEW Icon Stored Information.ctl" Type="VI" URL="vi.lib/LabVIEW Icon API/lv_icon/Controls/LabVIEW Icon Stored Information.ctl"/>
					<Item Name="Layer.ctl" Type="VI" URL="vi.lib/LabVIEW Icon API/lv_icon/Controls/Layer.ctl"/>
					<Item Name="LayerType.ctl" Type="VI" URL="vi.lib/LabVIEW Icon API/lv_icon/Controls/LayerType.ctl"/>
					<Item Name="Pathes.ctl" Type="VI" URL="vi.lib/LabVIEW Icon API/lv_icon/Controls/Pathes.ctl"/>
				</Item>
			</Item>
			<Item Name="Set Text Icon" Type="Folder">
				<Item Name="Configure Named Icons.vi" Type="VI" URL="vi.lib/LabVIEW Icon API/Set Text Icon/Configure Named Icons.vi"/>
				<Item Name="Group 1-Character Tokens.vi" Type="VI" URL="/&lt;vilib&gt;/LabVIEW Icon API/Set Text Icon/Group 1-Character Tokens.vi"/>
				<Item Name="Text-Based VI Icon.lvlib" Type="Library" URL="vi.lib/LabVIEW Icon API/Set Text Icon/Text-Based VI Icon.lvlib">
					<Item Name="Community" Type="Folder">
						<Item Name="Split Text Into Words.vi" Type="VI" URL="vi.lib/LabVIEW Icon API/Set Text Icon/Split Text Into Words.vi"/>
					</Item>
					<Item Name="Private" Type="Folder">
						<Item Name="Calculate Number of Text Rows.vi" Type="VI" URL="/&lt;vilib&gt;/LabVIEW Icon API/Set Text Icon/Calculate Number of Text Rows.vi"/>
						<Item Name="Does the Text Fit.vi" Type="VI" URL="/&lt;vilib&gt;/LabVIEW Icon API/Set Text Icon/Does the Text Fit.vi"/>
						<Item Name="Filter Words.vi" Type="VI" URL="/&lt;vilib&gt;/LabVIEW Icon API/Set Text Icon/Filter Words.vi"/>
						<Item Name="Generate Non Text Layer(s).vi" Type="VI" URL="/&lt;vilib&gt;/LabVIEW Icon API/Set Text Icon/Generate Non Text Layer(s).vi"/>
						<Item Name="Generate Pretty Icon Text Layer.vi" Type="VI" URL="/&lt;vilib&gt;/LabVIEW Icon API/Set Text Icon/Generate Pretty Icon Text Layer.vi"/>
						<Item Name="Library Icon Information.ctl" Type="VI" URL="/&lt;vilib&gt;/LabVIEW Icon API/Set Text Icon/Library Icon Information.ctl"/>
						<Item Name="Qualify Library Icon Core.vi" Type="VI" URL="/&lt;vilib&gt;/LabVIEW Icon API/Set Text Icon/Qualify Library Icon Core.vi"/>
						<Item Name="Read 2D Strings From Config.vi" Type="VI" URL="/&lt;vilib&gt;/LabVIEW Icon API/Set Text Icon/Read 2D Strings From Config.vi"/>
						<Item Name="Split First and Other Strings.vi" Type="VI" URL="/&lt;vilib&gt;/LabVIEW Icon API/Set Text Icon/Split First and Other Strings.vi"/>
						<Item Name="User Visible Strings.vi" Type="VI" URL="/&lt;vilib&gt;/LabVIEW Icon API/Set Text Icon/User Visible Strings.vi"/>
					</Item>
					<Item Name="Public" Type="Folder">
						<Item Name="Adjust Text to Fit Rectangle.vi" Type="VI" URL="/&lt;vilib&gt;/LabVIEW Icon API/Set Text Icon/Adjust Text to Fit Rectangle.vi"/>
						<Item Name="Set Icon.vi" Type="VI" URL="/&lt;vilib&gt;/LabVIEW Icon API/Set Text Icon/Set Icon.vi"/>
					</Item>
					<Item Name="Read 1D Strings From Config.vi" Type="VI" URL="/&lt;vilib&gt;/LabVIEW Icon API/Set Text Icon/Read 1D Strings From Config.vi"/>
				</Item>
			</Item>
			<Item Name="LabVIEW Icon API.lvlib" Type="Library" URL="vi.lib/LabVIEW Icon API/LabVIEW Icon API.lvlib">
				<Item Name="Controls" Type="Folder">
					<Item Name="API_Rectangle Colors.ctl" Type="VI" URL="/&lt;vilib&gt;/LabVIEW Icon API/API_Rectangle Colors.ctl"/>
					<Item Name="API_Rectangle Dimension.ctl" Type="VI" URL="/&lt;vilib&gt;/LabVIEW Icon API/API_Rectangle Dimension.ctl"/>
					<Item Name="API_Test Settings.ctl" Type="VI" URL="/&lt;vilib&gt;/LabVIEW Icon API/API_Test Settings.ctl"/>
					<Item Name="API_Text Colors.ctl" Type="VI" URL="/&lt;vilib&gt;/LabVIEW Icon API/API_Text Colors.ctl"/>
					<Item Name="API_Text.ctl" Type="VI" URL="/&lt;vilib&gt;/LabVIEW Icon API/API_Text.ctl"/>
					<Item Name="API_User Layer Data.ctl" Type="VI" URL="/&lt;vilib&gt;/LabVIEW Icon API/API_User Layer Data.ctl"/>
				</Item>
				<Item Name="Examples" Type="Folder">
					<Item Name="Advanced Generate LV Icon.vi" Type="VI" URL="/&lt;vilib&gt;/LabVIEW Icon API/Examples/Advanced Generate LV Icon.vi"/>
					<Item Name="Basic Generate LV Icon Template Layer.vi" Type="VI" URL="/&lt;vilib&gt;/LabVIEW Icon API/Examples/Basic Generate LV Icon Template Layer.vi"/>
					<Item Name="Basic Generate LV Icon Text Layer.vi" Type="VI" URL="/&lt;vilib&gt;/LabVIEW Icon API/Examples/Basic Generate LV Icon Text Layer.vi"/>
					<Item Name="Modify VI Icon Template Layer.vi" Type="VI" URL="/&lt;vilib&gt;/LabVIEW Icon API/Examples/Modify VI Icon Template Layer.vi"/>
					<Item Name="Modify VI Icon Text Layer.vi" Type="VI" URL="/&lt;vilib&gt;/LabVIEW Icon API/Examples/Modify VI Icon Text Layer.vi"/>
				</Item>
				<Item Name="Low Level Functions" Type="Folder">
					<Item Name="Apply Transparency.vi" Type="VI" URL="/&lt;vilib&gt;/LabVIEW Icon API/Support/Apply Transparency.vi"/>
					<Item Name="Generate Border User Layer.vi" Type="VI" URL="/&lt;vilib&gt;/LabVIEW Icon API/Support/Generate Border User Layer.vi"/>
					<Item Name="Get Flattened Image.vi" Type="VI" URL="/&lt;vilib&gt;/LabVIEW Icon API/Get Flattened Image.vi"/>
				</Item>
				<Item Name="Support" Type="Folder">
					<Item Name="Create Icon Framework.vi" Type="VI" URL="/&lt;vilib&gt;/LabVIEW Icon API/Support/Create Icon Framework.vi"/>
					<Item Name="Create Icon Layer.vi" Type="VI" URL="/&lt;vilib&gt;/LabVIEW Icon API/lv_icon/Support/Create Icon Layer.vi"/>
					<Item Name="Draw Template Glyph.vi" Type="VI" URL="/&lt;vilib&gt;/LabVIEW Icon API/Support/Draw Template Glyph.vi"/>
					<Item Name="Extract Default Icon Data.vi" Type="VI" URL="/&lt;vilib&gt;/LabVIEW Icon API/lv_icon/Support/Extract Default Icon Data.vi"/>
					<Item Name="Extract Icon Data.vi" Type="VI" URL="/&lt;vilib&gt;/LabVIEW Icon API/lv_icon/Support/Extract Icon Data.vi"/>
					<Item Name="Get Data from Icon Class.vi" Type="VI" URL="/&lt;vilib&gt;/LabVIEW Icon API/Support/Get Data from Icon Class.vi"/>
					<Item Name="Get Icon Class from Data.vi" Type="VI" URL="/&lt;vilib&gt;/LabVIEW Icon API/Support/Get Icon Class from Data.vi"/>
					<Item Name="Populate Body Text Data.vi" Type="VI" URL="/&lt;vilib&gt;/LabVIEW Icon API/Support/Populate Body Text Data.vi"/>
					<Item Name="Rotate Flip Layer.vi" Type="VI" URL="/&lt;vilib&gt;/LabVIEW Icon API/Support/Rotate Flip Layer.vi"/>
				</Item>
				<Item Name="Generate LV Icon Template Layer.vi" Type="VI" URL="/&lt;vilib&gt;/LabVIEW Icon API/Generate LV Icon Template Layer.vi"/>
				<Item Name="Generate LV Icon Text Layer.vi" Type="VI" URL="/&lt;vilib&gt;/LabVIEW Icon API/Generate LV Icon Text Layer.vi"/>
				<Item Name="Generate LV Icon User Layers.vi" Type="VI" URL="/&lt;vilib&gt;/LabVIEW Icon API/Generate LV Icon User Layers.vi"/>
				<Item Name="Get Library Icon.vi" Type="VI" URL="/&lt;vilib&gt;/LabVIEW Icon API/Get Library Icon.vi"/>
				<Item Name="Get VI Icon.vi" Type="VI" URL="/&lt;vilib&gt;/LabVIEW Icon API/Get VI Icon.vi"/>
				<Item Name="Launch Icon Editor.vi" Type="VI" URL="/&lt;vilib&gt;/LabVIEW Icon API/Launch Icon Editor.vi"/>
				<Item Name="Set Library Icon.vi" Type="VI" URL="/&lt;vilib&gt;/LabVIEW Icon API/Set Library Icon.vi"/>
				<Item Name="Set VI Icon.vi" Type="VI" URL="/&lt;vilib&gt;/LabVIEW Icon API/Set VI Icon.vi"/>
			</Item>
		</Item>
		<Item Name="Package Dependencies" Type="IIO Ladder Diagram"/>
		<Item Name="Dependencies" Type="Dependencies">
			<Item Name="vi.lib" Type="Folder">
				<Item Name="1D String Array to Delimited String.vi" Type="VI" URL="/&lt;vilib&gt;/AdvancedString/1D String Array to Delimited String.vi"/>
				<Item Name="8.6CompatibleGlobalVar.vi" Type="VI" URL="/&lt;vilib&gt;/Utility/config.llb/8.6CompatibleGlobalVar.vi"/>
				<Item Name="Add File to Zip.vi" Type="VI" URL="/&lt;vilib&gt;/zip/Add File to Zip.vi"/>
				<Item Name="Bit-array To Byte-array.vi" Type="VI" URL="/&lt;vilib&gt;/picture/pictutil.llb/Bit-array To Byte-array.vi"/>
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
				<Item Name="Close Zip File.vi" Type="VI" URL="/&lt;vilib&gt;/zip/Close Zip File.vi"/>
				<Item Name="Coerce Bad Rect.vi" Type="VI" URL="/&lt;vilib&gt;/picture/pictutil.llb/Coerce Bad Rect.vi"/>
				<Item Name="Color to RGB.vi" Type="VI" URL="/&lt;vilib&gt;/Utility/colorconv.llb/Color to RGB.vi"/>
				<Item Name="Compare Src And Dst Simple.vi" Type="VI" URL="/&lt;vilib&gt;/Utility/libraryn.llb/Compare Src And Dst Simple.vi"/>
				<Item Name="Compare Two Paths.vi" Type="VI" URL="/&lt;vilib&gt;/Utility/libraryn.llb/Compare Two Paths.vi"/>
				<Item Name="compatCalcOffset.vi" Type="VI" URL="/&lt;vilib&gt;/_oldvers/_oldvers.llb/compatCalcOffset.vi"/>
				<Item Name="compatFileDialog.vi" Type="VI" URL="/&lt;vilib&gt;/_oldvers/_oldvers.llb/compatFileDialog.vi"/>
				<Item Name="compatOpenFileOperation.vi" Type="VI" URL="/&lt;vilib&gt;/_oldvers/_oldvers.llb/compatOpenFileOperation.vi"/>
				<Item Name="Convert property node font to graphics font.vi" Type="VI" URL="/&lt;vilib&gt;/Utility/error.llb/Convert property node font to graphics font.vi"/>
				<Item Name="Create Directory Recursive.vi" Type="VI" URL="/&lt;vilib&gt;/Utility/libraryn.llb/Create Directory Recursive.vi"/>
				<Item Name="Create Mask By Alpha.vi" Type="VI" URL="/&lt;vilib&gt;/picture/picture.llb/Create Mask By Alpha.vi"/>
				<Item Name="Create Mask.vi" Type="VI" URL="/&lt;vilib&gt;/picture/pictutil.llb/Create Mask.vi"/>
				<Item Name="Delete Directory Recursive.vi" Type="VI" URL="/&lt;vilib&gt;/Utility/libraryn.llb/Delete Directory Recursive.vi"/>
				<Item Name="Delete From VI Library.vi" Type="VI" URL="/&lt;vilib&gt;/Utility/libraryn.llb/Delete From VI Library.vi"/>
				<Item Name="Delimited String to 1D String Array.vi" Type="VI" URL="/&lt;vilib&gt;/AdvancedString/Delimited String to 1D String Array.vi"/>
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
				<Item Name="Draw Rectangle.vi" Type="VI" URL="/&lt;vilib&gt;/picture/picture.llb/Draw Rectangle.vi"/>
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
				<Item Name="Escape Characters for HTTP.vi" Type="VI" URL="/&lt;vilib&gt;/printing/PathToURL.llb/Escape Characters for HTTP.vi"/>
				<Item Name="eventvkey.ctl" Type="VI" URL="/&lt;vilib&gt;/event_ctls.llb/eventvkey.ctl"/>
				<Item Name="ex_CorrectErrorChain.vi" Type="VI" URL="/&lt;vilib&gt;/express/express shared/ex_CorrectErrorChain.vi"/>
				<Item Name="Find Tag.vi" Type="VI" URL="/&lt;vilib&gt;/Utility/error.llb/Find Tag.vi"/>
				<Item Name="FixBadRect.vi" Type="VI" URL="/&lt;vilib&gt;/picture/pictutil.llb/FixBadRect.vi"/>
				<Item Name="Flatten Pixmap.vi" Type="VI" URL="/&lt;vilib&gt;/picture/pixmap.llb/Flatten Pixmap.vi"/>
				<Item Name="Flip and Pad for Picture Control.vi" Type="VI" URL="/&lt;vilib&gt;/picture/bmp.llb/Flip and Pad for Picture Control.vi"/>
				<Item Name="Format Message String.vi" Type="VI" URL="/&lt;vilib&gt;/Utility/error.llb/Format Message String.vi"/>
				<Item Name="General Error Handler Core CORE.vi" Type="VI" URL="/&lt;vilib&gt;/Utility/error.llb/General Error Handler Core CORE.vi"/>
				<Item Name="General Error Handler.vi" Type="VI" URL="/&lt;vilib&gt;/Utility/error.llb/General Error Handler.vi"/>
				<Item Name="Generate Temporary File Path.vi" Type="VI" URL="/&lt;vilib&gt;/Utility/libraryn.llb/Generate Temporary File Path.vi"/>
				<Item Name="Get File Extension.vi" Type="VI" URL="/&lt;vilib&gt;/Utility/libraryn.llb/Get File Extension.vi"/>
				<Item Name="Get Image Subset.vi" Type="VI" URL="/&lt;vilib&gt;/picture/pictutil.llb/Get Image Subset.vi"/>
				<Item Name="Get String Text Bounds.vi" Type="VI" URL="/&lt;vilib&gt;/Utility/error.llb/Get String Text Bounds.vi"/>
				<Item Name="Get Text Rect.vi" Type="VI" URL="/&lt;vilib&gt;/picture/picture.llb/Get Text Rect.vi"/>
				<Item Name="GetHelpDir.vi" Type="VI" URL="/&lt;vilib&gt;/Utility/error.llb/GetHelpDir.vi"/>
				<Item Name="GetRTHostConnectedProp.vi" Type="VI" URL="/&lt;vilib&gt;/Utility/error.llb/GetRTHostConnectedProp.vi"/>
				<Item Name="imagedata.ctl" Type="VI" URL="/&lt;vilib&gt;/picture/picture.llb/imagedata.ctl"/>
				<Item Name="Is Path and Not Empty.vi" Type="VI" URL="/&lt;vilib&gt;/Utility/file.llb/Is Path and Not Empty.vi"/>
				<Item Name="LabVIEWHTTPClient.lvlib" Type="Library" URL="/&lt;vilib&gt;/httpClient/LabVIEWHTTPClient.lvlib">
					<Item Name="HTTPClient.mnu" Type="Document" URL="/&lt;menus&gt;/Categories/Data Communication/_protocols/HTTPClient.mnu"/>
					<Item Name="HTTPClient_Headers.mnu" Type="Document" URL="/&lt;menus&gt;/Categories/Data Communication/_protocols/HTTPClient_Headers.mnu"/>
					<Item Name="HTTPClient_Security.mnu" Type="Document" URL="/&lt;menus&gt;/Categories/Data Communication/_protocols/HTTPClient_Security.mnu"/>
					<Item Name="AddHeader.vi" Type="VI" URL="/&lt;vilib&gt;/httpClient/AddHeader.vi"/>
					<Item Name="RemoveHeader.vi" Type="VI" URL="/&lt;vilib&gt;/httpClient/RemoveHeader.vi"/>
					<Item Name="GetHeader.vi" Type="VI" URL="/&lt;vilib&gt;/httpClient/GetHeader.vi"/>
					<Item Name="HeaderExists.vi" Type="VI" URL="/&lt;vilib&gt;/httpClient/HeaderExists.vi"/>
					<Item Name="ListHeaders.vi" Type="VI" URL="/&lt;vilib&gt;/httpClient/ListHeaders.vi"/>
					<Item Name="Base64Decode.vi" Type="VI" URL="/&lt;vilib&gt;/httpClient/Base64Decode.vi"/>
					<Item Name="Base64Encode.vi" Type="VI" URL="/&lt;vilib&gt;/httpClient/Base64Encode.vi"/>
					<Item Name="CheckForSuccess.vi" Type="VI" URL="/&lt;vilib&gt;/httpClient/CheckForSuccess.vi"/>
					<Item Name="ClientHandle.ctl" Type="VI" URL="/&lt;vilib&gt;/httpClient/ClientHandle.ctl"/>
					<Item Name="CloseHandle.vi" Type="VI" URL="/&lt;vilib&gt;/httpClient/CloseHandle.vi"/>
					<Item Name="ConfigKey.vi" Type="VI" URL="/&lt;vilib&gt;/httpClient/ConfigKey.vi"/>
					<Item Name="ConfigSSL.vi" Type="VI" URL="/&lt;vilib&gt;/httpClient/ConfigSSL.vi"/>
					<Item Name="Decrypt.vi" Type="VI" URL="/&lt;vilib&gt;/httpClient/Decrypt.vi"/>
					<Item Name="DELETE.vi" Type="VI" URL="/&lt;vilib&gt;/httpClient/DELETE.vi"/>
					<Item Name="Encrypt.vi" Type="VI" URL="/&lt;vilib&gt;/httpClient/Encrypt.vi"/>
					<Item Name="GET.vi" Type="VI" URL="/&lt;vilib&gt;/httpClient/GET.vi"/>
					<Item Name="HEAD.vi" Type="VI" URL="/&lt;vilib&gt;/httpClient/HEAD.vi"/>
					<Item Name="Headers.ctl" Type="VI" URL="/&lt;vilib&gt;/httpClient/Headers.ctl"/>
					<Item Name="MultipartData.ctl" Type="VI" URL="/&lt;vilib&gt;/httpClient/MultipartData.ctl"/>
					<Item Name="OpenHandle.vi" Type="VI" URL="/&lt;vilib&gt;/httpClient/OpenHandle.vi"/>
					<Item Name="ParseHeaders.vi" Type="VI" URL="/&lt;vilib&gt;/httpClient/ParseHeaders.vi"/>
					<Item Name="POST.vi" Type="VI" URL="/&lt;vilib&gt;/httpClient/POST.vi"/>
					<Item Name="POSTBuffer.vi" Type="VI" URL="/&lt;vilib&gt;/httpClient/POSTBuffer.vi"/>
					<Item Name="POSTFile.vi" Type="VI" URL="/&lt;vilib&gt;/httpClient/POSTFile.vi"/>
					<Item Name="POSTMultipart.vi" Type="VI" URL="/&lt;vilib&gt;/httpClient/POSTMultipart.vi"/>
					<Item Name="PUT.vi" Type="VI" URL="/&lt;vilib&gt;/httpClient/PUT.vi"/>
					<Item Name="PUTBuffer.vi" Type="VI" URL="/&lt;vilib&gt;/httpClient/PUTBuffer.vi"/>
					<Item Name="PUTFile.vi" Type="VI" URL="/&lt;vilib&gt;/httpClient/PUTFile.vi"/>
					<Item Name="SetAPIKey.vi" Type="VI" URL="/&lt;vilib&gt;/httpClient/SetAPIKey.vi"/>
					<Item Name="SmartPathToString.vi" Type="VI" URL="/&lt;vilib&gt;/httpClient/SmartPathToString.vi"/>
					<Item Name="Get Lib.vi" Type="VI" URL="/&lt;vilib&gt;/httpClient/Get Lib.vi"/>
				</Item>
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
				<Item Name="New Zip File.vi" Type="VI" URL="/&lt;vilib&gt;/zip/New Zip File.vi"/>
				<Item Name="NI_FileType.lvlib" Type="Library" URL="/&lt;vilib&gt;/Utility/lvfile.llb/NI_FileType.lvlib">
					<Item Name="lvfile" Type="Folder">
						<Item Name="Can File be in LLB.vi" Type="VI" URL="/&lt;vilib&gt;/Utility/lvfile.llb/Can File be in LLB.vi"/>
						<Item Name="FT_FileTypes.ctl" Type="VI" URL="/&lt;vilib&gt;/Utility/lvfile.llb/FT_FileTypes.ctl"/>
						<Item Name="Get File Type.vi" Type="VI" URL="/&lt;vilib&gt;/Utility/lvfile.llb/Get File Type.vi"/>
						<Item Name="Get File Type Icon Image.vi" Type="VI" URL="/&lt;vilib&gt;/Utility/lvfile.llb/Get File Type Icon Image.vi"/>
						<Item Name="Is File a LabVIEW document.vi" Type="VI" URL="/&lt;vilib&gt;/Utility/lvfile.llb/Is File a LabVIEW document.vi"/>
						<Item Name="Is File a type of library.vi" Type="VI" URL="/&lt;vilib&gt;/Utility/lvfile.llb/Is File a type of library.vi"/>
						<Item Name="Is File VI.vi" Type="VI" URL="/&lt;vilib&gt;/Utility/lvfile.llb/Is File VI.vi"/>
						<Item Name="Is File an LLB.vi" Type="VI" URL="/&lt;vilib&gt;/Utility/lvfile.llb/Is File an LLB.vi"/>
						<Item Name="LVFileType.ctl" Type="VI" URL="/&lt;vilib&gt;/Utility/lvfile.llb/LVFileType.ctl"/>
						<Item Name="Convert filetype to Is VI.vi" Type="VI" URL="/&lt;vilib&gt;/Utility/lvfile.llb/Convert filetype to Is VI.vi"/>
						<Item Name="Convert filetype to Icon Image.vi" Type="VI" URL="/&lt;vilib&gt;/Utility/lvfile.llb/Convert filetype to Icon Image.vi"/>
						<Item Name="Convert filetype to Can be in LLB.vi" Type="VI" URL="/&lt;vilib&gt;/Utility/lvfile.llb/Convert filetype to Can be in LLB.vi"/>
						<Item Name="Convert filetype to Is library type.vi" Type="VI" URL="/&lt;vilib&gt;/Utility/lvfile.llb/Convert filetype to Is library type.vi"/>
						<Item Name="Convert filetype to Is LabVIEW document.vi" Type="VI" URL="/&lt;vilib&gt;/Utility/lvfile.llb/Convert filetype to Is LabVIEW document.vi"/>
					</Item>
				</Item>
				<Item Name="NI_LVConfig.lvlib" Type="Library" URL="/&lt;vilib&gt;/Utility/config.llb/NI_LVConfig.lvlib">
					<Item Name="ctrl" Type="Folder">
						<Item Name="Config Data RefNum.ctl" Type="VI" URL="/&lt;vilib&gt;/Utility/config.llb/Config Data RefNum.ctl"/>
					</Item>
					<Item Name="Open/Close" Type="Folder">
						<Item Name="Close Config Data.vi" Type="VI" URL="/&lt;vilib&gt;/Utility/config.llb/Close Config Data.vi"/>
						<Item Name="Not A Config Data Refnum.vi" Type="VI" URL="/&lt;vilib&gt;/Utility/config.llb/Not A Config Data Refnum.vi"/>
						<Item Name="Open Config Data (compatibility).vi" Type="VI" URL="/&lt;vilib&gt;/Utility/config.llb/Open Config Data (compatibility).vi"/>
						<Item Name="Open Config Data.vi" Type="VI" URL="/&lt;vilib&gt;/Utility/config.llb/Open Config Data.vi"/>
					</Item>
					<Item Name="Private VIs" Type="Folder">
						<Item Name="Add Key.vi" Type="VI" URL="/&lt;vilib&gt;/Utility/config.llb/Add Key.vi"/>
						<Item Name="Add Quotes.vi" Type="VI" URL="/&lt;vilib&gt;/Utility/config.llb/Add Quotes.vi"/>
						<Item Name="Common Path to Specific Path.vi" Type="VI" URL="/&lt;vilib&gt;/Utility/config.llb/Common Path to Specific Path.vi"/>
						<Item Name="Config Data.ctl" Type="VI" URL="/&lt;vilib&gt;/Utility/config.llb/Config Data.ctl"/>
						<Item Name="Config Queue.ctl" Type="VI" URL="/&lt;vilib&gt;/Utility/config.llb/Config Queue.ctl"/>
						<Item Name="Config to String.vi" Type="VI" URL="/&lt;vilib&gt;/Utility/config.llb/Config to String.vi"/>
						<Item Name="Escape String.vi" Type="VI" URL="/&lt;vilib&gt;/Utility/config.llb/Escape String.vi"/>
						<Item Name="Get File Path.vi" Type="VI" URL="/&lt;vilib&gt;/Utility/config.llb/Get File Path.vi"/>
						<Item Name="Get Key.vi" Type="VI" URL="/&lt;vilib&gt;/Utility/config.llb/Get Key.vi"/>
						<Item Name="Get Section.vi" Type="VI" URL="/&lt;vilib&gt;/Utility/config.llb/Get Section.vi"/>
						<Item Name="Load.vi" Type="VI" URL="/&lt;vilib&gt;/Utility/config.llb/Load.vi"/>
						<Item Name="New Config to Queue.vi" Type="VI" URL="/&lt;vilib&gt;/Utility/config.llb/New Config to Queue.vi"/>
						<Item Name="Parse Config to Queue.vi" Type="VI" URL="/&lt;vilib&gt;/Utility/config.llb/Parse Config to Queue.vi"/>
						<Item Name="Parse Key Value Pair.vi" Type="VI" URL="/&lt;vilib&gt;/Utility/config.llb/Parse Key Value Pair.vi"/>
						<Item Name="Read Value Without Comment.vi" Type="VI" URL="/&lt;vilib&gt;/Utility/config.llb/Read Value Without Comment.vi"/>
						<Item Name="Remove Quotes.vi" Type="VI" URL="/&lt;vilib&gt;/Utility/config.llb/Remove Quotes.vi"/>
						<Item Name="Save Config File.vi" Type="VI" URL="/&lt;vilib&gt;/Utility/config.llb/Save Config File.vi"/>
						<Item Name="Section.ctl" Type="VI" URL="/&lt;vilib&gt;/Utility/config.llb/Section.ctl"/>
						<Item Name="Specific Path to Common Path.vi" Type="VI" URL="/&lt;vilib&gt;/Utility/config.llb/Specific Path to Common Path.vi"/>
						<Item Name="String to Config.vi" Type="VI" URL="/&lt;vilib&gt;/Utility/config.llb/String to Config.vi"/>
						<Item Name="Typecast Queue to Refnum.vi" Type="VI" URL="/&lt;vilib&gt;/Utility/config.llb/Typecast Queue to Refnum.vi"/>
						<Item Name="Typecast Refnum to Queue.vi" Type="VI" URL="/&lt;vilib&gt;/Utility/config.llb/Typecast Refnum to Queue.vi"/>
						<Item Name="Unescape String.vi" Type="VI" URL="/&lt;vilib&gt;/Utility/config.llb/Unescape String.vi"/>
					</Item>
					<Item Name="Read" Type="Folder">
						<Item Name="Get Key Names.vi" Type="VI" URL="/&lt;vilib&gt;/Utility/config.llb/Get Key Names.vi"/>
						<Item Name="Get Section Names.vi" Type="VI" URL="/&lt;vilib&gt;/Utility/config.llb/Get Section Names.vi"/>
						<Item Name="Read Key (Boolean).vi" Type="VI" URL="/&lt;vilib&gt;/Utility/config.llb/Read Key (Boolean).vi"/>
						<Item Name="Read Key (Double).vi" Type="VI" URL="/&lt;vilib&gt;/Utility/config.llb/Read Key (Double).vi"/>
						<Item Name="Read Key (I32).vi" Type="VI" URL="/&lt;vilib&gt;/Utility/config.llb/Read Key (I32).vi"/>
						<Item Name="Read Key (Path).vi" Type="VI" URL="/&lt;vilib&gt;/Utility/config.llb/Read Key (Path).vi"/>
						<Item Name="Read Key (String).vi" Type="VI" URL="/&lt;vilib&gt;/Utility/config.llb/Read Key (String).vi"/>
						<Item Name="Read Key (U32).vi" Type="VI" URL="/&lt;vilib&gt;/Utility/config.llb/Read Key (U32).vi"/>
						<Item Name="Read Key.vi" Type="VI" URL="/&lt;vilib&gt;/Utility/config.llb/Read Key.vi"/>
					</Item>
					<Item Name="Remove" Type="Folder">
						<Item Name="Remove Key.vi" Type="VI" URL="/&lt;vilib&gt;/Utility/config.llb/Remove Key.vi"/>
						<Item Name="Remove Section.vi" Type="VI" URL="/&lt;vilib&gt;/Utility/config.llb/Remove Section.vi"/>
					</Item>
					<Item Name="Write" Type="Folder">
						<Item Name="Write Key (Boolean).vi" Type="VI" URL="/&lt;vilib&gt;/Utility/config.llb/Write Key (Boolean).vi"/>
						<Item Name="Write Key (Double).vi" Type="VI" URL="/&lt;vilib&gt;/Utility/config.llb/Write Key (Double).vi"/>
						<Item Name="Write Key (I32).vi" Type="VI" URL="/&lt;vilib&gt;/Utility/config.llb/Write Key (I32).vi"/>
						<Item Name="Write Key (Path).vi" Type="VI" URL="/&lt;vilib&gt;/Utility/config.llb/Write Key (Path).vi"/>
						<Item Name="Write Key (String).vi" Type="VI" URL="/&lt;vilib&gt;/Utility/config.llb/Write Key (String).vi"/>
						<Item Name="Write Key (U32).vi" Type="VI" URL="/&lt;vilib&gt;/Utility/config.llb/Write Key (U32).vi"/>
						<Item Name="Write Key.vi" Type="VI" URL="/&lt;vilib&gt;/Utility/config.llb/Write Key.vi"/>
					</Item>
					<Item Name="config.mnu" Type="Document" URL="/&lt;menus&gt;/Categories/Programming/_File IO/config.mnu"/>
				</Item>
				<Item Name="NI_Multibyte Utilities.lvlib" Type="Library" URL="/&lt;vilib&gt;/Utility/Multibyte/NI_Multibyte Utilities.lvlib">
					<Item Name="Get Next Character.vi" Type="VI" URL="/&lt;vilib&gt;/Utility/Multibyte/Get Next Character.vi"/>
					<Item Name="Is Name Multiplatform_Allow Multibyte.vi" Type="VI" URL="/&lt;vilib&gt;/Utility/Multibyte/Is Name Multiplatform_Allow Multibyte.vi"/>
					<Item Name="Remove Multibyte Characters.vi" Type="VI" URL="/&lt;vilib&gt;/Utility/Multibyte/Remove Multibyte Characters.vi"/>
					<Item Name="Replace Specified Characters From Multibyte Array.vi" Type="VI" URL="/&lt;vilib&gt;/Utility/Multibyte/Replace Specified Characters From Multibyte Array.vi"/>
					<Item Name="To Multibyte Char Array.vi" Type="VI" URL="/&lt;vilib&gt;/Utility/Multibyte/To Multibyte Char Array.vi"/>
				</Item>
				<Item Name="NI_PackedLibraryUtility.lvlib" Type="Library" URL="/&lt;vilib&gt;/Utility/LVLibp/NI_PackedLibraryUtility.lvlib">
					<Item Name="Enable Caching.vi" Type="VI" URL="/&lt;vilib&gt;/Utility/LVLibp/Enable Caching.vi"/>
					<Item Name="Get Exported File List.vi" Type="VI" URL="/&lt;vilib&gt;/Utility/LVLibp/Get Exported File List.vi"/>
					<Item Name="Get Exported File Path.vi" Type="VI" URL="/&lt;vilib&gt;/Utility/LVLibp/Get Exported File Path.vi"/>
					<Item Name="Get Guid String.vi" Type="VI" URL="/&lt;vilib&gt;/Utility/LVLibp/Get Guid String.vi"/>
					<Item Name="Get Source Project Path.vi" Type="VI" URL="/&lt;vilib&gt;/Utility/LVLibp/Get Source Project Path.vi"/>
					<Item Name="Packed Library Path.vi" Type="VI" URL="/&lt;vilib&gt;/Utility/LVLibp/Packed Library Path.vi"/>
				</Item>
				<Item Name="NI_Unzip.lvlib" Type="Library" URL="/&lt;vilib&gt;/zip/NI_Unzip.lvlib">
					<Item Name="Unzip.vi" Type="VI" URL="/&lt;vilib&gt;/zip/Unzip.vi"/>
					<Item Name="Close unZip File.vi" Type="VI" URL="/&lt;vilib&gt;/zip/Close unZip File.vi"/>
					<Item Name="Open unZip File.vi" Type="VI" URL="/&lt;vilib&gt;/zip/Open unZip File.vi"/>
					<Item Name="Set Unzip File Date Time.vi" Type="VI" URL="/&lt;vilib&gt;/zip/Set Unzip File Date Time.vi"/>
				</Item>
				<Item Name="NI_XML.lvlib" Type="Library" URL="/&lt;vilib&gt;/xml/NI_XML.lvlib">
					<Item Name="Internal" Type="Folder">
						<Item Name="Generate Error Cluster.vi" Type="VI" URL="/&lt;vilib&gt;/xml/Internal/Generate Error Cluster.vi"/>
					</Item>
					<Item Name="Instance VIs" Type="Folder">
						<Item Name="Close Reference(Node).vi" Type="VI" URL="/&lt;vilib&gt;/xml/Close Reference(Node).vi"/>
						<Item Name="Close Reference(NNMap).vi" Type="VI" URL="/&lt;vilib&gt;/xml/Close Reference(NNMap).vi"/>
						<Item Name="Close Reference(NdList).vi" Type="VI" URL="/&lt;vilib&gt;/xml/Close Reference(NdList).vi"/>
						<Item Name="Close Reference(Impl).vi" Type="VI" URL="/&lt;vilib&gt;/xml/Close Reference(Impl).vi"/>
						<Item Name="Load XML File.vi" Type="VI" URL="/&lt;vilib&gt;/xml/Load XML File.vi"/>
						<Item Name="Load XML String.vi" Type="VI" URL="/&lt;vilib&gt;/xml/Load XML String.vi"/>
					</Item>
					<Item Name="API VIs" Type="Folder">
						<Item Name="New.vi" Type="VI" URL="/&lt;vilib&gt;/xml/New.vi"/>
						<Item Name="Close.vi" Type="VI" URL="/&lt;vilib&gt;/xml/Close.vi"/>
						<Item Name="Load.vi" Type="VI" URL="/&lt;vilib&gt;/xml/Load.vi"/>
						<Item Name="Save.vi" Type="VI" URL="/&lt;vilib&gt;/xml/Save.vi"/>
						<Item Name="Get Next Non-Text Sibling.vi" Type="VI" URL="/&lt;vilib&gt;/xml/Get Next Non-Text Sibling.vi"/>
						<Item Name="Get First Non-Text Child.vi" Type="VI" URL="/&lt;vilib&gt;/xml/Get First Non-Text Child.vi"/>
						<Item Name="Get Node Text Content.vi" Type="VI" URL="/&lt;vilib&gt;/xml/Get Node Text Content.vi"/>
						<Item Name="Get All Matched Nodes.vi" Type="VI" URL="/&lt;vilib&gt;/xml/XPath/Get All Matched Nodes.vi"/>
						<Item Name="Get First Matched Node.vi" Type="VI" URL="/&lt;vilib&gt;/xml/XPath/Get First Matched Node.vi"/>
					</Item>
				</Item>
				<Item Name="Not Found Dialog.vi" Type="VI" URL="/&lt;vilib&gt;/Utility/error.llb/Not Found Dialog.vi"/>
				<Item Name="OffsetRect.vi" Type="VI" URL="/&lt;vilib&gt;/picture/PictureSupport.llb/OffsetRect.vi"/>
				<Item Name="Open Registry Key.vi" Type="VI" URL="/&lt;vilib&gt;/registry/registry.llb/Open Registry Key.vi"/>
				<Item Name="Open URL in Default Browser (path).vi" Type="VI" URL="/&lt;vilib&gt;/Platform/browser.llb/Open URL in Default Browser (path).vi"/>
				<Item Name="Open URL in Default Browser (string).vi" Type="VI" URL="/&lt;vilib&gt;/Platform/browser.llb/Open URL in Default Browser (string).vi"/>
				<Item Name="Open URL in Default Browser core.vi" Type="VI" URL="/&lt;vilib&gt;/Platform/browser.llb/Open URL in Default Browser core.vi"/>
				<Item Name="Open URL in Default Browser.vi" Type="VI" URL="/&lt;vilib&gt;/Platform/browser.llb/Open URL in Default Browser.vi"/>
				<Item Name="Open_Create_Replace File.vi" Type="VI" URL="/&lt;vilib&gt;/_oldvers/_oldvers.llb/Open_Create_Replace File.vi"/>
				<Item Name="Path To Command Line String.vi" Type="VI" URL="/&lt;vilib&gt;/AdvancedString/Path To Command Line String.vi"/>
				<Item Name="Path to URL inner.vi" Type="VI" URL="/&lt;vilib&gt;/printing/PathToURL.llb/Path to URL inner.vi"/>
				<Item Name="Path to URL.vi" Type="VI" URL="/&lt;vilib&gt;/printing/PathToURL.llb/Path to URL.vi"/>
				<Item Name="PathToUNIXPathString.vi" Type="VI" URL="/&lt;vilib&gt;/Platform/CFURL.llb/PathToUNIXPathString.vi"/>
				<Item Name="PCT Pad String.vi" Type="VI" URL="/&lt;vilib&gt;/picture/picture.llb/PCT Pad String.vi"/>
				<Item Name="Picture to Pixmap.vi" Type="VI" URL="/&lt;vilib&gt;/picture/pictutil.llb/Picture to Pixmap.vi"/>
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
				<Item Name="Relative Path To Platform Independent String.vi" Type="VI" URL="/&lt;vilib&gt;/AdvancedString/Relative Path To Platform Independent String.vi"/>
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
				<Item Name="Space Constant.vi" Type="VI" URL="/&lt;vilib&gt;/dlg_ctls.llb/Space Constant.vi"/>
				<Item Name="STR_ASCII-Unicode.vi" Type="VI" URL="/&lt;vilib&gt;/registry/registry.llb/STR_ASCII-Unicode.vi"/>
				<Item Name="subFile Dialog.vi" Type="VI" URL="/&lt;vilib&gt;/express/express input/FileDialogBlock.llb/subFile Dialog.vi"/>
				<Item Name="System Exec.vi" Type="VI" URL="/&lt;vilib&gt;/Platform/system.llb/System Exec.vi"/>
				<Item Name="TagReturnType.ctl" Type="VI" URL="/&lt;vilib&gt;/Utility/error.llb/TagReturnType.ctl"/>
				<Item Name="Three Button Dialog CORE.vi" Type="VI" URL="/&lt;vilib&gt;/Utility/error.llb/Three Button Dialog CORE.vi"/>
				<Item Name="Three Button Dialog.vi" Type="VI" URL="/&lt;vilib&gt;/Utility/error.llb/Three Button Dialog.vi"/>
				<Item Name="Trim Whitespace One-Sided.vi" Type="VI" URL="/&lt;vilib&gt;/Utility/error.llb/Trim Whitespace One-Sided.vi"/>
				<Item Name="Trim Whitespace.vi" Type="VI" URL="/&lt;vilib&gt;/Utility/error.llb/Trim Whitespace.vi"/>
				<Item Name="Unflatten Pixmap.vi" Type="VI" URL="/&lt;vilib&gt;/picture/pixmap.llb/Unflatten Pixmap.vi"/>
				<Item Name="Unset Busy.vi" Type="VI" URL="/&lt;vilib&gt;/Utility/cursorutil.llb/Unset Busy.vi"/>
				<Item Name="whitespace.ctl" Type="VI" URL="/&lt;vilib&gt;/Utility/error.llb/whitespace.ctl"/>
				<Item Name="Write BMP Data To Buffer.vi" Type="VI" URL="/&lt;vilib&gt;/picture/bmp.llb/Write BMP Data To Buffer.vi"/>
				<Item Name="Write BMP Data.vi" Type="VI" URL="/&lt;vilib&gt;/picture/bmp.llb/Write BMP Data.vi"/>
				<Item Name="Write BMP File.vi" Type="VI" URL="/&lt;vilib&gt;/picture/bmp.llb/Write BMP File.vi"/>
				<Item Name="Write JPEG File.vi" Type="VI" URL="/&lt;vilib&gt;/picture/jpeg.llb/Write JPEG File.vi"/>
				<Item Name="Write PNG File.vi" Type="VI" URL="/&lt;vilib&gt;/picture/png.llb/Write PNG File.vi"/>
				<Item Name="Write to XML File(array).vi" Type="VI" URL="/&lt;vilib&gt;/Utility/xml.llb/Write to XML File(array).vi"/>
				<Item Name="Write to XML File(string).vi" Type="VI" URL="/&lt;vilib&gt;/Utility/xml.llb/Write to XML File(string).vi"/>
				<Item Name="Write to XML File.vi" Type="VI" URL="/&lt;vilib&gt;/Utility/xml.llb/Write to XML File.vi"/>
				<Item Name="Caraya.lvlib" Type="Library" URL="/&lt;vilib&gt;/addons/_JKI Toolkits/Caraya/Caraya.lvlib">
					<Item Name="Test Manager" Type="Folder">
						<Item Name="Basic Test Manager.lvclass" Type="LVClass" URL="/&lt;vilib&gt;/addons/_JKI Toolkits/Caraya/classes/Basic Test Manager/Basic Test Manager.lvclass">
							<Item Name="Basic Test Manager.ctl" Type="Class Private Data" URL="/&lt;vilib&gt;/addons/_JKI Toolkits/Caraya/classes/Basic Test Manager/Basic Test Manager.lvclass/Basic Test Manager.ctl"/>
							<Item Name="Accessors" Type="Folder">
								<Item Name="Read Test Report.vi" Type="VI" URL="/&lt;vilib&gt;/addons/_JKI Toolkits/Caraya/classes/Basic Test Manager/Read Test Report.vi"/>
								<Item Name="Write Test Report.vi" Type="VI" URL="/&lt;vilib&gt;/addons/_JKI Toolkits/Caraya/classes/Basic Test Manager/Write Test Report.vi"/>
								<Item Name="Read Verbose.vi" Type="VI" URL="/&lt;vilib&gt;/addons/_JKI Toolkits/Caraya/classes/Basic Test Manager/Read Verbose.vi"/>
								<Item Name="Write Verbose.vi" Type="VI" URL="/&lt;vilib&gt;/addons/_JKI Toolkits/Caraya/classes/Basic Test Manager/Write Verbose.vi"/>
								<Item Name="Read Test Suite Result.vi" Type="VI" URL="/&lt;vilib&gt;/addons/_JKI Toolkits/Caraya/classes/Basic Test Manager/Read Test Suite Result.vi"/>
								<Item Name="Write Test Suite Result.vi" Type="VI" URL="/&lt;vilib&gt;/addons/_JKI Toolkits/Caraya/classes/Basic Test Manager/Write Test Suite Result.vi"/>
								<Item Name="Read Test Events.vi" Type="VI" URL="/&lt;vilib&gt;/addons/_JKI Toolkits/Caraya/classes/Basic Test Manager/Read Test Events.vi"/>
								<Item Name="Write Test Events.vi" Type="VI" URL="/&lt;vilib&gt;/addons/_JKI Toolkits/Caraya/classes/Basic Test Manager/Write Test Events.vi"/>
							</Item>
							<Item Name="Private" Type="Folder">
								<Item Name="Report" Type="Folder">
									<Item Name="Export Report.vi" Type="VI" URL="/&lt;vilib&gt;/addons/_JKI Toolkits/Caraya/classes/Basic Test Manager/Export Report.vi"/>
									<Item Name="Reorder Keys.vi" Type="VI" URL="/&lt;vilib&gt;/addons/_JKI Toolkits/Caraya/classes/Basic Test Manager/Reorder Keys.vi"/>
									<Item Name="Generate Results.vi" Type="VI" URL="/&lt;vilib&gt;/addons/_JKI Toolkits/Caraya/classes/Basic Test Manager/Generate Results.vi"/>
								</Item>
								<Item Name="Dialogs" Type="Folder">
									<Item Name="About.vi" Type="VI" URL="/&lt;vilib&gt;/addons/_JKI Toolkits/Caraya/classes/Basic Test Manager/About.vi"/>
									<Item Name="Overwrite Dialog.vi" Type="VI" URL="/&lt;vilib&gt;/addons/_JKI Toolkits/Caraya/classes/Basic Test Manager/Overwrite Dialog.vi"/>
								</Item>
								<Item Name="Events" Type="Folder">
									<Item Name="Send Assertion Update.vi" Type="VI" URL="/&lt;vilib&gt;/addons/_JKI Toolkits/Caraya/classes/Basic Test Manager/Send Assertion Update.vi"/>
									<Item Name="Send Assertion Event.vi" Type="VI" URL="/&lt;vilib&gt;/addons/_JKI Toolkits/Caraya/classes/Basic Test Manager/Send Assertion Event.vi"/>
									<Item Name="Send Test Event.vi" Type="VI" URL="/&lt;vilib&gt;/addons/_JKI Toolkits/Caraya/classes/Basic Test Manager/Send Test Event.vi"/>
								</Item>
								<Item Name="Tree Symbol.ctl" Type="VI" URL="/&lt;vilib&gt;/addons/_JKI Toolkits/Caraya/classes/Basic Test Manager/Tree Symbol.ctl"/>
								<Item Name="UI Tab -- enum.ctl" Type="VI" URL="/&lt;vilib&gt;/addons/_JKI Toolkits/Caraya/classes/Basic Test Manager/UI Tab -- enum.ctl"/>
								<Item Name="Process Container.vi" Type="VI" URL="/&lt;vilib&gt;/addons/_JKI Toolkits/Caraya/classes/Basic Test Manager/Process Container.vi"/>
								<Item Name="Open Block Diagram.vi" Type="VI" URL="/&lt;vilib&gt;/addons/_JKI Toolkits/Caraya/classes/Basic Test Manager/Open Block Diagram.vi"/>
								<Item Name="Find-VIPath-from-CallChain.vi" Type="VI" URL="/&lt;vilib&gt;/addons/_JKI Toolkits/Caraya/classes/Basic Test Manager/Find-VIPath-from-CallChain.vi"/>
								<Item Name="LIst Searcheable Folders.vi" Type="VI" URL="/&lt;vilib&gt;/addons/_JKI Toolkits/Caraya/classes/Basic Test Manager/LIst Searcheable Folders.vi"/>
								<Item Name="Highlight Assert Node.vi" Type="VI" URL="/&lt;vilib&gt;/addons/_JKI Toolkits/Caraya/classes/Basic Test Manager/Highlight Assert Node.vi"/>
								<Item Name="Defined Passed To State.vi" Type="VI" URL="/&lt;vilib&gt;/addons/_JKI Toolkits/Caraya/classes/Basic Test Manager/Defined Passed To State.vi"/>
								<Item Name="Add Test Event To Tree.vi" Type="VI" URL="/&lt;vilib&gt;/addons/_JKI Toolkits/Caraya/classes/Basic Test Manager/Add Test Event To Tree.vi"/>
								<Item Name="Compute Orphaned Keys.vi" Type="VI" URL="/&lt;vilib&gt;/addons/_JKI Toolkits/Caraya/classes/Basic Test Manager/Compute Orphaned Keys.vi"/>
								<Item Name="Add Node To Tree.vi" Type="VI" URL="/&lt;vilib&gt;/addons/_JKI Toolkits/Caraya/classes/Basic Test Manager/Add Node To Tree.vi"/>
								<Item Name="Test State.vi" Type="VI" URL="/&lt;vilib&gt;/addons/_JKI Toolkits/Caraya/classes/Basic Test Manager/Test State.vi"/>
								<Item Name="Message Event Global.vi" Type="VI" URL="/&lt;vilib&gt;/addons/_JKI Toolkits/Caraya/classes/Basic Test Manager/Message Event Global.vi"/>
								<Item Name="Spawn Process.vi" Type="VI" URL="/&lt;vilib&gt;/addons/_JKI Toolkits/Caraya/classes/Basic Test Manager/Spawn Process.vi"/>
								<Item Name="Register Check Running.vi" Type="VI" URL="/&lt;vilib&gt;/addons/_JKI Toolkits/Caraya/classes/Basic Test Manager/Register Check Running.vi"/>
								<Item Name="Resolve New State.vi" Type="VI" URL="/&lt;vilib&gt;/addons/_JKI Toolkits/Caraya/classes/Basic Test Manager/Resolve New State.vi"/>
								<Item Name="Separator.vi" Type="VI" URL="/&lt;vilib&gt;/addons/_JKI Toolkits/Caraya/classes/Basic Test Manager/Separator.vi"/>
								<Item Name="Test State.ctl" Type="VI" URL="/&lt;vilib&gt;/addons/_JKI Toolkits/Caraya/classes/Basic Test Manager/Test State.ctl"/>
								<Item Name="Rerun Tests.vi" Type="VI" URL="/&lt;vilib&gt;/addons/_JKI Toolkits/Caraya/classes/Basic Test Manager/Rerun Tests.vi"/>
							</Item>
							<Item Name="_deprecated" Type="Folder">
								<Item Name="Timestamp to String.vi" Type="VI" URL="/&lt;vilib&gt;/addons/_JKI Toolkits/Caraya/classes/Basic Test Manager/Timestamp to String.vi"/>
							</Item>
							<Item Name="Process.vi" Type="VI" URL="/&lt;vilib&gt;/addons/_JKI Toolkits/Caraya/classes/Basic Test Manager/Process.vi"/>
							<Item Name="Initialize.vi" Type="VI" URL="/&lt;vilib&gt;/addons/_JKI Toolkits/Caraya/classes/Basic Test Manager/Initialize.vi"/>
							<Item Name="Register Message.vi" Type="VI" URL="/&lt;vilib&gt;/addons/_JKI Toolkits/Caraya/classes/Basic Test Manager/Register Message.vi"/>
							<Item Name="Read Interactive.vi" Type="VI" URL="/&lt;vilib&gt;/addons/_JKI Toolkits/Caraya/classes/Basic Test Manager/Read Interactive.vi"/>
							<Item Name="Write Interactive.vi" Type="VI" URL="/&lt;vilib&gt;/addons/_JKI Toolkits/Caraya/classes/Basic Test Manager/Write Interactive.vi"/>
							<Item Name="GetConfigFilepath.vi" Type="VI" URL="/&lt;vilib&gt;/addons/_JKI Toolkits/Caraya/classes/Basic Test Manager/GetConfigFilepath.vi"/>
						</Item>
						<Item Name="Test Event Storage.lvclass" Type="LVClass" URL="/&lt;vilib&gt;/addons/_JKI Toolkits/Caraya/classes/Test Event Storage/Test Event Storage.lvclass">
							<Item Name="Test Event Storage.ctl" Type="Class Private Data" URL="/&lt;vilib&gt;/addons/_JKI Toolkits/Caraya/classes/Test Event Storage/Test Event Storage.lvclass/Test Event Storage.ctl"/>
							<Item Name="Private" Type="Folder">
								<Item Name="Add Update Node.vi" Type="VI" URL="/&lt;vilib&gt;/addons/_JKI Toolkits/Caraya/classes/Test Event Storage/Add Update Node.vi"/>
								<Item Name="Find Owner Type.vi" Type="VI" URL="/&lt;vilib&gt;/addons/_JKI Toolkits/Caraya/classes/Test Event Storage/Find Owner Type.vi"/>
								<Item Name="Store Type -- enum.ctl" Type="VI" URL="/&lt;vilib&gt;/addons/_JKI Toolkits/Caraya/classes/Test Event Storage/Store Type -- enum.ctl"/>
							</Item>
							<Item Name="typedefs" Type="Folder">
								<Item Name="test store -- cluster.ctl" Type="VI" URL="/&lt;vilib&gt;/addons/_JKI Toolkits/Caraya/classes/Test Event Storage/test store -- cluster.ctl"/>
								<Item Name="assert store -- cluster.ctl" Type="VI" URL="/&lt;vilib&gt;/addons/_JKI Toolkits/Caraya/classes/Test Event Storage/assert store -- cluster.ctl"/>
							</Item>
							<Item Name="Conversions" Type="Folder">
								<Item Name="transform MessageProperties.vi" Type="VI" URL="/&lt;vilib&gt;/addons/_JKI Toolkits/Caraya/classes/Test Event Storage/transform MessageProperties.vi"/>
								<Item Name="transform MessageMeasurement.vi" Type="VI" URL="/&lt;vilib&gt;/addons/_JKI Toolkits/Caraya/classes/Test Event Storage/transform MessageMeasurement.vi"/>
								<Item Name="toTestEvent.vi" Type="VI" URL="/&lt;vilib&gt;/addons/_JKI Toolkits/Caraya/classes/Test Event Storage/toTestEvent.vi"/>
							</Item>
							<Item Name="Get Tests Events by Key.vi" Type="VI" URL="/&lt;vilib&gt;/addons/_JKI Toolkits/Caraya/classes/Test Event Storage/Get Tests Events by Key.vi"/>
							<Item Name="Get All Test Events.vi" Type="VI" URL="/&lt;vilib&gt;/addons/_JKI Toolkits/Caraya/classes/Test Event Storage/Get All Test Events.vi"/>
							<Item Name="Get Test Registration by Key.vi" Type="VI" URL="/&lt;vilib&gt;/addons/_JKI Toolkits/Caraya/classes/Test Event Storage/Get Test Registration by Key.vi"/>
							<Item Name="Get All Test Registrations.vi" Type="VI" URL="/&lt;vilib&gt;/addons/_JKI Toolkits/Caraya/classes/Test Event Storage/Get All Test Registrations.vi"/>
							<Item Name="Get Root Test.vi" Type="VI" URL="/&lt;vilib&gt;/addons/_JKI Toolkits/Caraya/classes/Test Event Storage/Get Root Test.vi"/>
							<Item Name="New-Update Test.vi" Type="VI" URL="/&lt;vilib&gt;/addons/_JKI Toolkits/Caraya/classes/Test Event Storage/New-Update Test.vi"/>
							<Item Name="New-Update Assertion.vi" Type="VI" URL="/&lt;vilib&gt;/addons/_JKI Toolkits/Caraya/classes/Test Event Storage/New-Update Assertion.vi"/>
							<Item Name="Update Verbose Explanation.vi" Type="VI" URL="/&lt;vilib&gt;/addons/_JKI Toolkits/Caraya/classes/Test Event Storage/Update Verbose Explanation.vi"/>
							<Item Name="Update Test-Assertion KVP.vi" Type="VI" URL="/&lt;vilib&gt;/addons/_JKI Toolkits/Caraya/classes/Test Event Storage/Update Test-Assertion KVP.vi"/>
							<Item Name="Update Test-Assertion Measurement.vi" Type="VI" URL="/&lt;vilib&gt;/addons/_JKI Toolkits/Caraya/classes/Test Event Storage/Update Test-Assertion Measurement.vi"/>
						</Item>
					</Item>
					<Item Name="Private" Type="Folder">
						<Item Name="Assert Factory" Type="Folder">
							<Item Name="Test Assert Factory.lvclass" Type="LVClass" URL="/&lt;vilib&gt;/addons/_JKI Toolkits/Caraya/classes/Test Assert Factory/Test Assert Factory.lvclass">
								<Item Name="Test Assert Factory.ctl" Type="Class Private Data" URL="/&lt;vilib&gt;/addons/_JKI Toolkits/Caraya/classes/Test Assert Factory/Test Assert Factory.lvclass/Test Assert Factory.ctl"/>
								<Item Name="Private" Type="Folder">
									<Item Name="Test Storage Global.vi" Type="VI" URL="/&lt;vilib&gt;/addons/_JKI Toolkits/Caraya/classes/Test Assert Factory/Test Storage Global.vi"/>
									<Item Name="Test Storage -- cluster.ctl" Type="VI" URL="/&lt;vilib&gt;/addons/_JKI Toolkits/Caraya/classes/Test Assert Factory/Test Storage -- cluster.ctl"/>
								</Item>
								<Item Name="Accessors" Type="Folder">
									<Item Name="Read Report File.vi" Type="VI" URL="/&lt;vilib&gt;/addons/_JKI Toolkits/Caraya/classes/Test Assert Factory/Read Report File.vi"/>
									<Item Name="Write Report File.vi" Type="VI" URL="/&lt;vilib&gt;/addons/_JKI Toolkits/Caraya/classes/Test Assert Factory/Write Report File.vi"/>
									<Item Name="Read Interactive.vi" Type="VI" URL="/&lt;vilib&gt;/addons/_JKI Toolkits/Caraya/classes/Test Assert Factory/Read Interactive.vi"/>
									<Item Name="Write Interactive.vi" Type="VI" URL="/&lt;vilib&gt;/addons/_JKI Toolkits/Caraya/classes/Test Assert Factory/Write Interactive.vi"/>
									<Item Name="Read Verbose.vi" Type="VI" URL="/&lt;vilib&gt;/addons/_JKI Toolkits/Caraya/classes/Test Assert Factory/Read Verbose.vi"/>
									<Item Name="Write Verbose.vi" Type="VI" URL="/&lt;vilib&gt;/addons/_JKI Toolkits/Caraya/classes/Test Assert Factory/Write Verbose.vi"/>
									<Item Name="Read Test Suite Result.vi" Type="VI" URL="/&lt;vilib&gt;/addons/_JKI Toolkits/Caraya/classes/Test Assert Factory/Read Test Suite Result.vi"/>
									<Item Name="Write Test Suite Result.vi" Type="VI" URL="/&lt;vilib&gt;/addons/_JKI Toolkits/Caraya/classes/Test Assert Factory/Write Test Suite Result.vi"/>
									<Item Name="Read Public Events.vi" Type="VI" URL="/&lt;vilib&gt;/addons/_JKI Toolkits/Caraya/classes/Test Assert Factory/Read Public Events.vi"/>
									<Item Name="Write Public Events.vi" Type="VI" URL="/&lt;vilib&gt;/addons/_JKI Toolkits/Caraya/classes/Test Assert Factory/Write Public Events.vi"/>
								</Item>
								<Item Name="Create Assert Factory.vi" Type="VI" URL="/&lt;vilib&gt;/addons/_JKI Toolkits/Caraya/classes/Test Assert Factory/Create Assert Factory.vi"/>
								<Item Name="Destroy Test Assert Factory.vi" Type="VI" URL="/&lt;vilib&gt;/addons/_JKI Toolkits/Caraya/classes/Test Assert Factory/Destroy Test Assert Factory.vi"/>
								<Item Name="Read Test Manager.vi" Type="VI" URL="/&lt;vilib&gt;/addons/_JKI Toolkits/Caraya/classes/Test Assert Factory/Read Test Manager.vi"/>
								<Item Name="Read Assert.vi" Type="VI" URL="/&lt;vilib&gt;/addons/_JKI Toolkits/Caraya/classes/Test Assert Factory/Read Assert.vi"/>
								<Item Name="Register Test.vi" Type="VI" URL="/&lt;vilib&gt;/addons/_JKI Toolkits/Caraya/classes/Test Assert Factory/Register Test.vi"/>
							</Item>
						</Item>
						<Item Name="Assert Factory Manager" Type="Folder">
							<Item Name="Assert Factory Manager.lvclass" Type="LVClass" URL="/&lt;vilib&gt;/addons/_JKI Toolkits/Caraya/classes/Assert Factory Manager/Assert Factory Manager.lvclass">
								<Item Name="Assert Factory Manager.ctl" Type="Class Private Data" URL="/&lt;vilib&gt;/addons/_JKI Toolkits/Caraya/classes/Assert Factory Manager/Assert Factory Manager.lvclass/Assert Factory Manager.ctl"/>
								<Item Name="Private" Type="Folder">
									<Item Name="Assert Factory Global.vi" Type="VI" URL="/&lt;vilib&gt;/addons/_JKI Toolkits/Caraya/classes/Assert Factory Manager/Assert Factory Global.vi"/>
								</Item>
								<Item Name="Register Assert Factory.vi" Type="VI" URL="/&lt;vilib&gt;/addons/_JKI Toolkits/Caraya/classes/Assert Factory Manager/Register Assert Factory.vi"/>
								<Item Name="Reset Assert Factory.vi" Type="VI" URL="/&lt;vilib&gt;/addons/_JKI Toolkits/Caraya/classes/Assert Factory Manager/Reset Assert Factory.vi"/>
								<Item Name="Read Assert Factory.vi" Type="VI" URL="/&lt;vilib&gt;/addons/_JKI Toolkits/Caraya/classes/Assert Factory Manager/Read Assert Factory.vi"/>
								<Item Name="Register Read Assert Factory.vi" Type="VI" URL="/&lt;vilib&gt;/addons/_JKI Toolkits/Caraya/classes/Assert Factory Manager/Register Read Assert Factory.vi"/>
							</Item>
						</Item>
						<Item Name="Call Chain To Hash.vi" Type="VI" URL="/&lt;vilib&gt;/addons/_JKI Toolkits/Caraya/subVIs/Call Chain To Hash.vi"/>
						<Item Name="Call Chain To Hash Hierarchy.vi" Type="VI" URL="/&lt;vilib&gt;/addons/_JKI Toolkits/Caraya/subVIs/Call Chain To Hash Hierarchy.vi"/>
						<Item Name="VI Name.vi" Type="VI" URL="/&lt;vilib&gt;/addons/_JKI Toolkits/Caraya/subVIs/VI Name.vi"/>
						<Item Name="Custom or Standard Message.vi" Type="VI" URL="/&lt;vilib&gt;/addons/_JKI Toolkits/Caraya/subVIs/Custom or Standard Message.vi"/>
						<Item Name="Get Library Info.vi" Type="VI" URL="/&lt;vilib&gt;/addons/_JKI Toolkits/Caraya/subVIs/Get Library Info.vi"/>
						<Item Name="Library Info Constant.vi" Type="VI" URL="/&lt;vilib&gt;/addons/_JKI Toolkits/Caraya/subVIs/Library Info Constant.vi"/>
						<Item Name="private_iterator.vi" Type="VI" URL="/&lt;vilib&gt;/addons/_JKI Toolkits/Caraya/subVIs/private_iterator.vi"/>
					</Item>
					<Item Name="Reporting" Type="Folder">
						<Item Name="AutoSelect Test Report.vi" Type="VI" URL="/&lt;vilib&gt;/addons/_JKI Toolkits/Caraya/classes/Test Report/AutoSelect Test Report.vi"/>
						<Item Name="Test Report.lvclass" Type="LVClass" URL="/&lt;vilib&gt;/addons/_JKI Toolkits/Caraya/classes/Test Report/Test Report.lvclass">
							<Item Name="Test Report.ctl" Type="Class Private Data" URL="/&lt;vilib&gt;/addons/_JKI Toolkits/Caraya/classes/Test Report/Test Report.lvclass/Test Report.ctl"/>
							<Item Name="Accessors" Type="Folder">
								<Item Name="Read Test Result.vi" Type="VI" URL="/&lt;vilib&gt;/addons/_JKI Toolkits/Caraya/classes/Test Report/Read Test Result.vi"/>
								<Item Name="Write Test Result.vi" Type="VI" URL="/&lt;vilib&gt;/addons/_JKI Toolkits/Caraya/classes/Test Report/Write Test Result.vi"/>
								<Item Name="Read Verbose.vi" Type="VI" URL="/&lt;vilib&gt;/addons/_JKI Toolkits/Caraya/classes/Test Report/Read Verbose.vi"/>
								<Item Name="Write Verbose.vi" Type="VI" URL="/&lt;vilib&gt;/addons/_JKI Toolkits/Caraya/classes/Test Report/Write Verbose.vi"/>
								<Item Name="Read MsgSerializer.vi" Type="VI" URL="/&lt;vilib&gt;/addons/_JKI Toolkits/Caraya/classes/Test Report/Read MsgSerializer.vi"/>
								<Item Name="Write MsgSerializer.vi" Type="VI" URL="/&lt;vilib&gt;/addons/_JKI Toolkits/Caraya/classes/Test Report/Write MsgSerializer.vi"/>
							</Item>
							<Item Name="protected" Type="Folder">
								<Item Name="Indent.vi" Type="VI" URL="/&lt;vilib&gt;/addons/_JKI Toolkits/Caraya/classes/Test Report/Indent.vi"/>
								<Item Name="Call Chain To Indent.vi" Type="VI" URL="/&lt;vilib&gt;/addons/_JKI Toolkits/Caraya/classes/Test Report/Call Chain To Indent.vi"/>
								<Item Name="Transpose Export Error Code.vi" Type="VI" URL="/&lt;vilib&gt;/addons/_JKI Toolkits/Caraya/classes/Test Report/Transpose Export Error Code.vi"/>
								<Item Name="AlignString.vi" Type="VI" URL="/&lt;vilib&gt;/addons/_JKI Toolkits/Caraya/classes/Test Report.Event/AlignString.vi"/>
							</Item>
							<Item Name="Export.vi" Type="VI" URL="/&lt;vilib&gt;/addons/_JKI Toolkits/Caraya/classes/Test Report/Export.vi"/>
							<Item Name="isReporting.vi" Type="VI" URL="/&lt;vilib&gt;/addons/_JKI Toolkits/Caraya/classes/Test Report/isReporting.vi"/>
						</Item>
						<Item Name="Test Report.Default.lvclass" Type="LVClass" URL="/&lt;vilib&gt;/addons/_JKI Toolkits/Caraya/classes/Test Report.Default/Test Report.Default.lvclass">
							<Item Name="Test Report.Default.ctl" Type="Class Private Data" URL="/&lt;vilib&gt;/addons/_JKI Toolkits/Caraya/classes/Test Report.Default/Test Report.Default.lvclass/Test Report.Default.ctl"/>
							<Item Name="Accessors" Type="Folder">
								<Item Name="Read Report Path.vi" Type="VI" URL="/&lt;vilib&gt;/addons/_JKI Toolkits/Caraya/classes/Test Report.Default/Read Report Path.vi"/>
								<Item Name="Write Report Path.vi" Type="VI" URL="/&lt;vilib&gt;/addons/_JKI Toolkits/Caraya/classes/Test Report.Default/Write Report Path.vi"/>
							</Item>
							<Item Name="Private" Type="Folder">
								<Item Name="Test To Report Entry.vi" Type="VI" URL="/&lt;vilib&gt;/addons/_JKI Toolkits/Caraya/classes/Test Report.Default/Test To Report Entry.vi"/>
								<Item Name="Assert To Report Entry.vi" Type="VI" URL="/&lt;vilib&gt;/addons/_JKI Toolkits/Caraya/classes/Test Report.Default/Assert To Report Entry.vi"/>
							</Item>
							<Item Name="Create DefaultReport.vi" Type="VI" URL="/&lt;vilib&gt;/addons/_JKI Toolkits/Caraya/classes/Test Report.Default/Create DefaultReport.vi"/>
							<Item Name="Export.vi" Type="VI" URL="/&lt;vilib&gt;/addons/_JKI Toolkits/Caraya/classes/Test Report.Default/Export.vi"/>
							<Item Name="isReporting.vi" Type="VI" URL="/&lt;vilib&gt;/addons/_JKI Toolkits/Caraya/classes/Test Report.Default/isReporting.vi"/>
							<Item Name="Default.Append Attributes.vi" Type="VI" URL="/&lt;vilib&gt;/addons/_JKI Toolkits/Caraya/classes/Test Report.Default/Default.Append Attributes.vi"/>
						</Item>
						<Item Name="Test Report.Event.lvclass" Type="LVClass" URL="/&lt;vilib&gt;/addons/_JKI Toolkits/Caraya/classes/Test Report.Event/Test Report.Event.lvclass">
							<Item Name="Test Report.Event.ctl" Type="Class Private Data" URL="/&lt;vilib&gt;/addons/_JKI Toolkits/Caraya/classes/Test Report.Event/Test Report.Event.lvclass/Test Report.Event.ctl"/>
							<Item Name="Accessors" Type="Folder">
								<Item Name="Read Report Path.vi" Type="VI" URL="/&lt;vilib&gt;/addons/_JKI Toolkits/Caraya/classes/Test Report.Event/Read Report Path.vi"/>
								<Item Name="Write ReportEvent.vi" Type="VI" URL="/&lt;vilib&gt;/addons/_JKI Toolkits/Caraya/classes/Test Report.Event/Write ReportEvent.vi"/>
							</Item>
							<Item Name="Private" Type="Folder">
								<Item Name="Test To Report Entry.vi" Type="VI" URL="/&lt;vilib&gt;/addons/_JKI Toolkits/Caraya/classes/Test Report.Event/Test To Report Entry.vi"/>
								<Item Name="Assert To Report Entry.vi" Type="VI" URL="/&lt;vilib&gt;/addons/_JKI Toolkits/Caraya/classes/Test Report.Event/Assert To Report Entry.vi"/>
							</Item>
							<Item Name="Create EventReport.vi" Type="VI" URL="/&lt;vilib&gt;/addons/_JKI Toolkits/Caraya/classes/Test Report.Event/Create EventReport.vi"/>
							<Item Name="Export.vi" Type="VI" URL="/&lt;vilib&gt;/addons/_JKI Toolkits/Caraya/classes/Test Report.Event/Export.vi"/>
							<Item Name="isReporting.vi" Type="VI" URL="/&lt;vilib&gt;/addons/_JKI Toolkits/Caraya/classes/Test Report.Event/isReporting.vi"/>
							<Item Name="Append Attributes.vi" Type="VI" URL="/&lt;vilib&gt;/addons/_JKI Toolkits/Caraya/classes/Test Report.Event/Append Attributes.vi"/>
						</Item>
						<Item Name="Test Report.JUnit.lvclass" Type="LVClass" URL="/&lt;vilib&gt;/addons/_JKI Toolkits/Caraya/classes/Test Report.JUnit/Test Report.JUnit.lvclass">
							<Item Name="Test Report.JUnit.ctl" Type="Class Private Data" URL="/&lt;vilib&gt;/addons/_JKI Toolkits/Caraya/classes/Test Report.JUnit/Test Report.JUnit.lvclass/Test Report.JUnit.ctl"/>
							<Item Name="Accessors" Type="Folder">
								<Item Name="Read Report Path.vi" Type="VI" URL="/&lt;vilib&gt;/addons/_JKI Toolkits/Caraya/classes/Test Report.JUnit/Read Report Path.vi"/>
								<Item Name="Write Report Path.vi" Type="VI" URL="/&lt;vilib&gt;/addons/_JKI Toolkits/Caraya/classes/Test Report.JUnit/Write Report Path.vi"/>
							</Item>
							<Item Name="Private" Type="Folder">
								<Item Name="Test To Report Entry.vi" Type="VI" URL="/&lt;vilib&gt;/addons/_JKI Toolkits/Caraya/classes/Test Report.JUnit/Test To Report Entry.vi"/>
								<Item Name="Assert To Report Entry.vi" Type="VI" URL="/&lt;vilib&gt;/addons/_JKI Toolkits/Caraya/classes/Test Report.JUnit/Assert To Report Entry.vi"/>
								<Item Name="getXMLTestSuite.vi" Type="VI" URL="/&lt;vilib&gt;/addons/_JKI Toolkits/Caraya/classes/Test Report.JUnit/getXMLTestSuite.vi"/>
								<Item Name="getXMLTestCases.vi" Type="VI" URL="/&lt;vilib&gt;/addons/_JKI Toolkits/Caraya/classes/Test Report.JUnit/getXMLTestCases.vi"/>
								<Item Name="getXMLTestCases (Extended).vi" Type="VI" URL="/&lt;vilib&gt;/addons/_JKI Toolkits/Caraya/classes/Test Report.JUnit/getXMLTestCases (Extended).vi"/>
							</Item>
							<Item Name="typedefs" Type="Folder">
								<Item Name="testsuite -- cluster.ctl" Type="VI" URL="/&lt;vilib&gt;/addons/_JKI Toolkits/Caraya/classes/Test Report.JUnit/testsuite -- cluster.ctl"/>
								<Item Name="testcase -- cluster.ctl" Type="VI" URL="/&lt;vilib&gt;/addons/_JKI Toolkits/Caraya/classes/Test Report.JUnit/testcase -- cluster.ctl"/>
								<Item Name="property -- cluster.ctl" Type="VI" URL="/&lt;vilib&gt;/addons/_JKI Toolkits/Caraya/classes/Test Report.JUnit/property -- cluster.ctl"/>
								<Item Name="extended -- cluster.ctl" Type="VI" URL="/&lt;vilib&gt;/addons/_JKI Toolkits/Caraya/classes/Test Report.JUnit/extended -- cluster.ctl"/>
							</Item>
							<Item Name="protected" Type="Folder">
								<Item Name="escapeXML.vi" Type="VI" URL="/&lt;vilib&gt;/addons/_JKI Toolkits/Caraya/classes/Test Report.JUnit/escapeXML.vi"/>
								<Item Name="getXMLHeader.vi" Type="VI" URL="/&lt;vilib&gt;/addons/_JKI Toolkits/Caraya/classes/Test Report.JUnit/getXMLHeader.vi"/>
								<Item Name="SerializeAttributes.vi" Type="VI" URL="/&lt;vilib&gt;/addons/_JKI Toolkits/Caraya/classes/Test Report.JUnit/SerializeAttributes.vi"/>
							</Item>
							<Item Name="_test" Type="Folder">
								<Item Name="_test_formattingJUnitFromResult.vi" Type="VI" URL="/&lt;vilib&gt;/addons/_JKI Toolkits/Caraya/classes/Test Report.JUnit/_test_formattingJUnitFromResult.vi"/>
								<Item Name="_test_formattingJUnitFromResult__2.vi" Type="VI" URL="/&lt;vilib&gt;/addons/_JKI Toolkits/Caraya/classes/Test Report.JUnit/_test_formattingJUnitFromResult__2.vi"/>
							</Item>
							<Item Name="Create JUnit Report.vi" Type="VI" URL="/&lt;vilib&gt;/addons/_JKI Toolkits/Caraya/classes/Test Report.JUnit/Create JUnit Report.vi"/>
							<Item Name="Export.vi" Type="VI" URL="/&lt;vilib&gt;/addons/_JKI Toolkits/Caraya/classes/Test Report.JUnit/Export.vi"/>
							<Item Name="isReporting.vi" Type="VI" URL="/&lt;vilib&gt;/addons/_JKI Toolkits/Caraya/classes/Test Report.JUnit/isReporting.vi"/>
						</Item>
						<Item Name="Test Report.Template.lvclass" Type="LVClass" URL="/&lt;vilib&gt;/addons/_JKI Toolkits/Caraya/classes/Test Report.Template/Test Report.Template.lvclass">
							<Item Name="Test Report.Template.ctl" Type="Class Private Data" URL="/&lt;vilib&gt;/addons/_JKI Toolkits/Caraya/classes/Test Report.Template/Test Report.Template.lvclass/Test Report.Template.ctl"/>
							<Item Name="Accessors" Type="Folder">
								<Item Name="Read Report Path.vi" Type="VI" URL="/&lt;vilib&gt;/addons/_JKI Toolkits/Caraya/classes/Test Report.Template/Read Report Path.vi"/>
								<Item Name="Write Report Path.vi" Type="VI" URL="/&lt;vilib&gt;/addons/_JKI Toolkits/Caraya/classes/Test Report.Template/Write Report Path.vi"/>
							</Item>
							<Item Name="Private" Type="Folder">
								<Item Name="Test To Report Entry.vi" Type="VI" URL="/&lt;vilib&gt;/addons/_JKI Toolkits/Caraya/classes/Test Report.Template/Test To Report Entry.vi"/>
								<Item Name="Assert To Report Entry.vi" Type="VI" URL="/&lt;vilib&gt;/addons/_JKI Toolkits/Caraya/classes/Test Report.Template/Assert To Report Entry.vi"/>
							</Item>
							<Item Name="Create Report (Template).vi" Type="VI" URL="/&lt;vilib&gt;/addons/_JKI Toolkits/Caraya/classes/Test Report.Template/Create Report (Template).vi"/>
							<Item Name="isReporting.vi" Type="VI" URL="/&lt;vilib&gt;/addons/_JKI Toolkits/Caraya/classes/Test Report.Template/isReporting.vi"/>
							<Item Name="Export.vi" Type="VI" URL="/&lt;vilib&gt;/addons/_JKI Toolkits/Caraya/classes/Test Report.Template/Export.vi"/>
						</Item>
					</Item>
					<Item Name="Results" Type="Folder">
						<Item Name="Test Result.lvclass" Type="LVClass" URL="/&lt;vilib&gt;/addons/_JKI Toolkits/Caraya/classes/Test Result/Test Result.lvclass">
							<Item Name="Test Result.ctl" Type="Class Private Data" URL="/&lt;vilib&gt;/addons/_JKI Toolkits/Caraya/classes/Test Result/Test Result.lvclass/Test Result.ctl"/>
							<Item Name="toJSON" Type="Folder">
								<Item Name="utilities" Type="Folder">
									<Item Name="json_indentlevel.vi" Type="VI" URL="/&lt;vilib&gt;/addons/_JKI Toolkits/Caraya/classes/Test Result/json_indentlevel.vi"/>
									<Item Name="json_escape.vi" Type="VI" URL="/&lt;vilib&gt;/addons/_JKI Toolkits/Caraya/classes/Test Result/json_escape.vi"/>
									<Item Name="json_array.vi" Type="VI" URL="/&lt;vilib&gt;/addons/_JKI Toolkits/Caraya/classes/Test Result/json_array.vi"/>
									<Item Name="json_cluster.vi" Type="VI" URL="/&lt;vilib&gt;/addons/_JKI Toolkits/Caraya/classes/Test Result/json_cluster.vi"/>
									<Item Name="json_test-error.vi" Type="VI" URL="/&lt;vilib&gt;/addons/_JKI Toolkits/Caraya/classes/Test Result/json_test-error.vi"/>
									<Item Name="json_call-chain.vi" Type="VI" URL="/&lt;vilib&gt;/addons/_JKI Toolkits/Caraya/classes/Test Result/json_call-chain.vi"/>
								</Item>
								<Item Name="Test Registration Event to JSON.vi" Type="VI" URL="/&lt;vilib&gt;/addons/_JKI Toolkits/Caraya/classes/Test Result/Test Registration Event to JSON.vi"/>
								<Item Name="Test Assert Event to JSON.vi" Type="VI" URL="/&lt;vilib&gt;/addons/_JKI Toolkits/Caraya/classes/Test Result/Test Assert Event to JSON.vi"/>
								<Item Name="Test Assert Update Event to JSON.vi" Type="VI" URL="/&lt;vilib&gt;/addons/_JKI Toolkits/Caraya/classes/Test Result/Test Assert Update Event to JSON.vi"/>
								<Item Name="Test Result Event to JSON.vi" Type="VI" URL="/&lt;vilib&gt;/addons/_JKI Toolkits/Caraya/classes/Test Result/Test Result Event to JSON.vi"/>
							</Item>
							<Item Name="Conversion" Type="Folder">
								<Item Name="DownConvert AssertEventData.vi" Type="VI" URL="/&lt;vilib&gt;/addons/_JKI Toolkits/Caraya/classes/Test Result/DownConvert AssertEventData.vi"/>
								<Item Name="UpConvert AssertEventData.vi" Type="VI" URL="/&lt;vilib&gt;/addons/_JKI Toolkits/Caraya/classes/Test Result/UpConvert AssertEventData.vi"/>
								<Item Name="DownConvert Test Node.vi" Type="VI" URL="/&lt;vilib&gt;/addons/_JKI Toolkits/Caraya/classes/Test Result/DownConvert Test Node.vi"/>
								<Item Name="UpConvert Test Node.vi" Type="VI" URL="/&lt;vilib&gt;/addons/_JKI Toolkits/Caraya/classes/Test Result/UpConvert Test Node.vi"/>
							</Item>
							<Item Name="Get Type.vi" Type="VI" URL="/&lt;vilib&gt;/addons/_JKI Toolkits/Caraya/classes/Test Result/Get Type.vi"/>
							<Item Name="Add Node.vi" Type="VI" URL="/&lt;vilib&gt;/addons/_JKI Toolkits/Caraya/classes/Test Result/Add Node.vi"/>
							<Item Name="Add Node (Extended).vi" Type="VI" URL="/&lt;vilib&gt;/addons/_JKI Toolkits/Caraya/classes/Test Result/Add Node (Extended).vi"/>
							<Item Name="List Nodes.vi" Type="VI" URL="/&lt;vilib&gt;/addons/_JKI Toolkits/Caraya/classes/Test Result/List Nodes.vi"/>
							<Item Name="Get Node.vi" Type="VI" URL="/&lt;vilib&gt;/addons/_JKI Toolkits/Caraya/classes/Test Result/Get Node.vi"/>
							<Item Name="Get Node (Extended).vi" Type="VI" URL="/&lt;vilib&gt;/addons/_JKI Toolkits/Caraya/classes/Test Result/Get Node (Extended).vi"/>
							<Item Name="Get All Test Results.vi" Type="VI" URL="/&lt;vilib&gt;/addons/_JKI Toolkits/Caraya/classes/Test Result/Get All Test Results.vi"/>
							<Item Name="Get All Test Results (Extended).vi" Type="VI" URL="/&lt;vilib&gt;/addons/_JKI Toolkits/Caraya/classes/Test Result/Get All Test Results (Extended).vi"/>
							<Item Name="Test Node.ctl" Type="VI" URL="/&lt;vilib&gt;/addons/_JKI Toolkits/Caraya/classes/Test Result/Test Node.ctl"/>
							<Item Name="Test Node (Extended).ctl" Type="VI" URL="/&lt;vilib&gt;/addons/_JKI Toolkits/Caraya/classes/Test Result/Test Node (Extended).ctl"/>
							<Item Name="Test Registration Data.ctl" Type="VI" URL="/&lt;vilib&gt;/addons/_JKI Toolkits/Caraya/classes/Test Result/Test Registration Data.ctl"/>
							<Item Name="Node Results.ctl" Type="VI" URL="/&lt;vilib&gt;/addons/_JKI Toolkits/Caraya/classes/Test Result/Node Results.ctl"/>
							<Item Name="Node Results (Extended).ctl" Type="VI" URL="/&lt;vilib&gt;/addons/_JKI Toolkits/Caraya/classes/Test Result/Node Results (Extended).ctl"/>
							<Item Name="Assert Event Data.ctl" Type="VI" URL="/&lt;vilib&gt;/addons/_JKI Toolkits/Caraya/classes/Test Result/Assert Event Data.ctl"/>
							<Item Name="Assert Event Data (Extended).ctl" Type="VI" URL="/&lt;vilib&gt;/addons/_JKI Toolkits/Caraya/classes/Test Result/Assert Event Data (Extended).ctl"/>
							<Item Name="Test Verbose Explanation.ctl" Type="VI" URL="/&lt;vilib&gt;/addons/_JKI Toolkits/Caraya/classes/Test Result/Test Verbose Explanation.ctl"/>
							<Item Name="Test Events -- cluster.ctl" Type="VI" URL="/&lt;vilib&gt;/addons/_JKI Toolkits/Caraya/classes/Test Result/Test Events -- cluster.ctl"/>
						</Item>
					</Item>
					<Item Name="Utilities" Type="Folder">
						<Item Name="LibPath" Type="Folder">
							<Item Name="FindLibPath.vi" Type="VI" URL="/&lt;vilib&gt;/addons/_JKI Toolkits/Caraya/subVIs/FindLibPath.vi"/>
						</Item>
						<Item Name="SearchForAllTests (Folder).vi" Type="VI" URL="/&lt;vilib&gt;/addons/_JKI Toolkits/Caraya/subVIs/SearchForAllTests (Folder).vi"/>
						<Item Name="Run Tests Programmatically.vi" Type="VI" URL="/&lt;vilib&gt;/addons/_JKI Toolkits/Caraya/subVIs/Run Tests Programmatically.vi"/>
						<Item Name="Run Tests (Project).vi" Type="VI" URL="/&lt;vilib&gt;/addons/_JKI Toolkits/Caraya/subVIs/Run Tests (Project).vi"/>
						<Item Name="Get Caraya Namespace.vi" Type="VI" URL="/&lt;vilib&gt;/addons/_JKI Toolkits/Caraya/subVIs/Get Caraya Namespace.vi"/>
						<Item Name="Get Caraya Library Information.vi" Type="VI" URL="/&lt;vilib&gt;/addons/_JKI Toolkits/Caraya/subVIs/Get Caraya Library Information.vi"/>
						<Item Name="Caraya Library Info.ctl" Type="VI" URL="/&lt;vilib&gt;/addons/_JKI Toolkits/Caraya/subVIs/Caraya Library Info.ctl"/>
						<Item Name="Path to Common String.vi" Type="VI" URL="/&lt;vilib&gt;/addons/_JKI Toolkits/Caraya/subVIs/Path to Common String.vi"/>
						<Item Name="guid_generator.vi" Type="VI" URL="/&lt;vilib&gt;/addons/_JKI Toolkits/Caraya/subVIs/guid_generator.vi"/>
					</Item>
					<Item Name="Runners" Type="Folder">
						<Item Name="Test Runner.lvclass" Type="LVClass" URL="/&lt;vilib&gt;/addons/_JKI Toolkits/Caraya/classes/Test Runner/Test Runner.lvclass">
							<Item Name="Test Runner.ctl" Type="Class Private Data" URL="/&lt;vilib&gt;/addons/_JKI Toolkits/Caraya/classes/Test Runner/Test Runner.lvclass/Test Runner.ctl"/>
							<Item Name="accessors" Type="Folder">
								<Item Name="Test VIs" Type="Property Definition">
									<Item Name="Read Test VIs.vi" Type="VI" URL="/&lt;vilib&gt;/addons/_JKI Toolkits/Caraya/classes/Test Runner/Read Test VIs.vi"/>
									<Item Name="Write Test VIs.vi" Type="VI" URL="/&lt;vilib&gt;/addons/_JKI Toolkits/Caraya/classes/Test Runner/Write Test VIs.vi"/>
								</Item>
								<Item Name="Excluded Tests" Type="Property Definition">
									<Item Name="Read Excluded Tests.vi" Type="VI" URL="/&lt;vilib&gt;/addons/_JKI Toolkits/Caraya/classes/Test Runner/Read Excluded Tests.vi"/>
									<Item Name="Write Excluded Tests.vi" Type="VI" URL="/&lt;vilib&gt;/addons/_JKI Toolkits/Caraya/classes/Test Runner/Write Excluded Tests.vi"/>
								</Item>
								<Item Name="Linkage Errors" Type="Property Definition">
									<Item Name="Read Linkage Errors.vi" Type="VI" URL="/&lt;vilib&gt;/addons/_JKI Toolkits/Caraya/classes/Test Runner/Read Linkage Errors.vi"/>
									<Item Name="Write Linkage Errors.vi" Type="VI" URL="/&lt;vilib&gt;/addons/_JKI Toolkits/Caraya/classes/Test Runner/Write Linkage Errors.vi"/>
								</Item>
								<Item Name="Read Interactive.vi" Type="VI" URL="/&lt;vilib&gt;/addons/_JKI Toolkits/Caraya/classes/Test Runner/Read Interactive.vi"/>
								<Item Name="Write Interactive.vi" Type="VI" URL="/&lt;vilib&gt;/addons/_JKI Toolkits/Caraya/classes/Test Runner/Write Interactive.vi"/>
								<Item Name="Read Test error.vi" Type="VI" URL="/&lt;vilib&gt;/addons/_JKI Toolkits/Caraya/classes/Test Runner/Read Test error.vi"/>
								<Item Name="Write Test Report.vi" Type="VI" URL="/&lt;vilib&gt;/addons/_JKI Toolkits/Caraya/classes/Test Runner/Write Test Report.vi"/>
								<Item Name="Read Test Report.vi" Type="VI" URL="/&lt;vilib&gt;/addons/_JKI Toolkits/Caraya/classes/Test Runner/Read Test Report.vi"/>
								<Item Name="Read Verbose.vi" Type="VI" URL="/&lt;vilib&gt;/addons/_JKI Toolkits/Caraya/classes/Test Runner/Read Verbose.vi"/>
								<Item Name="Write Verbose.vi" Type="VI" URL="/&lt;vilib&gt;/addons/_JKI Toolkits/Caraya/classes/Test Runner/Write Verbose.vi"/>
								<Item Name="Read ApplicationRef.vi" Type="VI" URL="/&lt;vilib&gt;/addons/_JKI Toolkits/Caraya/classes/Test Runner/Read ApplicationRef.vi"/>
								<Item Name="Write ApplicationRef.vi" Type="VI" URL="/&lt;vilib&gt;/addons/_JKI Toolkits/Caraya/classes/Test Runner/Write ApplicationRef.vi"/>
							</Item>
							<Item Name="protected" Type="Folder">
								<Item Name="Linker.Find Tests and Suites.vi" Type="VI" URL="/&lt;vilib&gt;/addons/_JKI Toolkits/Caraya/classes/Test Runner/Linker.Find Tests and Suites.vi"/>
								<Item Name="Linker.Remove sub tests.vi" Type="VI" URL="/&lt;vilib&gt;/addons/_JKI Toolkits/Caraya/classes/Test Runner.Folder/Linker.Remove sub tests.vi"/>
								<Item Name="SearchForAllTests (In Memory).vi" Type="VI" URL="/&lt;vilib&gt;/addons/_JKI Toolkits/Caraya/subVIs/SearchForAllTests (In Memory).vi"/>
								<Item Name="Runner.ItemsToPathArray.vi" Type="VI" URL="/&lt;vilib&gt;/addons/_JKI Toolkits/Caraya/classes/Test Runner/Runner.ItemsToPathArray.vi"/>
								<Item Name="Runner.FilterDefineTest.vi" Type="VI" URL="/&lt;vilib&gt;/addons/_JKI Toolkits/Caraya/classes/Test Runner/Runner.FilterDefineTest.vi"/>
								<Item Name="Runner.ReadLinkerInfo.vi" Type="VI" URL="/&lt;vilib&gt;/addons/_JKI Toolkits/Caraya/classes/Test Runner/Runner.ReadLinkerInfo.vi"/>
								<Item Name="Runner.FilterRunnerCallers.vi" Type="VI" URL="/&lt;vilib&gt;/addons/_JKI Toolkits/Caraya/classes/Test Runner/Runner.FilterRunnerCallers.vi"/>
								<Item Name="Runner.FilterExcludeVIList.vi" Type="VI" URL="/&lt;vilib&gt;/addons/_JKI Toolkits/Caraya/classes/Test Runner.Folder/Runner.FilterExcludeVIList.vi"/>
							</Item>
							<Item Name="overrides" Type="Folder">
								<Item Name="pre-suite action.vi" Type="VI" URL="/&lt;vilib&gt;/addons/_JKI Toolkits/Caraya/classes/Test Runner/pre-suite action.vi"/>
								<Item Name="onTestDiscovery.vi" Type="VI" URL="/&lt;vilib&gt;/addons/_JKI Toolkits/Caraya/classes/Test Runner/onTestDiscovery.vi"/>
								<Item Name="setUp.vi" Type="VI" URL="/&lt;vilib&gt;/addons/_JKI Toolkits/Caraya/classes/Test Runner/setUp.vi"/>
								<Item Name="onTestExecution.vi" Type="VI" URL="/&lt;vilib&gt;/addons/_JKI Toolkits/Caraya/classes/Test Runner/onTestExecution.vi"/>
								<Item Name="onLinkageErrors.vi" Type="VI" URL="/&lt;vilib&gt;/addons/_JKI Toolkits/Caraya/classes/Test Runner/onLinkageErrors.vi"/>
								<Item Name="tearDown.vi" Type="VI" URL="/&lt;vilib&gt;/addons/_JKI Toolkits/Caraya/classes/Test Runner/tearDown.vi"/>
								<Item Name="Transpose Test Runner Error Codes.vi" Type="VI" URL="/&lt;vilib&gt;/addons/_JKI Toolkits/Caraya/classes/Test Runner/Transpose Test Runner Error Codes.vi"/>
								<Item Name="post-suite action.vi" Type="VI" URL="/&lt;vilib&gt;/addons/_JKI Toolkits/Caraya/classes/Test Runner/post-suite action.vi"/>
							</Item>
							<Item Name="private" Type="Folder">
								<Item Name="DestroyTestSuite.vi" Type="VI" URL="/&lt;vilib&gt;/addons/_JKI Toolkits/Caraya/classes/Test Runner/DestroyTestSuite.vi"/>
								<Item Name="computeNamespace.vi" Type="VI" URL="/&lt;vilib&gt;/addons/_JKI Toolkits/Caraya/classes/Test Runner/computeNamespace.vi"/>
								<Item Name="Read Test Suite.vi" Type="VI" URL="/&lt;vilib&gt;/addons/_JKI Toolkits/Caraya/classes/Test Runner/Read Test Suite.vi"/>
								<Item Name="Write Test Suite.vi" Type="VI" URL="/&lt;vilib&gt;/addons/_JKI Toolkits/Caraya/classes/Test Runner/Write Test Suite.vi"/>
								<Item Name="Write Test error.vi" Type="VI" URL="/&lt;vilib&gt;/addons/_JKI Toolkits/Caraya/classes/Test Runner/Write Test error.vi"/>
							</Item>
							<Item Name="Discover Tests.vi" Type="VI" URL="/&lt;vilib&gt;/addons/_JKI Toolkits/Caraya/classes/Test Runner/Discover Tests.vi"/>
							<Item Name="Run.vi" Type="VI" URL="/&lt;vilib&gt;/addons/_JKI Toolkits/Caraya/classes/Test Runner/Run.vi"/>
						</Item>
						<Item Name="Test Runner.Folder.lvclass" Type="LVClass" URL="/&lt;vilib&gt;/addons/_JKI Toolkits/Caraya/classes/Test Runner.Folder/Test Runner.Folder.lvclass">
							<Item Name="Test Runner.Folder.ctl" Type="Class Private Data" URL="/&lt;vilib&gt;/addons/_JKI Toolkits/Caraya/classes/Test Runner.Folder/Test Runner.Folder.lvclass/Test Runner.Folder.ctl"/>
							<Item Name="SubVIs" Type="Folder">
								<Item Name="Find Test and Suite Index.vi" Type="VI" URL="/&lt;vilib&gt;/addons/_JKI Toolkits/Caraya/classes/Test Runner.Folder/Find Test and Suite Index.vi"/>
								<Item Name="Remove test suites.vi" Type="VI" URL="/&lt;vilib&gt;/addons/_JKI Toolkits/Caraya/classes/Test Runner.Folder/Remove test suites.vi"/>
							</Item>
							<Item Name="Setup TestRunner Files.vi" Type="VI" URL="/&lt;vilib&gt;/addons/_JKI Toolkits/Caraya/classes/Test Runner.Folder/Setup TestRunner Files.vi"/>
							<Item Name="Setup TestRunner Folder.vi" Type="VI" URL="/&lt;vilib&gt;/addons/_JKI Toolkits/Caraya/classes/Test Runner.Folder/Setup TestRunner Folder.vi"/>
							<Item Name="onTestDiscovery.vi" Type="VI" URL="/&lt;vilib&gt;/addons/_JKI Toolkits/Caraya/classes/Test Runner.Folder/onTestDiscovery.vi"/>
							<Item Name="setUp.vi" Type="VI" URL="/&lt;vilib&gt;/addons/_JKI Toolkits/Caraya/classes/Test Runner.Folder/setUp.vi"/>
							<Item Name="FindCommonFolder.vi" Type="VI" URL="/&lt;vilib&gt;/addons/_JKI Toolkits/Caraya/classes/Test Runner.Folder/FindCommonFolder.vi"/>
						</Item>
						<Item Name="Test Runner.Project.lvclass" Type="LVClass" URL="/&lt;vilib&gt;/addons/_JKI Toolkits/Caraya/classes/Test Runner.Project/Test Runner.Project.lvclass">
							<Item Name="Test Runner.Project.ctl" Type="Class Private Data" URL="/&lt;vilib&gt;/addons/_JKI Toolkits/Caraya/classes/Test Runner.Project/Test Runner.Project.lvclass/Test Runner.Project.ctl"/>
							<Item Name="Accessors" Type="Folder">
								<Item Name="Read Project Refnum.vi" Type="VI" URL="/&lt;vilib&gt;/addons/_JKI Toolkits/Caraya/classes/Test Runner.Project/Read Project Refnum.vi"/>
								<Item Name="Write Project Refnum.vi" Type="VI" URL="/&lt;vilib&gt;/addons/_JKI Toolkits/Caraya/classes/Test Runner.Project/Write Project Refnum.vi"/>
								<Item Name="Read Virtual Folder.vi" Type="VI" URL="/&lt;vilib&gt;/addons/_JKI Toolkits/Caraya/classes/Test Runner.Project/Read Virtual Folder.vi"/>
								<Item Name="Write Virtual Folder.vi" Type="VI" URL="/&lt;vilib&gt;/addons/_JKI Toolkits/Caraya/classes/Test Runner.Project/Write Virtual Folder.vi"/>
							</Item>
							<Item Name="private" Type="Folder">
								<Item Name="Search for Virtual Folder.vi" Type="VI" URL="/&lt;vilib&gt;/addons/_JKI Toolkits/Caraya/classes/Test Runner.Project/Search for Virtual Folder.vi"/>
							</Item>
							<Item Name="Setup TestRunner Project.vi" Type="VI" URL="/&lt;vilib&gt;/addons/_JKI Toolkits/Caraya/classes/Test Runner.Project/Setup TestRunner Project.vi"/>
							<Item Name="setUp.vi" Type="VI" URL="/&lt;vilib&gt;/addons/_JKI Toolkits/Caraya/classes/Test Runner.Project/setUp.vi"/>
							<Item Name="onTestDiscovery.vi" Type="VI" URL="/&lt;vilib&gt;/addons/_JKI Toolkits/Caraya/classes/Test Runner.Project/onTestDiscovery.vi"/>
							<Item Name="onTestExecution.vi" Type="VI" URL="/&lt;vilib&gt;/addons/_JKI Toolkits/Caraya/classes/Test Runner.Project/onTestExecution.vi"/>
						</Item>
						<Item Name="Test Runner.Library.lvclass" Type="LVClass" URL="/&lt;vilib&gt;/addons/_JKI Toolkits/Caraya/classes/Test Runner.Library/Test Runner.Library.lvclass">
							<Item Name="Test Runner.Library.ctl" Type="Class Private Data" URL="/&lt;vilib&gt;/addons/_JKI Toolkits/Caraya/classes/Test Runner.Library/Test Runner.Library.lvclass/Test Runner.Library.ctl"/>
							<Item Name="onTestDiscovery.vi" Type="VI" URL="/&lt;vilib&gt;/addons/_JKI Toolkits/Caraya/classes/Test Runner.Library/onTestDiscovery.vi"/>
							<Item Name="onTestExecution.vi" Type="VI" URL="/&lt;vilib&gt;/addons/_JKI Toolkits/Caraya/classes/Test Runner.Library/onTestExecution.vi"/>
							<Item Name="Setup TestRunner Library.vi" Type="VI" URL="/&lt;vilib&gt;/addons/_JKI Toolkits/Caraya/classes/Test Runner.Library/Setup TestRunner Library.vi"/>
						</Item>
						<Item Name="Test Runner.Class.lvclass" Type="LVClass" URL="/&lt;vilib&gt;/addons/_JKI Toolkits/Caraya/classes/Test Runner.Class/Test Runner.Class.lvclass">
							<Item Name="Test Runner.Class.ctl" Type="Class Private Data" URL="/&lt;vilib&gt;/addons/_JKI Toolkits/Caraya/classes/Test Runner.Class/Test Runner.Class.lvclass/Test Runner.Class.ctl"/>
							<Item Name="Accessors" Type="Folder">
								<Item Name="Read Class Instance.vi" Type="VI" URL="/&lt;vilib&gt;/addons/_JKI Toolkits/Caraya/classes/Test Runner.Class/Read Class Instance.vi"/>
								<Item Name="Write Class Instance.vi" Type="VI" URL="/&lt;vilib&gt;/addons/_JKI Toolkits/Caraya/classes/Test Runner.Class/Write Class Instance.vi"/>
							</Item>
							<Item Name="Setup TestRunner ClassInstance.vi" Type="VI" URL="/&lt;vilib&gt;/addons/_JKI Toolkits/Caraya/classes/Test Runner.Class/Setup TestRunner ClassInstance.vi"/>
							<Item Name="onTestDiscovery.vi" Type="VI" URL="/&lt;vilib&gt;/addons/_JKI Toolkits/Caraya/classes/Test Runner.Class/onTestDiscovery.vi"/>
							<Item Name="onTestExecution.vi" Type="VI" URL="/&lt;vilib&gt;/addons/_JKI Toolkits/Caraya/classes/Test Runner.Class/onTestExecution.vi"/>
						</Item>
						<Item Name="Test Runner.Collection.lvclass" Type="LVClass" URL="/&lt;vilib&gt;/addons/_JKI Toolkits/Caraya/classes/Test Runner.Collection/Test Runner.Collection.lvclass">
							<Item Name="Test Runner.Collection.ctl" Type="Class Private Data" URL="/&lt;vilib&gt;/addons/_JKI Toolkits/Caraya/classes/Test Runner.Collection/Test Runner.Collection.lvclass/Test Runner.Collection.ctl"/>
							<Item Name="private" Type="Folder">
								<Item Name="Read Collection.vi" Type="VI" URL="/&lt;vilib&gt;/addons/_JKI Toolkits/Caraya/classes/Test Runner.Collection/Read Collection.vi"/>
								<Item Name="Write Collection.vi" Type="VI" URL="/&lt;vilib&gt;/addons/_JKI Toolkits/Caraya/classes/Test Runner.Collection/Write Collection.vi"/>
							</Item>
							<Item Name="Create Collection.vi" Type="VI" URL="/&lt;vilib&gt;/addons/_JKI Toolkits/Caraya/classes/Test Runner.Collection/Create Collection.vi"/>
							<Item Name="Merge Runner.vi" Type="VI" URL="/&lt;vilib&gt;/addons/_JKI Toolkits/Caraya/classes/Test Runner.Collection/Merge Runner.vi"/>
							<Item Name="onTestDiscovery.vi" Type="VI" URL="/&lt;vilib&gt;/addons/_JKI Toolkits/Caraya/classes/Test Runner.Collection/onTestDiscovery.vi"/>
							<Item Name="onTestExecution.vi" Type="VI" URL="/&lt;vilib&gt;/addons/_JKI Toolkits/Caraya/classes/Test Runner.Collection/onTestExecution.vi"/>
							<Item Name="setUp.vi" Type="VI" URL="/&lt;vilib&gt;/addons/_JKI Toolkits/Caraya/classes/Test Runner.Collection/setUp.vi"/>
							<Item Name="tearDown.vi" Type="VI" URL="/&lt;vilib&gt;/addons/_JKI Toolkits/Caraya/classes/Test Runner.Collection/tearDown.vi"/>
						</Item>
						<Item Name="Test Runner.Template.lvclass" Type="LVClass" URL="/&lt;vilib&gt;/addons/_JKI Toolkits/Caraya/classes/Test Runner.Template/Test Runner.Template.lvclass">
							<Item Name="Test Runner.Template.ctl" Type="Class Private Data" URL="/&lt;vilib&gt;/addons/_JKI Toolkits/Caraya/classes/Test Runner.Template/Test Runner.Template.lvclass/Test Runner.Template.ctl"/>
							<Item Name="Create Test Suite (Template).vi" Type="VI" URL="/&lt;vilib&gt;/addons/_JKI Toolkits/Caraya/classes/Test Runner.Template/Create Test Suite (Template).vi"/>
							<Item Name="onTestExecution.vi" Type="VI" URL="/&lt;vilib&gt;/addons/_JKI Toolkits/Caraya/classes/Test Runner.Template/onTestExecution.vi"/>
							<Item Name="RunMe (Test Launcher).vi" Type="VI" URL="/&lt;vilib&gt;/addons/_JKI Toolkits/Caraya/classes/Test Runner.Template/RunMe (Test Launcher).vi"/>
						</Item>
					</Item>
					<Item Name="Properties" Type="Folder">
						<Item Name="Properties.lvclass" Type="LVClass" URL="/&lt;vilib&gt;/addons/_JKI Toolkits/Caraya/classes/Properties/Properties.lvclass">
							<Item Name="Properties.ctl" Type="Class Private Data" URL="/&lt;vilib&gt;/addons/_JKI Toolkits/Caraya/classes/Properties/Properties.lvclass/Properties.ctl"/>
							<Item Name="Accessors" Type="Folder">
								<Item Name="Read call-chain.vi" Type="VI" URL="/&lt;vilib&gt;/addons/_JKI Toolkits/Caraya/classes/Properties/Read call-chain.vi"/>
								<Item Name="Read Owner ID.vi" Type="VI" URL="/&lt;vilib&gt;/addons/_JKI Toolkits/Caraya/classes/Properties/Read Owner ID.vi"/>
								<Item Name="Read Self ID.vi" Type="VI" URL="/&lt;vilib&gt;/addons/_JKI Toolkits/Caraya/classes/Properties/Read Self ID.vi"/>
								<Item Name="Read Label.vi" Type="VI" URL="/&lt;vilib&gt;/addons/_JKI Toolkits/Caraya/classes/Properties/Read Label.vi"/>
								<Item Name="Read TestManager.vi" Type="VI" URL="/&lt;vilib&gt;/addons/_JKI Toolkits/Caraya/classes/Properties/Read TestManager.vi"/>
								<Item Name="Read Time Stamp.vi" Type="VI" URL="/&lt;vilib&gt;/addons/_JKI Toolkits/Caraya/classes/Properties/Read Time Stamp.vi"/>
								<Item Name="Write call-chain.vi" Type="VI" URL="/&lt;vilib&gt;/addons/_JKI Toolkits/Caraya/classes/Properties/Write call-chain.vi"/>
								<Item Name="Write Owner ID.vi" Type="VI" URL="/&lt;vilib&gt;/addons/_JKI Toolkits/Caraya/classes/Properties/Write Owner ID.vi"/>
								<Item Name="Write Self ID.vi" Type="VI" URL="/&lt;vilib&gt;/addons/_JKI Toolkits/Caraya/classes/Properties/Write Self ID.vi"/>
								<Item Name="Write Label.vi" Type="VI" URL="/&lt;vilib&gt;/addons/_JKI Toolkits/Caraya/classes/Properties/Write Label.vi"/>
								<Item Name="Write TestManager.vi" Type="VI" URL="/&lt;vilib&gt;/addons/_JKI Toolkits/Caraya/classes/Properties/Write TestManager.vi"/>
								<Item Name="Write Time Stamp.vi" Type="VI" URL="/&lt;vilib&gt;/addons/_JKI Toolkits/Caraya/classes/Properties/Write Time Stamp.vi"/>
							</Item>
							<Item Name="Create Properties.vi" Type="VI" URL="/&lt;vilib&gt;/addons/_JKI Toolkits/Caraya/classes/Properties/Create Properties.vi"/>
							<Item Name="Send Message.vi" Type="VI" URL="/&lt;vilib&gt;/addons/_JKI Toolkits/Caraya/classes/Properties/Send Message.vi"/>
							<Item Name="Add Key-Value Pair.vi" Type="VI" URL="/&lt;vilib&gt;/addons/_JKI Toolkits/Caraya/classes/Properties/Add Key-Value Pair.vi"/>
							<Item Name="Add RequirementID.vi" Type="VI" URL="/&lt;vilib&gt;/addons/_JKI Toolkits/Caraya/classes/Properties/Add RequirementID.vi"/>
							<Item Name="Add hyperlink.vi" Type="VI" URL="/&lt;vilib&gt;/addons/_JKI Toolkits/Caraya/classes/Properties/Add hyperlink.vi"/>
							<Item Name="Add Verbose Explanation.vi" Type="VI" URL="/&lt;vilib&gt;/addons/_JKI Toolkits/Caraya/classes/Properties/Add Verbose Explanation.vi"/>
							<Item Name="Add Measurement.vi" Type="VI" URL="/&lt;vilib&gt;/addons/_JKI Toolkits/Caraya/classes/Properties/Add Measurement.vi"/>
							<Item Name="kvp entry -- cluster.ctl" Type="VI" URL="/&lt;vilib&gt;/addons/_JKI Toolkits/Caraya/classes/Properties/kvp entry -- cluster.ctl"/>
						</Item>
						<Item Name="Properties.Suite.lvclass" Type="LVClass" URL="/&lt;vilib&gt;/addons/_JKI Toolkits/Caraya/classes/Properties.Suite/Properties.Suite.lvclass">
							<Item Name="Properties.Suite.ctl" Type="Class Private Data" URL="/&lt;vilib&gt;/addons/_JKI Toolkits/Caraya/classes/Properties.Suite/Properties.Suite.lvclass/Properties.Suite.ctl"/>
							<Item Name="Accessors" Type="Folder">
								<Item Name="Read timeout.vi" Type="VI" URL="/&lt;vilib&gt;/addons/_JKI Toolkits/Caraya/classes/Properties.Suite/Read timeout.vi"/>
								<Item Name="Write timeout.vi" Type="VI" URL="/&lt;vilib&gt;/addons/_JKI Toolkits/Caraya/classes/Properties.Suite/Write timeout.vi"/>
							</Item>
							<Item Name="Register Suite.vi" Type="VI" URL="/&lt;vilib&gt;/addons/_JKI Toolkits/Caraya/classes/Properties.Suite/Register Suite.vi"/>
							<Item Name="Complete Suite.vi" Type="VI" URL="/&lt;vilib&gt;/addons/_JKI Toolkits/Caraya/classes/Properties.Suite/Complete Suite.vi"/>
						</Item>
						<Item Name="Properties.Test.lvclass" Type="LVClass" URL="/&lt;vilib&gt;/addons/_JKI Toolkits/Caraya/classes/Properties.Test/Properties.Test.lvclass">
							<Item Name="Properties.Test.ctl" Type="Class Private Data" URL="/&lt;vilib&gt;/addons/_JKI Toolkits/Caraya/classes/Properties.Test/Properties.Test.lvclass/Properties.Test.ctl"/>
							<Item Name="Register Test.vi" Type="VI" URL="/&lt;vilib&gt;/addons/_JKI Toolkits/Caraya/classes/Properties.Test/Register Test.vi"/>
						</Item>
						<Item Name="Properties.Assert.lvclass" Type="LVClass" URL="/&lt;vilib&gt;/addons/_JKI Toolkits/Caraya/classes/Properties.Assert/Properties.Assert.lvclass">
							<Item Name="Properties.Assert.ctl" Type="Class Private Data" URL="/&lt;vilib&gt;/addons/_JKI Toolkits/Caraya/classes/Properties.Assert/Properties.Assert.lvclass/Properties.Assert.ctl"/>
							<Item Name="Accessors" Type="Folder">
								<Item Name="Read Execution time.vi" Type="VI" URL="/&lt;vilib&gt;/addons/_JKI Toolkits/Caraya/classes/Properties.Assert/Read Execution time.vi"/>
								<Item Name="Write Execution time.vi" Type="VI" URL="/&lt;vilib&gt;/addons/_JKI Toolkits/Caraya/classes/Properties.Assert/Write Execution time.vi"/>
								<Item Name="Read Asserted.vi" Type="VI" URL="/&lt;vilib&gt;/addons/_JKI Toolkits/Caraya/classes/Properties.Assert/Read Asserted.vi"/>
								<Item Name="Write Asserted.vi" Type="VI" URL="/&lt;vilib&gt;/addons/_JKI Toolkits/Caraya/classes/Properties.Assert/Write Asserted.vi"/>
								<Item Name="Read upstream error.vi" Type="VI" URL="/&lt;vilib&gt;/addons/_JKI Toolkits/Caraya/classes/Properties.Assert/Read upstream error.vi"/>
								<Item Name="Write upstream error.vi" Type="VI" URL="/&lt;vilib&gt;/addons/_JKI Toolkits/Caraya/classes/Properties.Assert/Write upstream error.vi"/>
							</Item>
							<Item Name="Register Assert.vi" Type="VI" URL="/&lt;vilib&gt;/addons/_JKI Toolkits/Caraya/classes/Properties.Assert/Register Assert.vi"/>
						</Item>
					</Item>
					<Item Name="Serializer" Type="Folder">
						<Item Name="MsgSerializer.lvclass" Type="LVClass" URL="/&lt;vilib&gt;/addons/_JKI Toolkits/Caraya/classes/MsgSerializer/MsgSerializer.lvclass">
							<Item Name="MsgSerializer.ctl" Type="Class Private Data" URL="/&lt;vilib&gt;/addons/_JKI Toolkits/Caraya/classes/MsgSerializer/MsgSerializer.lvclass/MsgSerializer.ctl"/>
							<Item Name="Accessors" Type="Folder">
								<Item Name="Read indent.vi" Type="VI" URL="/&lt;vilib&gt;/addons/_JKI Toolkits/Caraya/classes/MsgSerializer/Read indent.vi"/>
								<Item Name="Write indent.vi" Type="VI" URL="/&lt;vilib&gt;/addons/_JKI Toolkits/Caraya/classes/MsgSerializer/Write indent.vi"/>
								<Item Name="Read Decimal.vi" Type="VI" URL="/&lt;vilib&gt;/addons/_JKI Toolkits/Caraya/classes/MsgSerializer.XML/Read Decimal.vi"/>
								<Item Name="Read Locale.vi" Type="VI" URL="/&lt;vilib&gt;/addons/_JKI Toolkits/Caraya/classes/MsgSerializer.XML/Read Locale.vi"/>
							</Item>
							<Item Name="Utilities" Type="Folder">
								<Item Name="Set Locale Settings.vi" Type="VI" URL="/&lt;vilib&gt;/addons/_JKI Toolkits/Caraya/classes/MsgSerializer.XML/Set Locale Settings.vi"/>
								<Item Name="ComputeIndentation.vi" Type="VI" URL="/&lt;vilib&gt;/addons/_JKI Toolkits/Caraya/classes/MsgSerializer/ComputeIndentation.vi"/>
								<Item Name="Indent.vi" Type="VI" URL="/&lt;vilib&gt;/addons/_JKI Toolkits/Caraya/classes/MsgSerializer/Indent.vi"/>
								<Item Name="De-Indent.vi" Type="VI" URL="/&lt;vilib&gt;/addons/_JKI Toolkits/Caraya/classes/MsgSerializer/De-Indent.vi"/>
								<Item Name="txt_escape.vi" Type="VI" URL="/&lt;vilib&gt;/addons/_JKI Toolkits/Caraya/classes/MsgSerializer/txt_escape.vi"/>
							</Item>
							<Item Name="Serialize.vi" Type="VI" URL="/&lt;vilib&gt;/addons/_JKI Toolkits/Caraya/classes/MsgSerializer/Serialize.vi"/>
							<Item Name="decimal-notation -- enum.ctl" Type="VI" URL="/&lt;vilib&gt;/addons/_JKI Toolkits/Caraya/classes/MsgSerializer.XML/decimal-notation -- enum.ctl"/>
						</Item>
						<Item Name="MsgSerializer.XML.lvclass" Type="LVClass" URL="/&lt;vilib&gt;/addons/_JKI Toolkits/Caraya/classes/MsgSerializer.XML/MsgSerializer.XML.lvclass">
							<Item Name="MsgSerializer.XML.ctl" Type="Class Private Data" URL="/&lt;vilib&gt;/addons/_JKI Toolkits/Caraya/classes/MsgSerializer.XML/MsgSerializer.XML.lvclass/MsgSerializer.XML.ctl"/>
							<Item Name="Accessors" Type="Folder">
								<Item Name="Read property.vi" Type="VI" URL="/&lt;vilib&gt;/addons/_JKI Toolkits/Caraya/classes/MsgSerializer.XML/Read property.vi"/>
								<Item Name="Write property.vi" Type="VI" URL="/&lt;vilib&gt;/addons/_JKI Toolkits/Caraya/classes/MsgSerializer.XML/Write property.vi"/>
							</Item>
							<Item Name="typedefs" Type="Folder">
								<Item Name="format -- enum.ctl" Type="VI" URL="/&lt;vilib&gt;/addons/_JKI Toolkits/Caraya/classes/MsgSerializer.XML/format -- enum.ctl"/>
							</Item>
							<Item Name="utilities" Type="Folder">
								<Item Name="escapeXML.vi" Type="VI" URL="/&lt;vilib&gt;/addons/_JKI Toolkits/Caraya/classes/MsgSerializer.XML/escapeXML.vi"/>
								<Item Name="normalizeXMLname.vi" Type="VI" URL="/&lt;vilib&gt;/addons/_JKI Toolkits/Caraya/classes/MsgSerializer.XML/normalizeXMLname.vi"/>
								<Item Name="xml.boolean.vi" Type="VI" URL="/&lt;vilib&gt;/addons/_JKI Toolkits/Caraya/classes/MsgSerializer.XML/xml.boolean.vi"/>
								<Item Name="xml.numeric.vi" Type="VI" URL="/&lt;vilib&gt;/addons/_JKI Toolkits/Caraya/classes/MsgSerializer.XML/xml.numeric.vi"/>
								<Item Name="xml.scalar.vi" Type="VI" URL="/&lt;vilib&gt;/addons/_JKI Toolkits/Caraya/classes/MsgSerializer.XML/xml.scalar.vi"/>
							</Item>
							<Item Name="Serialize.vi" Type="VI" URL="/&lt;vilib&gt;/addons/_JKI Toolkits/Caraya/classes/MsgSerializer.XML/Serialize.vi"/>
						</Item>
						<Item Name="MsgSerializer.JSON.lvclass" Type="LVClass" URL="/&lt;vilib&gt;/addons/_JKI Toolkits/Caraya/classes/MsgSerializer.JSON/MsgSerializer/MsgSerializer.JSON.lvclass">
							<Item Name="MsgSerializer.JSON.ctl" Type="Class Private Data" URL="/&lt;vilib&gt;/addons/_JKI Toolkits/Caraya/classes/MsgSerializer.JSON/MsgSerializer/MsgSerializer.JSON.lvclass/MsgSerializer.JSON.ctl"/>
							<Item Name="Utilities" Type="Folder">
								<Item Name="json_escape.vi" Type="VI" URL="/&lt;vilib&gt;/addons/_JKI Toolkits/Caraya/classes/MsgSerializer.JSON/MsgSerializer/json_escape.vi"/>
							</Item>
							<Item Name="Serialize.vi" Type="VI" URL="/&lt;vilib&gt;/addons/_JKI Toolkits/Caraya/classes/MsgSerializer.JSON/MsgSerializer/Serialize.vi"/>
						</Item>
					</Item>
					<Item Name="TestManager Messages" Type="Folder">
						<Item Name="TestManagerMsg.lvclass" Type="LVClass" URL="/&lt;vilib&gt;/addons/_JKI Toolkits/Caraya/classes/Test Manager Message/TestManagerMsg.lvclass">
							<Item Name="TestManagerMsg.ctl" Type="Class Private Data" URL="/&lt;vilib&gt;/addons/_JKI Toolkits/Caraya/classes/Test Manager Message/TestManagerMsg.lvclass/TestManagerMsg.ctl"/>
							<Item Name="Accessors" Type="Folder">
								<Item Name="Read key.vi" Type="VI" URL="/&lt;vilib&gt;/addons/_JKI Toolkits/Caraya/classes/Test Manager Message/Read key.vi"/>
								<Item Name="Read overwrite.vi" Type="VI" URL="/&lt;vilib&gt;/addons/_JKI Toolkits/Caraya/classes/Test Manager Message/Read overwrite.vi"/>
								<Item Name="Read owner-id.vi" Type="VI" URL="/&lt;vilib&gt;/addons/_JKI Toolkits/Caraya/classes/Test Manager Message/Read owner-id.vi"/>
								<Item Name="Read self-id.vi" Type="VI" URL="/&lt;vilib&gt;/addons/_JKI Toolkits/Caraya/classes/Test Manager Message/Read self-id.vi"/>
							</Item>
							<Item Name="Init Message.vi" Type="VI" URL="/&lt;vilib&gt;/addons/_JKI Toolkits/Caraya/classes/Test Manager Message/Init Message.vi"/>
							<Item Name="SerializeMessage.vi" Type="VI" URL="/&lt;vilib&gt;/addons/_JKI Toolkits/Caraya/classes/Test Manager Message/SerializeMessage.vi"/>
						</Item>
						<Item Name="TestManagerMsg.KVP.lvclass" Type="LVClass" URL="/&lt;vilib&gt;/addons/_JKI Toolkits/Caraya/classes/Test Manager Message KVP/TestManagerMsg.KVP.lvclass">
							<Item Name="TestManagerMsg.KVP.ctl" Type="Class Private Data" URL="/&lt;vilib&gt;/addons/_JKI Toolkits/Caraya/classes/Test Manager Message KVP/TestManagerMsg.KVP.lvclass/TestManagerMsg.KVP.ctl"/>
							<Item Name="Accessors" Type="Folder">
								<Item Name="Read value.vi" Type="VI" URL="/&lt;vilib&gt;/addons/_JKI Toolkits/Caraya/classes/Test Manager Message KVP/Read value.vi"/>
							</Item>
							<Item Name="Init Generic Message.vi" Type="VI" URL="/&lt;vilib&gt;/addons/_JKI Toolkits/Caraya/classes/Test Manager Message KVP/Init Generic Message.vi"/>
							<Item Name="SerializeMessage.vi" Type="VI" URL="/&lt;vilib&gt;/addons/_JKI Toolkits/Caraya/classes/Test Manager Message KVP/SerializeMessage.vi"/>
						</Item>
						<Item Name="TestManagerMsg.Verbose.lvclass" Type="LVClass" URL="/&lt;vilib&gt;/addons/_JKI Toolkits/Caraya/classes/Test Manager Message Verbose/TestManagerMsg.Verbose.lvclass">
							<Item Name="TestManagerMsg.Verbose.ctl" Type="Class Private Data" URL="/&lt;vilib&gt;/addons/_JKI Toolkits/Caraya/classes/Test Manager Message Verbose/TestManagerMsg.Verbose.lvclass/TestManagerMsg.Verbose.ctl"/>
							<Item Name="Accessors" Type="Folder">
								<Item Name="Read explanation.vi" Type="VI" URL="/&lt;vilib&gt;/addons/_JKI Toolkits/Caraya/classes/Test Manager Message Verbose/Read explanation.vi"/>
							</Item>
							<Item Name="Init Verbose Message.vi" Type="VI" URL="/&lt;vilib&gt;/addons/_JKI Toolkits/Caraya/classes/Test Manager Message Verbose/Init Verbose Message.vi"/>
							<Item Name="SerializeMessage.vi" Type="VI" URL="/&lt;vilib&gt;/addons/_JKI Toolkits/Caraya/classes/Test Manager Message Verbose/SerializeMessage.vi"/>
						</Item>
						<Item Name="TestManagerMsg.Measurement.lvclass" Type="LVClass" URL="/&lt;vilib&gt;/addons/_JKI Toolkits/Caraya/classes/Test Manager Message Measurement/TestManagerMsg.Measurement.lvclass">
							<Item Name="TestManagerMsg.Measurement.ctl" Type="Class Private Data" URL="/&lt;vilib&gt;/addons/_JKI Toolkits/Caraya/classes/Test Manager Message Measurement/TestManagerMsg.Measurement.lvclass/TestManagerMsg.Measurement.ctl"/>
							<Item Name="Accessors" Type="Folder">
								<Item Name="Read name.vi" Type="VI" URL="/&lt;vilib&gt;/addons/_JKI Toolkits/Caraya/classes/Test Manager Message Measurement/Read name.vi"/>
								<Item Name="Read Value.vi" Type="VI" URL="/&lt;vilib&gt;/addons/_JKI Toolkits/Caraya/classes/Test Manager Message Measurement/Read Value.vi"/>
							</Item>
							<Item Name="Init Measurement Message.vi" Type="VI" URL="/&lt;vilib&gt;/addons/_JKI Toolkits/Caraya/classes/Test Manager Message Measurement/Init Measurement Message.vi"/>
							<Item Name="SerializeMessage.vi" Type="VI" URL="/&lt;vilib&gt;/addons/_JKI Toolkits/Caraya/classes/Test Manager Message Measurement/SerializeMessage.vi"/>
						</Item>
						<Item Name="TestManagerMsg.CompleteSuite.lvclass" Type="LVClass" URL="/&lt;vilib&gt;/addons/_JKI Toolkits/Caraya/classes/Test Manager Message Complete Suite/TestManagerMsg.CompleteSuite.lvclass">
							<Item Name="TestManagerMsg.CompleteSuite.ctl" Type="Class Private Data" URL="/&lt;vilib&gt;/addons/_JKI Toolkits/Caraya/classes/Test Manager Message Complete Suite/TestManagerMsg.CompleteSuite.lvclass/TestManagerMsg.CompleteSuite.ctl"/>
							<Item Name="Accessors" Type="Folder">
								<Item Name="Read Notifier.vi" Type="VI" URL="/&lt;vilib&gt;/addons/_JKI Toolkits/Caraya/classes/Test Manager Message Complete Suite/Read Notifier.vi"/>
							</Item>
							<Item Name="Init Complete Suite Message.vi" Type="VI" URL="/&lt;vilib&gt;/addons/_JKI Toolkits/Caraya/classes/Test Manager Message Complete Suite/Init Complete Suite Message.vi"/>
							<Item Name="SerializeMessage.vi" Type="VI" URL="/&lt;vilib&gt;/addons/_JKI Toolkits/Caraya/classes/Test Manager Message Complete Suite/SerializeMessage.vi"/>
						</Item>
						<Item Name="TestManagerMsg.Test.lvclass" Type="LVClass" URL="/&lt;vilib&gt;/addons/_JKI Toolkits/Caraya/classes/Test Manager Message Test/TestManagerMsg.Test.lvclass">
							<Item Name="TestManagerMsg.Test.ctl" Type="Class Private Data" URL="/&lt;vilib&gt;/addons/_JKI Toolkits/Caraya/classes/Test Manager Message Test/TestManagerMsg.Test.lvclass/TestManagerMsg.Test.ctl"/>
							<Item Name="Accessors" Type="Folder">
								<Item Name="Read Call Chain.vi" Type="VI" URL="/&lt;vilib&gt;/addons/_JKI Toolkits/Caraya/classes/Test Manager Message Test/Read Call Chain.vi"/>
								<Item Name="Read properties.vi" Type="VI" URL="/&lt;vilib&gt;/addons/_JKI Toolkits/Caraya/classes/Test Manager Message Test/Read properties.vi"/>
								<Item Name="Read property By Key.vi" Type="VI" URL="/&lt;vilib&gt;/addons/_JKI Toolkits/Caraya/classes/Test Manager Message Test/Read property By Key.vi"/>
							</Item>
							<Item Name="Conversion" Type="Folder">
								<Item Name="To Test Event.vi" Type="VI" URL="/&lt;vilib&gt;/addons/_JKI Toolkits/Caraya/classes/Test Manager Message Test/To Test Event.vi"/>
							</Item>
							<Item Name="EnumerateProperties.vi" Type="VI" URL="/&lt;vilib&gt;/addons/_JKI Toolkits/Caraya/classes/Test Manager Message Test/EnumerateProperties.vi"/>
							<Item Name="Test-Data -- cluster.ctl" Type="VI" URL="/&lt;vilib&gt;/addons/_JKI Toolkits/Caraya/classes/Test Manager Message Test/Test-Data -- cluster.ctl"/>
							<Item Name="Init Test Data Message.vi" Type="VI" URL="/&lt;vilib&gt;/addons/_JKI Toolkits/Caraya/classes/Test Manager Message Test/Init Test Data Message.vi"/>
							<Item Name="Read Test Data.vi" Type="VI" URL="/&lt;vilib&gt;/addons/_JKI Toolkits/Caraya/classes/Test Manager Message Test/Read Test Data.vi"/>
							<Item Name="Update Property.vi" Type="VI" URL="/&lt;vilib&gt;/addons/_JKI Toolkits/Caraya/classes/Test Manager Message Test/Update Property.vi"/>
							<Item Name="SerializeMessage.vi" Type="VI" URL="/&lt;vilib&gt;/addons/_JKI Toolkits/Caraya/classes/Test Manager Message Test/SerializeMessage.vi"/>
						</Item>
						<Item Name="TestManagerMsg.Assertion.lvclass" Type="LVClass" URL="/&lt;vilib&gt;/addons/_JKI Toolkits/Caraya/classes/Test Manager Message Assertion/TestManagerMsg.Assertion.lvclass">
							<Item Name="TestManagerMsg.Assertion.ctl" Type="Class Private Data" URL="/&lt;vilib&gt;/addons/_JKI Toolkits/Caraya/classes/Test Manager Message Assertion/TestManagerMsg.Assertion.lvclass/TestManagerMsg.Assertion.ctl"/>
							<Item Name="Accessors" Type="Folder">
								<Item Name="Read Call Chain.vi" Type="VI" URL="/&lt;vilib&gt;/addons/_JKI Toolkits/Caraya/classes/Test Manager Message Assertion/Read Call Chain.vi"/>
							</Item>
							<Item Name="Conversion" Type="Folder">
								<Item Name="To Test Event.vi" Type="VI" URL="/&lt;vilib&gt;/addons/_JKI Toolkits/Caraya/classes/Test Manager Message Assertion/To Test Event.vi"/>
							</Item>
							<Item Name="Add Measurement.vi" Type="VI" URL="/&lt;vilib&gt;/addons/_JKI Toolkits/Caraya/classes/Test Manager Message Assertion/Add Measurement.vi"/>
							<Item Name="Assert-Data -- cluster.ctl" Type="VI" URL="/&lt;vilib&gt;/addons/_JKI Toolkits/Caraya/classes/Test Manager Message Assertion/Assert-Data -- cluster.ctl"/>
							<Item Name="Init Assert Data Message.vi" Type="VI" URL="/&lt;vilib&gt;/addons/_JKI Toolkits/Caraya/classes/Test Manager Message Assertion/Init Assert Data Message.vi"/>
							<Item Name="Query Assert Status.vi" Type="VI" URL="/&lt;vilib&gt;/addons/_JKI Toolkits/Caraya/classes/Test Manager Message Assertion/Query Assert Status.vi"/>
							<Item Name="Read Assert Data.vi" Type="VI" URL="/&lt;vilib&gt;/addons/_JKI Toolkits/Caraya/classes/Test Manager Message Assertion/Read Assert Data.vi"/>
							<Item Name="SerializeMessage.vi" Type="VI" URL="/&lt;vilib&gt;/addons/_JKI Toolkits/Caraya/classes/Test Manager Message Assertion/SerializeMessage.vi"/>
							<Item Name="Update Property.vi" Type="VI" URL="/&lt;vilib&gt;/addons/_JKI Toolkits/Caraya/classes/Test Manager Message Assertion/Update Property.vi"/>
							<Item Name="Update Verbose Explanation.vi" Type="VI" URL="/&lt;vilib&gt;/addons/_JKI Toolkits/Caraya/classes/Test Manager Message Assertion/Update Verbose Explanation.vi"/>
						</Item>
					</Item>
					<Item Name="Assertions" Type="Folder">
						<Item Name="Assert.lvclass" Type="LVClass" URL="/&lt;vilib&gt;/addons/_JKI Toolkits/Caraya/classes/Assert/Assert.lvclass">
							<Item Name="Assert.ctl" Type="Class Private Data" URL="/&lt;vilib&gt;/addons/_JKI Toolkits/Caraya/classes/Assert/Assert.lvclass/Assert.ctl"/>
							<Item Name="Private" Type="Folder">
								<Item Name="Default Name.vi" Type="VI" URL="/&lt;vilib&gt;/addons/_JKI Toolkits/Caraya/classes/Assert/Default Name.vi"/>
								<Item Name="Assert Wrapper.vi" Type="VI" URL="/&lt;vilib&gt;/addons/_JKI Toolkits/Caraya/classes/Assert/Assert Wrapper.vi"/>
								<Item Name="Assert_Core.vi" Type="VI" URL="/&lt;vilib&gt;/addons/_JKI Toolkits/Caraya/classes/Assert/Assert_Core.vi"/>
								<Item Name="isVerbose.vi" Type="VI" URL="/&lt;vilib&gt;/addons/_JKI Toolkits/Caraya/classes/Assert/isVerbose.vi"/>
								<Item Name="isNumerics.vi" Type="VI" URL="/&lt;vilib&gt;/addons/_JKI Toolkits/Caraya/classes/Assert/isNumerics.vi"/>
								<Item Name="Disconnect TypeDef.vi" Type="VI" URL="/&lt;vilib&gt;/addons/_JKI Toolkits/Caraya/subVIs/Disconnect TypeDef.vi"/>
								<Item Name="Greater Value Comparison.vi" Type="VI" URL="/&lt;vilib&gt;/addons/_JKI Toolkits/Caraya/subVIs/Greater Value Comparison.vi"/>
								<Item Name="Equal Value Comparison.vi" Type="VI" URL="/&lt;vilib&gt;/addons/_JKI Toolkits/Caraya/subVIs/Equal Value Comparison.vi"/>
								<Item Name="Equal Type Comparison.vi" Type="VI" URL="/&lt;vilib&gt;/addons/_JKI Toolkits/Caraya/subVIs/Equal Type Comparison.vi"/>
								<Item Name="_init_assert_properties.vi" Type="VI" URL="/&lt;vilib&gt;/addons/_JKI Toolkits/Caraya/classes/Assert/_init_assert_properties.vi"/>
							</Item>
							<Item Name="_deprecated" Type="Folder">
								<Item Name="Assert Equal_Variant.vi" Type="VI" URL="/&lt;vilib&gt;/addons/_JKI Toolkits/Caraya/classes/Assert/Assert Equal_Variant.vi"/>
								<Item Name="Assert Not Equal_Variant.vi" Type="VI" URL="/&lt;vilib&gt;/addons/_JKI Toolkits/Caraya/classes/Assert/Assert Not Equal_Variant.vi"/>
								<Item Name="Assert (Poly).vi" Type="VI" URL="/&lt;vilib&gt;/addons/_JKI Toolkits/Caraya/classes/Assert/Assert (Poly).vi"/>
							</Item>
							<Item Name="Accessors" Type="Folder">
								<Item Name="Read Unique Test ID.vi" Type="VI" URL="/&lt;vilib&gt;/addons/_JKI Toolkits/Caraya/classes/Assert/Read Unique Test ID.vi"/>
								<Item Name="Write Unique Test ID.vi" Type="VI" URL="/&lt;vilib&gt;/addons/_JKI Toolkits/Caraya/classes/Assert/Write Unique Test ID.vi"/>
								<Item Name="Read Unique Assert ID.vi" Type="VI" URL="/&lt;vilib&gt;/addons/_JKI Toolkits/Caraya/classes/Assert/Read Unique Assert ID.vi"/>
								<Item Name="Write Unique Assert ID.vi" Type="VI" URL="/&lt;vilib&gt;/addons/_JKI Toolkits/Caraya/classes/Assert/Write Unique Assert ID.vi"/>
								<Item Name="Read Assert Only_.vi" Type="VI" URL="/&lt;vilib&gt;/addons/_JKI Toolkits/Caraya/classes/Assert/Read Assert Only_.vi"/>
								<Item Name="Write Assert Only_.vi" Type="VI" URL="/&lt;vilib&gt;/addons/_JKI Toolkits/Caraya/classes/Assert/Write Assert Only_.vi"/>
								<Item Name="Read Call Chain.vi" Type="VI" URL="/&lt;vilib&gt;/addons/_JKI Toolkits/Caraya/classes/Assert/Read Call Chain.vi"/>
								<Item Name="Write Call Chain.vi" Type="VI" URL="/&lt;vilib&gt;/addons/_JKI Toolkits/Caraya/classes/Assert/Write Call Chain.vi"/>
								<Item Name="Read Label (Name).vi" Type="VI" URL="/&lt;vilib&gt;/addons/_JKI Toolkits/Caraya/classes/Assert/Read Label (Name).vi"/>
								<Item Name="Write Label (Name).vi" Type="VI" URL="/&lt;vilib&gt;/addons/_JKI Toolkits/Caraya/classes/Assert/Write Label (Name).vi"/>
							</Item>
							<Item Name="Assert.vi" Type="VI" URL="/&lt;vilib&gt;/addons/_JKI Toolkits/Caraya/classes/Assert/Assert.vi"/>
							<Item Name="Assert True.vi" Type="VI" URL="/&lt;vilib&gt;/addons/_JKI Toolkits/Caraya/classes/Assert/Assert True.vi"/>
							<Item Name="Assert False.vi" Type="VI" URL="/&lt;vilib&gt;/addons/_JKI Toolkits/Caraya/classes/Assert/Assert False.vi"/>
							<Item Name="Assert Error.vi" Type="VI" URL="/&lt;vilib&gt;/addons/_JKI Toolkits/Caraya/classes/Assert/Assert Error.vi"/>
							<Item Name="Assert Not Error.vi" Type="VI" URL="/&lt;vilib&gt;/addons/_JKI Toolkits/Caraya/classes/Assert/Assert Not Error.vi"/>
							<Item Name="Assert Equal Value and Type_Variant.vi" Type="VI" URL="/&lt;vilib&gt;/addons/_JKI Toolkits/Caraya/classes/Assert/Assert Equal Value and Type_Variant.vi"/>
							<Item Name="Assert Equal Value_Variant.vi" Type="VI" URL="/&lt;vilib&gt;/addons/_JKI Toolkits/Caraya/classes/Assert/Assert Equal Value_Variant.vi"/>
							<Item Name="Assert Equal Type_Variant.vi" Type="VI" URL="/&lt;vilib&gt;/addons/_JKI Toolkits/Caraya/classes/Assert/Assert Equal Type_Variant.vi"/>
							<Item Name="Assert Almost Equal_Float.vi" Type="VI" URL="/&lt;vilib&gt;/addons/_JKI Toolkits/Caraya/classes/Assert/Assert Almost Equal_Float.vi"/>
							<Item Name="Assert Not Equal Value and Type_Variant.vi" Type="VI" URL="/&lt;vilib&gt;/addons/_JKI Toolkits/Caraya/classes/Assert/Assert Not Equal Value and Type_Variant.vi"/>
							<Item Name="Assert Not Equal Value_Variant.vi" Type="VI" URL="/&lt;vilib&gt;/addons/_JKI Toolkits/Caraya/classes/Assert/Assert Not Equal Value_Variant.vi"/>
							<Item Name="Assert Not Equal Type_Variant.vi" Type="VI" URL="/&lt;vilib&gt;/addons/_JKI Toolkits/Caraya/classes/Assert/Assert Not Equal Type_Variant.vi"/>
							<Item Name="Assert Greater_Variant.vi" Type="VI" URL="/&lt;vilib&gt;/addons/_JKI Toolkits/Caraya/classes/Assert/Assert Greater_Variant.vi"/>
							<Item Name="Assert Less_Variant.vi" Type="VI" URL="/&lt;vilib&gt;/addons/_JKI Toolkits/Caraya/classes/Assert/Assert Less_Variant.vi"/>
							<Item Name="Assert Greater Or Equal_Variant.vi" Type="VI" URL="/&lt;vilib&gt;/addons/_JKI Toolkits/Caraya/classes/Assert/Assert Greater Or Equal_Variant.vi"/>
							<Item Name="Assert Less Or Equal_Variant.vi" Type="VI" URL="/&lt;vilib&gt;/addons/_JKI Toolkits/Caraya/classes/Assert/Assert Less Or Equal_Variant.vi"/>
						</Item>
						<Item Name="Test.lvclass" Type="LVClass" URL="/&lt;vilib&gt;/addons/_JKI Toolkits/Caraya/classes/Test/Test.lvclass">
							<Item Name="Test.ctl" Type="Class Private Data" URL="/&lt;vilib&gt;/addons/_JKI Toolkits/Caraya/classes/Test/Test.lvclass/Test.ctl"/>
							<Item Name="Define Test.vi" Type="VI" URL="/&lt;vilib&gt;/addons/_JKI Toolkits/Caraya/classes/Test/Define Test.vi"/>
						</Item>
						<Item Name="Test Suite.lvclass" Type="LVClass" URL="/&lt;vilib&gt;/addons/_JKI Toolkits/Caraya/classes/Test Suite/Test Suite.lvclass">
							<Item Name="Test Suite.ctl" Type="Class Private Data" URL="/&lt;vilib&gt;/addons/_JKI Toolkits/Caraya/classes/Test Suite/Test Suite.lvclass/Test Suite.ctl"/>
							<Item Name="Poly Members" Type="Folder">
								<Item Name="Define Test Suite (Default).vi" Type="VI" URL="/&lt;vilib&gt;/addons/_JKI Toolkits/Caraya/classes/Test Suite/Define Test Suite (Default).vi"/>
								<Item Name="Define Test Suite (JUnit Report).vi" Type="VI" URL="/&lt;vilib&gt;/addons/_JKI Toolkits/Caraya/classes/Test Suite/Define Test Suite (JUnit Report).vi"/>
								<Item Name="Define Test Suite (SimpleText Report).vi" Type="VI" URL="/&lt;vilib&gt;/addons/_JKI Toolkits/Caraya/classes/Test Suite/Define Test Suite (SimpleText Report).vi"/>
							</Item>
							<Item Name="Accessors" Type="Folder">
								<Item Name="Read timeout.vi" Type="VI" URL="/&lt;vilib&gt;/addons/_JKI Toolkits/Caraya/classes/Test Suite/Read timeout.vi"/>
								<Item Name="Write timeout.vi" Type="VI" URL="/&lt;vilib&gt;/addons/_JKI Toolkits/Caraya/classes/Test Suite/Write timeout.vi"/>
							</Item>
							<Item Name="Typedef" Type="Folder">
								<Item Name="Suite PublicEvents -- cluster.ctl" Type="VI" URL="/&lt;vilib&gt;/addons/_JKI Toolkits/Caraya/classes/Test Suite/Suite PublicEvents -- cluster.ctl"/>
							</Item>
							<Item Name="Define Test Suite (Poly).vi" Type="VI" URL="/&lt;vilib&gt;/addons/_JKI Toolkits/Caraya/classes/Test Suite/Define Test Suite (Poly).vi"/>
							<Item Name="Define Test Suite.vi" Type="VI" URL="/&lt;vilib&gt;/addons/_JKI Toolkits/Caraya/classes/Test Suite/Define Test Suite.vi"/>
							<Item Name="Read Suite PublicEvents.vi" Type="VI" URL="/&lt;vilib&gt;/addons/_JKI Toolkits/Caraya/classes/Test Suite/Read Suite PublicEvents.vi"/>
							<Item Name="Destroy Test Suite.vi" Type="VI" URL="/&lt;vilib&gt;/addons/_JKI Toolkits/Caraya/classes/Test Suite/Destroy Test Suite.vi"/>
						</Item>
						<Item Name="Run Tests.vi" Type="VI" URL="/&lt;vilib&gt;/addons/_JKI Toolkits/Caraya/run-tests/Run Tests.vi"/>
					</Item>
					<Item Name="Polymorphic" Type="Folder">
						<Item Name="Run Test (Scalar Path).vi" Type="VI" URL="/&lt;vilib&gt;/addons/_JKI Toolkits/Caraya/run-tests/Run Test (Scalar Path).vi"/>
						<Item Name="Run Test (Array Path).vi" Type="VI" URL="/&lt;vilib&gt;/addons/_JKI Toolkits/Caraya/run-tests/Run Test (Array Path).vi"/>
						<Item Name="Run Test (ProjectRefnum).vi" Type="VI" URL="/&lt;vilib&gt;/addons/_JKI Toolkits/Caraya/run-tests/Run Test (ProjectRefnum).vi"/>
						<Item Name="Run Test (LibraryRefnum).vi" Type="VI" URL="/&lt;vilib&gt;/addons/_JKI Toolkits/Caraya/run-tests/Run Test (LibraryRefnum).vi"/>
						<Item Name="Run Test (Object).vi" Type="VI" URL="/&lt;vilib&gt;/addons/_JKI Toolkits/Caraya/run-tests/Run Test (Object).vi"/>
						<Item Name="Run Test (Object Array).vi" Type="VI" URL="/&lt;vilib&gt;/addons/_JKI Toolkits/Caraya/run-tests/Run Test (Object Array).vi"/>
						<Item Name="Run Test (VIRefnum Scalar).vi" Type="VI" URL="/&lt;vilib&gt;/addons/_JKI Toolkits/Caraya/run-tests/Run Test (VIRefnum Scalar).vi"/>
						<Item Name="Run Test (VIRefnum Array).vi" Type="VI" URL="/&lt;vilib&gt;/addons/_JKI Toolkits/Caraya/run-tests/Run Test (VIRefnum Array).vi"/>
					</Item>
				</Item>
				<Item Name="7842910552F72B45FFAA5B67DFEBCBC5Build Error Cluster__ogtk.vi" Type="VI" URL="/&lt;vilib&gt;/addons/_JKI Toolkits/_Caraya_internal_deps/7842910552F72B45FFAA5B67DFEBCBC5Build Error Cluster__ogtk.vi"/>
				<Item Name="7842910552F72B45FFAA5B67DFEBCBC5Get Last PString__ogtk.vi" Type="VI" URL="/&lt;vilib&gt;/addons/_JKI Toolkits/_Caraya_internal_deps/7842910552F72B45FFAA5B67DFEBCBC5Get Last PString__ogtk.vi"/>
				<Item Name="7842910552F72B45FFAA5B67DFEBCBC5Get PString__ogtk.vi" Type="VI" URL="/&lt;vilib&gt;/addons/_JKI Toolkits/_Caraya_internal_deps/7842910552F72B45FFAA5B67DFEBCBC5Get PString__ogtk.vi"/>
				<Item Name="7842910552F72B45FFAA5B67DFEBCBC5Get Header from TD__ogtk.vi" Type="VI" URL="/&lt;vilib&gt;/addons/_JKI Toolkits/_Caraya_internal_deps/7842910552F72B45FFAA5B67DFEBCBC5Get Header from TD__ogtk.vi"/>
				<Item Name="7842910552F72B45FFAA5B67DFEBCBC5Variant to Header Info__ogtk.vi" Type="VI" URL="/&lt;vilib&gt;/addons/_JKI Toolkits/_Caraya_internal_deps/7842910552F72B45FFAA5B67DFEBCBC5Variant to Header Info__ogtk.vi"/>
				<Item Name="7842910552F72B45FFAA5B67DFEBCBC5Get Variant Attributes__ogtk.vi" Type="VI" URL="/&lt;vilib&gt;/addons/_JKI Toolkits/_Caraya_internal_deps/7842910552F72B45FFAA5B67DFEBCBC5Get Variant Attributes__ogtk.vi"/>
				<Item Name="7842910552F72B45FFAA5B67DFEBCBC5Set Data Name__ogtk.vi" Type="VI" URL="/&lt;vilib&gt;/addons/_JKI Toolkits/_Caraya_internal_deps/7842910552F72B45FFAA5B67DFEBCBC5Set Data Name__ogtk.vi"/>
				<Item Name="7842910552F72B45FFAA5B67DFEBCBC5Get Data Name from TD__ogtk.vi" Type="VI" URL="/&lt;vilib&gt;/addons/_JKI Toolkits/_Caraya_internal_deps/7842910552F72B45FFAA5B67DFEBCBC5Get Data Name from TD__ogtk.vi"/>
				<Item Name="7842910552F72B45FFAA5B67DFEBCBC5Get Data Name__ogtk.vi" Type="VI" URL="/&lt;vilib&gt;/addons/_JKI Toolkits/_Caraya_internal_deps/7842910552F72B45FFAA5B67DFEBCBC5Get Data Name__ogtk.vi"/>
				<Item Name="7842910552F72B45FFAA5B67DFEBCBC5Array Size(s)__ogtk.vi" Type="VI" URL="/&lt;vilib&gt;/addons/_JKI Toolkits/_Caraya_internal_deps/7842910552F72B45FFAA5B67DFEBCBC5Array Size(s)__ogtk.vi"/>
				<Item Name="7842910552F72B45FFAA5B67DFEBCBC5Reshape Array to 1D VArray__ogtk.vi" Type="VI" URL="/&lt;vilib&gt;/addons/_JKI Toolkits/_Caraya_internal_deps/7842910552F72B45FFAA5B67DFEBCBC5Reshape Array to 1D VArray__ogtk.vi"/>
				<Item Name="7842910552F72B45FFAA5B67DFEBCBC5Array to Array of VData__ogtk.vi" Type="VI" URL="/&lt;vilib&gt;/addons/_JKI Toolkits/_Caraya_internal_deps/7842910552F72B45FFAA5B67DFEBCBC5Array to Array of VData__ogtk.vi"/>
				<Item Name="7842910552F72B45FFAA5B67DFEBCBC5Parse String with TDs__ogtk.vi" Type="VI" URL="/&lt;vilib&gt;/addons/_JKI Toolkits/_Caraya_internal_deps/7842910552F72B45FFAA5B67DFEBCBC5Parse String with TDs__ogtk.vi"/>
				<Item Name="7842910552F72B45FFAA5B67DFEBCBC5Split Cluster TD__ogtk.vi" Type="VI" URL="/&lt;vilib&gt;/addons/_JKI Toolkits/_Caraya_internal_deps/7842910552F72B45FFAA5B67DFEBCBC5Split Cluster TD__ogtk.vi"/>
				<Item Name="7842910552F72B45FFAA5B67DFEBCBC5Cluster to Array of VData__ogtk.vi" Type="VI" URL="/&lt;vilib&gt;/addons/_JKI Toolkits/_Caraya_internal_deps/7842910552F72B45FFAA5B67DFEBCBC5Cluster to Array of VData__ogtk.vi"/>
				<Item Name="VariantType.lvlib" Type="Library" URL="/&lt;vilib&gt;/Utility/VariantDataType/VariantType.lvlib">
					<Item Name="Private" Type="Folder">
						<Item Name="MDTFlavorToTypeEnum.vi" Type="VI" URL="/&lt;vilib&gt;/Utility/VariantDataType/Private/MDTFlavorToTypeEnum.vi"/>
						<Item Name="I32ToMemoryInfo.vi" Type="VI" URL="/&lt;vilib&gt;/Utility/VariantDataType/Private/I32ToMemoryInfo.vi"/>
						<Item Name="I32ToRefnumType.vi" Type="VI" URL="/&lt;vilib&gt;/Utility/VariantDataType/Private/I32ToRefnumType.vi"/>
						<Item Name="RefnumTypeToI32.vi" Type="VI" URL="/&lt;vilib&gt;/Utility/VariantDataType/Private/RefnumTypeToI32.vi"/>
						<Item Name="GetRefnumInfoInternal.vi" Type="VI" URL="/&lt;vilib&gt;/Utility/VariantDataType/Private/GetRefnumInfoInternal.vi"/>
					</Item>
					<Item Name="GetArrayInfo.vi" Type="VI" URL="/&lt;vilib&gt;/Utility/VariantDataType/GetArrayInfo.vi"/>
					<Item Name="GetClusterInfo.vi" Type="VI" URL="/&lt;vilib&gt;/Utility/VariantDataType/GetClusterInfo.vi"/>
					<Item Name="GetLVClassInfo.vi" Type="VI" URL="/&lt;vilib&gt;/Utility/VariantDataType/GetLVClassInfo.vi"/>
					<Item Name="GetNumericFxpInfo.vi" Type="VI" URL="/&lt;vilib&gt;/Utility/VariantDataType/GetNumericFxpInfo.vi"/>
					<Item Name="GetNumericInfo.vi" Type="VI" URL="/&lt;vilib&gt;/Utility/VariantDataType/GetNumericInfo.vi"/>
					<Item Name="GetPolyVIInfo.vi" Type="VI" URL="/&lt;vilib&gt;/Utility/VariantDataType/GetPolyVIInfo.vi"/>
					<Item Name="GetRandomNumberForType.vi" Type="VI" URL="/&lt;vilib&gt;/Utility/VariantDataType/GetRandomNumberForType.vi"/>
					<Item Name="GetRefnumInfo.vi" Type="VI" URL="/&lt;vilib&gt;/Utility/VariantDataType/GetRefnumInfo.vi"/>
					<Item Name="GetStringInfo.vi" Type="VI" URL="/&lt;vilib&gt;/Utility/VariantDataType/GetStringInfo.vi"/>
					<Item Name="GetTagInfo.vi" Type="VI" URL="/&lt;vilib&gt;/Utility/VariantDataType/GetTagInfo.vi"/>
					<Item Name="GetTypeInfo.vi" Type="VI" URL="/&lt;vilib&gt;/Utility/VariantDataType/GetTypeInfo.vi"/>
					<Item Name="GetUserDefinedRefnumInfo.vi" Type="VI" URL="/&lt;vilib&gt;/Utility/VariantDataType/GetUserDefinedRefnumInfo.vi"/>
					<Item Name="GetUserDefinedTagInfo.vi" Type="VI" URL="/&lt;vilib&gt;/Utility/VariantDataType/GetUserDefinedTagInfo.vi"/>
					<Item Name="GetUserDefinedTagRefnumInfo.vi" Type="VI" URL="/&lt;vilib&gt;/Utility/VariantDataType/GetUserDefinedTagRefnumInfo.vi"/>
					<Item Name="GetVIInfo.vi" Type="VI" URL="/&lt;vilib&gt;/Utility/VariantDataType/GetVIInfo.vi"/>
					<Item Name="GetWaveformInfo.vi" Type="VI" URL="/&lt;vilib&gt;/Utility/VariantDataType/GetWaveformInfo.vi"/>
					<Item Name="MemoryInfo.ctl" Type="VI" URL="/&lt;vilib&gt;/Utility/VariantDataType/MemoryInfo.ctl"/>
					<Item Name="MemoryInfoToI32.vi" Type="VI" URL="/&lt;vilib&gt;/Utility/VariantDataType/Private/MemoryInfoToI32.vi"/>
					<Item Name="MemoryType.ctl" Type="VI" URL="/&lt;vilib&gt;/Utility/VariantDataType/MemoryType.ctl"/>
					<Item Name="PolyVITimestamp.ctl" Type="VI" URL="/&lt;vilib&gt;/Utility/VariantDataType/PolyVITimestamp.ctl"/>
					<Item Name="RefnumType.ctl" Type="VI" URL="/&lt;vilib&gt;/Utility/VariantDataType/RefnumType.ctl"/>
					<Item Name="SetArrayInfo.vi" Type="VI" URL="/&lt;vilib&gt;/Utility/VariantDataType/SetArrayInfo.vi"/>
					<Item Name="SetClusterInfo.vi" Type="VI" URL="/&lt;vilib&gt;/Utility/VariantDataType/SetClusterInfo.vi"/>
					<Item Name="SetNumericFxpBitAndRangeInfo.vi" Type="VI" URL="/&lt;vilib&gt;/Utility/VariantDataType/SetNumericFxpBitAndRangeInfo.vi"/>
					<Item Name="SetNumericFxpBitInfo.vi" Type="VI" URL="/&lt;vilib&gt;/Utility/VariantDataType/SetNumericFxpBitInfo.vi"/>
					<Item Name="SetNumericFxpRangeInfo.vi" Type="VI" URL="/&lt;vilib&gt;/Utility/VariantDataType/SetNumericFxpRangeInfo.vi"/>
					<Item Name="SetNumericFxpIncludeOverflowStatus.vi" Type="VI" URL="/&lt;vilib&gt;/Utility/VariantDataType/SetNumericFxpIncludeOverflowStatus.vi"/>
					<Item Name="SetNumericInfo.vi" Type="VI" URL="/&lt;vilib&gt;/Utility/VariantDataType/SetNumericInfo.vi"/>
					<Item Name="SetRefnumContainedType.vi" Type="VI" URL="/&lt;vilib&gt;/Utility/VariantDataType/SetRefnumContainedType.vi"/>
					<Item Name="SetRefnumInfo.vi" Type="VI" URL="/&lt;vilib&gt;/Utility/VariantDataType/SetRefnumInfo.vi"/>
					<Item Name="SetTypeInfo.vi" Type="VI" URL="/&lt;vilib&gt;/Utility/VariantDataType/SetTypeInfo.vi"/>
					<Item Name="SetUserDefinedRefnumInfo.vi" Type="VI" URL="/&lt;vilib&gt;/Utility/VariantDataType/SetUserDefinedRefnumInfo.vi"/>
					<Item Name="SetUserDefinedTagInfo.vi" Type="VI" URL="/&lt;vilib&gt;/Utility/VariantDataType/SetUserDefinedTagInfo.vi"/>
					<Item Name="SetUserDefinedTagRefnumInfo.vi" Type="VI" URL="/&lt;vilib&gt;/Utility/VariantDataType/SetUserDefinedTagRefnumInfo.vi"/>
					<Item Name="SetVIInfo.vi" Type="VI" URL="/&lt;vilib&gt;/Utility/VariantDataType/SetVIInfo.vi"/>
					<Item Name="Type.ctl" Type="VI" URL="/&lt;vilib&gt;/Utility/VariantDataType/Type.ctl"/>
					<Item Name="TypedefInfo.ctl" Type="VI" URL="/&lt;vilib&gt;/Utility/VariantDataType/TypedefInfo.ctl"/>
					<Item Name="UnitInfo.ctl" Type="VI" URL="/&lt;vilib&gt;/Utility/VariantDataType/UnitInfo.ctl"/>
					<Item Name="UnitType.ctl" Type="VI" URL="/&lt;vilib&gt;/Utility/VariantDataType/UnitType.ctl"/>
					<Item Name="VIInfo.ctl" Type="VI" URL="/&lt;vilib&gt;/Utility/VariantDataType/VIInfo.ctl"/>
					<Item Name="GetUserDefinedClassRelationship.vi" Type="VI" URL="/&lt;vilib&gt;/Utility/VariantDataType/GetUserDefinedClassRelationship.vi"/>
					<Item Name="VITerminalInfo.ctl" Type="VI" URL="/&lt;vilib&gt;/Utility/VariantDataType/VITerminalInfo.ctl"/>
					<Item Name="ContainsTypedef.vi" Type="VI" URL="/&lt;vilib&gt;/Utility/VariantDataType/ContainsTypedef.vi"/>
					<Item Name="DisconnectFromTypedef.vi" Type="VI" URL="/&lt;vilib&gt;/Utility/VariantDataType/DisconnectFromTypedef.vi"/>
					<Item Name="VI Server Generic Type.ctl" Type="VI" URL="/&lt;vilib&gt;/Utility/VariantDataType/VI Server Generic Type.ctl"/>
				</Item>
				<Item Name="7842910552F72B45FFAA5B67DFEBCBC5Get Local UTC Offset.vi" Type="VI" URL="/&lt;vilib&gt;/addons/_JKI Toolkits/_Caraya_internal_deps/7842910552F72B45FFAA5B67DFEBCBC5Get Local UTC Offset.vi"/>
				<Item Name="7842910552F72B45FFAA5B67DFEBCBC5Timestamp to ISO8601 UTC DateTime.vi" Type="VI" URL="/&lt;vilib&gt;/addons/_JKI Toolkits/_Caraya_internal_deps/7842910552F72B45FFAA5B67DFEBCBC5Timestamp to ISO8601 UTC DateTime.vi"/>
				<Item Name="TD_MDTFlavor.ctl" Type="VI" URL="/&lt;vilib&gt;/Utility/GetType.llb/TD_MDTFlavor.ctl"/>
				<Item Name="Type Descriptor I16.ctl" Type="VI" URL="/&lt;vilib&gt;/Utility/GetType.llb/Type Descriptor I16.ctl"/>
				<Item Name="Type Descriptor I16 Array.ctl" Type="VI" URL="/&lt;vilib&gt;/Utility/GetType.llb/Type Descriptor I16 Array.ctl"/>
				<Item Name="TD_Get MDT Information.vi" Type="VI" URL="/&lt;vilib&gt;/Utility/GetType.llb/TD_Get MDT Information.vi"/>
				<Item Name="7842910552F72B45FFAA5B67DFEBCBC5Unwrap VVariant__ogtk.vi" Type="VI" URL="/&lt;vilib&gt;/addons/_JKI Toolkits/_Caraya_internal_deps/7842910552F72B45FFAA5B67DFEBCBC5Unwrap VVariant__ogtk.vi"/>
				<Item Name="Get File System Separator.vi" Type="VI" URL="/&lt;vilib&gt;/Utility/sysinfo.llb/Get File System Separator.vi"/>
				<Item Name="7842910552F72B45FFAA5B67DFEBCBC5Strip Path Extension - String__ogtk.vi" Type="VI" URL="/&lt;vilib&gt;/addons/_JKI Toolkits/_Caraya_internal_deps/7842910552F72B45FFAA5B67DFEBCBC5Strip Path Extension - String__ogtk.vi"/>
				<Item Name="TRef TravTarget.ctl" Type="VI" URL="/&lt;vilib&gt;/Utility/traverseref.llb/TRef TravTarget.ctl"/>
				<Item Name="TRef Traverse.vi" Type="VI" URL="/&lt;vilib&gt;/Utility/traverseref.llb/TRef Traverse.vi"/>
				<Item Name="VI Scripting - Traverse.lvlib" Type="Library" URL="/&lt;vilib&gt;/Utility/traverseref.llb/VI Scripting - Traverse.lvlib">
					<Item Name="Traverse for GObjects.vi" Type="VI" URL="/&lt;vilib&gt;/Utility/traverseref.llb/Traverse for GObjects.vi"/>
				</Item>
				<Item Name="TRef Traverse for References.vi" Type="VI" URL="/&lt;vilib&gt;/Utility/traverseref.llb/TRef Traverse for References.vi"/>
				<Item Name="7842910552F72B45FFAA5B67DFEBCBC5File Exists - Scalar__ogtk.vi" Type="VI" URL="/&lt;vilib&gt;/addons/_JKI Toolkits/_Caraya_internal_deps/7842910552F72B45FFAA5B67DFEBCBC5File Exists - Scalar__ogtk.vi"/>
				<Item Name="7842910552F72B45FFAA5B67DFEBCBC5Remove Duplicates from 1D Array (Path)__ogtk.vi" Type="VI" URL="/&lt;vilib&gt;/addons/_JKI Toolkits/_Caraya_internal_deps/7842910552F72B45FFAA5B67DFEBCBC5Remove Duplicates from 1D Array (Path)__ogtk.vi"/>
				<Item Name="7842910552F72B45FFAA5B67DFEBCBC5Reorder 1D Array2 (Path)__ogtk.vi" Type="VI" URL="/&lt;vilib&gt;/addons/_JKI Toolkits/_Caraya_internal_deps/7842910552F72B45FFAA5B67DFEBCBC5Reorder 1D Array2 (Path)__ogtk.vi"/>
				<Item Name="7842910552F72B45FFAA5B67DFEBCBC5Sort 1D Array (I32)__ogtk.vi" Type="VI" URL="/&lt;vilib&gt;/addons/_JKI Toolkits/_Caraya_internal_deps/7842910552F72B45FFAA5B67DFEBCBC5Sort 1D Array (I32)__ogtk.vi"/>
				<Item Name="7842910552F72B45FFAA5B67DFEBCBC5Delete Elements from 1D Array (Path)__ogtk.vi" Type="VI" URL="/&lt;vilib&gt;/addons/_JKI Toolkits/_Caraya_internal_deps/7842910552F72B45FFAA5B67DFEBCBC5Delete Elements from 1D Array (Path)__ogtk.vi"/>
				<Item Name="7842910552F72B45FFAA5B67DFEBCBC5Search 1D Array (Path)__ogtk.vi" Type="VI" URL="/&lt;vilib&gt;/addons/_JKI Toolkits/_Caraya_internal_deps/7842910552F72B45FFAA5B67DFEBCBC5Search 1D Array (Path)__ogtk.vi"/>
				<Item Name="7842910552F72B45FFAA5B67DFEBCBC5Filter 1D Array (Path)__ogtk.vi" Type="VI" URL="/&lt;vilib&gt;/addons/_JKI Toolkits/_Caraya_internal_deps/7842910552F72B45FFAA5B67DFEBCBC5Filter 1D Array (Path)__ogtk.vi"/>
				<Item Name="Get VI Library File Info.vi" Type="VI" URL="/&lt;vilib&gt;/Utility/libraryn.llb/Get VI Library File Info.vi"/>
				<Item Name="7842910552F72B45FFAA5B67DFEBCBC5Build Path - File Names Array__ogtk.vi" Type="VI" URL="/&lt;vilib&gt;/addons/_JKI Toolkits/_Caraya_internal_deps/7842910552F72B45FFAA5B67DFEBCBC5Build Path - File Names Array__ogtk.vi"/>
				<Item Name="7842910552F72B45FFAA5B67DFEBCBC5Remove Duplicates from 1D Array (String)__ogtk.vi" Type="VI" URL="/&lt;vilib&gt;/addons/_JKI Toolkits/_Caraya_internal_deps/7842910552F72B45FFAA5B67DFEBCBC5Remove Duplicates from 1D Array (String)__ogtk.vi"/>
				<Item Name="7842910552F72B45FFAA5B67DFEBCBC5Trim Whitespace (String)__ogtk.vi" Type="VI" URL="/&lt;vilib&gt;/addons/_JKI Toolkits/_Caraya_internal_deps/7842910552F72B45FFAA5B67DFEBCBC5Trim Whitespace (String)__ogtk.vi"/>
				<Item Name="7842910552F72B45FFAA5B67DFEBCBC5List Directory__ogtk.vi" Type="VI" URL="/&lt;vilib&gt;/addons/_JKI Toolkits/_Caraya_internal_deps/7842910552F72B45FFAA5B67DFEBCBC5List Directory__ogtk.vi"/>
				<Item Name="Has LLB Extension.vi" Type="VI" URL="/&lt;vilib&gt;/Utility/libraryn.llb/Has LLB Extension.vi"/>
				<Item Name="7842910552F72B45FFAA5B67DFEBCBC5List Directory Recursive__ogtk.vi" Type="VI" URL="/&lt;vilib&gt;/addons/_JKI Toolkits/_Caraya_internal_deps/7842910552F72B45FFAA5B67DFEBCBC5List Directory Recursive__ogtk.vi"/>
				<Item Name="Application Directory.vi" Type="VI" URL="/&lt;vilib&gt;/Utility/file.llb/Application Directory.vi"/>
				<Item Name="7842910552F72B45FFAA5B67DFEBCBC5Get Element TD from Array TD__ogtk.vi" Type="VI" URL="/&lt;vilib&gt;/addons/_JKI Toolkits/_Caraya_internal_deps/7842910552F72B45FFAA5B67DFEBCBC5Get Element TD from Array TD__ogtk.vi"/>
				<Item Name="7842910552F72B45FFAA5B67DFEBCBC5Get TDEnum from TD__ogtk.vi" Type="VI" URL="/&lt;vilib&gt;/addons/_JKI Toolkits/_Caraya_internal_deps/7842910552F72B45FFAA5B67DFEBCBC5Get TDEnum from TD__ogtk.vi"/>
				<Item Name="7842910552F72B45FFAA5B67DFEBCBC5Get Physical Units from TD__ogtk.vi" Type="VI" URL="/&lt;vilib&gt;/addons/_JKI Toolkits/_Caraya_internal_deps/7842910552F72B45FFAA5B67DFEBCBC5Get Physical Units from TD__ogtk.vi"/>
				<Item Name="7842910552F72B45FFAA5B67DFEBCBC5Get Physical Units__ogtk.vi" Type="VI" URL="/&lt;vilib&gt;/addons/_JKI Toolkits/_Caraya_internal_deps/7842910552F72B45FFAA5B67DFEBCBC5Get Physical Units__ogtk.vi"/>
				<Item Name="7842910552F72B45FFAA5B67DFEBCBC5Resolve Timestamp Format__ogtk.vi" Type="VI" URL="/&lt;vilib&gt;/addons/_JKI Toolkits/_Caraya_internal_deps/7842910552F72B45FFAA5B67DFEBCBC5Resolve Timestamp Format__ogtk.vi"/>
				<Item Name="7842910552F72B45FFAA5B67DFEBCBC5Get Waveform Type Enum from TD__ogtk.vi" Type="VI" URL="/&lt;vilib&gt;/addons/_JKI Toolkits/_Caraya_internal_deps/7842910552F72B45FFAA5B67DFEBCBC5Get Waveform Type Enum from TD__ogtk.vi"/>
				<Item Name="7842910552F72B45FFAA5B67DFEBCBC5Get Waveform Type Enum from Data__ogtk.vi" Type="VI" URL="/&lt;vilib&gt;/addons/_JKI Toolkits/_Caraya_internal_deps/7842910552F72B45FFAA5B67DFEBCBC5Get Waveform Type Enum from Data__ogtk.vi"/>
				<Item Name="7842910552F72B45FFAA5B67DFEBCBC5Get Strings from Enum TD__ogtk.vi" Type="VI" URL="/&lt;vilib&gt;/addons/_JKI Toolkits/_Caraya_internal_deps/7842910552F72B45FFAA5B67DFEBCBC5Get Strings from Enum TD__ogtk.vi"/>
				<Item Name="7842910552F72B45FFAA5B67DFEBCBC5Get Strings from Enum__ogtk.vi" Type="VI" URL="/&lt;vilib&gt;/addons/_JKI Toolkits/_Caraya_internal_deps/7842910552F72B45FFAA5B67DFEBCBC5Get Strings from Enum__ogtk.vi"/>
				<Item Name="7842910552F72B45FFAA5B67DFEBCBC5Get Array Element TDEnum__ogtk.vi" Type="VI" URL="/&lt;vilib&gt;/addons/_JKI Toolkits/_Caraya_internal_deps/7842910552F72B45FFAA5B67DFEBCBC5Get Array Element TDEnum__ogtk.vi"/>
				<Item Name="7842910552F72B45FFAA5B67DFEBCBC5Strip Units__ogtk.vi" Type="VI" URL="/&lt;vilib&gt;/addons/_JKI Toolkits/_Caraya_internal_deps/7842910552F72B45FFAA5B67DFEBCBC5Strip Units__ogtk.vi"/>
				<Item Name="7842910552F72B45FFAA5B67DFEBCBC5Get Refnum Type Enum from TD__ogtk.vi" Type="VI" URL="/&lt;vilib&gt;/addons/_JKI Toolkits/_Caraya_internal_deps/7842910552F72B45FFAA5B67DFEBCBC5Get Refnum Type Enum from TD__ogtk.vi"/>
				<Item Name="7842910552F72B45FFAA5B67DFEBCBC5Get Refnum Type Enum from Data__ogtk.vi" Type="VI" URL="/&lt;vilib&gt;/addons/_JKI Toolkits/_Caraya_internal_deps/7842910552F72B45FFAA5B67DFEBCBC5Get Refnum Type Enum from Data__ogtk.vi"/>
				<Item Name="7842910552F72B45FFAA5B67DFEBCBC5Get TDEnum from Data__ogtk.vi" Type="VI" URL="/&lt;vilib&gt;/addons/_JKI Toolkits/_Caraya_internal_deps/7842910552F72B45FFAA5B67DFEBCBC5Get TDEnum from Data__ogtk.vi"/>
				<Item Name="7842910552F72B45FFAA5B67DFEBCBC5Format Variant Into String__ogtk.vi" Type="VI" URL="/&lt;vilib&gt;/addons/_JKI Toolkits/_Caraya_internal_deps/7842910552F72B45FFAA5B67DFEBCBC5Format Variant Into String__ogtk.vi"/>
				<Item Name="Get LV Class Name.vi" Type="VI" URL="/&lt;vilib&gt;/Utility/LVClass/Get LV Class Name.vi"/>
				<Item Name="Parse State Queue__jki_lib_state_machine.vi" Type="VI" URL="/&lt;vilib&gt;/addons/_JKI Toolkits/State Machine/_JKI_lib_State_Machine.llb/Parse State Queue__jki_lib_state_machine.vi"/>
				<Item Name="Add State(s) to Queue__jki_lib_state_machine.vi" Type="VI" URL="/&lt;vilib&gt;/addons/_JKI Toolkits/State Machine/_JKI_lib_State_Machine.llb/Add State(s) to Queue__jki_lib_state_machine.vi"/>
				<Item Name="7842910552F72B45FFAA5B67DFEBCBC5Empty 1D Array (String)__ogtk.vi" Type="VI" URL="/&lt;vilib&gt;/addons/_JKI Toolkits/_Caraya_internal_deps/7842910552F72B45FFAA5B67DFEBCBC5Empty 1D Array (String)__ogtk.vi"/>
				<Item Name="7842910552F72B45FFAA5B67DFEBCBC5Reorder 1D Array2 (String)__ogtk.vi" Type="VI" URL="/&lt;vilib&gt;/addons/_JKI Toolkits/_Caraya_internal_deps/7842910552F72B45FFAA5B67DFEBCBC5Reorder 1D Array2 (String)__ogtk.vi"/>
				<Item Name="7842910552F72B45FFAA5B67DFEBCBC5Delete Elements from 1D Array (String)__ogtk.vi" Type="VI" URL="/&lt;vilib&gt;/addons/_JKI Toolkits/_Caraya_internal_deps/7842910552F72B45FFAA5B67DFEBCBC5Delete Elements from 1D Array (String)__ogtk.vi"/>
				<Item Name="7842910552F72B45FFAA5B67DFEBCBC5Search 1D Array (String)__ogtk.vi" Type="VI" URL="/&lt;vilib&gt;/addons/_JKI Toolkits/_Caraya_internal_deps/7842910552F72B45FFAA5B67DFEBCBC5Search 1D Array (String)__ogtk.vi"/>
				<Item Name="7842910552F72B45FFAA5B67DFEBCBC5Filter 1D Array (String)__ogtk.vi" Type="VI" URL="/&lt;vilib&gt;/addons/_JKI Toolkits/_Caraya_internal_deps/7842910552F72B45FFAA5B67DFEBCBC5Filter 1D Array (String)__ogtk.vi"/>
				<Item Name="7842910552F72B45FFAA5B67DFEBCBC5Remove Duplicates from 1D Array (I32)__ogtk.vi" Type="VI" URL="/&lt;vilib&gt;/addons/_JKI Toolkits/_Caraya_internal_deps/7842910552F72B45FFAA5B67DFEBCBC5Remove Duplicates from 1D Array (I32)__ogtk.vi"/>
				<Item Name="System Directory Type.ctl" Type="VI" URL="/&lt;vilib&gt;/Utility/sysdir.llb/System Directory Type.ctl"/>
				<Item Name="Get System Directory.vi" Type="VI" URL="/&lt;vilib&gt;/Utility/sysdir.llb/Get System Directory.vi"/>
				<Item Name="Caraya Interactive Menu.rtm" Type="Document" URL="/&lt;vilib&gt;/Addons/_JKI Toolkits/Caraya/menu/Caraya Interactive Menu.rtm"/>
				<Item Name="7842910552F72B45FFAA5B67DFEBCBC5Strip Path - Traditional__ogtk.vi" Type="VI" URL="/&lt;vilib&gt;/addons/_JKI Toolkits/_Caraya_internal_deps/7842910552F72B45FFAA5B67DFEBCBC5Strip Path - Traditional__ogtk.vi"/>
				<Item Name="7842910552F72B45FFAA5B67DFEBCBC5Valid Path - Traditional__ogtk.vi" Type="VI" URL="/&lt;vilib&gt;/addons/_JKI Toolkits/_Caraya_internal_deps/7842910552F72B45FFAA5B67DFEBCBC5Valid Path - Traditional__ogtk.vi"/>
				<Item Name="7842910552F72B45FFAA5B67DFEBCBC5File Exists - Array__ogtk.vi" Type="VI" URL="/&lt;vilib&gt;/addons/_JKI Toolkits/_Caraya_internal_deps/7842910552F72B45FFAA5B67DFEBCBC5File Exists - Array__ogtk.vi"/>
				<Item Name="Get LV Class Path.vi" Type="VI" URL="/&lt;vilib&gt;/Utility/LVClass/Get LV Class Path.vi"/>
				<Item Name="7842910552F72B45FFAA5B67DFEBCBC5Valid Path - Array__ogtk.vi" Type="VI" URL="/&lt;vilib&gt;/addons/_JKI Toolkits/_Caraya_internal_deps/7842910552F72B45FFAA5B67DFEBCBC5Valid Path - Array__ogtk.vi"/>
				<Item Name="Get LV Class Default Value.vi" Type="VI" URL="/&lt;vilib&gt;/Utility/LVClass/Get LV Class Default Value.vi"/>
				<Item Name="7842910552F72B45FFAA5B67DFEBCBC5Strip Path Extension - Path__ogtk.vi" Type="VI" URL="/&lt;vilib&gt;/addons/_JKI Toolkits/_Caraya_internal_deps/7842910552F72B45FFAA5B67DFEBCBC5Strip Path Extension - Path__ogtk.vi"/>
				<Item Name="Find First Error.vi" Type="VI" URL="/&lt;vilib&gt;/Utility/error.llb/Find First Error.vi"/>
				<Item Name="Librarian Get Info.vi" Type="VI" URL="/&lt;vilib&gt;/Utility/libraryn.llb/Librarian Get Info.vi"/>
				<Item Name="Single String To Qualified Name Array.vi" Type="VI" URL="/&lt;vilib&gt;/Utility/LVClass/Single String To Qualified Name Array.vi"/>
				<Item Name="Qualified Name Array To Single String.vi" Type="VI" URL="/&lt;vilib&gt;/Utility/LVClass/Qualified Name Array To Single String.vi"/>
			</Item>
			<Item Name="Add dev dist if present.vi" Type="VI" URL="Tooling/support/Add dev dist if present.vi"/>
			<Item Name="Discover Who Invoked The Icon Editor.vi" Type="VI" URL="/&lt;resource&gt;/plugins/IconEditor/Discover Who Invoked The Icon Editor.vi"/>
			<Item Name="Icon Editor Invoker Type.ctl" Type="VI" URL="/&lt;resource&gt;/plugins/IconEditor/Icon Editor Invoker Type.ctl"/>
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
			<Item Name="Who Invoked Icon Editor.ctl" Type="VI" URL="/&lt;resource&gt;/plugins/IconEditor/Who Invoked Icon Editor.ctl"/>
			<Item Name="Advapi32.dll" Type="Document" URL="Advapi32.dll">
				<Property Name="NI.PreserveRelativePath" Type="Bool">true</Property>
			</Item>
			<Item Name="kernel32.dll" Type="Document" URL="kernel32.dll">
				<Property Name="NI.PreserveRelativePath" Type="Bool">true</Property>
			</Item>
			<Item Name="DOMUserDefRef.dll" Type="Document" URL="DOMUserDefRef.dll">
				<Property Name="NI.PreserveRelativePath" Type="Bool">true</Property>
			</Item>
		</Item>
		<Item Name="Build Specifications" Type="Build">
			<Item Name="Editor Packed Library" Type="Packed Library">
				<Property Name="Bld_autoIncrement" Type="Bool">true</Property>
				<Property Name="Bld_buildCacheID" Type="Str">{2EFDE742-60A0-4EBA-A8BF-5DA02968166D}</Property>
				<Property Name="Bld_buildSpecName" Type="Str">Editor Packed Library</Property>
				<Property Name="Bld_excludeLibraryItems" Type="Bool">true</Property>
				<Property Name="Bld_excludePolymorphicVIs" Type="Bool">true</Property>
				<Property Name="Bld_excludeTypedefs" Type="Bool">true</Property>
				<Property Name="Bld_localDestDir" Type="Path">../resource/plugins</Property>
				<Property Name="Bld_localDestDirType" Type="Str">relativeToProject</Property>
				<Property Name="Bld_modifyLibraryFile" Type="Bool">true</Property>
				<Property Name="Bld_preActionVIID" Type="Ref">/My Computer/Tooling/Pre Build Icon Editor PPL.vi</Property>
				<Property Name="Bld_previewCacheID" Type="Str">{C699D48A-6A0A-4A55-BF6A-D6FC254001CD}</Property>
				<Property Name="Bld_version.build" Type="Int">14</Property>
				<Property Name="Bld_version.major" Type="Int">1</Property>
				<Property Name="Destination[0].destName" Type="Str">lv_icon.lvlibp</Property>
				<Property Name="Destination[0].path" Type="Path">../resource/plugins/lv_icon.lvlibp</Property>
				<Property Name="Destination[0].path.type" Type="Str">relativeToProject</Property>
				<Property Name="Destination[0].preserveHierarchy" Type="Bool">true</Property>
				<Property Name="Destination[0].type" Type="Str">App</Property>
				<Property Name="Destination[1].destName" Type="Str">Support Directory</Property>
				<Property Name="Destination[1].path" Type="Path">../resource/plugins</Property>
				<Property Name="Destination[1].path.type" Type="Str">relativeToProject</Property>
				<Property Name="DestinationCount" Type="Int">2</Property>
				<Property Name="PackedLib_callersAdapt" Type="Bool">true</Property>
				<Property Name="Source[0].itemID" Type="Str">{DF18F03D-AB3A-4A60-8CAC-2585657B8F29}</Property>
				<Property Name="Source[0].type" Type="Str">Container</Property>
				<Property Name="Source[1].destinationIndex" Type="Int">0</Property>
				<Property Name="Source[1].itemID" Type="Ref">/My Computer/resource\/plugins/lv_icon.lvlib</Property>
				<Property Name="Source[1].Library.allowMissingMembers" Type="Bool">true</Property>
				<Property Name="Source[1].Library.atomicCopy" Type="Bool">true</Property>
				<Property Name="Source[1].Library.LVLIBPtopLevel" Type="Bool">true</Property>
				<Property Name="Source[1].preventRename" Type="Bool">true</Property>
				<Property Name="Source[1].sourceInclusion" Type="Str">TopLevel</Property>
				<Property Name="Source[1].type" Type="Str">Library</Property>
				<Property Name="Source[10].destinationIndex" Type="Int">0</Property>
				<Property Name="Source[10].itemID" Type="Ref">/My Computer/vi.lib\/LabVIEW Icon API/LabVIEW Icon API.lvlib/Get Library Icon.vi</Property>
				<Property Name="Source[10].sourceInclusion" Type="Str">Include</Property>
				<Property Name="Source[10].type" Type="Str">VI</Property>
				<Property Name="Source[11].destinationIndex" Type="Int">0</Property>
				<Property Name="Source[11].itemID" Type="Ref">/My Computer/vi.lib\/LabVIEW Icon API/LabVIEW Icon API.lvlib/Get VI Icon.vi</Property>
				<Property Name="Source[11].sourceInclusion" Type="Str">Include</Property>
				<Property Name="Source[11].type" Type="Str">VI</Property>
				<Property Name="Source[12].destinationIndex" Type="Int">0</Property>
				<Property Name="Source[12].itemID" Type="Ref">/My Computer/vi.lib\/LabVIEW Icon API/LabVIEW Icon API.lvlib/Low Level Functions/Generate Border User Layer.vi</Property>
				<Property Name="Source[12].sourceInclusion" Type="Str">Include</Property>
				<Property Name="Source[12].type" Type="Str">VI</Property>
				<Property Name="Source[13].destinationIndex" Type="Int">0</Property>
				<Property Name="Source[13].itemID" Type="Ref">/My Computer/vi.lib\/LabVIEW Icon API/LabVIEW Icon API.lvlib/Support/Create Icon Framework.vi</Property>
				<Property Name="Source[13].sourceInclusion" Type="Str">Include</Property>
				<Property Name="Source[13].type" Type="Str">VI</Property>
				<Property Name="Source[14].destinationIndex" Type="Int">0</Property>
				<Property Name="Source[14].itemID" Type="Ref">/My Computer/vi.lib\/LabVIEW Icon API/LabVIEW Icon API.lvlib/Support/Draw Template Glyph.vi</Property>
				<Property Name="Source[14].sourceInclusion" Type="Str">Include</Property>
				<Property Name="Source[14].type" Type="Str">VI</Property>
				<Property Name="Source[15].destinationIndex" Type="Int">0</Property>
				<Property Name="Source[15].itemID" Type="Ref">/My Computer/vi.lib\/LabVIEW Icon API/LabVIEW Icon API.lvlib/Support/Populate Body Text Data.vi</Property>
				<Property Name="Source[15].sourceInclusion" Type="Str">Include</Property>
				<Property Name="Source[15].type" Type="Str">VI</Property>
				<Property Name="Source[16].Container.applyInclusion" Type="Bool">true</Property>
				<Property Name="Source[16].Container.depDestIndex" Type="Int">0</Property>
				<Property Name="Source[16].destinationIndex" Type="Int">0</Property>
				<Property Name="Source[16].itemID" Type="Ref">/My Computer/vi.lib\/LabVIEW Icon API/LabVIEW Icon API.lvlib/Controls</Property>
				<Property Name="Source[16].sourceInclusion" Type="Str">Include</Property>
				<Property Name="Source[16].type" Type="Str">Container</Property>
				<Property Name="Source[2].destinationIndex" Type="Int">0</Property>
				<Property Name="Source[2].itemID" Type="Ref">/My Computer/vi.lib\/LabVIEW Icon API/LabVIEW Icon API.lvlib</Property>
				<Property Name="Source[2].Library.allowMissingMembers" Type="Bool">true</Property>
				<Property Name="Source[2].type" Type="Str">Library</Property>
				<Property Name="Source[3].Container.applyProperties" Type="Bool">true</Property>
				<Property Name="Source[3].Container.depDestIndex" Type="Int">0</Property>
				<Property Name="Source[3].itemID" Type="Ref">/My Computer/vi.lib\/LabVIEW Icon API</Property>
				<Property Name="Source[3].properties[0].type" Type="Str">Allow debugging</Property>
				<Property Name="Source[3].properties[0].value" Type="Bool">false</Property>
				<Property Name="Source[3].propertiesCount" Type="Int">1</Property>
				<Property Name="Source[3].type" Type="Str">Container</Property>
				<Property Name="Source[4].destinationIndex" Type="Int">0</Property>
				<Property Name="Source[4].itemID" Type="Ref">/My Computer/resource\/plugins/NIIconEditor/Miscellaneous/Icon Editor/Keep IE in Memory.vi</Property>
				<Property Name="Source[4].sourceInclusion" Type="Str">Include</Property>
				<Property Name="Source[4].type" Type="Str">VI</Property>
				<Property Name="Source[5].destinationIndex" Type="Int">0</Property>
				<Property Name="Source[5].itemID" Type="Ref">/My Computer/resource\/plugins/NIIconEditor/Support/ApplyLibIconOverlayToVIIcon.vi</Property>
				<Property Name="Source[5].type" Type="Str">VI</Property>
				<Property Name="Source[6].destinationIndex" Type="Int">0</Property>
				<Property Name="Source[6].itemID" Type="Ref">/My Computer/resource\/plugins/NIIconEditor/Miscellaneous/Create new class icon user layers.vi</Property>
				<Property Name="Source[6].type" Type="Str">VI</Property>
				<Property Name="Source[7].destinationIndex" Type="Int">0</Property>
				<Property Name="Source[7].itemID" Type="Ref">/My Computer/resource\/plugins/NIIconEditor/Launch Icon Editor From String.vi</Property>
				<Property Name="Source[7].sourceInclusion" Type="Str">Include</Property>
				<Property Name="Source[7].type" Type="Str">VI</Property>
				<Property Name="Source[8].destinationIndex" Type="Int">0</Property>
				<Property Name="Source[8].itemID" Type="Ref">/My Computer/vi.lib\/LabVIEW Icon API/LabVIEW Icon API.lvlib/Set Library Icon.vi</Property>
				<Property Name="Source[8].sourceInclusion" Type="Str">Include</Property>
				<Property Name="Source[8].type" Type="Str">VI</Property>
				<Property Name="Source[9].destinationIndex" Type="Int">0</Property>
				<Property Name="Source[9].itemID" Type="Ref">/My Computer/vi.lib\/LabVIEW Icon API/LabVIEW Icon API.lvlib/Set VI Icon.vi</Property>
				<Property Name="Source[9].sourceInclusion" Type="Str">Include</Property>
				<Property Name="Source[9].type" Type="Str">VI</Property>
				<Property Name="SourceCount" Type="Int">17</Property>
				<Property Name="TgtF_companyName" Type="Str">National Instruments</Property>
				<Property Name="TgtF_fileDescription" Type="Str">Icon Editor Packed Library</Property>
				<Property Name="TgtF_internalName" Type="Str">Icon Editor Packed Library</Property>
				<Property Name="TgtF_legalCopyright" Type="Str">Copyright © 2024 National Instruments</Property>
				<Property Name="TgtF_productName" Type="Str">Icon Editor Packed Library</Property>
				<Property Name="TgtF_targetfileGUID" Type="Str">{8000CA4B-2279-41C6-9767-84059F743142}</Property>
				<Property Name="TgtF_targetfileName" Type="Str">lv_icon.lvlibp</Property>
				<Property Name="TgtF_versionIndependent" Type="Bool">true</Property>
			</Item>
		</Item>
	</Item>
</Project>
