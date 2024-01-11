-- **************************************************
-- LAR.LUA
-- require function with archive reading capabilities
-- (c) 2009-2023 hipbali
-- **************************************************
--
-- extends original require function with search in an archive content 
--
-- supports: gzipped tar and pkzipped files
--
-- based on: https://github.com/zerkman/zzlib  (WTFPL licensed) :D
--

local LUA_DIRSEP = '/'
local LUA_PATH_MARK = '?'
local LUA_MODULE_EXT = '.lua'
local luar_tar_filetypes = {"tgz","tar.gz","largz"}
local luar_zip_filetypes = {"zip","lar"}

-- local ffi = require "ffi"
local bit = require "bit"
local inflate_band = bit.band
local inflate_rshift = bit.rshift 

local function trim(s)
  return s:match'^%s*(.*%S)' or ''
end

-- **************************************************
--
-- ZZLIB
--
-- **************************************************
local unpack = table.unpack or unpack
local loadstring = loadstring or load

local function inflate_bitstream_init(file)
  local bs = {
    file = file,  -- the open file handle
    buf = nil,    -- character buffer
    len = nil,    -- length of character buffer
    pos = 1,      -- position in char buffer, next to be read
    b = 0,        -- bit buffer
    n = 0,        -- number of bits in buffer
  }
  -- get rid of n first bits
  function bs:flushb(n)
    self.n = self.n - n
    self.b = bit.rshift(self.b,n)
  end
  -- returns the next byte from the stream, excluding any half-read bytes
  function bs:next_byte()
    if self.pos > self.len then
      self.buf = self.file:read(4096)
      self.len = self.buf:len()
      self.pos = 1
    end
    local pos = self.pos
    self.pos = pos + 1
    return self.buf:byte(pos)
  end
  -- peek a number of n bits from stream
  function bs:peekb(n)
    while self.n < n do
      self.b = self.b + bit.lshift(self:next_byte(),self.n)
      self.n = self.n + 8
    end
    return bit.band(self.b,bit.lshift(1,n)-1)
  end
  -- get a number of n bits from stream
  function bs:getb(n)
    local ret = bs:peekb(n)
    self.n = self.n - n
    self.b = bit.rshift(self.b,n)
    return ret
  end
  -- get next variable-size of maximum size=n element from stream, according to Huffman table
  function bs:getv(hufftable,n)
    local e = hufftable[bs:peekb(n)]
    local len = bit.band(e,15)
    local ret = bit.rshift(e,4)
    self.n = self.n - len
    self.b = bit.rshift(self.b,len)
    return ret
  end
  function bs:close()
    if self.file then
      self.file:close()
    end
  end
  if type(file) == "string" then
    bs.file = nil
    bs.buf = file
  else
    bs.buf = file:read(4096)
  end
  bs.len = bs.buf:len()
  return bs
end

local function hufftable_create(depths)
  local nvalues = #depths
  local nbits = 1
  local bl_count = {}
  local next_code = {}
  for i=1,nvalues do
    local d = depths[i]
    if d > nbits then
      nbits = d
    end
    bl_count[d] = (bl_count[d] or 0) + 1
  end
  local table = {}
  local code = 0
  bl_count[0] = 0
  for i=1,nbits do
    code = (code + (bl_count[i-1] or 0)) * 2
    next_code[i] = code
  end
  for i=1,nvalues do
    local len = depths[i] or 0
    if len > 0 then
      local e = (i-1)*16 + len
      local code = next_code[len]
      local rcode = 0
      for j=1,len do
        rcode = rcode + bit.lshift(bit.band(1,bit.rshift(code,j-1)),len-j)
      end
      for j=0,2^nbits-1,2^len do
        table[j+rcode] = e
      end
      next_code[len] = next_code[len] + 1
    end
  end
  return table,nbits
end

local function block_loop(out,bs,nlit,ndist,littable,disttable)
  local lit
  repeat
    lit = bs:getv(littable,nlit)
    if lit < 256 then
      table.insert(out,lit)
    elseif lit > 256 then
      local nbits = 0
      local size = 3
      local dist = 1
      if lit < 265 then
        size = size + lit - 257
      elseif lit < 285 then
        nbits = bit.rshift(lit-261,2)
        size = size + bit.lshift(bit.band(lit-261,3)+4,nbits)
      else
        size = 258
      end
      if nbits > 0 then
        size = size + bs:getb(nbits)
      end
      local v = bs:getv(disttable,ndist)
      if v < 4 then
        dist = dist + v
      else
        nbits = bit.rshift(v-2,1)
        dist = dist + bit.lshift(bit.band(v,1)+2,nbits)
        dist = dist + bs:getb(nbits)
      end
      local p = #out-dist+1
      while size > 0 do
        table.insert(out,out[p])
        p = p + 1
        size = size - 1
      end
    end
  until lit == 256
