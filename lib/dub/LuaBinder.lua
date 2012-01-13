--[[------------------------------------------------------

  dub.LuaBinder
  -------------

  Use the dub.Inspector to create Lua bindings.

--]]------------------------------------------------------
local format  = string.format
local lib     = {
  type = 'dub.LuaBinder',
  SELF = 'self',
  -- By default, we try to access userdata in field 'super'. This is not
  -- slower then checkudata if the element passed is a userdata.
  TYPE_ACCESSOR = 'checksdata',
  -- By default does an strcmp to ensure correct attribute key.
  ASSERT_ATTR_KEY = true,
  LUA_STACK_SIZE_NAME = 'DubStackSize',
  TYPE_TO_NATIVE = {
    double     = 'number',
    float      = 'number',
    int        = 'number',
    bool       = 'boolean',
    ['char']   = 'string',
    ['std::string'] = {
      -- Get value from Lua.
      pull   = function(name, position, prefix)
        return format('size_t %s_sz_;\nconst char *%s = %schecklstring(L, %i, &%s_sz_);',
                      name, name, prefix, position, name)
      end,
      -- Push value in Lua
      push   = function(name)
        return format('lua_pushlstring(L, %s.data(), %s.length());', name, name)
      end,
      -- Cast value
      cast   = function(name)
        return format('std::string(%s, %s_sz_)', name, name)
      end,
    }
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
  private.parseCustomBindings(self, options.custom_bindings)
  self.ins = inspector
  if options.only then
    for _,name in ipairs(options.only) do
      local elem = inspector:find(name)
      if elem then
        private.bindElem(self, elem, options)
      else
        print(string.format("Element '%s' not found.", name))
      end
    end
  end

  for elem in inspector:children() do
    private.bindElem(self, elem, options)
  end
  private.copyDubFiles(self)
end

function lib:build(output, base_path, file_pattern, extra_flags)
  local dir = lk.Dir(base_path)
  local files = ''
  if type(file_pattern) == 'string' then
    for f in dir:glob(file_pattern) do
      files = files .. ' ' .. f
    end
  else
    for _, f in ipairs(file_pattern) do
      files = files .. ' ' .. base_path .. '/' .. f
    end
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
  local res = pipe:read('*a')
  if res ~= '' then
    print(res)
  end
end

--- Return a string containing the Lua bindings for a class.
function lib:bindClass(class)
  if not self.class_template then
    -- path to current file
    local dir = lk.dir()
    self.class_template = dub.Template {path = dir .. '/lua/class.cpp'}
  end
  class.custom_bindings = self.custom_bindings
  local res = self.class_template:run {class = class, self = self}
  -- Cleanup
  class.custom_bindings = nil
  return res
end

--- Create the body of the bindings for a given method/function.
function lib:functionBody(class, method)
  local custom
  if class.custom_bindings then
    custom = (class.custom_bindings[method.parent.name] or {})[method.name]
  end
  if custom then
    -- strip last newline
    custom = string.sub(custom, 1, -2)
  end
  local res = ''
  if method.dtor then
    res = res .. private.getSelf(self, class, method, true)
    if custom then
      res = res .. custom
    else
      res = res .. format('if (*%s) delete *%s;\n', self.SELF, self.SELF)
      res = res .. format('*%s = NULL;\n', self.SELF)
      res = res .. 'return 0;'
    end
  else
    local param_delta = 0
    if not method.static then
      -- We need self
      res = res .. private.getSelf(self, class, method, false, method.is_get_attr)
      param_delta = 1
    end
    if method.is_set_attr then
      res = res .. private.switch(self, class, method, param_delta, private.setAttrBody, class.attributes)
    elseif method.is_get_attr then
      res = res .. private.switch(self, class, method, param_delta, private.getAttrBody, class.attributes)
    elseif method.is_cast then
      res = res .. private.switch(self, class, method, param_delta, private.castBody, class.superclasses)
    else
      for param in method:params() do
        local p, acc = private.getParamVar(self, method, param, param_delta)
        res = res .. p
        -- This is used later by doCall (cast)
        param.acc = acc
      end
      if custom then
        res = res .. custom
      else
        res = res .. private.doCall(self, class, method)
        res = res .. private.pushReturnValue(self, class, method)
      end
    end
  end
  return res
end

function lib:bindName(method)
  local name = method.name
  if method.bind_name then
    -- This is to let users define custom binding name (overwrite '+'
    -- methods for example).
    return method.bind_name
  end
  if method.dtor then
    return '__gc'
  elseif method.is_set_attr then
    return '__newindex'
  elseif method.is_get_attr then
    return '__index'
  elseif string.match(name, '^operator') then
    return '__' .. string.match(method.cname, '^operator_(.+)$')
  elseif name == '' then
    -- ??
  elseif not method.ctor and method.static and method.member then
    return method.parent.name .. '_' .. method.name
  else
    return method.name
  end
end
--=============================================== Methods that can be customized

function lib:customTypeAccessor(method)
  if method:neverThrows() then
    return 'dub_checksdata_n'
  else
    return private.checkPrefix(self, method) .. self.TYPE_ACCESSOR
  end
end

function lib:libName(class)
  return string.gsub(class:fullname(), '::', '.')
end

--- Returns the method to retrieve a given ctype from Lua.
function lib:nativeType(method, ctype)
  local typ = method.db:resolveType(ctype.name) or ctype
  return self.TYPE_TO_NATIVE[typ.name]
end

-- Return the method to retrieve a paramters with arguments.
function lib:nativeTypeAccessor(method, param, delta)
  local acc = self:nativeType(method, param.ctype)
  if acc then
    local prefix = private.checkPrefix(self, method)
    if type(acc) == 'table' then                      
      -- special accessor
      return acc.pull(param.name, param.position + delta, prefix), acc
    else
      return format('%scheck%s(L, %i)', prefix, acc, param.position + delta)
    end
  end
end

--=============================================== PRIVATE

-- if this method does never throw, we can use luaL_check...
function private:checkPrefix(method)
  if self.options.exceptions == false or
     method:neverThrows() then
    return 'luaL_'
  else
    return 'dub_'
  end
end
--- Find the userdata from the current lua_State. The userdata can
-- be directly passed as first parameter or it can be inside a table as
-- 'super'.
function private.getSelf(self, class, method, need_fullptr, need_mt)
  local fmt
  local nmt
  if need_fullptr then
    -- Need userdata pointer, not just the pointer to object
    fmt = '%s **%s = ((%s**)%s(L, 1, "%s"%s));\n'
  else
    fmt = '%s *%s = *((%s**)%s(L, 1, "%s"%s));\n'
  end
  if need_mt then
    -- Type accessor should leave metatable on stack.
    nmt = ', true'
  else
    nmt = ''
  end
  return format(fmt, class.name, self.SELF, class.name, self:customTypeAccessor(method), self:libName(class), nmt)
end

--- Prepare a variable with a function parameter.
function private:getParamVar(method, param, delta)
  local p, acc = private.getParam(self, method, param, delta)
  if acc then
    return p .. '\n', acc
  elseif acc == false then
    -- custom type
    return format('%s *%s = %s;\n', param.ctype.name, param.name, p), acc
  else
    return format('%s%s = %s;\n', param.ctype.create_name, param.name, p)
  end
end

function private:getParam(method, param, delta)
  local res, acc = self:nativeTypeAccessor(method, param, delta)
  if res then
    return res, acc
  else
    -- userdata
    local lib_name
    local class = method.db:findByFullname(param.ctype.name)
    if class then
      lib_name = self:libName(class)
    else
      lib_name = param.ctype.name
    end
    type_method = self:customTypeAccessor(method)
    return format('*((%s**)%s(L, %i, "%s"))',
      param.ctype.name, type_method, param.position + delta, lib_name), false
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
    if param.acc then
      -- Special accessor
      res = res .. param.acc.cast(param.name)
    elseif param.acc == false then
      -- custom type
      if param.ctype.ptr then
        res = res .. param.name
      else
        res = res .. '*' .. param.name
      end
    else
      -- native type
      res = res .. param.name
    end
  end
  res = res .. ');\n'
  if method.ctor then
    res = 'new ' .. res
  elseif method.static then
    res = class.name .. '::' .. res
  else
    res = self.SELF .. '->' .. res
  end
  
  --- Return value
  local ctype = method.return_value
  if ctype then
    local native = self:nativeType(method, ctype)
    --if not native and not ctype.ptr then
    --  res = ctype.create_name .. format('*retval__ = new %s(%s)',ctype.name, res)
    --else
      res = ctype.create_name .. 'retval__ = ' .. res
    --end
  end
  return res;
end

function private:pushReturnValue(class, method)
  local return_value = method.return_value
  if return_value then
    if return_value.name == self.LUA_STACK_SIZE_NAME then
      return 'return retval__;'
    else
      return private.pushValue(self, method, 'retval__', return_value)
    end
  else
    return 'return 0;'
  end
end

function private:pushValue(method, name, ctype)
  local res
  local ctype = method.db:resolveType(ctype.name) or ctype
  local accessor = self.TYPE_TO_NATIVE[ctype.name]
  if accessor then
    if type(accessor) == 'table' then
      res = accessor.push(name)
    else
      res = format('lua_push%s(L, %s);', accessor, name)
    end
  elseif not ctype.ptr then
    res = format('dub_pushudata(L, new %s(%s), "%s");', ctype.name, name, ctype.name)
  else
    res = format('dub_pushudata(L, %s, "%s");', name, ctype.name)
  end
  return res .. '\nreturn 1;'
end

function private:copyDubFiles()
  local dub_path = self.COPY_DUB_PATH
  if dub_path then
    local base_path = self.output_directory .. dub_path
    os.execute(format("mkdir -p '%s'", base_path))
    -- path to current file
    local dir = lk.dir()
    local dub_dir = dir .. '/lua/dub'
    os.execute(format("cp -r '%s' '%s'", dub_dir, base_path))
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

-- function body to set a variable.
function private:setAttrBody(method, attr, delta)
  local name = attr.name
  local res = ''
  local param = {
    name     = name,
    ctype    = attr.ctype,
    position = 2,
  }
  local p, acc = private.getParam(self, method, param, delta)
  if acc then
    res = res .. p
    p = acc.cast(name)
  elseif acc == false then
    -- custom type
    if not param.ctype.ptr then
      p = '*' .. p
    end
  else
    -- native type
  end
  res = res .. format('self->%s = %s;\n', name, p)
  res = res .. 'return 0;'
  return res
end

-- function body to set a variable.
function private:castBody(method, super, delta)
  if super.dub.cast == false then
    return
  end
  local name = super.name
  local res = ''
  res = res .. format('*retval__ = static_cast<%s*>(self);\n', name)
  res = res .. 'return 1;'
  return res
end

-- function body to get a variable.
function private:getAttrBody(method, attr, delta)
  local accessor = format('self->%s', attr.name)
  return private.pushValue(self, method, accessor, attr.ctype)
end

function private:switch(class, method, delta, bfunc, iterator)
  local res = ''
  -- get key
  local param = {
    name     = 'key',
    ctype    = dub.MemoryStorage.makeType('const char *'),
    position = 1,
  }
  res = res .. private.getParamVar(self, method, param, delta)
  if method.is_get_attr then
    res = res .. '// <self> "key" <mt>\n'
    res = res .. '// rawget(mt, key)\n'
    res = res .. 'lua_pushvalue(L, 2);\n'
    res = res .. '// <self> "key" <mt> "key"\n'
    res = res .. 'lua_rawget(L, -2);\n'
    res = res .. 'if (!lua_isnil(L, -1)) {\n'
    res = res .. '  // Found method.\n'
    res = res .. '  return 1;\n'
    res = res .. '} else {\n'
    res = res .. '  // Not in mt = attribute access.\n'
    res = res .. '  lua_pop(L, 2);\n'
    res = res .. '}\n'
  elseif method.is_cast then
    res = res .. 'void **retval__ = (void**)lua_newuserdata(L, sizeof(void*));\n'
  end

  -- get key hash
  local sz = dub.minHash(class, iterator, 'name')
  res = res .. format('int key_h = dub_hash(key, %i);\n', sz)
  -- switch
  res = res .. 'switch(key_h) {\n'
  for elem in iterator(class) do
    local body = bfunc(self, method, elem, delta)
    if body then
      local name = elem.name
      res = res .. format('  case %s: {\n', dub.hash(name, sz))
      -- get or set value
      if method.is_set_attr then
        res = res .. format('    if (DUB_ASSERT_KEY(key, "%s")) luaL_error(L, KEY_EXCEPTION_MSG, key);\n', name)
      else
        -- No error on bad read or cast: just return nil.
        res = res .. format('    if (DUB_ASSERT_KEY(key, "%s")) return 0;\n', name)
      end
      res = res .. '    ' .. string.gsub(body, '\n', '\n    ') .. '\n  }\n'
    end
  end
  res = res .. '  default:\n'
  if method.is_set_attr then
    res = res .. '    throw dub::Exception(KEY_EXCEPTION_MSG, key);\n'
  else
    res = res .. '    return 0;\n'
  end
  res = res .. '}'
  return res
end

function private:bindElem(elem, options)
  if elem.type == 'dub.Class' then
    local path = self.output_directory .. lk.Dir.sep .. elem.name .. '.cpp'
    local file = io.open(path, 'w')
    file:write(self:bindClass(elem))
    file:close()
  end
end

function private:parseCustomBindings(custom)
  if type(custom) == 'string' then
    -- This is a directory. Build table.
    local dir = lk.Dir(custom)
    custom = {}
    for yaml_file in dir:glob('%.yml') do
      local name = string.match(yaml_file, '([^/]+)%.yml$')
      local yml = yaml.loadpath(yaml_file)
      custom[name] = yml.lua
    end
  end
  self.custom_bindings = custom or {}
end
