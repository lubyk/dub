--[[------------------------------------------------------

  dub.Class
  ---------

  A class/struct definition.

--]]------------------------------------------------------

local lib     = {type = 'dub.Class'}
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

--- Return true if the given method is a constructor for this class.
function lib:isConstructor(method)
  return self.name == method.name
end

function lib:fullname()
  if self.parent then
    return self.parent:fullname() .. '::' .. self.name
  else
    return self.name
  end
end

--=============================================== PRIVATE

