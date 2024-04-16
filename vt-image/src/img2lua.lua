-- ***************************************
-- Image to lua converter
-- Copyright (C) 2013-2024 Hi-Project Ltd.
-- ***************************************
VCL = require "vcl.core"
require "loader"

local mainForm, _, jForm = jsonFormLoad("img2lua.json")
local imgList = jForm.clFiles

-- Converter
local img2lua = function(fName)
	local img = VCL.Image()
	img.picture:LoadFromFile(fName)
	local str = VCL.MemoryStream()
	img.picture:SaveToStream(str)
	local hexData = "" -- 36040000"
	str.Position = 0
	while str.Position < str.Size do
		hexData = hexData .. string.format('%02X', str:ReadByte())
	end
	--str:LoadFromHex(hexData) -- for testing
	--jForm.imgView.Picture:LoadFromStream(str)
	str:Free()
	img:Free()
	return hexData
end

-- Events
mainForm.ondropfiles = function(sender,f)
	imgList.Items:Clear()
	if type(f)=="table" then
		for k,v in pairs(f) do
			local n = imgList.Items:Add(v)
			imgList:Checked(n,true)
		end
	elseif type(f)=="string" then
		local n = imgList.Items:Add(v)
		imgList:Checked(n,true)
	end
end
jForm.btAdd.onClick = function() 
	local fod = VCL.OpenDialog()
	fod._ = { title="Select an image" , filter="Images files|*.bmp;*.jpg;*.png", options="[ofFileMustExist]"}
	local fileName 
	if fod:Execute() then
		n = imgList.Items:Add(fod.fileName)
		imgList:Checked(n,true)
	end
	fod:Free()
end
jForm.btClear.onClick = function() imgList.Items:Clear() end
jForm.clFiles.OnClick = function(s)
	local items = imgList.Items:ToStringArray2()
	local img = jForm.imgView
	if imgList.ItemIndex ~= -1 then
		-- lua table index +1
		img.Picture:LoadFromFile(items[imgList.ItemIndex+1])
		jForm.lbInfo.Caption = string.format("Width: %d Height: %d", img.Picture.Width, img.Picture.Height)
	end
end
jForm.btConvert.onClick = function() 
	local cImages = {}
	local items = imgList.Items:ToStringArray2()
	-- Convert checked files
	for n,item in pairs(items) do
		if imgList:Checked(n-1) then
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
			f:write(string.format('\t{filename=%q, hexdata=[[%s]] },\n', img.filename, img.hexdata))
		end
		f:write("}\nreturn images\n")
		f:flush()
		io.close(f)
	end

end

-- Run
VCL.TheApplication():Initialize()
mainForm:ShowModal()