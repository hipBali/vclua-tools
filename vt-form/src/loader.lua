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
   local pattern = string.format("([^.]+)", sep)
   s:gsub(pattern, function(c) fields[#fields+1] = c end)
   return fields
end

-- use getScriptPaths()..'filename.ext' to get a file near to current script file
function getScriptPaths()
  local src = debug.getinfo(2).source:gsub('^@','')
  return src:gsub('[^\\/]+$',''),src
end

-- try using _G for byName if your form has unique component names suitable for being Lua identificators
function jsonFormLoad(fileName,byName)
  local file, errorString = io.open(fileName)
  assert(file,"Can't open "..fileName..": "..(errorString or ""))
  local contents = file:read("*a")
  io.close(file)
  local frm = toNewFormat(json.decode(contents))
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
  return byPath[frm.name], byPath, byName
end

