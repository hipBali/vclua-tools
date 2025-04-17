-- ***************************************
-- Json form to lua script converter
-- Copyright (C) 2013-2025 Hi-Project Ltd.
-- ***************************************
local VCL = require "vcl.core"

require "loader"

local function split(s)
  local fields = {}
  s:gsub("([^.]+)", function(c) fields[#fields+1] = c end)
  return fields
end

function json2lua(fileName, unique)
  assert(fileName,"missing filename parameter!")
  local frm = fileToJson(fileName)
  local function has_duplicate_names(c, names)
    names = names or {}
    if names[c.name] then
      return true
    end
    names[c.name] = true
    for _,c in ipairs(c.items) do
      if has_duplicate_names(c, names) then return true end
    end
    return false
  end
  unique = unique == nil and not has_duplicate_names(frm) or (unique == "true")
  local print_prop
  local lua_out = {"by_name = {}"}
  print_prop = function(key,value,n)
    n = n or 1
    key = type(key) == "number" and math.type(key) == "integer" and "" or string.format("%s = ", key)
    if type(value)=="table" then
      table.insert(lua_out,(string.format("%s%s{",string.rep("\t",n),key)))
      for k,v in pairs(value) do
        print_prop(k,v, n+1)
      end
      table.insert(lua_out,(string.format("%s},",string.rep("\t",n),key)))
    elseif type(value)=="string" then
      local words = split(value)
      if table.remove(words) == 'vt-form' then
        value = unique and table.remove(words) or table.concat(words, "_")
      else
        value = "'"..value.."'"
      end
      table.insert(lua_out,(string.format("%s%s%s,",string.rep("\t",n),key,value)))
    else
      table.insert(lua_out,(string.format("%s%s%s,",string.rep("\t",n),key,tostring(value))))
    end
  end

  local function add_tree(c,path)
    local p = path
    path = unique and c.name or (path and path.."_" or "")..c.name
    table.insert(lua_out, string.format('%s = VCL.%s(%s, "%s")', path, c.class, p, c.name))
    table.insert(lua_out, string.format('by_name.%s = %s', path, path))
    for _,c in ipairs(c.items) do add_tree(c,path) end
  end

  local function set_props(c,path)
    path = unique and c.name or (path and path.."_" or "")..c.name
    if c.props and next(c.props) then
      table.insert(lua_out, string.format("%s._ = {", path))
      for k,v in pairs(c.props) do
        print_prop(k,v)
      end
      table.insert(lua_out,"}")
    end
    for _,c in ipairs(c.items) do set_props(c,path) end
  end

  add_tree(frm)
  set_props(frm)

  return lua_out
end

local j2lua = json2lua(arg[1], arg[2])
print(table.concat(j2lua,"\n"))
