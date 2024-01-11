-- ***************************************
-- VCLua Form tool
-- Copyright (C) 2013-2023 Hi-Project Ltd.
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

function setCurElem(elem)
	elem = elem or prjTable.items[1]
	-- save virtual element content into property, except on initialization
	if curElem and curElem.vclObj and curElem.vclObj.virtual and prjInit==nil then
		curElem.vclObj.code = seCode.Text
		setProperty(curElem.vclObj, "code", seCode.Text)
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
	prjName = fileName
	fileio.saveJson(fileName,toJson())
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
	prjName = nil	
	curElem = nil
	if prjTable then
		for k,v in pairs(prjTable.items) do
			if v.vclObj and v.vclObj.virtual==nil then
				v.vclObj:Free()
			end
		end
	end
	prjTable = {items={}}
	-- prjSrc:Clear()
	tvForm.Items:Clear()
	resetUniqueNames()
	return true
end

function prjNew()
	_newProject()
	local t = addComponent(nil,"Form")	
	t.vclObj.position = "poScreenCenter"
	prjForm = prjTable.items[1]
	setCurElem(prjForm)
end

local function loadProject(fileName)
	prjInit = true
	tvForm.OnSelectionChanged=nil
	local frm = fileio.loadJson(fileName)
	_newProject()
	fromJson(frm)
	prjForm = prjTable.items[1]
	setCurElem(prjForm,true) -- true means initializaton only, no property change
	tvForm:FullExpand()	
	tvForm.OnSelectionChanged=function(Sender)
		local elem = Sender.Selected
		if elem then	
			setCurElem(findElem(elem))
		end
	end
	prjInit = nil
end

function prjLoad()
	local fileName = openDialog(frmMain,"Open form","forms/",
					 "VCLua forms|*.json","[ofFileMustExist]")
	if type(fileName)=="string" then
		loadProject(fileName)
		prjName = fileName
	end
end

function prjPreview()
	prjForm.vclObj:ShowOnTop()
end

function prjRefresh()
	local isPrv = prjForm.vclObj.visible
	local frm = toJson()
	prjInit = true
	tvForm.OnSelectionChanged=nil
	_newProject()
	fromJson(frm)
	prjForm = prjTable.items[1]
	setCurElem(prjForm,true)
	tvForm:FullExpand()	
	tvForm.OnSelectionChanged=function(Sender)
		local elem = Sender.Selected
		if elem then	
			setCurElem(findElem(elem))
		end
	end
	prjInit = nil
	if isPrv then
		prjPreview()
	end
end

function prjExit()
	frmMain:Close()
end

