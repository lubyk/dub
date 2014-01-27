package = "dub"
version = "2.2.0-1"
source = {
  url = 'https://github.com/lubyk/dub/archive/REL-2.2.0.tar.gz',
  dir = 'dub-REL-2.2.0',
}
description = {
  summary = "Lua binding generator from C++ code (uses Doxygen to parse C++ comments).",
  detailed = [[
    A powerful binding generator for C++ code with support for attributes,
    callbacks, errors on callbacks, enums, nested classes, operators, public
    attributes, etc.
  ]],
  homepage = "http://doc.lubyk.org/dub.html",
  license = "MIT"
}
dependencies = {
  "lua >= 5.1, < 5.3",
  "lub >= 1.0.3, < 1.1",
  "xml ~> 1.0",
}
build = {
  type = 'builtin',
  modules = {
    ['dub'               ] = 'dub/init.lua',
    ['dub.Class'         ] = 'dub/Class.lua',
    ['dub.CTemplate'     ] = 'dub/CTemplate.lua',
    ['dub.Function'      ] = 'dub/Function.lua',
    ['dub.Inspector'     ] = 'dub/Inspector.lua',
    ['dub.LuaBinder'     ] = 'dub/LuaBinder.lua',
    ['dub.MemoryStorage' ] = 'dub/MemoryStorage.lua',
    ['dub.Namespace'     ] = 'dub/Namespace.lua',
    ['dub.OptParser'     ] = 'dub/OptParser.lua',
  },
  install = {
    -- These assets are needed to generate the bindings.
    lua = {
      ['dub.assets.Doxyfile'           ] = 'dub/assets/Doxyfile',
      ['dub.assets.lua.class_cpp'      ] = 'dub/assets/lua/class.cpp',
      ['dub.assets.lua.dub.dub_cpp'    ] = 'dub/assets/lua/dub/dub.cpp',
      ['dub.assets.lua.dub.dub_h'      ] = 'dub/assets/lua/dub/dub.h',
      ['dub.assets.lua.lib_cpp'        ] = 'dub/assets/lua/lib.cpp',
    },
  },
}