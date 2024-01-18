-- ***************************************
-- VCLua Form tool
-- Copyright (C) 2013-2023 Hi-Project Ltd.
--
-- builder component tree manager
-- ***************************************

require "designer"

local uniNames={}
local compTargets={
	ActionList={Action=1},
	Form=1,Panel=1,GroupBox=1,ScollBox=1,TabSheet=1,
	PageControl={TabSheet=1,},
	ToolBar={ToolButton=1,},
}
local compFixed={ Script=1, Form=1 }
local ComponentClipBoard = {}

-- returns: child table, orig parent table, index
function findElem(elem,t)
	t = t or getProject() 
	for k,v in pairs(t.items) do
		if v.obj.AbsoluteIndex==elem.AbsoluteIndex then
			return v,t,k							
		end
		local r,p,n = findElem(elem,v)
		if r then return r,p,n end
	end	
	return nil
end

local function findElemByName(name,t)
	t = t or getProject() 
	for k,v in pairs(t.items) do
		if v.name==name then
			return v							
		end
		local r = findElemByName(name,v)
		if r then return r end
	end	
	return nil
end

local function getUniqueName(compName)
	local n = uniNames[compName] or 0
	n = n + 1
	uniNames[compName] = n
	return compName..n
end

function resetUniqueNames()
	uniNames ={}
end

-- Property getter/setter
function getProperty(obj, pPath)
	local p = obj
	local propValue = p[pPath]
	local root = nil
	for s in string.gmatch(pPath, '([^%.]+)') do	
		root = root or s
		-- test array/collection
		local n = s:find('%[')
		if n then
			local index = s:match("%[(%w+)%]")
			local coll = s:sub(1,n-1)
			if p[coll] and p[coll].GetItem then
				p = p[coll]:GetItem(index)
			end
		else
			if (p[s]) then
				propValue = p[s] or propValue
				p = p[s]
			end
		end
	end
	return propValue, root 
end

function setProperty(obj, pPath, pValue)
	local p = obj
	local propName = nil
	for s in string.gmatch(pPath, '([^%.]+)') do	
		local n = s:find('%[')
		if n then	
			local index = s:match("%[(%w+)%]")
			local coll = s:sub(1,n-1)
			-- collection has GetItem?
			if p[coll] and p[coll].GetItem then
				local pp = p[coll]:GetItem(index)
				if pp==nil then
					p = p[coll]:Add()
				else
					p = pp
				end
			end
		elseif type(p[s])=="table" then
			p = p[s]			
		end
		propName = s
	end		
	propName = propName or pPath
	p[propName] = pValue	
end

local function mkObjTable(parent,compName,vclParent)	

	local c = tvForm.Items:Add(parent,compName)	
	c.StateIndex = cmpImg[compName].ii	
	local o = VCL[compName](vclParent,'')
	local s = getUniqueName(compName)
	
	o.Name = s	
	c.Text = s
	local t = {
		obj=c,
		vclObj=o,		
		name=s,
		class=compName,
		items={},
		events={},
		props={},
		collections={},
	}				
	return t
end	

local function checkTarget(tName,sName)
	if compTargets[tName]==1 then
		return true
	elseif type(compTargets[tName])=="table" then
		if compTargets[tName][sName] then
			return true
		end
	end
	VCL.ShowMessage(tName.." can't have control '"..sName.."' as child!")
	return nil
end

local function checkFixedSource(sName)
	return compFixed[sName]
end

function addComponent(parent, compName)	
	local t = nil
	local n = 0
	if parent==nil then
		t = mkObjTable(parent,compName,nil)
		t.vclObj.Caption = t.name
		if t.vclObj.virtual then
		else
			-- t.vclObj:Hide()
			-- t.vclObj.left = 100
			-- t.vclObj.top = 100
		end
		n = #(getProject().items) + 1
		getProject().items[n] = t
	else	
		local pt = findElem(parent)
		-- isTarget?
		if checkTarget(pt.class,compName) then
			n = #pt.items + 1
			t = mkObjTable(parent,compName,pt.vclObj)
			pt.items[n] = t
		else 
			return nil
		end
	end	
	if t then 
		-- setCurElem(t) 
	end
	return t,n	
end

