--[[------------------------------------------------------
  # Lua C++ binding generator <a href="https://travis-ci.org/lubyk/dub"><img src="https://travis-ci.org/lubyk/dub.png" alt="Build Status"></a> 
  

  Create lua bindings by parsing C++ header files using [doxygen](http://doxygen.org).

  Generated lua bindings do not contain any external dependencies. Dub C++ files
  are copied along with the generated C++ bindings.

  <html><a href="https://github.com/lubyk/dub"><img style="position: absolute; top: 0; right: 0; border: 0;" src="https://s3.amazonaws.com/github/ribbons/forkme_right_green_007200.png" alt="Fork me on GitHub"></a></html>

  This module is part of the [lubyk](http://lubyk.org) project. *MIT license*
  &copy; Gaspard Bucher 2014.

  ## Installation
  
  With [luarocks](http://luarocks.org):

    $ luarocks install dub
  
  With [luadist](http://luadist.org):

    $ luadist install dub
    
--]]------------------------------------------------------
local lub = require 'lub'
local lib = lub.Autoload 'dub' 
local private = {}

-- nodoc
lib.private = private

-- Current version of 'dub' respecting [semantic versioning](http://semver.org).
lib.VERSION = '2.2.0'

lib.DEPENDS = { -- doc
  -- Compatible with Lua 5.1, 5.2 and LuaJIT
  'lua >= 5.1, < 5.3',
  -- Uses [Lubyk base library](http://doc.lubyk.org/lub.html)
  'lub >= 1.0.3, < 1.1',
  -- Uses [Lubyk fast xml library](http://doc.lubyk.org/xml.html)
  'xml ~> 1.0',
}

--[[
  # Usage example

  The following code is used to generated bindings from all the headers located
  in `include/xml` and output generated files inside `src/bind`.

  First we must parse headers. To do this, we create a dub.Inspector which we
  could also use to query function names, classes and other information on the
  parsed C++ headers.
  
    local lub = require 'lub'
    local dub = require 'dub'

    local inspector = dub.Inspector {
      INPUT    = {
        lub.path '|include/xml',
      },
    }

  We can now generate Lua bindings with the dub.LuaBinder.

    local binder = dub.LuaBinder()

    binder:bind(inspector, {
      output_directory = lub.path '|src/bind',

      -- Remove this part in included headers
      header_base = lub.path '|include',

      -- Create a single library named 'xm' (not a library for each class).
      single_lib = 'xml',

      -- Open the library with require 'xml.core' (not 'xml') because
      -- we want to add some more Lua methods inside 'xml.lua'.
      luaopen    = 'xml_core',
    })
    
  The code above generates files such as:

  + xml_core.cpp:  This contains bindings for methods in the 'xml' namespace,
                   constants and also the main 'luaopen_xml_core' function.
  + xml_Parser.cpp:  This contains bindings for xml::Parser class.
  + dub/...:       Compile time dub C++ and header files.

  When building the library, make sure to include all C++ files (including those
  in the `dub` folder. You should also include the binding folder in the include
  path so that `#include "dub/dub.h"` is properly resolved.

  You can view the generated files on [xml lib on github](https://github.com/lubyk/xml/tree/master/src/bind).

  # C++ exceptions

  The dub library catches all exceptions thrown during binding execution and
  passes the exceptions as lua errors. Internally, the library itself throws
  `dub::Exception` and `dub::TypeException`.
--]]
local DUB_MAX_IN_SHIFT = 4294967296

local function shiftleft(v, nb)
  local r = v * (2^nb)
  -- simulate overflow with 32 bits
  r = r % DUB_MAX_IN_SHIFT
  return r
end

-- Find the minimal modulo value for the list of keys to
-- avoid collisions.
function lib.minHash(list_or_obj, func)
  local list = {}
  if not func then
    for _, name in ipairs(list_or_obj) do
      if not list[name] then
        list[name] = true
        table.insert(list, name)
      end
    end
  else
    list = {}
    for name in func(list_or_obj) do
      if not list[name] then
        list[name] = true
        table.insert(list, name)
      end
    end
  end
  local list_sz = #list
  if list_sz == 0 then
    -- This is an error.
    return nil
  end

  local sz = 1
  while true do
    sz = sz + 1
    local hashes = {}
    for i, key in ipairs(list) do
      local h = lib.hash(key, sz)
      if hashes[h] then
        break
      elseif i == list_sz then
        return sz
      else
        hashes[h] = key
      end
    end
  end
end

function lib.hash(str, sz)
  local h = 0
  for i=1,string.len(str) do
    local c = string.byte(str,i)
    h = c + shiftleft(h, 6) + shiftleft(h, 16) - h
    h = h % DUB_MAX_IN_SHIFT
  end
  return h % sz
end
--=============================================== PRIVATE

local shown_warnings = {}
function lib.printWarn(level, fmt, ...)
  if level > lib.warn_level then
    return
  end
  local msg = string.format(fmt, ...)
  if not shown_warnings[msg] then
    print('warning:', msg)
    shown_warnings[msg] = true
  end
end

function lib.silentWarn(level, fmt, ...)
  local msg = string.format(fmt, ...)
  if not shown_warnings[msg] then
    shown_warnings[msg] = true
  end
end

-- Warning function. Can be overwriten. The `level` parameter is a value between
-- 1 and 10 (the higher the level the less important the message).
-- function lib.warn(level, format, ...)

-- nodoc
lib.warn = lib.printWarn

-- Default warning level (anything below or equal to this level will be
-- notified).
lib.warn_level = 5

return lib
