--[[------------------------------------------------------

  dub.Namespace
  -------------

  A C++ namespace definition with nested classes, enums
  and functions.

--]]------------------------------------------------------

local lib     = {
  type        = 'dub.Namespace',
  is_class    = false,
}
local private = {}
lib.__index   = lib
dub.Namespace = lib
-- Behaves like a class by default
setmetatable(lib, dub.Class)

--=============================================== dub.Namespace()

function lib.new(self)
  local name = self.name
  self.name = nil
  self = dub.Class(self)
  setmetatable(self, lib)
  self:setName(name)
  return self
end


--=============================================== PUBLIC METHODS

function lib:setName(name)
  self.name = name
end

function lib:fullname()
  if self.parent and self.parent.type ~= 'dub.MemoryStorage' then
    return self.parent:fullname() .. '::' .. self.name
  else
    return self.name
  end
end