end

local function block_dynamic(out,bs)
  local order = { 17, 18, 19, 1, 9, 8, 10, 7, 11, 6, 12, 5, 13, 4, 14, 3, 15, 2, 16 }
  local hlit = 257 + bs:getb(5)
  local hdist = 1 + bs:getb(5)
  local hclen = 4 + bs:getb(4)
  local depths = {}
  for i=1,hclen do
    local v = bs:getb(3)
    depths[order[i]] = v
  end
  for i=hclen+1,19 do
    depths[order[i]] = 0
  end
  local lengthtable,nlen = hufftable_create(depths)
  local i=1
  while i<=hlit+hdist do
    local v = bs:getv(lengthtable,nlen)
    if v < 16 then
      depths[i] = v
      i = i + 1
    elseif v < 19 then
      local nbt = {2,3,7}
      local nb = nbt[v-15]
      local c = 0
      local n = 3 + bs:getb(nb)
      if v == 16 then
        c = depths[i-1]
      elseif v == 18 then
        n = n + 8
      end
      for j=1,n do
        depths[i] = c
        i = i + 1
      end
    else
      error("wrong entry in depth table for literal/length alphabet: "..v);
    end
  end
  local litdepths = {} for i=1,hlit do table.insert(litdepths,depths[i]) end
  local littable,nlit = hufftable_create(litdepths)
  local distdepths = {} for i=hlit+1,#depths do table.insert(distdepths,depths[i]) end
  local disttable,ndist = hufftable_create(distdepths)
  block_loop(out,bs,nlit,ndist,littable,disttable)
end

local function block_static(out,bs)
  local cnt = { 144, 112, 24, 8 }
  local dpt = { 8, 9, 7, 8 }
  local depths = {}
  for i=1,4 do
    local d = dpt[i]
    for j=1,cnt[i] do
      table.insert(depths,d)
    end
  end
  local littable,nlit = hufftable_create(depths)
  depths = {}
  for i=1,32 do
    depths[i] = 5
  end
  local disttable,ndist = hufftable_create(depths)
  block_loop(out,bs,nlit,ndist,littable,disttable)
end

local function block_uncompressed(out,bs)
  bs:flushb(bit.band(bs.n,7))
  local len = bs:getb(16)
  if bs.n > 0 then
    error("Unexpected.. should be zero remaining bits in buffer.")
  end
  local nlen = bs:getb(16)
  if bit.bxor(len,nlen) ~= 65535 then
    error("LEN and NLEN don't match")
  end
  for i=1,len do
    table.insert(out,bs:next_byte())
  end
end

local function inflate_main(bs)
  local last,type
  local output = {}
  repeat
    local block
    last = bs:getb(1)
    type = bs:getb(2)
    if type == 0 then
      block_uncompressed(output,bs)
    elseif type == 1 then
      block_static(output,bs)
    elseif type == 2 then
      block_dynamic(output,bs)
    else
      error("unsupported block type")
    end
  until last == 1
  bs:flushb(bit.band(bs.n,7))
  return output
end

local function arraytostr(array)
  local tmp = {}
  local size = #array
  local pos = 1
  local imax = 1
  while size > 0 do
    local bsize = size>=2048 and 2048 or size
    local s = string.char(unpack(array,pos,pos+bsize-1))
    pos = pos + bsize
    size = size - bsize
    local i = 1
    while tmp[i] do
      s = tmp[i]..s
      tmp[i] = nil
      i = i + 1
    end
    if i > imax then
      imax = i
    end
    tmp[i] = s
  end
  local str = ""
  for i=1,imax do
    if tmp[i] then
      str = tmp[i]..str
    end
  end
  return str
end

local crc32_table
function inflate_crc32(s,crc)
  if not crc32_table then
    crc32_table = {}
    for i=0,255 do
      local r=i
      for j=1,8 do
        r = bit.bxor(bit.rshift(r,1),bit.band(0xedb88320,bit.bnot(bit.band(r,1)-1)))
      end
      crc32_table[i] = r
    end
  end
  crc = bit.bnot(crc or 0)
  for i=1,#s do
    local c = s:byte(i)
    crc = bit.bxor(crc32_table[bit.bxor(c,bit.band(crc,0xff))],bit.rshift(crc,8))
  end
  crc = bit.bnot(crc)
  if crc<0 then
    -- in Lua < 5.2, sign extension was performed
    crc = crc + 4294967296
  end
  return crc
