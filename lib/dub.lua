--[[------------------------------------------------------

  dub
  ---

  This file loads the dub library.

--]]------------------------------------------------------
dub = Autoload('dub')
dub.version = '2.0'

local DUB_MAX_IN_SHIFT = 4294967296

local function shiftleft(v, nb)
  local r = v * (2^nb)
  -- simulate overflow with 32 bits
  r = r % DUB_MAX_IN_SHIFT
  return r
end

function dub.hash(str, sz)
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
function dub.minHash(list_or_obj, func, accessor)
  local list
  if not accessor then
    accessor = func
    list = list_or_obj
  else
    list = {}
    for elem in func(list_or_obj) do
      table.insert(list, elem)
    end
  end
  local list_sz = #list
  local sz = 1
  while true do
    sz = sz + 1
    local hashes = {}
    for i, key in ipairs(list) do
      if accessor then
        key = key[accessor]
      end
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

