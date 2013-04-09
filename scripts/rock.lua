#!/usr/bin/env lua
lub = require 'lub'
local mod = require 'lut'

local tmp = lub.Template(lub.content(lub.path '|rockspec.in'))
lub.writeall(mod.type..'-'..mod.VERSION..'-1.rockspec', tmp:run())

tmp = lub.Template(lub.content(lub.path '|CMakeLists.txt.in'))
lub.writeall('CMakeLists.txt', tmp:run())

tmp = lub.Template(lub.content(lub.path '|dist.info.in'))
lub.writeall('dist.info', tmp:run())

