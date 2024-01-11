-- ***************************************
-- VCLua Form tool
-- Copyright (C) 2013-2023 Hi-Project Ltd.
--
-- common funcs
-- ***************************************

function pairsByKeys (t, f)
      local a = {}
      for n in pairs(t) do table.insert(a, n) end
      table.sort(a, f)
      local i = 0      -- iterator variable
      local iter = function ()   -- iterator function
        i = i + 1
        if a[i] == nil then return nil
        else return a[i], t[a[i]]
        end
      end
      return iter
end

local function deepCopy(orig)
    local orig_type = type(orig)
    local copy
    if orig_type == 'table' then
        copy = {}
        for orig_key, orig_value in next, orig, nil do
            copy[deepCopy(orig_key)] = deepCopy(orig_value)
        end
        setmetatable(copy, deepCopy(getmetatable(orig)))
    else -- number, string, boolean, etc
        copy = orig
    end
    return copy
end

table.copy = function (t) return deepCopy(t) end

function SplitFileName(f)
	return string.match(f,"(.-)([^\\/]-%.?([^%.\\/]*))$")
end

function ExtractFileName(fileName)
	local p,n,e = SplitFileName(fileName)
	return n
end

function ExtractFileName(fileName)
	local p,n,e = SplitFileName(fileName)
	return n
end

function ExtractFilePath(fileName)
	local p,n,e = SplitFileName(fileName)
	return p
end

function ChangeFileExt(fileName, newExt)
	local p,n,e = SplitFileName(fileName)
	n = string.sub(n,1,string.len(n)-string.len(e)-1)..(newExt or "")
	return p..n
end

-- VCLUA required
function saveStringsToFile(strList, fileName)
  local f = io.open(fileName, "w+b")
  if f==nil then return false end
  for i=0,strList.Count-1 do	
    f:write(strList:Get(i).."\n")
  end
  f:flush()
  io.close(f)
  return true
end

function saveTextToFile(txt, fileName)
  local f = io.open(fileName, "w+b")
  if f==nil then return false end
  f:write(txt)
  f:flush()
  io.close(f)
  return true
end

function openDialog(parent,title,initialdir,filter,options)
	local fod = VCL.OpenDialog(parent)
	fod._ = { title=title,initialdir=initialdir,filter=filter,options=options}
	local fileName 
	if fod:Execute() then
		fileName = fod.fileName
	end
	fod:Free()
	return fileName
end

function saveDialog(parent,title,filename,initialdir,filter,options,replaceDialog)
	local sad = VCL.SaveDialog(frmMain)
	sad._ = { title=title,filename=filename,initialdir=initialdir,filter=filter,options=options}
	local fileName
	if sad:Execute() then
		fileName = sad.fileName
	end
	sad:Free()
	if fileName == nil then
		return nil
	else
		if replaceDialog then
			if io.open(fileName or "","r")~=nil then
				if VCL.MessageDlg("File exists on disk. Do you want to replace it?\n\n"..fileName,"mtConfirmation",{"mbYes","mbNo"})=="mrNo" then
					return nil
				end
				os.remove(fileName)
			end
		end
		return fileName
	end
end

function selectDirectoryDialog(parent,title,filename,initialdir,filter,options,replaceDialog)
	local sad = VCL.SelectDirectoryDialog(frmMain)
	sad._ = { title=title,filename=filename,initialdir=initialdir,filter=filter,options=options}
	local fileName
	if sad:Execute() then
		fileName = sad.fileName
	end
	sad:Free()
	return fileName
end

---------------------------------------------------------------------------
-- Lua 5.1+ base64 v3.0 (c) 2009 by Alex Kloss <alexthkloss@web.de>
-- licensed under the terms of the LGPL2
-- character table string
local b='ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/'
-- encoding
function b64enc(data)
    return ((data:gsub('.', function(x) 
        local r,b='',x:byte()
        for i=8,1,-1 do r=r..(b%2^i-b%2^(i-1)>0 and '1' or '0') end
        return r;
    end)..'0000'):gsub('%d%d%d?%d?%d?%d?', function(x)
        if (#x < 6) then return '' end
        local c=0
        for i=1,6 do c=c+(x:sub(i,i)=='1' and 2^(6-i) or 0) end
        return b:sub(c+1,c+1)
    end)..({ '', '==', '=' })[#data%3+1])
end
-- decoding
function b64dec(data)
    data = string.gsub(data, '[^'..b..'=]', '')
    return (data:gsub('.', function(x)
        if (x == '=') then return '' end
        local r,f='',(b:find(x)-1)
        for i=6,1,-1 do r=r..(f%2^i-f%2^(i-1)>0 and '1' or '0') end
        return r;
    end):gsub('%d%d%d?%d?%d?%d?%d?%d?', function(x)
        if (#x ~= 8) then return '' end
        local c=0
        for i=1,8 do c=c+(x:sub(i,i)=='1' and 2^(8-i) or 0) end
        return string.char(c)
    end))
end
---------------------------------------------------------------------------
