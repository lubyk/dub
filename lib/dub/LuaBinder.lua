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
    unm   = true,
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

  if options.single_lib then
    -- default is to prefix mt types with lib name
    if options.lib_prefix == false then
      options.lib_prefix = nil
    else
      options.lib_prefix = options.lib_prefix or options.single_lib
    end
  end

  if options.lib_prefix == false then
    options.lib_prefix = nil
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
  else
    for elem in inspector:children() do
      if elem.type == 'dub.Class' then
        table.insert(bound, elem)
        private.bindElem(self, elem, options)
      end
    end
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

function private:callWithParams(class, method, param_delta, indent, custom, max_arg)
  local max_arg = max_arg or #method.params_list
  local res = ''
  for param in method:params() do
    if param.position > max_arg then
      break
    end
    res = res .. private.getParamVar(self, method, param, param_delta)
  end
  if custom then
    res = res .. custom
    if not string.match(custom, 'return[ ]+[^ ]') then
      res = res .. '\nreturn 0;'
    end
  else
    if method.array_get or method.array_set then
      local i_name = method.params_list[1].name
      res = res .. format('if (!%s || %s > %s) return 0;\n', i_name, i_name, method.array_dim)
    end
    if method.array_set then
      -- C array attribute set
      local i_name = method.params_list[1].name
      res = method.name .. '[' .. i_name .. '] = '
      res = res .. private.paramForCall(method.params_list[2]) .. ';\n'
      res = res .. 'return 0;'
    else
      local call = private.doCall(self, class, method, max_arg)
      res = res .. private.pushReturnValue(self, class, method, call)
    end
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
  local res = ''
  if method.dtor then
    res = res .. format('DubUserdata *userdata = ((DubUserdata*)dub_checksdata(L, 1, "%s"));\n', self:libName(class))
    if custom and custom.body then
      res = res .. custom.body
    else
      res = res .. 'if (userdata->gc) {\n'
      res = res .. format('  %sself = (%s)userdata->ptr;\n', class.create_name, class.create_name)
      if custom and custom.cleanup then
        res = res .. '  ' .. string.gsub(custom.cleanup, '\n', '\n  ')
      end
      res = res .. '  delete self;\n'
      res = res .. '}\n'
      res = res .. 'userdata->gc = false;\n'
      res = res .. 'return 0;'
    end
  else
    local param_delta = 0
    if not method.static then
      -- We need self
      res = res .. private.getSelf(self, class, method, method.is_get_attr)
      param_delta = 1
    end
    if method.has_defaults then
      -- We need arg count
    end
    if method.is_set_attr then
      res = res .. private.switch(self, class, method, param_delta, private.setAttrBody, class.attributes)
    elseif method.is_get_attr then
      res = res .. private.switch(self, class, method, param_delta, private.getAttrBody, class.attributes)
    elseif method.is_cast then
      res = res .. private.switch(self, class, method, param_delta, private.castBody, class.superclasses)
    elseif method.overloaded then
      local tree, need_top = self:decisionTree(method.overloaded)
      if need_top then
        res = res .. 'int top__ = lua_gettop(L);\n'
      end
      res = res .. private.expandTree(self, tree, class, param_delta, '')
    elseif not custom and method.has_defaults then
      res = res .. 'int top__ = lua_gettop(L);\n'
      local last, first = #method.params_list, method.first_default - 1
      for i=last, first, -1 do
        if i ~= last then
          res = res .. '} else '
        end
        if i == first then
          res = res .. '{\n'
        else
          res = res .. format('if (top__ >= %i) {\n', param_delta + i)
        end
        res = res .. '  ' .. private.callWithParams(self, class, method, param_delta, '  ', nil, i) .. '\n'
      end
      res = res .. '}'
    else
      res = res .. private.callWithParams(self, class, method, param_delta, '', custom and custom.body)
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