end

local function inflate_raw(buf,offset,crc)
  local bs = inflate_bitstream_init(buf)
  bs.pos = offset
  local result = arraytostr(inflate_main(bs))
  if crc and crc ~= inflate_crc32(result) then
    error("checksum verification failed")
  end
  return result
end

local function inflate_gzip(bs)
  local id1,id2,cm,flg = bs.buf:byte(1,4)
  if id1 ~= 31 or id2 ~= 139 then
    error("invalid gzip header")
  end
  if cm ~= 8 then
    error("only deflate format is supported")
  end
  bs.pos=11
  if inflate_band(flg,4) ~= 0 then
    local xl1,xl2 = bs.buf.byte(bs.pos,bs.pos+1)
    local xlen = xl2*256+xl1
    bs.pos = bs.pos+xlen+2
  end
  if inflate_band(flg,8) ~= 0 then
    local pos = bs.buf:find("\0",bs.pos)
    bs.pos = pos+1
  end
  if inflate_band(flg,16) ~= 0 then
    local pos = bs.buf:find("\0",bs.pos)
    bs.pos = pos+1
  end
  if inflate_band(flg,2) ~= 0 then
    -- TODO: check header CRC16
    bs.pos = bs.pos+2
  end
  local result = arraytostr(inflate_main(bs))
  local crc = bs:getb(8)+256*(bs:getb(8)+256*(bs:getb(8)+256*bs:getb(8)))
  bs:close()
  if crc ~= inflate_crc32(result) then
    error("checksum verification failed")
  end
  return result
end

local function int2le(str,pos)
  local a,b = str:byte(pos,pos+1)
  return b*256+a
end

local function int4le(str,pos)
  local a,b,c,d = str:byte(pos,pos+3)
  return ((d*256+c)*256+b)*256+a
end

local function nextfile(buf,p)
  if int4le(buf,p) ~= 0x02014b50 then
    -- end of central directory list
    return
  end
  -- local flag = int2le(buf,p+8)
  local packed = int2le(buf,p+10)~=0
  local crc = int4le(buf,p+16)
  local namelen = int2le(buf,p+28)
  local name = buf:sub(p+46,p+45+namelen)
  local offset = int4le(buf,p+42)+1
  p = p+46+namelen+int2le(buf,p+30)+int2le(buf,p+32)
  if int4le(buf,offset) ~= 0x04034b50 then
    error("invalid local header signature")
  end
  local size = int4le(buf,offset+18)
  local extlen = int2le(buf,offset+28)
  offset = offset+30+namelen+extlen
  return p,name,offset,size,packed,crc
end


-- **************************************************
--
-- ZIP
--
-- **************************************************

function zip_gunzipf(filename)
  local file,err = io.open(filename,"rb")
  if not file then
    return nil,err
  end
  return inflate_gzip(inflate_bitstream_init(file))
end

local function zip_files(buf)
  local p = #buf-21
  if int4le(buf,p) ~= 0x06054b50 then
    -- not sure there is a reliable way to locate the end of central directory record
    -- if it has a variable sized comment field
    error(".ZIP file comments not supported")
  end
  local cdoffset = int4le(buf,p+16)+1
  return nextfile,buf,cdoffset
end

local function zip_unzip(buf,arg1,arg2)
  if type(arg1) == "number" then
    -- mode 1: unpack data from specified position in zip file
    return inflate_raw(buf,arg1,arg2)
  end
  -- mode 2: search and unpack file from zip file
  local filename = arg1
  for _,name,offset,size,packed,crc in zip_files(buf) do
    if name == filename then
      local result
      if not packed then
        -- no compression
        result = buf:sub(offset,offset+size-1)
      else
        -- DEFLATE compression
        result = inflate_raw(buf,offset,crc)
      end
      return result
    end
  end
end

local function open_zip(ar_name)
	local f, err = io.open(ar_name, "rb")
	if f == nil then
		return nil, err
	end
	local buf = f:read( "*a" )
	io.close(f)
	return buf
end

local function zip_read_file(ar_name, f_name)
	local buf, err = open_zip(ar_name)
	if buf then
		return zip_unzip(buf,f_name)
	end
end

