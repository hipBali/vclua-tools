-- ****************************************
-- VCLua Form tool (packaged module) loader
-- Copyright (C) 2013-2024 Hi-Project Ltd.
-- ****************************************

package.path=package.path ..'?.lua;?/init.lua;lar/?.lua;lar/?/init.lua;'
package.path=package.path ..'lar/vt-form/?.lua;'
local lar = require 'lar'
require 'main'