function private:expandTreeByType(tree, class, param_delta, indent, max_arg)
  local pos = tree.pos
  local res = ''
  local keys = {}
  local type_count = 0
  for k, v in pairs(tree.map) do
    -- collect keys, sorted by native type first
    -- because they are easier to detect with lua_type
    if self.NATIVE_TO_TLUA[k] then
      table.insert(keys, 1, k)
    else
      table.insert(keys, k)
    end
  end
  local last_key = #keys
  if last_key == 1 then
    -- single entry in decision, just go deeper
    return private.expandTreeByType(self, tree.map[keys[1]], class, param_delta, indent, max_arg)
  end

  res = res .. format('int type__ = lua_type(L, %i);\n', param_delta + pos)
  for i, type_name in ipairs(keys) do
    local elem = tree.map[type_name]
    if i > 1 then
      res = res .. '} else '
    end
    if i == last_key then
      res = res .. '{\n'
    else
      res = res .. format('if (%s) {\n', private.detectType(self, param_delta + pos, type_name))
    end
    if elem.type == 'dub.Function' then
      -- done
      res = res .. '  ' .. private.callWithParams(self, class, elem, param_delta, '  ', nil, max_arg) .. '\n'
    else
      -- continue expanding
      res = res .. '  ' .. private.expandTreeByType(self, elem, class, param_delta, '  ', max_arg) .. '\n'
    end
  end
  res = res .. '}'
  return string.gsub(res, '\n', '\n' .. indent)
end -- expandTreeByTyp

function private:expandTree(tree, class, param_delta, indent)
  local res = ''
  local keys = {}
  local type_count = 0
  for k, v in pairs(tree.map) do
    -- cast to number
    local nb = k + 0
    local done
    for i, ek in ipairs(keys) do
      -- insert biggest first
      if nb > ek then
        table.insert(keys, i, nb)
        done = true
        break
      end
    end
    if not done then
      -- insert at the end
      table.insert(keys, nb)
    end
  end

  local last_key = #keys
  if last_key == 1 then
    -- single entry in decision, just go deeper
    return private.expandTreeByType(self, tree.map[keys[1]..''], class, param_delta, indent)
  end

  for i, arg_count in ipairs(keys) do
    local elem = tree.map[arg_count..'']
    if i > 1 then
      res = res .. '} else '
    end
    if i == last_key then
      res = res .. '{\n'
    else
      res = res .. format('if (top__ >= %i) {\n', param_delta + arg_count)
    end
    if elem.type == 'dub.Function' then
      -- done
      res = res .. '  ' .. private.callWithParams(self, class, elem, param_delta, '  ', nil, arg_count) .. '\n'
    else
      -- continue expanding
      res = res .. '  ' .. private.expandTreeByType(self, elem, class, param_delta, '  ', arg_count) .. '\n'
    end
  end
  res = res .. '}'
  return string.gsub(res, '\n', '\n' .. indent)
end -- expandTree (by position)

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
function lib:header(header)
  return string.gsub(header, self.header_base .. '/', '')
end
--=============================================== Methods that can be customized

function lib:customTypeAccessor(method)
  if method:neverThrows() then
    return 'dub_checksdata_n'
  else
    return private.checkPrefix(self, method) .. self.TYPE_ACCESSOR
  end
end

-- Return the 'public' name to use for the element in the
-- bindings. This can be used to rename classes or namespaces.
function lib:name(elem)
  return elem.name
end

-- Return the 'lua_open' name to use for the element in the
-- bindings.
function lib:openName(elem)
  if not self.options.single_lib then
    return self:name(elem)
  else
    return string.gsub(self:libName(elem), '%.', '_')
  end
end

-- Return the 'public' name to use for a constant.
function lib:constName(name)
  return name
end

function lib:libName(elem)
  -- default name for dub.MemoryStorage
  if not elem.name then
    return '_G'
  else
    local res = ''
    while elem and elem.name do
      if res ~= '' then
        res = '.' .. res
      end
      res = (self:name(elem) or elem.name) .. res
      elem = elem.parent
    end
    return res
  end
end

function lib:luaType(parent, ctype)
  local rtype  = parent.db:resolveType(parent, ctype.name) or ctype
  local native = self.TYPE_TO_NATIVE[rtype.name]
  if native then
    if type(native) == 'table' then
      native.rtype = native
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
    local mt_name = self:libName(rtype)
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
function private.getSelf(self, class, method, need_mt)
  local nmt
  local fmt = '%s%s = *((%s*)%s(L, 1, "%s"%s));\n'
  if need_mt then
    -- Type accessor should leave metatable on stack.
    nmt = ', true'
  else
    nmt = ''
  end
  return format(fmt, class.create_name, self.SELF, class.create_name, self:customTypeAccessor(method), self:libName(class), nmt)
end

--- Prepare a variable with a function parameter.
function private:getParamVar(method, param, delta)
  local p = private.getParam(self, method, param, delta)
  local lua = param.lua
  local rtype = lua.rtype
  if lua.push then
    -- special push/pull type
    return p .. '\n'
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
  else
    base.resolved_for = 'lua'
  end
  if base.index_op then
    self:resolveTypes(base.index_op)
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
    res = format('*((%s*)%s(L, %i, "%s"))',
      rtype.create_name, type_method, param.position + delta, lua.mt_name)
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
  return res
