--[[------------------------------------------------------

  # A C++ template definition.

  (internal) C++ template definition. This is a sub-class of dub.Class.

--]]------------------------------------------------------
local lub = require 'lub'
local dub = require 'dub'
local lib = lub.class 'dub.CTemplate'
local private = {}

-- nodoc
lib.template = true

-- CTemplate is a sub-class of dub.Class
setmetatable(lib, dub.Class)

-- # Constructor
-- The Constructor is never used. We transform a dub.Class while parsing
-- template parameters.

-- Returns a dub.Class by resolving the template parameters.
function lib:resolveTemplateParams(parent, name, types)
  local name_to_type = {}
  name_to_type[self.name] = name
  local all_resolved = true
  for i, param in ipairs(self.template_params) do
    local typ = types[i]
    if typ then
      name_to_type[param] = typ
    else
      all_resolved = false
    end
  end
  if all_resolved then
    -- Make class
    local class = dub.Class {
      db           = self.db,
      parent       = parent or self.parent,
      name         = name,
    }
    -- Rebuild methods
    private.resolveMethods(self, class, name_to_type)
    -- Rebuild attributes
    if self.has_variables then
      private.resolveAttributes(self, class, name_to_type)
    end
    return class
  else
    -- Make another template
  end
end

-- nodoc
lib.fullname = dub.Class.fullname

--=============================================== PRIVATE

function private:resolveMethods(class, name_to_type)
  for method in self:methods() do
    local opts = {
      db            = self.db,
      parent        = class,
      name          = method.name,
      params_list   = private.resolveParams(method, name_to_type),
      return_value  = private.resolveType(method.return_value, name_to_type),
      definition    = method.definition,
      argsstring    = method.argsstring,
      location      = method.location,
      desc          = method.desc,
      static        = method.static,
      xml           = method.xml,
      member        = method.member,
      dtor          = method.dtor,
      ctor          = method.ctor,
      dub           = method.dub,
      is_set_attr   = method.is_set_attr,
      is_get_attr   = method.is_get_attr,
      is_cast       = method.is_cast,
    }
    if method.ctor then
      opts.name = class.name
      opts.return_value = dub.MemoryStorage.makeType(class.name .. ' *')
    elseif method.dtor then
      opts.name = '~' .. class.name
    end

    local m = dub.Function(opts)
    class.cache[m.name] = m
    table.insert(class.functions_list, m)
  end
end

function private:resolveAttributes(class, name_to_type)
  class.has_variables = true
  local list = class.variables_list
  for attr in self:attributes() do
    table.insert(list, {
      type   = 'dub.Attribute',
      parent = class,
      name   = attr.name,
      ctype  = private.resolveType(attr.ctype, name_to_type),
    })
  end
end

function private:resolveParams(name_to_type)
  local res = {}
  for _, param in ipairs(self.params_list) do
    local p = {
      type     = 'dub.Param',
      name     = param.name,
      position = param.position,
      ctype    = private.resolveType(param.ctype, name_to_type),
    }
    table.insert(res, p)
  end
  return res
end

function private.resolveType(ctype, name_to_type)
  if not ctype then
    return
  end
  local resolv = name_to_type[ctype.name]
      
  if resolv then
    local t = dub.MemoryStorage.makeType(resolv)
    return dub.MemoryStorage.makeType(resolv)
  else
    return ctype
  end
end
    
return lib
