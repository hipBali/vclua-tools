-- ***************************************
-- VCLua Form tool
-- Copyright (C) 2013-2023 Hi-Project Ltd.
--
-- file i/o functions
-- ***************************************

local json = require "json"
local log = require "log"

local m={}

function m.exists(fileName)
  local file = io.open( fileName, "r" )
  if file then
    io.close( file )
	return true
  end
  return false
end

function m.load(fileName, mode)
  local file, errorString = io.open( fileName, mode or "r"  )
  if not file then
    log.error( string.format("File open: %s ", errorString) )
  else
    contents = file:read( "*a" )
    io.close( file )
  end
  return contents
end

function m.loadLines(fileName)
  local file, errorString = io.open( fileName )
  local contents = {}
  if not file then
    log.error( string.format("File open: %s ", errorString) )
  else
    local lines = file:lines()
    for line in lines do  
      table.insert(contents,line)
    end
    io.close( file )
  end
  return contents
end

function m.save(fileName, content, mode)
  local file, errorString = io.open( fileName, mode or "w" )
  if not file then
    log.error( string.format("File save: %s %s ",tostring(filename), errorString) )
    return false
  else
      file:write( content )
      io.close( file )
  end
  file = nil
  return true
end

function m.loadJson( filename )
  local j = m.load(filename)
  if type(j)=="string" then
    return json.decode(j)
  end
  return {}
end

function m.saveJson( filename, t )
    return m.save( filename, json.encode( t ) )
end

function m.copy(src, dst, blocksize)
  blocksize = blocksize or 1024*1024
  local sf, df, err
  local function bail(...)
    if sf then sf:close() end
    if df then df:close() end
    return ...
  end
  sf, err = io.open(src, "rb")
  if not sf then return bail(nil, err) end
  df, err = io.open(dst, "wb")
  if not df then return bail(nil, err) end
  while true do
    local ok, data
    data = sf:read(blocksize)
    if not data then break end
    ok, err = df:write(data)
    if not ok then return bail(nil, err) end
  end
  return bail(true)
end


return m