local function moveChild(child,parent)
	local ct,cp,cn = findElem(child) -- child table, orig parent table, index
	local pt = findElem(parent)	-- new parent table
	local n = #pt.items + 1			
	pt.items[n] = ct
	cp.items[cn] = nil	
	setCurElem(pt.items[n])
	prjRefresh()
end

local function addElemToTreeView(t,p,level)
	level = level or 1	
	for k,v in pairs(t) do
		local c
		if level==1 then
			c = tvForm.Items:Add(p,v.name)
		else
			c = tvForm.Items:AddChild(p,v.name)
		end
		c.StateIndex = cmpImg[v.class].ii
		v.obj = c
		addElemToTreeView(v.items,c,level+1)
	end
end

local function tableToTreeView()
	tvForm:BeginUpdate()
	tvForm.Items:Clear()		
	for k,v in pairs(getProject()) do
		addElemToTreeView(v)
	end
	tvForm:EndUpdate()
end


---------------------------------------------------------------
local function deleteComponentTree(t,doremove)
	for k,v in pairs(t.items) do
		deleteComponentTree(v,doremove)
	end
	if doremove and t.vclObj and t.vclObj.virtual==nil then
		t.vclObj = t.vclObj:Free()
	end
end

-- remove element
function DeleteComponent()
	local elem = tvForm.Selected
	if elem then
		local ct,cp,cn = findElem(elem)
		if ct.obj.AbsoluteIndex==0 then
			VCL.ShowMessage("The root element can't be removed!")
			return
		end
		deleteComponentTree(ct,true)	
		cp.items[cn] = nil	
		tableToTreeView()
		if (cn>1) then
			setCurElem(cp.items[cn-1])
		else
			setCurElem(cp)
		end		
	end			
end

local function copyComponentTree(p,t)
	local n = #p.items + 1
	local ct = mkObjTable(p,t.class,p.vclObj)
	p.items[n] = ct	
	for k,v in pairs(t.items) do		
		copyComponentTree(ct,v)
	end
	return ct
end

-- duplicate element (parent, table of components)
function DuplicateComponent()
	local elem = tvForm.Selected
	if elem then
		local ct,cp,cn = findElem(elem)
		if ct.obj.AbsoluteIndex==0 then
			VCL.ShowMessage("The root element can't be duplicated!")
			return
		end		
		elem = copyComponentTree(cp,ct)
		tableToTreeView()
		setCurElem(elem)		
	end			
end

local function toClipboard(t)
	-- clean
	if type(ComponentClipBoard)=="table" and ComponentClipBoard.items then
		deleteComponentTree(ComponentClipBoard)
	end
	ComponentClipBoard = table.copy(t)
end

function CopyComponent()
	local elem = tvForm.Selected
	if elem then
		local ct,cp,cn = findElem(elem)
		if ct.obj.AbsoluteIndex==0 then
			VCL.ShowMessage("The root element can't be copied!")
			return
		end		
		-- ComponentClipBoard		
		toClipboard(ct)
	end			
end

function CutComponent()
	local elem = tvForm.Selected
	if elem then
		local ct,cp,cn = findElem(elem)
		if ct.obj.AbsoluteIndex==0 then
			VCL.ShowMessage("The root element can't be removed!")
			return
		end		
		-- ComponentClipBoard
		toClipboard(ct)
		cp.items[cn] = nil		
		tableToTreeView()
		if (cn>1) then
			setCurElem(cp.items[cn-1])
		else
			setCurElem(cp)
		end	
	end			
end

local function pasteComponentTree(p,t)
	-- exists?
	local e = findElemByName(t.name)
	local n = #p.items + 1	
	-- new object required
	local ne = nil
	if e then	
		local ne = mkObjTable(p,t.class,p.vclObj)
		ne.events= table.copy(t.events)
		ne.props = table.copy(t.props)
		ne.props["Name"] = ne.name		
		ne = ne or t
		for propPath,_ in pairs(ne.props) do
			if (propPath ~= "Name") then
				setProperty(ne.vclObj, propPath, t.vclObj[propPath])
			end
		end			
		p.items[n] = ne
		for k,v in pairs(t.items) do
			pasteComponentTree(ne,v)
		end
	else
		t.vclObj.parent = p.vclObj
		p.items[n] = t
	end	
	prjRefresh()
end

