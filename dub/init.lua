--[[------------------------------------------------------
  # Lua C++ binding generator

  Create lua bindings by parsing C++ header files using [doxygen](http://doxygen.org).

  This module is part of [lubyk](http://lubyk.org) project.  
  Install with [luarocks](http://luarocks.org) or [luadist](http://luadist.org).

    $ luarocks install dub    or    luadist install dub
  

--]]------------------------------------------------------
local lub = require 'lub'
local lib = lub.Autoload 'dub' 
local private = {}

-- nodoc
lib.private = private

-- Odd minor version numbers are never released and are used during development.
lib.VERSION = '2.2.1'

local DUB_MAX_IN_SHIFT = 4294967296

local function shiftleft(v, nb)
  local r = v * (2^nb)
  -- simulate overflow with 32 bits
  r = r % DUB_MAX_IN_SHIFT
  return r
end

--=============================================== PRIVATE
function private.hash(str, sz)
  local h = 0
  for i=1,string.len(str) do
    local c = string.byte(str,i)
    h = c + shiftleft(h, 6) + shiftleft(h, 16) - h
    h = h % DUB_MAX_IN_SHIFT
  end
  return h % sz
end

-- Find the minimal modulo value for the list of keys to
-- avoid collisions.
function private.minHash(list_or_obj, func)
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
      local h = dub.hash(key, sz)
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

local shown_warnings = {}
function private.printWarn(level, fmt, ...)
  if level > dub.warn_level then
    return
  end
  local msg = string.format(fmt, ...)
  if not shown_warnings[msg] then
    print('warning:', msg)
    shown_warnings[msg] = true
  end
end

function private.silentWarn(level, fmt, ...)
  local msg = string.format(fmt, ...)
  if not shown_warnings[msg] then
    shown_warnings[msg] = true
  end
end

-- Warning function. Can be overwriten. The `level` parameter is a value between
-- 1 and 10 (the higher the level the less important the message).
-- function lib.warn(level, format, ...)

-- nodoc
lib.warn = private.printWarn

-- Default warning level (anything below or equal to this level will be
-- notified).
lib.warn_level = 5

return lib
