-- ***************************************
-- VCLua Form tool
-- Copyright (C) 2013-2024 Hi-Project Ltd.
--
-- builder component tree manager
-- ***************************************

require "designer"
require "loader"

local compFixed={ Script=1, Form=1 }
local ComponentClipBoard = {}

-- returns: child table, orig parent table, index
function findElem(elem,t)
	t = t or getProject() 
	for k,v in ipairs(t.items) do
		if v.obj.AbsoluteIndex==elem.AbsoluteIndex then
			return v,t,k							
		end
		local r,p,n = findElem(elem,v)
		if r then return r,p,n end
	end	
	return nil
end

local function getUniqueName(items, compName, name)
	local n = 0
	local names = {}
	for _,item in ipairs(items or {}) do names[item.name] = true end
	if name and not names[name] then return name end
	while true do
		n = n + 1
		name = compName..n
		if not names[name] then return name end
	end
end

-- Property getter/setter
function getProperty(p, pPath)
	local propPath, lastComponent = {}, nil
	for s in string.gmatch(pPath, '([^%.]+)') do
		if type(p) == "table" and p.Handle and p:is('TComponent') then
			lastComponent = p
			propPath = {s}
		else
			table.insert(propPath,s)
		end
		p = p[s]
	end
	return p, lastComponent, propPath
end

-- can use getNamePath result as input
-- path can point to property of class type
local function findElemByPath(path)
	path = type(path) == "string" and path:split() or path
	local len = #path
	local function impl(depth,t)
		for _,v in ipairs(t.items) do
			if v.name == path[depth] then
				if depth == len then return v
				else return impl(depth + 1, v)
				end
			end
		end
		return nil, depth, t
	end
	local elem, depth, t = impl(1,getProject())
	if elem then return elem, elem.vclObj end
	local suf = {}
	for i = depth,len do table.insert(suf,path[i]) end
	return t, (getProperty(t.props, table.concat(suf,".")))
end

local function setName(elem,name,fixObj)
	elem.name = name
	elem.vclObj.Name = name
	if fixObj then elem.obj.Text = name end
	if elem.vclObj.Caption == name then elem.props.Caption = nil end -- prevent errors later when name is changed
end

local function mkObjTable(p,compName,name)

	local o = VCL[compName](p and p.vclObj,'')
	local s = getUniqueName(p and p.items, compName, name)
	local c = tvForm.Items:Add(p and p.obj,s)
	c.StateIndex = cmpImg[compName].ii

	local t = {
		obj=c,
		vclObj=o,		
		class=compName,
		items={},
		events={},
		props={},
		collections={},
	}				
	setName(t,s) -- some components might not accept name in creator function, so set it here
	if p then
		o.OnMouseDown=function(o,Button,ShiftState, X,Y)
			if Button=='mbLeft' and ShiftState:find('ssCtrl') then MoveComponent(o,t) end
		end
	end
	return t
end	

local function checkFixedSource(sName)
	return compFixed[sName]
end

function addComponent(parent, compName, name)
	if parent==nil then
		local t = mkObjTable(nil,compName,name)
		if t.vclObj.virtual then
		else
			-- t.vclObj:Hide()
			-- t.vclObj.left = 100
			-- t.vclObj.top = 100
		end
		table.insert(getProject().items, t)
		return t
	else	
		local pt = findElem(parent)
		local t = mkObjTable(pt,compName,name)
		table.insert(pt.items, t)
		return t
	end
end

local function moveChild(child,parent)
	local ct,cp,cn = findElem(child) -- child table, orig parent table, index
	local pt = findElem(parent)	-- new parent table
	local res, err = pcall(function() ct.vclObj.Parent = pt.vclObj end)
	if not res then
		print(err)
		return
	end
	table.remove(cp.items, cn)
	local name = getUniqueName(pt.items, ct.class, ct.name)
	table.insert(pt.items, ct)
	local path = getNamePath(pt.vclObj)..'.'..name
	prjRefresh()
	setCurElem(findElemByPath(path))
end

local function addElemToTreeView(t,p)
	for _,v in ipairs(t) do
		local c
		if not p then
			c = tvForm.Items:Add(p,v.name)
		else
			c = tvForm.Items:AddChild(p,v.name)
		end
		c.StateIndex = cmpImg[v.class].ii
		v.obj = c
		addElemToTreeView(v.items,c)
	end
end

function tableToTreeView(toSelect)
	tvForm:BeginUpdate()
	tvForm.Items:Clear()		
	for k,v in pairs(getProject()) do
		addElemToTreeView(v)
	end
	setCurElem(toSelect)
	tvForm:SetFocus()
	tvForm:EndUpdate()
end


---------------------------------------------------------------
local function deleteComponentTree(t)
	for _,v in ipairs(t.items) do
		deleteComponentTree(v)
	end
	if t.vclObj and t.vclObj.virtual==nil then
		t.vclObj = t.vclObj:Free()
	end
end

