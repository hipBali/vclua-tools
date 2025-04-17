local deepCopy = require "copy"
local json = require "json"

function toNewFormat(src)
  if src[1] then
    -- support old JSONs
    local elems = {}
    for i,elem in ipairs(src) do
      elem.items = {}
      elems[elem.name] = elem
      if i ~= 1 then table.insert(elems[elem.parent].items,elem) end
    end
    src = src[1]
  end
  return src
end

function fileToJson(fileName)
  local file, errorString = io.open(fileName)
  assert(file,"Can't open "..fileName..": "..(errorString or ""))
  local contents = file:read("*a")
  io.close(file)
  return toNewFormat(json.decode(contents))
end

function jsonToFile(frm, fileName, encoder)
  local file, errorString = io.open(fileName, "w")
  assert(file,"Can't save to "..fileName..": "..(errorString or ""))
  file:write((encoder or json.encode)(frm))
  io.close(file)
end

function getNamePathTable(vclo)
  local t = {n=0}
  local function impl(vclo)
    local p = vclo.Parent
    if p then impl(p) end
    t.n = t.n + 1
    t[t.n] = vclo.Name
  end
  impl(vclo)
  return t
end

function getNamePath(vclo)
  return table.concat(getNamePathTable(vclo),'.')
end

function isVclo(vclo)
  return type(vclo) == 'table' and type(vclo.Handle) == 'userdata'
end

local function split(s)
   local fields = {}
   s:gsub("([^.]+)", function(c) fields[#fields+1] = c end)
   return fields
end

-- use getScriptPaths()..'filename.ext' to get a file near to current script file
function getScriptPaths()
  local src = debug.getinfo(2).source:gsub('^@','')
  return src:gsub('[^\\/]+$',''),src
end

-- try using _G for byName if your form has unique component names suitable for being Lua identificators
function jsonFormLoad(fileName,byName)
  local frm = fileToJson(fileName)
  local byPath = {}
  byName = byName or {}
  local function addTree(c,p,path)
    path = (path and path.."." or "")..c.name
    local comp = VCL[c.class](p,c.name)
    if not comp then error("Can't load "..path) end
    byPath[path] = comp
    local t = byName[c.name]
    if not t then byName[c.name] = comp
    elseif t.Handle then byName[c.name] = {{getNamePath(t),t},{path,comp}}
    else table.insert(byName[c.name],{path,comp})
    end
    for _,c in ipairs(c.items) do addTree(c,comp,path) end
  end
  local function relPathToObject(v)
    if type(v) == "string" then
      local words = split(v)
      if table.remove(words) == 'vt-form' then
        return true, byPath[table.concat(words,".")]
      end
    end
  end
  local function setProps(src,path)
    path = (path and path.."." or "")..src.name
    local props = deepCopy(src.props, relPathToObject) or {}
    if next(props) then byPath[path]._ = props end
    for _,c in ipairs(src.items) do setProps(c,path) end
  end
  addTree(frm)
  setProps(frm)
  return byPath[frm.name], byPath, byName, frm
end

function jsonUpdateWithForm(frm,topForm)
  local function updTree(vclo,tree)
    if not isVclo(vclo) then error('No component '..(tree and tree.name or 'nil')) end
    if not tree then error('Component '..vclo.Name..' not in json') end
    if vclo.Caption and vclo.Name ~= vclo.Caption then
      tree.props = tree.props or {}
      tree.props.Caption = vclo.Caption
    end
    local updateProp
    local function updateProps(vclo,props)
      for p,pv in pairs(props or {}) do
        updateProp(vclo,props,p,pv)
      end
    end
    updateProp = function(vclo,props,p,pv)
      if type(pv) ~= "table" then
        local newpv = vclo[p]
        if isVclo(newpv) then newpv = getNamePath(newpv)..'.vt-form' end -- objects are stored as paths in json
        if newpv ~= pv then
          props[p] = newpv
        end
      else
        local subobject = vclo[p]
        if subobject then
          if pv[1] then
            -- subobject should be TCollection
            local l, count = #pv, subobject.Count
            for i = l+1, count do pv[i] = deepCopy(pv[l]) end -- assume new collection item wants the same props saved as the last item
            for i = count+1, l do pv[i] = nil end
            -- now that #pv became subobject.Count
            for i = 1,count do updateProps(subobject:Items(i-1),pv[i]) end
          else
            updateProps(subobject,pv)
          end
        else
          props[p] = nil
        end
      end
    end
    updateProps(vclo, tree.props)
    for _,item in ipairs(tree.items) do
      updTree(vclo:FindComponent(item.name),item)
    end
  end
  updTree(topForm,frm)
  frm.props = frm.props or {}
  frm.props.Top = topForm.Top
  frm.props.Left = topForm.Left
  frm.props.Height = topForm.Height
  frm.props.Width = topForm.Width
  frm.props.Position = nil
  return frm
end

