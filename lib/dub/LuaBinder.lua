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
    size_t     = 'number',
    int        = 'number',
    ['signed int'] = 'number',
    bool       = 'boolean',
    ['char']   = 'string',
    ['std::string'] = {
      type   = 'std::string',
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
    },
  },
  -- Native Lua operators
  LUA_NATIVE_OP = {
    add   = true,
    sub   = true,
    mul   = true,
    div   = true,
    eq    = true,
    lt    = true,
    le    = true,
    call  = true,
    index = true,
  },
  -- Lua type constants
  NATIVE_TO_TLUA = {
    number = 'LUA_TNUMBER',
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
    self.header_base = lfs.currentdir()
    return setmetatable(self, lib)
  end
})

--=============================================== PUBLIC METHODS
-- Add xml headers to the database
function lib:bind(inspector, options)
  self.options = options
  if options.header_base then
    self.header_base = lk.absolutizePath(options.header_base)
  end

  if options.lib_prefix then
    -- This is the root of all classes.
    inspector.db.name = options.lib_prefix
  end
  self.output_directory = self.output_directory or options.output_directory
  private.parseCustomBindings(self, options.custom_bindings)
  self.ins = inspector
  local bound = {}
  if options.only then
    for _,name in ipairs(options.only) do
      local elem = inspector:find(name)
      if elem then
        table.insert(bound, elem)
        private.bindElem(self, elem, options)
      else
        print(string.format("Element '%s' not found.", name))
      end
    end
  end

  for elem in inspector:children() do
    table.insert(bound, elem)
    private.bindElem(self, elem, options)
  end

  if options.single_lib then
    private.makeLibFile(self, options.single_lib, bound)
  end
  private.copyDubFiles(self)
end

function lib:build(opts)
  local work_dir = opts.work_dir or lfs.currentdir()
  local files = ''
  for _, e in ipairs(opts.inputs) do
    files = files .. ' ' .. e
  end
  local flags = ' -I.'
  for _, e in ipairs(opts.includes or {}) do
    flags = flags .. ' -I' .. e
  end
  if opts.flags then
    flags = flags .. ' ' .. opts.flags
  end
  local cmd = 'cd ' .. work_dir .. ' && '
  cmd = cmd .. self.COMPILER .. ' ' 
  cmd = cmd .. self.COMPILER_FLAGS[private.platform()] .. ' '
  cmd = cmd .. flags .. ' '
  cmd = cmd .. '-o ' .. opts.output .. ' '
  cmd = cmd .. files
  if opts.verbose then
    print(cmd)
  end
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

function private:callWithParams(class, method, param_delta, indent, custom)
  local res = ''
  for param in method:params() do
    res = res .. private.getParamVar(self, method, param, param_delta)
  end
  if custom then
    res = res .. custom
  else
    local call = private.doCall(self, class, method)
    res = res .. private.pushReturnValue(self, class, method, call)
  end
  return string.gsub(res, '\n', '\n' .. indent)
end

--- Create the body of the bindings for a given method/function.
function lib:functionBody(class, method)
  -- Resolve C++ types to native lua types.
  self:resolveTypes(method)
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
    if method.has_defaults then
      -- We need arg count
      res = res .. 'int top__  = lua_gettop(L);\n'
    end
    if method.is_set_attr then
      res = res .. private.switch(self, class, method, param_delta, private.setAttrBody, class.attributes)
    elseif method.is_get_attr then
      res = res .. private.switch(self, class, method, param_delta, private.getAttrBody, class.attributes)
    elseif method.is_cast then
      res = res .. private.switch(self, class, method, param_delta, private.castBody, class.superclasses)
    elseif method.overloaded then
      local tree, need_top = self:decisionTree(method.overloaded)
      if need_top and not method.has_defaults then
        res = res .. 'int top__  = lua_gettop(L);\n'
      end
      res = res .. private.expandTree(self, tree, class, param_delta, 1, '')
    else
      res = res .. private.callWithParams(self, class, method, param_delta, '', custom)
    end
  end
  return res
end

function private:detectType(pos, type_name)
  local k = self.NATIVE_TO_TLUA[type_name]
  if k then
    return format('type__ == %s', k)
  else
    return format('dub_issdata(L, %i, "%s", type__)', pos, type_name)
  end
end