end

function private.paramForCall(param)
  local lua = param.lua
  local res = ''
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
  return res
end

function private:doCall(class, method, max_arg)
  local max_arg = max_arg or #method.params_list
  local res
  if method.array_get then
    -- C array attribute get
    i_name = method.params_list[1].name
    res = method.name .. '[' .. i_name .. '-1]'
  else
    if method.ctor then
      res = string.sub(class.create_name, 1, -3) .. '('
    else
      res = method.name .. '('
    end
    local first = true
    for param in method:params() do
      if param.position > max_arg then
        break
      end
      local lua = param.lua
      if not first then
        res = res .. ', '
      else
        first = false
      end
      res = res .. private.paramForCall(param)
    end
    res = res .. ')'
  end
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
    local gc
    if not ctype.ptr then
      if method.is_get_attr then
        if ctype.const then
          if self.options.read_const_member == 'copy' then
            -- copy
            res = format('dub_pushudata(L, new %s(%s), "%s", true);', rtype.name, value, lua.mt_name)
          else
            -- cast
            res = format('dub_pushudata(L, const_cast<%s*>(&%s), "%s", false);', rtype.name, value, lua.mt_name)
          end
        else
          res = format('dub_pushudata(L, &%s, "%s", false);', value, lua.mt_name)
        end
      else
        -- Return value is not a pointer: we have a copy
        if method.parent.dub.destroy == 'free' then
          res = format('dub_pushfulldata<%s>(L, %s, "%s");', rtype.name, value, lua.mt_name)
        else
          res = format('dub_pushudata(L, new %s(%s), "%s", true);', rtype.name, value, lua.mt_name)
        end
      end
    else
      -- Return value is a pointer
      res = format('%s%sretval__ = %s;\n', 
        (ctype.const and 'const ') or '',
        rtype.create_name, value)
      if not method.ctor then
        res = res .. 'if (!retval__) return 0;\n'
      end
      if ctype.const then
        if self.options.read_const_member == 'copy' then
          -- copy
          res = res .. format('dub_pushudata(L, new %s(*retval__), "%s", true);', rtype.name, lua.mt_name)
        else
          -- cast
          res = res .. format('dub_pushudata(L, const_cast<%s*>(retval__), "%s", false);', rtype.name, lua.mt_name)
        end
      else
        -- We should only GC in constructor.
        if method.static or method.dub and method.dub.gc then
          res = res .. format('dub_pushudata(L, retval__, "%s", true);', lua.mt_name)
        else
          res = res .. format('dub_pushudata(L, retval__, "%s", false);', lua.mt_name)
        end
      end
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
  if not name or string.match(name, 'Darwin') then
    return 'macosx'
  else
    -- FIXME: detect other platforms...
    return 'linux'
  end
end

-- function body to set a variable.
function private:setAttrBody(method, attr, delta)
  if method.parent.custom_bindings then
    local custom
    custom = (method.parent.custom_bindings[method.parent.name] or {})[attr.name]
    if custom and custom.set then
      return custom.set
    end
  end

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
    else
      -- protect from gc
      res = res .. format('dub_protect(L, 1, %i, "%s");\n', param.position + delta, param.name)
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
  local name = super.create_name
  local res = ''
  res = res .. format('*retval__ = static_cast<%s>(self);\n', name)
  res = res .. 'return 1;'
  return res
end

-- function body to get a variable.
function private:getAttrBody(method, attr, delta)
  if attr.ctype.const and self.options.read_const_member == 'no' then
    return nil
  end
  if method.parent.custom_bindings then
    local custom
    custom = (method.parent.custom_bindings[method.parent.name] or {})[attr.name]
    if custom and custom.get then
      return custom.get
    end
  end

  local lua = self:luaType(method.parent, attr.ctype)
  attr.ctype.lua = lua
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
      res = res .. format('    if (DUB_ASSERT_KEY(key, "%s")) break;\n', self:libName(elem))
      res = res .. '    ' .. string.gsub(body, '\n', '\n    ') .. '\n  }\n'
    end
  end
  res = res .. '}\n'
  if method.is_set_attr then
    res = res .. 'if (lua_istable(L, 1)) {\n'
    -- <tbl> <'key'> <value>
    res = res .. '  lua_rawset(L, 1);\n'
    res = res .. '} else {\n'
    res = res .. '  luaL_error(L, KEY_EXCEPTION_MSG, key);\n'
    res = res .. '}\n'
    -- If <self> is a table, write there
  end
  res = res .. 'return 0;'
  return res