local function zip_read_all(ar_name, cb_proc)
	local buf, err = open_zip(ar_name)
	if buf then
		for _,name,offset,size,packed,crc in zip_files(buf) do
		  if type(cb_proc) == "function" then
			  if not packed then
					cb_proc(name,buf:sub(offset,offset+size-1))
			   else
					cb_proc(name,inflate_raw(buf,offset,crc))
			   end
			end
		end
		return true
	end
end

local function zip_list(ar_name)
	local buf, err = open_zip(ar_name)
	local t = {}
	if buf then
		for _,name,offset,size,packed,crc in zip_files(buf) do
			table.insert(t,name)
		end
	end
	return t
end

local function zip_load(path, name)
	local m_name = string.format("%s%s", name,LUA_MODULE_EXT) 
	local mod = zip_read_file(path, m_name)
	if type(mod) == "string" then
		return mod
	end
end


-- **************************************************
--
-- TAR-GZIP
--
-- **************************************************
local headersize = 512

local function get_typeflag(flag)
	if flag == "0" or flag == "\0" then return "file"
	elseif flag == "1" then return "link"
	elseif flag == "2" then return "symlink" -- "reserved" in POSIX, "symlink" in GNU
	elseif flag == "3" then return "character"
	elseif flag == "4" then return "block"
	elseif flag == "5" then return "directory"
	elseif flag == "6" then return "fifo"
	elseif flag == "7" then return "contiguous" -- "reserved" in POSIX, "contiguous" in GNU
	elseif flag == "x" then return "next file"
	elseif flag == "g" then return "global extended header"
	elseif flag == "L" then return "long name"
	elseif flag == "K" then return "long link name"
	end
	return "unknown"
end

local function octal_to_number(octal)
	local exp = 0
	local number = 0
	octal = trim(octal)
	for i = #octal,1,-1 do
		local digit = tonumber(octal:sub(i,i))
		if not digit then break end
		number = number + (digit * 8^exp)
		exp = exp + 1
	end
	return number
end

local function checksum_header(block)
	local sum = 256
	for i = 1,148 do
		sum = sum + block:byte(i)
	end
	for i = 157,500 do
		sum = sum + block:byte(i)
	end
	return sum
end

local function nullterm(s)
	return s:match("^[^%z]*")
end

local function read_header_block(block)
	local header = {}
	header.name = nullterm(block:sub(1,100))
	header.mode = nullterm(block:sub(101,108))
	header.uid = octal_to_number(nullterm(block:sub(109,116)))
	header.gid = octal_to_number(nullterm(block:sub(117,124)))
	header.size = octal_to_number(nullterm(block:sub(125,136)))
	header.mtime = octal_to_number(nullterm(block:sub(137,148)))
	header.chksum = octal_to_number(nullterm(block:sub(149,156)))
	header.typeflag = get_typeflag(block:sub(157,157))
	header.linkname = nullterm(block:sub(158,257))
	header.magic = block:sub(258,263)
	header.version = block:sub(264,265)
	header.uname = nullterm(block:sub(266,297))
	header.gname = nullterm(block:sub(298,329))
	header.devmajor = octal_to_number(nullterm(block:sub(330,337)))
	header.devminor = octal_to_number(nullterm(block:sub(338,345)))
	header.prefix = block:sub(346,500)
	header.pad = block:sub(501,512)
	if header.magic ~= "ustar " and header.magic ~= "ustar\0" then
		return false, "Invalid header magic "..header.magic
	end
	if header.version ~= "00" and header.version ~= " \0" then
		return false, "Unknown version "..header.version
	end
	if not checksum_header(block) == header.chksum then
		return false, "Failed header checksum"
	end
	
	return header
end

local function untar(tarbuf, onComplete, findThis)
	local pos = 1
	local long_name, long_link_name
	while true do
		local block
		block = string.sub(tarbuf,pos,pos+headersize)
		pos = pos + headersize
		
		local header, err = read_header_block(block)
		if not header then
			break
		end
		
		if header.size>0 then
			local file_data = string.sub(tarbuf,pos,pos+header.size-1)
			pos = pos + header.size
			pos = pos + (headersize - pos % headersize) + 1
			-- pos on blocksize boundary
			if header.typeflag == "long name" then
				long_name = nullterm(file_data)
			elseif header.typeflag == "long link name" then
				long_link_name = nullterm(file_data)
			else
				if long_name then
					header.name = long_name
					long_name = nil
				end
				if long_link_name then
					header.name = long_link_name
					long_link_name = nil
				end
			end
			if type(findThis)=="string" then
				if findThis==header.name then
					return  file_data
				end
			else
				if onComplete and type(onComplete) == "function" then
					onComplete(header.name, file_data)
				end
			end
		end
	end
