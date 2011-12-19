--[[------------------------------------------------------

  dub.LuaBinder
  -------------

  Use the dub.Inspector to create Lua bindings.

--]]------------------------------------------------------
local lib     = {}
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

--=============================================== PRIVATE



