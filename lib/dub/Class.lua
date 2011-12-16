--[[------------------------------------------------------

  dub.Class
  ---------

  A class/struct definition.

--]]------------------------------------------------------

local lib     = {type = 'class'}
local private = {}
lib.__index   = lib
dub.Class     = lib

--=============================================== dub.Object()
setmetatable(lib, {
  __call = function(lib, inspector)
    local self = {inspector = inspector}
    return setmetatable(self, lib)
  end
})

--=============================================== PUBLIC METHODS








--=============================================== PRIVATE