-- remove element
function DeleteComponent(callback) -- or Sender
	local elem = tvForm.Selected
	if elem then
		local ct,cp,cn = findElem(elem)
		if ct.obj.AbsoluteIndex==0 then
			VCL.ShowMessage("The root element can't be removed!")
			return
		end
		if type(callback) == 'function' then callback(ct) end
		deleteComponentTree(ct)
		table.remove(cp.items, cn)
		tableToTreeView(cn>1 and cp.items[cn-1] or cp)
	end
end

local function copyComponentTree(p,t,name)
	local ct = mkObjTable(p,t.class,name)
	table.insert(p.items, ct)
	for _,v in ipairs(t.items) do
		copyComponentTree(ct,v,v.name)
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
		tableToTreeView(copyComponentTree(cp,ct))
	end			
end

local function applyCollectionsOrder(srcItem, dstProps)
	-- apply ID->order for collections
	if next(srcItem.collections) then
		for name,order in pairs(srcItem.collections) do
			local t,items = {},#order
			for i = 1,items do t[i] = srcItem.props[name][order[i]] end
			dstProps[name] = t
		end
	end
end

local function getPaths(vclo)
	local rootPathTable = getNamePathTable(vclo)
	local rootPath = table.concat(rootPathTable,'.')
	table.remove(rootPathTable)
	if rootPathTable[1] then
		return rootPath, table.concat(rootPathTable,'.')
	else
		-- processing top form
		return "(none)","(none)"
	end
end

function toJson(root)
	local rootPath, rootParentPath = getPaths(root.vclObj)
	local rpPos = #rootPath+1
	local rppPos = #rootParentPath+1
	local function vcloToRelativePath(vclo)
		if type(vclo) == "table" then
			-- erase empty tables which arise when incorrect values are set or when previous changes are undone
			if next(vclo) == nil then return true, nil
			elseif vclo.Handle then
				local path = getNamePath(vclo)
				if path:find(rootPath,1,true) == 1 then return true, '<root>'..path:sub(rpPos)..'.vt-form'
				elseif path:find(rootParentPath,1,true) == 1 then return true, '<rootparent>'..path:sub(rppPos)..'.vt-form'
				else return true, path..'.vt-form'
				end
			end
		else return false
		end
	end
	local function getObject(o)
		local props = table.copy(o.props, vcloToRelativePath)
		applyCollectionsOrder(o, props)
		local function copyItem(v)
			if type(v) == 'table' and v.class then return true, getObject(v) end
		end
		return {class=o.class, name=o.vclObj.name, props=props, items=table.copy(o.items, copyItem)}
	end
	local res = getObject(root)
	return res
end

local function toClipboard(t)
	ComponentClipBoard = toJson(t)
end

function CopyComponent()
	local elem = tvForm.Selected
	if elem then
		local ct,cp,cn = findElem(elem)
		if ct.obj.AbsoluteIndex==0 then
			VCL.ShowMessage("The root element can't be copied!")
			return
		end		
		toClipboard(ct)
	end			
end

function CutComponent()
	DeleteComponent(toClipboard)
end

function fromJson(src,t)
	-- t is table with vclObj==new parent of root(s) of src
	-- props can contain references to objects which are later in JSON
	-- so first create objects w/o props, then set properties
	local function addTree(src,p)
		local t = addComponent(p.obj,src.class,src.name)
		if t then for _,c in ipairs(src.items) do addTree(c,t) end end
		return t
	end
	src = toNewFormat(src)
	-- src.name will not apply if there is a sibling name clash
	local res = addTree(src, t)
	if not res then return nil end
	local rootPath, rootParentPath = getPaths(res.vclObj)
	local function relPathToObject(v)
		if type(v) == "string" then
			local words = v:split()
			if table.remove(words) == 'vt-form' then
				local path = table.concat(words,'.'):gsub('<rootparent>',rootParentPath,1):gsub('<root>',rootPath,1)
				local elem, vclo = findElemByPath(path)
				--print('replaced '..table.concat(words,'.')..' with '..path..' = '..getNamePath(vclo))
				return true, vclo
			end
		end
	end
	local function setProps(src,t)
		-- for relPathToObject to work component names must already be applied, meaning there should be no 'Name' in src.props
		t.props = table.copy(src.props, relPathToObject) or {}
		if next(t.props) then t.vclObj._ = t.props end
		for i,c in ipairs(t.items) do setProps(src.items[i],c) end
	end
	setProps(src,res)
	return res
end

function PasteComponent()
	local elem = tvForm.Selected
	if elem and next(ComponentClipBoard) then
		tableToTreeView(fromJson(ComponentClipBoard,findElem(elem)))
	end			
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
	if parent and Source.Selected and parent.Handle ~= Source.Selected.Handle then
		if Source.Handle==compListTree.Handle then
			local t = addComponent(parent, Source.Selected.Text)
			if t then
				parent.Expanded=true
				tableToTreeView(t)
			end
		else		
			local pt = findElem(parent)
			local ct = findElem(Source.Selected)			
			if checkFixedSource(ct.class)==nil then
				moveChild(Source.Selected,parent)
			end			
		end
	end
end

