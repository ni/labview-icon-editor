<?xml version='1.0' encoding='UTF-8'?>
<Project Type="Project" LVVersion="21008000">
	<Property Name="NI.LV.All.SaveVersion" Type="Str">21.0</Property>
	<Property Name="NI.LV.All.SourceOnly" Type="Bool">true</Property>
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
		<Item Name="Templates" Type="Folder">
			<Item Name="Class Template.lvclass" Type="LVClass" URL="../../Templates/Class Template/Class Template.lvclass"/>
			<Item Name="Control Template.ctl" Type="VI" URL="../../Templates/Control Template.ctl"/>
			<Item Name="Library Template.lvlib" Type="Library" URL="../../Templates/Library Template/Library Template.lvlib"/>
			<Item Name="Many Layers.vi" Type="VI" URL="../../Templates/Many Layers.vi"/>
			<Item Name="Polymorphic Template.vi" Type="VI" URL="../../Templates/Polymorphic Template.vi"/>
			<Item Name="Pyramid Icon Template.vi" Type="VI" URL="../../Templates/Pyramid Icon Template.vi"/>
		</Item>
		<Item Name="Tools" Type="Folder">
			<Item Name="Remove Icon Editor Settings.vi" Type="VI" URL="../../../Tooling/Remove Icon Editor Settings.vi"/>
		</Item>
		<Item Name="Dependencies" Type="Dependencies"/>
		<Item Name="Build Specifications" Type="Build"/>
	</Item>
</Project>