end

local function open_tar(ar_name)
	local f, err = io.open(ar_name, "rb")
	if f == nil then
		return nil, err
	end
	local buf = f:read( "*a" )
	io.close(f)
	return buf
end

local function tar_read_file(ar_name, f_name)
	local buf, err = open_tar(ar_name)
	if buf then
		return untar(buf, nil, f_name)
	end
end

local function tar_read_all(ar_name, cb_proc)
	local buf, err = open_tar(ar_name)
	if buf then
		untar(buf, cb_proc)
		return true
	end
end

local function tgz_read_file(ar_name, f_name)
	local buf, err = zip_gunzipf(ar_name)
	if buf then
		return untar(buf, nil, f_name)
	end
end

local function tgz_read_all(ar_name, cb_proc)
	local buf, err = zip_gunzipf(ar_name)
	if buf then
		untar(buf, cb_proc)
		return true
	end
end

local function tgz_list(ar_name)
	local buf, err = zip_gunzipf(ar_name)
	local t = {}
	if buf then
		untar(buf, function(name) table.insert(t,name) end)
	end
	return t
end

local function tgz_load(path, name)
	local m_name = string.format("%s%s", name,LUA_MODULE_EXT)
	local mod = tgz_read_file(path, m_name)
	if type(mod) == "string" then
		return mod
	end
end

-------------------------
-- lar package loader  --
-------------------------

local function search_archive(path,name)
	local err = ""
	-- search in zip files
	for _,ext in pairs(luar_zip_filetypes) do
		local s = string.format("%s.%s",path,ext)
		local mod = zip_load(s,name)
		if mod then
			return mod
		end
		err =  err.."\n\tno file '"..s..LUA_DIRSEP..name
	end
	-- search in tar files
	for _,ext in pairs(luar_tar_filetypes) do
		local s = string.format("%s.%s",path,ext)
		local mod = tgz_load(s,name)
		if mod then
			return mod
		end
		err =  err.."\n\tno file '"..s..LUA_DIRSEP..name
	end
	return nil, err
end

local function lar_loader (name)
	local errmsg = ""
	local _path=package.path
	assert (type(_path) == "string", string.format ("package.path must be a string"))
	local t_mod, t_path, t_chunk, path, trail, req_module, mod_name, err_path
	local t_chunk_init = {}
	for chunk in string.gmatch (name:gsub("%.", LUA_DIRSEP), "[^/]+") do
		table.insert(t_chunk_init,chunk)
	end
	for c in string.gmatch (_path, "[^;]+") do
		t_chunk = {}
		for _,chunk in pairs(t_chunk_init) do
			table.insert(t_chunk,chunk)
		end
		-- handle trailing init.lua --------
		local t = {}
		for w in c:gmatch("([^".. LUA_PATH_MARK .."]+)") do 
			table.insert(t,w) 
		end
		trail = (t[2] or ""):gsub(LUA_MODULE_EXT,"")
		if trail:sub(1,1) == LUA_DIRSEP then trail = trail:sub(2) end
		if trail:len()>0 and t_chunk[#t_chunk] ~= trail then
			table.insert(t_chunk,trail)
		end
		------------------------------------
		path = t[1]
		if path:sub(-1) == LUA_DIRSEP then path = path:sub(1,-2) end
		t_path = {path}
		for n=1,#t_chunk do
			t_mod = {}
			for i=n,#t_chunk do
				table.insert(t_mod,t_chunk[i])
			end
			for i=1,n-1 do
				table.insert(t_path,t_chunk[i])
			end
			req_module, err_path = search_archive(table.concat(t_path,LUA_DIRSEP),table.concat(t_mod,LUA_DIRSEP))
			mod_name = table.concat(t_path,LUA_DIRSEP) .. LUA_DIRSEP .. table.concat(t_mod,LUA_DIRSEP)
			if req_module then
				return assert(loadstring(assert(req_module), mod_name))
			end
			errmsg = errmsg..err_path
		end
	end
	return errmsg
end

-- Install loader
table.insert(package.loaders, 2, lar_loader) 

-- lar module
return {
	unzip = zip_read_file,
	unzip_all = zip_read_all,
	zip_list = zip_list,
	ungztar = tgz_read_file,
	ungztar_all = tgz_read_all,
	tgz_list = tgz_list,
	gunzip = zip_gunzipf
}
