--[[------------------------------------------------------

  dub.Class
  ---------

  A class/struct definition.

--]]------------------------------------------------------

local lib     = {kind = 'class'}
local private = {}
lib.__index   = lib
dub.Class     = lib

--=============================================== dub.Object()
setmetatable(lib, {
  __call = function(lib, self)
    return setmetatable(self, lib)
  end
})

--=============================================== PUBLIC METHODS

--- Return a method from a given name.
function lib:method(name)
  return self.db:findChild(self, name)
end

--- Return an iterator over the methods of this class.
function lib:methods()
  return self.db:functions(self)
end

--- Return an iterator over the headers for this class/namespace.
function lib:headers()
  return self.db:headers(self)
end

--=============================================== PRIVATE

function lib:resolveType(name)
  -- Do we have a typedef ?
  local td = self:findByFullname(name)
  if td then
    return td.type
  end
end
--=============================================== PRIVATE