function PasteComponent()
	local elem = tvForm.Selected
	if elem then
		local ct,cp,cn = findElem(elem)			
		pasteComponentTree(ct,ComponentClipBoard)		
		tableToTreeView()
	end			
end

-- export/import json

function toJson()
	local getObject
	getObject = function(t,parent,o)
		table.insert(t,{class=o.class, name=o.vclObj.name, parent=parent, props=o.props})
		for _,c in pairs(o.items) do
			getObject(t,o.vclObj.name,c)
		end
		return t
	end
	local frm = {}
	local p = getProject() 
	for _,item in pairs(p.items) do
		if item.vclObj and item.vclObj.virtual==nil then
			getObject(frm,nil,item)
		end
	end
	return frm
end

function fromJson(frm)
	-- buildProject(frm)
	local p = {}
	for _,item in pairs(frm) do
		local parent = item.parent
		if type(parent) == "string" then
			parent = p[parent]
		end
		local t = addComponent(parent,item.class)
		t.name = item.name
		p[t.name] = t.obj
		for k,v in pairs(item.props) do
			local propPath = k
			local propValue = v
			if type(v)=='string' then
				propValue = v:match("%[(%w+)%]") or v
			end
			if (type(propValue)=="table") then
				t.vclObj[propPath]=propValue					
			else					
				t.props[propPath]=propValue
			end						
			if t.vclObj and propPath and propValue ~= nil then					
				setProperty(t.vclObj, propPath, propValue)
			end	
			-- set original name
			if propPath=='Name' then
				t.name = propValue
				t.obj.Text = propValue
			end
		end

		-- t.vclObj._ = item.props	
	end
	tableToTreeView()
end

-- component drag&drop events
compListTree.OnDragOver=function(Sender,Source, X, Y, State)
	if Sender.Selected~=nil then return true end
end
tvForm.OnDragOver=function(Sender,Source, X, Y, State)
	return true
end 
tvForm.OnDragDrop=function(Sender,Source,X,Y)
	local parent = tvForm:GetNodeAt(X,Y)
	if parent and Source.Selected then 
		if Source.Handle==compListTree.Handle then
			local compName = Source.Selected.Text
			if addComponent(parent, compName) then
				parent.Expanded=true
			end
			tableToTreeView()								
		else		
			local pt = findElem(parent)
			local ct = findElem(Source.Selected)			
			-- isTarget?
			if checkTarget(pt.class,ct.class) and checkFixedSource(ct.class)==nil then
				moveChild(Source.Selected,parent)
				tableToTreeView()			
			end			
		end
	end
end

compPropGrid.OnModified=function(Sender) 
-- Property Grid events
	local elem=getCurElem()
	local path = Sender:PropertyPath(Sender:GetActiveRow())
	local pp = path:split()
	local propName = pp[#pp]
	local propValue = getProperty(Sender.TIObject,table.concat(pp,"."))
	local prop = elem.props
	-- filter out sets
	if type(propValue)=="string" and propValue:find("%b[]") and propValue:find(propName) then
		table.remove(pp,#pp)
		propName = pp[#pp]
	end
	for i,p in pairs(pp) do
		if i<#pp then
			prop[p] = prop[p] or {}
			prop = prop[p]
		end
	end
	prop[propName] = propValue
end
-- Tree events
tvForm.OnClick=function(Sender)
	local elem = Sender.Selected
	if elem then	
		setCurElem(findElem(elem))
	end		
end
tvForm.OnEdited=function(Sender,Node,S)
	local elem = findElem(Node)	
	if string.len(S)>0 then
		S = S:gsub('%W','')	
		elem.vclObj.name = S
		elem.name = S
		elem.props['Name']="'"..S.."'"		
	else 
		S = elem.vclObj.name
	end		
	return S
end
tvForm.OnMouseDown=function(Sender,Button,ShiftState, X,Y)
	if Button=='mbRight' then
		elem = tvForm:GetNodeAt(X,Y)		
		if elem then				
			setCurElem(findElem(elem))			
		end	
	elseif Button=='mbLeft' and ShiftState:find('ssCtrl') then
		elem = tvForm:GetNodeAt(X,Y)		
		if elem then
			elem = findElem(elem)
			MoveComponent(elem.vclObj, function()
				elem.props['Left'] = elem.vclObj.left
				elem.props['Top'] = elem.vclObj.top
				setCurElem(elem)
			end)			
		end
	end
end
