-- ***************************************
-- VCLua Form tool
-- Copyright (C) 2013-2023 Hi-Project Ltd.
-- ***************************************
package.path=package.path..';lua/?.lua;'

_VCLFB_COPY = "Copyright (C) 2013-2023 Hi-Project Ltd."
_VCLFB_VERSION = "0.9.2"
_VCLUA_MINVERSION = "0.9.2"

VCL = require "vcl.core"
if VCL._VERSION<_VCLUA_MINVERSION then
	VCL.ShowMessage("VCLua minimum version required is ".._VCLUA_MINVERSION.."!\nYour version is "..tostring(VCL._VERSION))
	return
end

require "common"
toolImg = require "images"		-- application icon gfx imported from Lazarus project
cmpImg = require "compimages"	-- vclua component gfx imported from Lazarus project
require "form"
require "components"
require "project"
require "designer"

VCL.Application():Initialize()

-- vcl.ActionList loader
function VCL.loadAction(self, t)
	local list = self
	for n,prop in pairs(t) do
		local a = VCL.Action()
		a._= prop
		list[prop.name] = a
	end
end

-- vcl.Menu
function VCL.loadMenu(self,t,mId)
	for mi,mt in pairs(t) do
		local props = {}
		for k,v in pairs(mt) do
			if k ~= "submenu" then
				props[k] = v
			end
		end
		if mId then
			self.Items:Find(mId):Add(VCL.MenuItem(self,props))
		else
			self.Items:Add(VCL.MenuItem(self,props))
		end
		if mt.submenu then
			VCL.loadMenu(self,mt.submenu,props.caption)
		end
	end
end

local function setupImages()
	local img = VCL.Image()	
	local str = VCL.Stream()
	local add = function(t,b)
		-- skip first 8 bytes
		local memStr,size = str.LoadFromHex(b:sub(9))
		img.picture:LoadFromStream(memStr) 	
		memStr:Free()
		return t:Add(img.picture.bitmap,nil)
	end
	
	-- adding form (root) element image	
	cmpImg.Form.ii=add(compImages,cmpImg.Form.data)
	
	-- load all component images
	for k,v in pairsByKeys(cmpImg) do 			
		v.ii=add(compImages,v.data)
	end	
	-- Adding tool images	
	add(toolImages,toolImg.New)
	add(toolImages,toolImg.Open)
	add(toolImages,toolImg.Save)
	add(toolImages,toolImg.SaveAs)
	add(toolImages,toolImg.LUA)
	add(toolImages,toolImg.Quit)
	add(toolImages,toolImg.Help)
	add(toolImages,toolImg.About)

	str:Free()
	img:Free()	
end

local function setupMenus()
	local mainActions = VCL.ActionList(frmMain)
	mainActions.Images = toolImages
	VCL.loadAction(mainActions, {
		{name="fileNew", caption="New form", shortcut="Ctrl+N", imageIndex=0, onexecute=prjNew },
		{name="fileOpen", caption="Open form", shortcut="Ctrl+O", imageIndex=1, onexecute=prjLoad },
		{name="fileSave", caption="Save form", shortcut="Ctrl+S", imageIndex=2, onexecute=prjSave },
		{name="fileSaveAs", caption="Save form as ...", imageIndex=3, onexecute=prjSaveAs },		
		{name="fileQuit", caption="Exit", shortcut="Ctrl+Q", imageIndex=5, onexecute=prjExit},			

		{name="frmPreview", caption="Form preview", shortcut="Ctrl+P",  onexecute=prjPreview},
				
		{name="aAbout", caption="About", shortcut="", imageIndex=7, onexecute=function() 
			VCL.ShowMessage('VCLua form tool v'.._VCLFB_VERSION)
		end},

	})
	local mainMenu = VCL.MainMenu(frmMain, "mmmainmenu")
	mainMenu.Images = toolImages
	mainMenu.showhint=true
	VCL.loadMenu(mainMenu, {
		{caption="&File",   
			submenu={
				{action=mainActions["fileNew"]},	
				{caption="-",},	
				{action=mainActions["fileOpen"]},					
				{action=mainActions["fileSave"]},
				{caption="-",},					
				{action=mainActions["fileSaveAs"]},	
				{caption="-",},	
				{action=mainActions["frmPreview"]},	
				{caption="-",},
				{action=mainActions["fileQuit"]}  
			}
		},
		{caption="&Help", RightJustify=true, 
			submenu =  {
				{action=mainActions["aAbout"]},
			}
		}
	})
	local prjActions = VCL.ActionList(frmMain)	
	prjPopupMenu = VCL.PopupMenu()
	-- autopopup on right click
	tvForm.PopupMenu = prjPopupMenu
	VCL.loadAction(prjActions, {		
		{name="treeCopy",   shortcut="Ctrl+C",   caption="Copy",      onexecute=CopyComponent },
		{name="treeCut",    shortcut="Ctrl+X",   caption="Cut", 	  onexecute=CutComponent },
		{name="treePaste",  shortcut="Ctrl+V", 	 caption="Paste", 	  onexecute=PasteComponent },
		{name="treeDup",    shortcut="Ctrl+D",   caption="Duplicate", onexecute=DuplicateComponent },
		{name="treeDelete", shortcut="Ctrl+Del", caption="Delete",    onexecute=DeleteComponent },
	})

	VCL.loadMenu(prjPopupMenu, {
		{action=prjActions["treeCopy"]},
		{action=prjActions["treeCut"]},
		{action=prjActions["treePaste"]},
		{name="treeSep1", caption="-" },
		{action=prjActions["treeDup"]},
		{name="treeSep2", caption="-" },
		{action=prjActions["treeDelete"]},
	})
end

local function fillView(flag)
	flag = flag or "C"	
	local items = compListTree.Items
	items:Clear()
	for k,v in pairsByKeys(cmpImg) do 			
		if v.flag==flag and VCL[k] then
			local c = items:Add(nil,k)
			c.StateIndex = cmpImg[k].ii
		end
	end		
end


local function setupMainForm()
	setupImages()
	setupMenus()
	tvForm.Items.KeepCollapse = false
	pgTabs.ActivePage=tsCompTree
	-- show components
	fillView("C")
	prjNew()
end

setupMainForm()
frmMain.OnActivate = function() prjPreview() end
frmMain:ShowModal()

