--[[------------------------------------------------------

  dub.Class
  ---------

  A class/struct definition.

--]]------------------------------------------------------

local lib     = {
  type          = 'dub.Class',
  is_class      = true,
  SET_ATTR_NAME = '_set_',
  GET_ATTR_NAME = '_get_',
  CAST_NAME     = '_cast_',
}
local private = {}
lib.__index   = lib
dub.Class     = lib

--=============================================== dub.Class()
setmetatable(lib, {
  __call = function(lib, self)
    self.cache          = {}
    self.sorted_cache   = {}
    self.functions_list = {}
    self.variables_list = {}
    self.constants_list = {}
    self.super_list     = {}
    self.dub            = self.dub or {}
    self.xml_headers    = self.xml_headers or {}
    return setmetatable(self, lib)
  end
})

--=============================================== PUBLIC METHODS

--- Return a child element from name.
function lib:findChild(name)
  return self.db:findChildFor(self, name)
end

--- Return a method from a given name.
lib.method = lib.findChild

--- Return an iterator over the methods of this class.
function lib:methods()
  return self.db:functions(self)
end

--- Return an iterator over the attributes of this class.
function lib:attributes()
  return self.db:variables(self)
end

--- Return an iterator over the superclasses of this class.
function lib:superclasses()
  return self.db:superclasses(self)
end

--- Return an iterator over the constants defined in this class.
function lib:constants()
  return self.db:constants(self)
end

function lib:fullname()
  if self.parent and self.parent.name then
    return self.parent:fullname() .. '::' .. self.name
  else
    return self.name
  end
end

--=============================================== PRIVATE