function private:expandTree(tree, class, param_delta, pos, indent)
  local res = ''
  local keys = {}
  local type_count = 0
  for k, v in pairs(tree) do
    if k == '_' then
      table.insert(keys, 1, k)
    else
      type_count = type_count + 1
      table.insert(keys, k)
    end
  end
  local got_type
  local last_key = #keys
  if last_key == 1 then
    -- single entry in decision, just go deeper
    return private.expandTree(self, tree[keys[1]], class, param_delta, pos + 1, indent)
  end

  local close  = '}'
  local if_ind = ''
  for i, k in ipairs(keys) do
    if k == '_' then
      res = res .. format('if (top__ < %i) {\n', param_delta + pos)
    else
      if i > 1 then
        res = res .. if_ind .. '} else '
      end
      if not got_type and type_count > 1 then
        if i > 1 then
          res = res .. '{\n'
          if_ind = '  '
          close = '  }\n' .. close
        end
        res = res .. if_ind .. format('int type__ = lua_type(L, %i);\n', param_delta + pos)
        got_type = true
      end
      if i == last_key then
        res = res .. '{\n'
      else
        res = res .. if_ind .. format('if (%s) {\n', private.detectType(self, param_delta + pos, k))
      end
    end
    met = tree[k]
    if met.type == 'dub.Function' then
      res = res .. if_ind .. '  ' .. private.callWithParams(self, class, met, param_delta, if_ind .. '  ') .. '\n'
    else
      res = res .. if_ind .. '  ' .. private.expandTree(self, met, class, param_delta, pos + 1, if_ind .. '  ') .. '\n'
    end
  end
  res = res .. close
  return string.gsub(res, '\n', '\n' .. indent)
end

function lib:bindName(method)
  local name = method.name
  if method.bind_name then
    -- This is to let users define custom binding name (overwrite '+'
    -- methods for example).
    return method.bind_name
  end
  if method.ctor then
    return 'new'
  elseif method.dtor then
    return '__gc'
  elseif method.is_set_attr then
    return '__newindex'
  elseif method.is_get_attr then
    return '__index'
  elseif string.match(name, '^operator') then
    local op = string.match(method.cname, '^operator_(.+)$')
    if self.LUA_NATIVE_OP[op] then
      return '__' .. op
    else
      -- remove ending 'e'
      return string.sub(op, 1, -2)
    end
  elseif name == '' then
    -- ??
  else
    return method.name
  end
end

-- Output the header for a class by removing the current path
-- or 'header_base',
function lib:header(class)
  return string.gsub(class.header, self.header_base .. '/', '')
end
--=============================================== Methods that can be customized

function lib:customTypeAccessor(method)
  if method:neverThrows() then
    return 'dub_checksdata_n'
  else
    return private.checkPrefix(self, method) .. self.TYPE_ACCESSOR
  end
end

function lib:libName(elem)
  -- default name for dub.MemoryStorage
  if not elem.name then
    return '_G'
  else
    return string.gsub(elem:fullname(), '::', '.')
  end
end

function lib:luaType(parent, ctype)
  local rtype  = parent.db:resolveType(parent, ctype.name) or ctype
  local native = self.TYPE_TO_NATIVE[rtype.name]
  if native then
    if type(native) == 'table' then
      return native
    else
      return {
        type  = native,
        -- Resolved type
        rtype = rtype,
      }
    end
  else
    -- userdata
    local mt_name
    if rtype.type == 'dub.Class' then
      mt_name = self:libName(rtype)
    else
      mt_name = rtype.name
    end
    return {
      type = 'userdata',
      -- Resolved type
      rtype   = rtype,
      mt_name = mt_name,
    }
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
  local p = private.getParam(self, method, param, delta)
  local lua = param.lua
  local rtype = lua.rtype
  if lua.push then
    -- special push/pull type
    return p .. '\n'
  elseif lua.type == 'userdata' then
    -- custom type
    return format('%s *%s = %s;\n', rtype.name, param.name, p)
  else
    -- native type
    return format('%s%s = %s;\n', rtype.create_name, param.name, p)
  end
end

--- Resolve all parameters and return value for Lua bindings.
function lib:resolveTypes(base)
  if base.resolved_for == 'lua' then
    -- done
    return
  end
  local list = base.overloaded or {base}
  for _, method in ipairs(list) do
    local parent = method.parent
    local sign = ''
    for i, param in ipairs(method.params_list) do
      if i > 1 then
        sign = sign .. ', '
      end
      param.lua = self:luaType(parent, param.ctype)
      if param.lua.type == 'userdata' then
        sign = sign .. param.lua.rtype.name
      else
        sign = sign .. param.lua.type
      end
    end
    if method.return_value then
      method.return_value.lua = self:luaType(parent, method.return_value)
    end
    method.lua_signature = sign
  end
  base.resolved_for = 'lua'
end

-- Retrieve a parameter and detect native type/userdata in param.
function private:getParam(method, param, delta)
  local res
  local lua = param.lua
  local ctype = param.ctype
  -- Resolved ctype
  local rtype = lua.rtype
  if lua.type == 'userdata' then
    -- userdata
    type_method = self:customTypeAccessor(method)
    res = format('*((%s**)%s(L, %i, "%s"))',
      rtype.name, type_method, param.position + delta, lua.mt_name)
  else
    -- native lua type
    local prefix = private.checkPrefix(self, method)
    if lua.pull then
      -- special accessor
      res = lua.pull(param.name, param.position + delta, prefix)
    elseif rtype.cast then
      res = format('(%s)%scheck%s(L, %i)', rtype.cast, prefix, lua.type, param.position + delta)
    else
      res = format('%scheck%s(L, %i)', prefix, lua.type, param.position + delta)
    end
  end
  if param.default then
    local default = param.default
    if rtype.scope then
      default = rtype.scope .. '::' .. default
    end
    res = format('top__ >= %i ? (%s) : (%s)', param.position + delta, res, default)
  end
  return res