local function getPropFromRow()
	local Sender = compPropGrid
	local row = Sender:GetActiveRow()
	local path = Sender:PropertyPath2(row)

	local pp = path:split()
	-- fix path for sets
	if row.Editor:is('TSetElementPropertyEditor') then table.remove(pp) end
	local propValue, lastComponent, propPath = getProperty(Sender.TIObject,table.concat(pp,'.'))
	-- check if we are editing property indirectly, e.g. for AnchorSide.Control
	local elem=getCurElem()
	local vclo
	if lastComponent and (lastComponent.Handle ~= Sender.TIObject.Handle) then
		elem, vclo = findElemByPath(getNamePathTable(lastComponent))
		pp = propPath
	end
	local propName = table.remove(pp)
	-- fix path for collection item properties
	local collectionField = Sender.TIObject:GetNamePath():match('.+%.([_%w]+)%[[^[%]]+%]$')
	if collectionField then
		elem, vclo = findElemByPath(getNamePathTable(Sender.TIObject.Collection:Owner()))
		table.insert(pp,1,collectionField)
		table.insert(pp,2,Sender.TIObject.ID+1)
	end
	--print(path,table.concat(pp,'.'), propName, propValue)
	local prop = elem.props
	for _,p in ipairs(pp) do
		prop[p] = prop[p] or {}
		prop = prop[p]
	end
	return prop, propName, propValue, elem, pp
end

compPropGrid.OnMouseDown = function(Sender,Button,Shift,X,Y)
	if Button == 'mbRight' then
		local index = Sender:MouseToIndex(Y, true)
		Sender:SetItemIndexAndFocus(index,true)
	end
end

function DeletePropAndReload()
	local row = compPropGrid:GetActiveRow()
	if row then
		local prop, propName, _, elem = getPropFromRow()
		if prop[propName] then -- Name never is in prop, so no check
			prop[propName] = nil
			local path = getNamePath(elem.vclObj)
			prjRefresh()
			setCurElem(findElemByPath(path))
		end
	end
end

local function CollectionItemClick(Sender)
  local i = Sender.ItemIndex
  if i>-1 and i<Sender.Count then
    compPropGrid.TIObject = Sender.Parent.Collection:Items(i)
    Sender.Parent:CollectionListBoxClick(nil)
  end
end
local function CollectionEditorClose(Sender)
  compPropGrid.TIObject = compPropGrid.oldTIObject
  return 'caHide'
end
local function GetOnCollectionModified(cb,fm,s)
  return function(Sender)
    if s == 'del' then compPropGrid.TIObject = nil end
    cb(fm,Sender)
    if s == 'del' then fm.CollectionListBox:Click() end
    local coll = fm.Collection
    local path = getNamePath(fm.OwnerPersistent)
    local elem = findElemByPath(path)
    local coll_desc = elem.collections[fm.PropertyName] or {}
    for i = 1,coll.Count do
       -- IDs are 0-based, so +1
      coll_desc[i] = coll:Items(i-1).ID+1
    end
    elem.collections[fm.PropertyName] = coll_desc
  end
end
local collectionFormInited = false

compPropGrid.OnEditorFilter=function(Sender,editor,show)
  --print(editor.ClassName, editor:GetPropertyPath())
  if editor:is('TCollectionPropertyEditor') then
    compPropGrid.oldTIObject = compPropGrid.TIObject
    -- this form is a singleton, so maybe TODO: add cb for OnShow to set oldTIObject
    if not collectionFormInited then
      local fm = editor:ShowCollectionEditor(nil, nil, '')
      compPropGrid.collectionForm = fm
      fm.CollectionListBox.OnClick = CollectionItemClick
      fm.OnClose = CollectionEditorClose
      fm.actAdd.OnExecute=GetOnCollectionModified(fm.actAddExecute,fm,'add')
      fm.actDel.OnExecute=GetOnCollectionModified(fm.actDelExecute,fm,'del')
      fm.actMoveDown.OnExecute=GetOnCollectionModified(fm.actMoveUpDownExecute,fm,'down')
      fm.actMoveUp.OnExecute=GetOnCollectionModified(fm.actMoveUpDownExecute,fm,'up')
      fm:Hide()
      collectionFormInited = true
    end
  end
end

compPropGrid.OnModified=function(Sender) 
	local prop, propName, propValue, elem, pp = getPropFromRow()
	if propName == 'Name' and elem.vclObj:is('TComponent') and not next(pp) then
		setName(elem,propValue,true)
		return
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
		setName(elem,S)
	else 
		S = elem.vclObj.name
	end		
	return S
end

tvForm.OnMouseDown=function(Sender,Button,ShiftState, X,Y)
	if Button=='mbRight' then
		local elem = tvForm:GetNodeAt(X,Y)
		if elem then				
			setCurElem(findElem(elem))			
		end	
	elseif Button=='mbLeft' and ShiftState:find('ssCtrl') then
		local elem = tvForm:GetNodeAt(X,Y)
		if elem then
			elem = findElem(elem)
			MoveComponent(elem.vclObj,elem)
		end
	end
end
