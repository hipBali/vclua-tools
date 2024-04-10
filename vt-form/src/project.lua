-- ***************************************
-- VCLua Form tool
-- Copyright (C) 2013-2024 Hi-Project Ltd.
--
-- project manager
-- ***************************************

local fileio = require "fileio"

local prjSrc = VCL.StringList()
local prjTable = nil
local prjName = nil
local curElem = nil
local prjInit = nil

local prjForm = nil

function setProject(t)
	prjTable = t
end

function getProject()
	return prjTable
end

local function setPrjName(name)
  prjName = name
  frmMain.Caption = name and defaultCaption..': '..name or defaultCaption
end

function setCurElem(elem)
	elem = elem or prjTable.items[1]
	-- save virtual element content into property, except on initialization
	if curElem and curElem.vclObj and curElem.vclObj.virtual and prjInit==nil then
		curElem.vclObj.code = seCode.Text
	end
	if elem.vclObj.virtual then
		tsProperties.TabVisible = false
	else
		tsProperties.TabVisible = true
		compPropGrid.TIObject = elem.vclObj
	end
	curElem = elem
	tvForm.Selected=elem.obj
end

function getCurElem()
	return curElem
end

local function _saveProject(fileName)
	setPrjName(fileName)
	fileio.saveJson(fileName,toJson(prjForm))
end

function prjSaveAs()
	local fileName = saveDialog(frmMain,"Save form as...",
					 ExtractFileName(prjName or ""),"forms/",
					 "VCLua forms|*.json","[ofViewDetail]",true)
	if fileName == nil then
		return 
	end
	_saveProject(fileName)
end

function prjSave()
	if prjName==nil then
		prjSaveAs()
	else
		_saveProject(prjName)
	end
end

local function _newProject()
	setPrjName(nil)
	curElem = nil
	if prjTable then
		if compPropGrid.collectionForm then
			-- this is only needed to prevent crashes when this form was ever used
			compPropGrid.collectionForm:Close()
			compPropGrid.oldTIObject = nil
		end
		for _,v in ipairs(prjTable.items) do
			if v.vclObj and v.vclObj.virtual==nil then
				v.vclObj:Free()
			end
		end
	end
	prjTable = {items={}}
	-- prjSrc:Clear()
	tvForm.Items:Clear()
	return true
end

function prjNew()
	_newProject()
	prjForm = addComponent(nil,"Form")
	prjForm.vclObj.Position = "poScreenCenter"
	prjForm.props.Position = "poScreenCenter"
	setCurElem(prjForm)
end

local function loadProject(frm,name)
	prjInit = true
	tvForm.OnSelectionChanged=nil
	_newProject()
	tableToTreeView(fromJson(frm,prjTable))
	setPrjName(name)
	prjForm = prjTable.items[1]
	setCurElem(prjForm)
	tvForm:FullExpand()	
	tvForm.OnSelectionChanged=function(Sender)
		local elem = Sender.Selected
		if elem then	
			setCurElem(findElem(elem))
		end
	end
	prjInit = nil
end

function prjPreview()
	prjForm.vclObj:ShowOnTop()
end

function prjLoad()
	local fileName = openDialog(frmMain,"Open form","forms/",
					 "VCLua forms|*.json","[ofFileMustExist]")
	if type(fileName)=="string" then
		loadProject(fileio.loadJson(fileName),fileName)
		setPrjName(fileName)
		prjPreview()
	end
end

function prjRefresh()
	local isPrv = prjForm.vclObj.visible
	loadProject(toJson(prjForm), prjName)
	if isPrv then
		prjPreview()
	end
end

function prjExit()
	frmMain:Close()
end