end

---
function private:doCall(class, method)
  local res = method.name .. '('
  local first = true
  for param in method:params() do
    local lua = param.lua
    if not first then
      res = res .. ', '
    else
      first = false
    end
    if lua.cast then
      -- Special accessor
      res = res .. lua.cast(param.name)
    elseif lua.type == 'userdata' then
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
  res = res .. ')'
  if method.ctor then
    res = 'new ' .. res
  elseif method.static then
    res = class.name .. '::' .. res
  else
    res = self.SELF .. '->' .. res
  end
  
  return res;
end

function private:pushReturnValue(class, method, value)
  local res = ''
  local return_value = method.return_value
  if return_value then
    if return_value.name == self.LUA_STACK_SIZE_NAME then
      res = res .. 'return ' .. value .. ';'
    else
      res = res .. private.pushValue(self, method, value, return_value)
    end
  else
    res = res .. value .. ';\n'
    res = res .. 'return 0;'
  end
  return res
end

function private:pushValue(method, value, return_value)
  local res
  local lua = return_value.lua
  local ctype = return_value
  if lua.push then
    res = lua.push(value)
  elseif lua.type == 'userdata' then
    -- resolved value
    local rtype = lua.rtype
    if not ctype.ptr then
      if method.parent.dub.destroy == 'free' then
        res = format('dub_pushfulldata<%s>(L, %s, "%s");', rtype.name, value, lua.mt_name)
      else
        res = format('dub_pushudata(L, new %s(%s), "%s");', rtype.name, value, lua.mt_name)
      end
    else
      res = format('dub_pushudata(L, %s, "%s");', value, lua.mt_name)
    end
  else
    -- native type
    res = format('lua_push%s(L, %s);', lua.type, value)
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
  local lua = self:luaType(method.parent, param.ctype)
  param.lua = lua
  local p = private.getParam(self, method, param, delta)
  if type(lua.cast) == 'function' then
    -- TODO: move this into getParam ?
    res = res .. p
    p = lua.cast(name)
  elseif lua.type == 'userdata' then
    -- custom type
    if not param.ctype.ptr then
      p = '*' .. p
    end
  else
    -- native type
  end
  if attr.static then
    res = res .. format('%s::%s = %s;\n', method.parent.name, name, p)
  else
    res = res .. format('self->%s = %s;\n', name, p)
  end
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
  attr.ctype.lua = self:luaType(method.parent, attr.ctype)
  local accessor
  if attr.static then
    accessor = format('%s::%s', method.parent.name, attr.name)
  else
    accessor = format('self->%s', attr.name)
  end
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
  param.lua = self:luaType(method.parent, param.ctype)
  if method.index_op then
    -- operator[]
    res = res .. format('if (lua_type(L, %i) != LUA_TSTRING) {\n', delta + 1)
    method.index_op.name = 'operator[]'
    self:resolveTypes(method.index_op)
    res = res .. '  ' .. private.callWithParams(self, class, method.index_op, delta, '  ') .. '\n'
    res = res .. '}'
    if not class.has_variables then
      return res
    else
      res = res .. '\n'
    end
  end
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

-- See lua_simple_test for the output of this tree.
function lib:decisionTree(list)
  local res = {}
  local need_top = false
  for _, func in ipairs(list) do
    need_top = private.insertByArg(self, res, func) or need_top
  end
  return res, need_top
end


-- Insert a function into the hash, using the argument at the given
-- index to filter
function private:insertByArg(res, func, index)
  index = index or 1
  local param = func.params_list[index]
  local need_top = func.has_defaults
  if not param or func.first_default == index then
    need_top = true
    -- no param here
    if res._ then
      -- Already something without argument here. Cannot decide.
      print(string.format('Overloaded function conflict for %s: %s and %s.', res._.definition, res._.argsstring, func.argsstring))
    else
      res._ = func
    end
  end
  if param then
    local type_name
    if param.lua.type == 'userdata' then
      type_name = param.lua.rtype.name
    else
      type_name = param.lua.type
    end

    local list = res[type_name]
    if not list then
      res[type_name] = func
    else
      -- further discrimination is needed
      if list.type == 'dub.Function' then
        local f = list
        list = {}
        res[type_name] = list
        -- move previous func further down
        need_top = private.insertByArg(self, list, f, index + 1) or need_top
      end
      -- insert new func
      need_top = private.insertByArg(self, list, func, index + 1) or need_top
    end
  end
  return need_top
end

function private:makeLibFile(lib_name, list)
  if not self.lib_template then
    local dir = lk.dir()
    self.lib_template = dub.Template {path = dir .. '/lua/lib_open.cpp'}
  end
  local res = self.lib_template:run {
    list     = list,
    lib_name = lib_name,
    self     = self,
  }

  local path = self.output_directory .. lk.Dir.sep .. lib_name .. '.cpp'
  local file = io.open(path, 'w')
  file:write(res)
  file:close()
end
