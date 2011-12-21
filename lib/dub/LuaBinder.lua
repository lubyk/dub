--[[------------------------------------------------------

  dub.LuaBinder
  -------------

  Use the dub.Inspector to create Lua bindings.

--]]------------------------------------------------------
local lib     = {
  type = 'dub.LuaBinder',
  SELF = 'self',
  SELF_ACCESSOR = 'luaL_checkudata',
  TYPE_TO_NATIVE = {
    double = 'number',
    float  = 'number',
    int    = 'number',
  }
}
local private = {}
lib.__index   = lib
dub.LuaBinder = lib

--=============================================== dub.Inspector()
setmetatable(lib, {
  __call = function(lib)
    local self = {}
    return setmetatable(self, lib)
  end
})

--=============================================== PUBLIC METHODS
-- Add xml headers to the database
function lib.bind(inspector, options)
  self.options = options
  self.ins     = inspector
  if options.only then
    for _,name in ipairs(options.only) do
      local elem = inspector:find(name)
      if elem.type == 'dub.Class' then
        local path = self.output_directory .. lk.Dir.sep .. class.name .. '.cpp'
        local file = io.open(path, 'w')
        file.write(self:bindClass(class))
        file.close()
      end
    end
  end
end

--- Return a string containing the Lua bindings for a class.
function lib:bindClass(class)
  if not self.class_template then
    -- path to current file
    local dir = lk.dir()
    self.class_template = dub.Template {path = dir .. '/lua/class.cpp'}
  end
  return self.class_template:run {self = class, binder = self}
end

--- Create the body of the bindings for a given method/function.
function lib:functionBody(class, method)
  local res = ''
  if class and not class:isConstructor(method) then
    -- We need self
    res = res .. private.getSelf(self, class)
  end
  for param in method:params() do
    res = res .. private.getParam(self, method, param, 1)
  end
  return res .. "return 0;"
end

--=============================================== Methods that can be customized

function lib:customTypeAccessor(class)
  return 'luaL_checkudata'
end

function lib:libName(class)
  return string.gsub(class:fullname(), '::', '.')
end

--- Returns the method to use to retrieve a given type from Lua.
function lib:nativeTypeAccessor(method, type_name)
  local typ = method.db:resolveType(type_name) or type_name
  local acc = self.TYPE_TO_NATIVE[typ]
  if acc then
    -- if this method does never throw, we can use luaL_check...
    if method:neverThrows() then
      return 'luaL_check' .. acc
    else
      return 'dubL_check' .. acc
    end
  end
end

--=============================================== PRIVATE

--- Find the userdata from the current lua_State. The userdata can
-- be directly passed as first parameter or it can be inside a table as
-- 'super'.
function private.getSelf(self, class)
  return string.format('%s *%s = *((%s**)%s(L, 1, "%s"));\n', 
    class.name, self.SELF, class.name, self:customTypeAccessor(class), self:libName(class))
end

--- Retrieve a function parameter.
function private.getParam(self, method, param, delta)
  local type_method = self:nativeTypeAccessor(method, param.ctype)
  if type_method then
    return string.format('%s %s = %s(L, %i);\n',
      param.ctype, param.name, type_method, param.position + delta)
  else
    -- userdata
    local lib_name
    local class = method.db:findByFullname(param.ctype)
    if class then
      lib_name = self:libName(class)
    else
      lib_name = param.ctype
    end
    type_method = self:customTypeAccessor(method, param.ctype)
    return string.format('%s *%s = *((%s**))%s(L, %i, "%s"));\n',
      param.ctype, param.name, param.ctype, type_method, param.position + delta, lib_name)
  end
end
