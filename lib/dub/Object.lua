--[[------------------------------------------------------

  dub.Object
  ----------

  Common methods to all the objects.

--]]------------------------------------------------------

local lib     = {type = 'unknown'}
local private = {}
lib.__index   = lib
dub.Object    = lib

--=============================================== dub.Object()
setmetatable(lib, {
  __call = function(lib)
    local self = {}
    return setmetatable(self, lib)
  end
})

--=============================================== PUBLIC METHODS








--=============================================== PRIVATE

