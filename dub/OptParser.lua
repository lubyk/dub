--[[------------------------------------------------------

  # "dub" options parser

  (internal) Simplified yaml parser to retrieve @dub inline options.

--]]------------------------------------------------------
local lub     = require 'lub'
local lib     = lub.class 'dub.OptParser'
local insert, match  = table.insert, string.match
local private = {}

--=============================================== dub.Class()
function lib.new(str)
  return lib.parse(str)
end

function lib.parse(str)
  local res = {}
  for line in str:gmatch("[^\r\n]+") do
    local key, value = line:match(' *([A-Za-z_]+): *(.-) *$')
    if not key then
      return nil
    end
    local str = value:match('^"(.*)"$') or
                value:match("^'(.*)'$")
    if str then
      -- string
      value = str
    elseif value == 'false' then
      value = false
    elseif value == 'true' then
      value = true
    elseif value:match('^[0-9.]+$') then
      value = value * 1
    elseif value:match(',') then
      local list = {}
      for elem in value:gmatch('[^,]+') do
        elem = private.strip(elem)
        insert(list, elem)
        list[elem] = true
      end
      value = list
    end

    res[key] = value
  end
  return res
end

--=============================================== PRIVATE

function private.strip(str)
  return match(str, '^ *(.-) *$')
end

return lib
