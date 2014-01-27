--[[------------------------------------------------------

  # C++ Namespace definition.

  (internal) A C++ namespace definition with nested classes, enums
  and functions.

--]]------------------------------------------------------
local lub     = require 'lub'
local dub     = require 'dub'
local lib     = lub.class('dub.Namespace', {
  is_class    = false,
})
local private = {}

-- Behaves like a class by default
setmetatable(lib, dub.Class)

--=============================================== dub.Namespace()
function lib.new(self)
  local self = self or {}
  local name = self.name
  self.name = nil
  self.const_headers = {}
  self = dub.Class(self)
  setmetatable(self, lib)
  self:setName(name)
  return self
end

function lib:namespaces()
  return self.db:namespaces()
end

function lib:functions()
  return self.db:functions(self)
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

function lib:children()
  return self.db:children(self)
end

return lib
