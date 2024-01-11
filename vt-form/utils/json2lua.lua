-- ***************************************
-- Json form loader example
-- Copyright (C) 2013-2024 Hi-Project Ltd.
-- ***************************************
local VCL = require "vcl.core"
local json = require "json"

function jsonFormLoad(fileName) 
    assert(fileName,"missing filename parameter!")
	local file, errorString = io.open( fileName, mode or "r"  )
	assert(file,string.format("%s not found!", tostring(fileName)))
	local contents = file:read( "*a" )
	io.close( file )
	local frm = json.decode(contents)
	local print_prop
	local lua_out = {}
	print_prop = function(key,value,n)
		n = n or 1
		if type(value)=="table" then
			table.insert(lua_out,(string.format("%s%s = {",string.rep("\t",n),key)))
			for k,v in pairs(value) do
				print_prop(k,v, n+1)
			end
			table.insert(lua_out,(string.format("%s},",string.rep("\t",n),key)))
		elseif type(value)=="string" then
			table.insert(lua_out,(string.format("%s%s = '%s',",string.rep("\t",n),key,value)))
		else
			table.insert(lua_out,(string.format("%s%s = '%s',",string.rep("\t",n),key,value)))
		end
	end
	for n,c in pairs(frm) do
		if VCL[c.class]~=nil then
			table.insert(lua_out,(string.format("local %s = VCL.%s( %s, '%s', { ", c.name, c.class, tostring(c.parent), c.name)))
			for k,v in pairs(c.props) do
				if string.lower(k)~="name" then
					print_prop(k,v)
				end
			end
			table.insert(lua_out,("})"))
		end
	end
	return lua_out
end

local j2lua = jsonFormLoad(arg[1])
print(table.concat(j2lua,"\n"))
