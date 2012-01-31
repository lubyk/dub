--[[------------------------------------------------------

  dub.OptParser
  -------------

  Simplified yaml parser to retrieve @dub inline options.

--]]------------------------------------------------------

local lib     = {
  type          = 'dub.OptParser',
}
local private = {}
lib.__index   = lib
dub.OptParser = lib

--=============================================== dub.Class()
setmetatable(lib, {
  __call = function(lib, str)
    return lib.parse(str)
  end
})

function lib.parse(str)
  local res = {}
  for line in str:gmatch("[^\r\n]+") do
    local key, value = line:match(' *([a-z]+): *(.-) *$')
    if value == 'false' then
      value = false
    elseif value == 'true' then
      value = true
    elseif value:match('^[0-9.]+$') then
      value = value * 1
    elseif value:match(',') then
      local list = {}
      for elem in value:gmatch('[^,]+') do
        elem = private.strip(elem)
        table.insert(list, elem)
        list[elem] = true
      end
      value = list
    else
      value = private.parseString(value)
    end

    res[key] = value
  end
  return res
end

--=============================================== PRIVATE

function private.parseString(str)
  return str:match('^"(.*)"$') or
         str:match("^'(.*)'$") or str
end

function private.strip(str)
  return str:match('^ *(.-) *$')
end