end

function private:bindElem(elem, options)
  if elem.type == 'dub.Class' then
    local path = self.output_directory .. lk.Dir.sep .. self:openName(elem) .. '.cpp'
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
      local lua = yaml.loadpath(yaml_file).lua
      for method_name, body in pairs(lua) do
        if type(body) == 'string' then
          -- strip last newline
          lua[method_name] = {body = string.sub(body, 1, -2)}
        else
          for k, v in pairs(body) do
            body[k] = string.sub(v, 1, -2)
          end
        end
      end
      custom[name] = lua
    end
  end
  self.custom_bindings = custom or {}
end

-- See lua_simple_test for the output of this tree.
function lib:decisionTree(list)
  local res = {count = 0, map = {}}
  local need_top = false
  for _, func in ipairs(list) do
    self:resolveTypes(func)
    for i=func.min_arg_size, #func.params_list do
      need_top = private.insertByTop(self, res, func, i) or need_top
    end
  end
  return res, need_top
end


function private:insertByTop(res, func, index)
  -- force string keys
  local top_key  = format('%i', index)
  local map      = res.map
  local list     = map[top_key]
  local need_top = false
  if list then
    -- we need to make decision on argument type
    if list.type == 'dub.Function' then
      local f = list
      list = {}
      map[top_key] = list
      private.insertByArg(self, list, f)
    end
    private.insertByArg(self, list, func, index)
  else
    map[top_key] = func
    res.count = res.count + 1
    need_top = need_top or res.count > 1
  end
  return need_top
end

local function hasMorePositions(skip_index, max_index)
  for i=1,max_index do
    if not skip_index[i] then
      return true
    end
  end
  return false
end
-- Insert a function into the hash, using the argument at the given
-- index to filter
function private:insertByArg(res, func, max_index, skip_index)
  -- First try existing positions in res (only get type for a few positions).
  if not res.map then
    -- first element inserted
    res.map = func
    res.list = {func}
    return
  elseif max_index == 0 or skip_index and not hasMorePositions(skip_index, max_index) then
    print("No more arguments to decide....", max_index)
    table.insert(res.list, func)
    for _, func in ipairs(res.list) do
      print(func.name .. func.argsstring)
    end
    return
  elseif res.map.type == 'dub.Function' then
    res.list = {res.map, func}
  else
    table.insert(res.list, func)
  end

  -- Build a count of differences by available index [1,max_index]
  local diff = {}
  for _, func in ipairs(res.list) do
    for i=1,max_index do
      if skip_index and skip_index[i] then
        -- already used, cannot use again
      else
        local lua = func.params_list[i].lua
        assert(lua, func.name .. func.argsstring)
        local type_name = (lua.type == 'userdata' and lua.rtype.name) or lua.type
        local d = diff[i]
        if not d then
          diff[i] = {position = i, count = 0, map = {}, weight = 0}
          d = diff[i]
        end
        local list = d.map[type_name]
        if not list then
          d.count = d.count + 1
          if lua.type ~= 'userdata' then
            d.weight = d.weight + 1
          end
          d.map[type_name] = func
        else
          if list.type == 'dub.Function' then
            list = {list, func}
            d.map[type_name] = list
          else
            table.insert(list, func)
          end
        end
      end
    end
  end

  -- Select best match
  local match
  for _, d in ipairs(diff) do
    if not match then
      match = d
    elseif d.weight > match.weight then
      match = d
    elseif d.weight == match.weight and d.count > match.count then
      match = d
    end
  end

  if match.count < #res.list then
    local skip_index = skip_index or {}
    skip_index[match.position] = true
    for k, elem in pairs(match.map) do
      if elem.type == 'dub.Function' then
        -- OK
      else
        local map = {}
        for _, func in ipairs(elem) do
          private.insertByArg(self, map, func, max_index, skip_index)
        end
        match.map[k] = map
      end
    end
  end

  res.pos = match.position
  res.map = match.map
end

function private:makeLibFile(lib_name, list)
  if not self.lib_template then
    local dir = lk.dir()
    self.lib_template = dub.Template {path = dir .. '/lua/lib.cpp'}
  end
  local res = self.lib_template:run {
    lib      = self.ins.db,
    lib_name = lib_name,
    classes  = list,
    self     = self,
  }

  local path = self.output_directory .. lk.Dir.sep .. lib_name .. '.cpp'
  local file = io.open(path, 'w')
  file:write(res)
  file:close()
end
