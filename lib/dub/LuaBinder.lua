--[[------------------------------------------------------

  dub.LuaBinder
  -------------

  Use the dub.Inspector to create Lua bindings.

--]]------------------------------------------------------
local lib     = {
  type = 'dub.LuaBinder',
  SELF = 'self',
  -- By default, we try to access userdata in field 'super'. This is not
  -- slower then checkudata if the element passed is a userdata.
  TYPE_ACCESSOR = 'checksdata',
  LUA_STACK_SIZE_NAME = 'LuaStackSize',
  TYPE_TO_NATIVE = {
    double = 'number',
    float  = 'number',
    int    = 'number',
  },
  -- Relative path to copy dub headers and cpp files. Must be
  -- relative to the bindings output directory.
  COPY_DUB_PATH  = '',
  COMPILER       = 'g++',
  COMPILER_FLAGS = {
    macosx = '-g -Wall -Wl,-headerpad_max_install_names -flat_namespace -undefined suppress -dynamic -bundle -fPIC',
    linux  = '-g -Wall -Wl,-headerpad_max_install_names -flat_namespace -undefined suppress -dynamic -fPIC',
  }
}
local private = {}
lib.__index   = lib
dub.LuaBinder = lib

--=============================================== dub.LuaBinder()
setmetatable(lib, {
  __call = function(lib, options)
    local self = {options = options or {}}
    return setmetatable(self, lib)
  end
})

--=============================================== PUBLIC METHODS
-- Add xml headers to the database
function lib:bind(inspector, options)
  self.options = options
  self.output_directory = self.output_directory or options.output_directory
  self.ins     = inspector
  if options.only then
    for _,name in ipairs(options.only) do
      local elem = inspector:find(name)
      if elem.type == 'dub.Class' then
        local path = self.output_directory .. lk.Dir.sep .. elem.name .. '.cpp'
        local file = io.open(path, 'w')
        file:write(self:bindClass(elem))
        file:close()
      end
    end
  end
  private.copyDubFiles(self)
end

function lib:build(output, base_path, file_pattern, extra_flags)
  local dir = lk.Dir(base_path)
  local files = ''
  for f in dir:glob(file_pattern) do
    files = files .. ' ' .. f
  end
  local cmd = self.COMPILER .. ' ' 
  cmd = cmd .. self.COMPILER_FLAGS[private.platform()] .. ' '
  cmd = cmd .. (self.extra_flags or '') .. ' '
  cmd = cmd .. '-I' .. base_path .. ' '
  cmd = cmd .. '-o ' .. output .. ' '
  if extra_flags then
    cmd = cmd .. extra_flags .. ' '
  end
  cmd = cmd .. files
  local pipe = io.popen(cmd)
  print(pipe:read('*a'))
end

--- Return a string containing the Lua bindings for a class.
function lib:bindClass(class)
  if not self.class_template then
    -- path to current file
    local dir = lk.dir()
    self.class_template = dub.Template {path = dir .. '/lua/class.cpp'}
  end
  return self.class_template:run {class = class, self = self}
end

--- Create the body of the bindings for a given method/function.
function lib:functionBody(class, method)
  local res = ''
  if method.is_destructor then
    res = res .. private.getSelf(self, class, true)
    res = res .. string.format('if (*%s) delete *%s;\n', self.SELF, self.SELF)
    res = res .. string.format('*%s = NULL;\n', self.SELF)
    res = res .. 'return 0;'
  else
    local param_delta = 0
    if class and not class:isConstructor(method) then
      -- We need self
      res = res .. private.getSelf(self, class)
      param_delta = 1
    end
    if method.is_set_attr then
      res = res .. private.setAttrBody(self, param_delta)
    elseif method.is_get_attr then
      res = res .. private.getAttrBody(self, param_delta)
    else
      for param in method:params() do
        res = res .. private.getParam(self, method, param, param_delta)
      end
      res = res .. private.doCall(self, class, method)
      res = res .. private.pushReturnValue(self, class, method)
    end
  end
  return res
