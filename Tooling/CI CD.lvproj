<?xml version='1.0' encoding='UTF-8'?>
<Project Type="Project" LVVersion="21008000">
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
		<Item Name="G-CLI" Type="Folder">
			<Item Name="ApplyVIPC.vi" Type="VI" URL="../deployment/ApplyVIPC.vi"/>
			<Item Name="Create_LV_INI_Token.vi" Type="VI" URL="../deployment/Create_LV_INI_Token.vi"/>
			<Item Name="CreateLVAddonJSONfile.vi" Type="VI" URL="../deployment/CreateLVAddonJSONfile.vi"/>
			<Item Name="Destroy_LV_INI_Token.vi" Type="VI" URL="../deployment/Destroy_LV_INI_Token.vi"/>
			<Item Name="Modify_VIPB_Display_Information.vi" Type="VI" URL="../deployment/Modify_VIPB_Display_Information.vi"/>
			<Item Name="PrepareIESource.vi" Type="VI" URL="../PrepareIESource.vi"/>
			<Item Name="PrepareIESourceCore.vi" Type="VI" URL="../PrepareIESourceCore.vi"/>
			<Item Name="RestoreSetupLVSource.vi" Type="VI" URL="../RestoreSetupLVSource.vi"/>
			<Item Name="RestoreSetupLVSourceCore.vi" Type="VI" URL="../RestoreSetupLVSourceCore.vi"/>
		</Item>
		<Item Name="NI Package install actions" Type="Folder">
			<Item Name="NIP Post uninstall.vi" Type="VI" URL="../deployment/NIP Post uninstall.vi"/>
		</Item>
		<Item Name="VI Package install actions" Type="Folder">
			<Property Name="NI.SortType" Type="Int">3</Property>
			<Item Name="VIP_Pre-Uninstall Custom Action.vi" Type="VI" URL="../deployment/VIP_Pre-Uninstall Custom Action.vi"/>
			<Item Name="VIP_Pre-Install Custom Action.vi" Type="VI" URL="../deployment/VIP_Pre-Install Custom Action.vi"/>
			<Item Name="VIP_Post-Install Custom Action.vi" Type="VI" URL="../deployment/VIP_Post-Install Custom Action.vi"/>
			<Item Name="VIP_Post-Uninstall Custom Action.vi" Type="VI" URL="../deployment/VIP_Post-Uninstall Custom Action.vi"/>
		</Item>
		<Item Name="Dependencies" Type="Dependencies"/>
		<Item Name="Build Specifications" Type="Build">
			<Item Name="VIPM Install support" Type="Packed Library">
				<Property Name="Bld_autoIncrement" Type="Bool">true</Property>
				<Property Name="Bld_buildCacheID" Type="Str">{496D9561-7C2E-410B-B213-BD49FC44C77D}</Property>
				<Property Name="Bld_buildSpecName" Type="Str">VIPM Install support</Property>
				<Property Name="Bld_excludeLibraryItems" Type="Bool">true</Property>
				<Property Name="Bld_excludePolymorphicVIs" Type="Bool">true</Property>
				<Property Name="Bld_excludeTypedefs" Type="Bool">true</Property>
				<Property Name="Bld_localDestDir" Type="Path">../builds/VIPM Install support</Property>
				<Property Name="Bld_localDestDirType" Type="Str">relativeToCommon</Property>
				<Property Name="Bld_modifyLibraryFile" Type="Bool">true</Property>
				<Property Name="Bld_previewCacheID" Type="Str">{775CE458-DA89-4A9A-8C9A-586CC58285CF}</Property>
				<Property Name="Bld_version.build" Type="Int">1</Property>
				<Property Name="Bld_version.major" Type="Int">1</Property>
				<Property Name="Destination[0].destName" Type="Str">VIPM Install support.lvlibp</Property>
				<Property Name="Destination[0].path" Type="Path">../builds/VIPM Install support/VIPM Install support.lvlibp</Property>
				<Property Name="Destination[0].preserveHierarchy" Type="Bool">true</Property>
				<Property Name="Destination[0].type" Type="Str">App</Property>
				<Property Name="Destination[1].destName" Type="Str">Support Directory</Property>
				<Property Name="Destination[1].path" Type="Path">../builds/VIPM Install support</Property>
				<Property Name="DestinationCount" Type="Int">2</Property>
				<Property Name="PackedLib_callersAdapt" Type="Bool">true</Property>
				<Property Name="Source[0].itemID" Type="Str">{35081879-4FB0-4AEF-A64A-5BD8095F0C7D}</Property>
				<Property Name="Source[0].type" Type="Str">Container</Property>
				<Property Name="Source[1].destinationIndex" Type="Int">0</Property>
				<Property Name="Source[1].itemID" Type="Ref">/</Property>
				<Property Name="Source[1].Library.allowMissingMembers" Type="Bool">true</Property>
				<Property Name="Source[1].Library.atomicCopy" Type="Bool">true</Property>
				<Property Name="Source[1].Library.LVLIBPtopLevel" Type="Bool">true</Property>
				<Property Name="Source[1].preventRename" Type="Bool">true</Property>
				<Property Name="Source[1].sourceInclusion" Type="Str">TopLevel</Property>
				<Property Name="Source[1].type" Type="Str">Library</Property>
				<Property Name="SourceCount" Type="Int">2</Property>
				<Property Name="TgtF_companyName" Type="Str">National Instruments</Property>
				<Property Name="TgtF_fileDescription" Type="Str">VIPM Install support</Property>
				<Property Name="TgtF_internalName" Type="Str">VIPM Install support</Property>
				<Property Name="TgtF_legalCopyright" Type="Str">Copyright © 2024 National Instruments</Property>
				<Property Name="TgtF_productName" Type="Str">VIPM Install support</Property>
				<Property Name="TgtF_targetfileGUID" Type="Str">{0EBB8DFF-C52E-4312-B9DC-6FBCF30AE477}</Property>
				<Property Name="TgtF_targetfileName" Type="Str">VIPM Install support.lvlibp</Property>
				<Property Name="TgtF_versionIndependent" Type="Bool">true</Property>
			</Item>
		</Item>
	</Item>
</Project>
