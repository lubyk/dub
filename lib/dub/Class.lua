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

--=============================================== PRIVATE

function private.methodsIterator(self)
  for _, child in ipairs(self.cache) do
    if child.kind == 'function' then
      coroutine.yield(child)
    end
  end
end