end

function lib:bindName(method)
  if method.bind_name then
    -- This is to let users define custom binding name (overwrite '+'
    -- methods for example).
    return method.bind_name
  end
  if method.destructor then
    return '__gc'
  elseif method.is_set_attr then
    return '__newindex'
  elseif method.is_get_attr then
    return '__index'
  else
    return method.name
  end
end
--=============================================== Methods that can be customized

function lib:customTypeAccessor(class)
  return private.checkPrefix(self) .. self.TYPE_ACCESSOR
end

function lib:libName(class)
  return string.gsub(class:fullname(), '::', '.')
end

--- Returns the method to use to retrieve a given type from Lua.
function lib:nativeTypeAccessor(method, ctype)
  local typ = method.db:resolveType(ctype) or ctype
  local acc = self.TYPE_TO_NATIVE[typ]
  if acc then
    -- if this method does never throw, we can use luaL_check...
    if method:neverThrows() then
      return 'luaL_check' .. acc
    else
      return 'dub_check' .. acc
    end
  end
end

--=============================================== PRIVATE

function private.checkPrefix(self)
  if self.options.exceptions == false then
    return 'luaL_'
  else
    return 'dub_'
  end
end
--- Find the userdata from the current lua_State. The userdata can
-- be directly passed as first parameter or it can be inside a table as
-- 'super'.
function private.getSelf(self, class, need_fullptr)
  local format
  if need_fullptr then
    -- Need userdata pointer, not just the pointer to object
    format = '%s **%s = ((%s**)%s(L, 1, "%s"));\n'
  else
    format = '%s *%s = *((%s**)%s(L, 1, "%s"));\n'
  end
  return string.format(format, class.name, self.SELF, class.name, self:customTypeAccessor(class), self:libName(class))
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

---
function private:doCall(class, method)
  local res = method.name .. '('
  local first = true
  for param in method:params() do
    if not first then
      res = res .. ', '
    else
      first = false
    end
    res = res .. param.name
  end
  res = res .. ');\n'
  if class:isConstructor(method) then
    res = 'new ' .. res
  else
    res = self.SELF .. '->' .. res
  end
  
  --- Return value
  local return_value = method.return_value
  if method.return_value then
    res = return_value.ctype .. ' retval__ = ' .. res
  end
  return res;
end

function private:pushReturnValue(class, method)
  local return_value = method.return_value
  if return_value then
    if return_value.ctype == self.LUA_STACK_SIZE_NAME then
      return 'return retval__;'
    else
      return private.pushValue(self, method, 'retval__', return_value.ctype)
    end
  else
    return 'return 0;'
  end
end

function private:pushValue(method, name, ctype)
  local typ = method.db:resolveType(ctype) or ctype
  local acc = self.TYPE_TO_NATIVE[typ]
  if acc then
    return string.format('lua_push%s(L, %s);\nreturn 1;', acc, name)
  else
    return string.format('dub_pushclass<%s>(%s);\nreturn 1;', ctype, name)
  end
end

function private:copyDubFiles()
  local dub_path = self.COPY_DUB_PATH
  if dub_path then
    local base_path = self.output_directory .. dub_path
    os.execute(string.format("mkdir -p '%s'", base_path))
    -- path to current file
    local dir = lk.dir()
    local dub_dir = dir .. '/lua/dub'
    os.execute(string.format("cp -r '%s' '%s'", dub_dir, base_path))
  end
end

-- Detect platform
function private.platform()
  local name = io.popen('uname'):read()
  if string.match(name, 'Darwin') then
    return 'macosx'
  else
    -- FIXME: detect other platforms...
    return 'linux'
  end
end

-- __newindex
function private:setAttrBody(class)
  return ''
  --[[
__newindex:

int h = dub_hash(key);
switch(key) {
  case 9824: /* a */
    float a = luaL_checknumber(L, 2);
    self.a = a;
    break;
  case 0984: /* b */
    break;
}            
--]]
end

function private:getAttrBody(class)
  return ''
end

