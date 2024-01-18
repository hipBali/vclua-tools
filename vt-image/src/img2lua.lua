-- ***************************************
-- Image to lua converter
-- Copyright (C) 2013-2024 Hi-Project Ltd.
-- ***************************************
local VCL = require "vcl.core"
local json = require "json"

-- Loader
function jsonFormLoad(fileName) 
	local file, errorString = io.open( fileName, mode or "r"  )
	assert(file,string.format("%s not found!", tostring(fileName)))
	local contents = file:read( "*a" )
	io.close( file )
	local frm = json.decode(contents)
	local comp = {}
	for n,c in pairs(frm) do
		if VCL[c.class]~=nil then
			comp[c.name] = VCL[c.class](comp[c.parent],c.name,c.props)
		end
	end
	return comp
end

-- Converter
local img2lua = function(fName)
	local img = VCL.Image()
	img.picture:LoadFromFile(fName)
	local str = VCL.Stream()
	img.picture:SaveToStream(str)
	local hexData = "" -- 36040000"
	str.position = 0
	while str.position < str.size do
		hexData = hexData .. string.format('%02X', str:ReadByte())
	end
	str:Free()
	img:Free()
	return hexData
end


local jForm = jsonFormLoad("img2lua.json")
local mainForm = jForm["img2lua_form"]
local imgList = jForm.clFiles

-- Events
mainForm.ondropfiles = function(sender,f)
	imgList.Items:Clear()
	if type(f)=="table" then
		for k,v in pairs(f) do
			local n = imgList.Items:Add(v)
			imgList:SetChecked(n,true)
		end
	elseif type(f)=="string" then
		local n = imgList.Items:Add(v)
		imgList:SetChecked(n,true)
	end
end
jForm.btAdd.onClick = function() 
	local fod = VCL.OpenDialog()
	fod._ = { title="Select an image" , filter="Images files|*.bmp;*.jpg;*.png", options="[ofFileMustExist]"}
	local fileName 
	if fod:Execute() then
		n = imgList.Items:Add(fod.fileName)
		imgList:SetChecked(n,true)
	end
	fod:Free()
end
jForm.btClear.onClick = function() imgList.Items:Clear() end
jForm.clFiles.OnClick = function(s)
	local items = imgList.Items:ToTable()
	local img = jForm.imgView
	if imgList.ItemIndex ~= -1 then
		-- lua table index +1
		img.Picture:LoadFromFile(items[imgList.ItemIndex+1])
		jForm.lbInfo.Caption = string.format("Width: %d Height: %d", img.Width, img.Height)
	end
end
jForm.btConvert.onClick = function() 
	local cImages = {}
	local items = imgList.Items:ToTable()
	-- Convert checked files
	for n,item in pairs(items) do
		if imgList:GetChecked(n-1) then
			table.insert (cImages, { filename = item, hexdata = img2lua(items[n]) })
		end
	end 
	-- save output with savedialog
	local sad = VCL.SaveDialog(frmMain)
	sad._ = { title="Select output file",filter="Lua files|*.lua",initialdir="./",options="[ofViewDetail]"}
	local fileName
	if sad:Execute() then
		fileName = sad.fileName
	end
	sad:Free()
	if fileName ~= nil then
		if io.open(fileName or "","r")~=nil then
			if VCL.MessageDlg("File exists on disk. Do you want to replace it?\n\n"..fileName,"mtConfirmation",{"mbYes","mbNo"})=="mrNo" then
				return nil
			end
			os.remove(fileName)
		end
		local f = io.open(fileName, "w")
		if f==nil then return false end
		f:write("local images={\n")					
		for _,img in pairs(cImages) do
			f:write(string.format('\t{filename="%s", hexdata=[[%s]] },\n', img.filename, img.hexdata))		
		end
		f:write("}\nreturn images\n")
		f:flush()
		io.close(f)
	end

end

-- Run
VCL.Application():Initialize()
mainForm:ShowModal()