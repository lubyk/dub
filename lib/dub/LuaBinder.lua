--[[------------------------------------------------------

  dub.LuaBinder
  -------------

  Use the dub.Inspector to create Lua bindings.

--]]------------------------------------------------------
local lib     = {SELF = 'self', SELF_ACCESSOR = 'luaL_checkudata'}
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
      if elem.kind == 'class' then
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
  -- TODO
  return res .. "return 0;"
end

--=============================================== Methods that can be customized

function lib:selfAccessor(class)
  -- TODO: if class.opts.self_accessor ? See on the testing side.
  return 'luaL_checkudata'
end

function lib:libName(class)
  return string.gsub(class:fullname(), '::', '.')
end
--=============================================== PRIVATE

--- Find the userdata from the current lua_State. The userdata can
-- be directly passed as first parameter or it can be inside a table as
-- 'super'.
function private.getSelf(self, class)
  return string.format('%s *%s = *((%s**)%s(L, 1, "%s"));\n', 
    class.name, self.SELF, class.name, self:selfAccessor(class), self:libName(class))
end
