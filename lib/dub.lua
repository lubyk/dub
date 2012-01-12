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
    if h < 0 then
      assert(false, 'ERROR in dub.hash function: negative value')
    end
  end
  return h % sz
end

-- Find the minimal modulo value for the list of keys to
-- avoid collisions.
function dub.minHash(list, accessor)
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

