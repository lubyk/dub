--[[------------------------------------------------------

  dub.Class
  ---------

  A class/struct definition.

--]]------------------------------------------------------

local lib     = {
  type          = 'dub.Class',
  is_class      = true,
  is_scope      = true,
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
    return lib.new(self)
  end
})

-- For sub-classes of dub.Class (dub.Namespace, dub.CTemplate)
function lib.__call(lib, self)
  return lib.new(self)
end

function lib.new(self)
  self.cache          = {}
  self.sorted_cache   = {}
  self.functions_list = {}
  self.variables_list = {}
  self.constants_list = {}
  self.super_list     = {}
  
  self.xml_headers    = self.xml_headers or {}
  setmetatable(self, lib)
  self:setOpt(self.dub or {})
  self:setName(self.name)
  if self.dub.ignore == true then
    return nil
  else
    return self
  end
end

--=============================================== PUBLIC METHODS

--- Return a child element from name.
function lib:findChild(name)
  private.makeSpecialMethods(self)
  return self.db:findChildFor(self, name)
end

--- Return a method from a given name.
lib.method = lib.findChild

--- Return an iterator over the methods of this class.
function lib:methods()
  -- Create --get--, --set-- and ~Destructor if needed.
  private.makeSpecialMethods(self)
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

function lib:hasVariables()
  if self.has_variables then
    return true
  end
  -- Look in inheritance chain
  for super in self:superclasses() do
    if super:hasVariables() then
      self.has_variables = true
      return true
    end
  end
  return false
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

-- Return true if the class needs a cast method (it has
-- known superclasses).
function lib:needCast()
  for super in self:superclasses() do
    return true
  end
  return false
end

function lib:setName(name)
  if not name then
    return
  end
  self.name = name
  -- Remove namespace from name
  local create_name = ''
  local current = self
  while current and current.is_scope do
    if current ~= self then
      create_name = '::' .. create_name
    end
    create_name = current.name .. create_name
    current = current.parent
    if current.type == 'dub.Namespace' then
      break
    end
  end
  self.create_name = create_name .. ' *'
end

function lib:setOpt(opt)
  self.dub      = opt or {}
  self.dub_type = self.dub.type
  self.ignore   = self.dub.ignore or {}
  if type(self.ignore) == 'string' then
    self.ignore = { self.ignore,
      [self.ignore] = true,
    }
  end

  if type(self.dub.super) == 'string' then
    self.dub.super = { self.dub.super }
  end

  local dtor = self.dub.destructor
  if dtor == false then
    self.ignore['~'..self.name] = true
  elseif dtor then
    self.ignore[dtor] = true
  end
end

-- Return the enclosing namespace or nil if none found.
function lib:namespace()
  local p = self.parent
  while p do
    if p.type == 'dub.Namespace' then
      return p
    else
      p = p.parent
    end
  end
end

function lib:ignoreFunc(name)
  return self.ignore[name] or name == self.dub.push
end

--=============================================== PRIVATE
function private:makeSpecialMethods()
  if self.made_special_methods then
    return
  end
  self.made_special_methods = true
  dub.MemoryStorage.makeSpecialMethods(self)
end
