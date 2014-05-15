#!/usr/bin/env lua
local lub = require 'lub'

local lib = require 'dub'

local def = {
  description = {
    summary = "Lua binding generator from C/C++ code (uses Doxygen to parse C++ comments).",
    detailed = [[
      A powerful binding generator for C/C++ code with support for attributes,
      callbacks, errors on callbacks, enums, nested classes, operators, public
      attributes, etc.
      
      Full documentation: http://doc.lubyk.org/dub.html
    ]],
    homepage = "http://doc.lubyk.org/"..lib.type..".html",
    author   = "Gaspard Bucher",
    license  = "MIT",
  },

  pure_lua  = true,
}

--- End configuration

local tmp = lub.Template(lub.content(lub.path '|rockspec.in'))
lub.writeall(lib.type..'-'..lib.VERSION..'-1.rockspec', tmp:run {lib = lib, def = def, lub = lub})

tmp = lub.Template(lub.content(lub.path '|dist.info.in'))
lub.writeall('dist.info', tmp:run {lib = lib, def = def, lub = lub})

tmp = lub.Template(lub.content(lub.path '|CMakeLists.txt.in'))
lub.writeall('CMakeLists.txt', tmp:run {lib = lib, def = def, lub = lub})


