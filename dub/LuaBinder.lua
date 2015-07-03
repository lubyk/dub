--[[------------------------------------------------------

  # LuaBinder

  Use the dub.Inspector to create Lua bindings.

--]]------------------------------------------------------
local lub     = require 'lub'
local dub     = require 'dub'
local yaml    = require 'yaml'

local PLAT    = lub.plat()

local pairs, ipairs, format,        gsub,        insert,       sub,        len = 
      pairs, ipairs, string.format, string.gsub, table.insert, string.sub, string.len
local lib     = lub.class('dub.LuaBinder', {
  SELF = 'self',
  -- By default, we try to access userdata in field 'super'. This is not
  -- slower then checkudata if the element passed is a userdata.
  TYPE_ACCESSOR = 'checksdata',
  -- By default does an strcmp to ensure correct attribute key.
  ASSERT_ATTR_KEY = true,
  LUA_STACK_SIZE_NAME = 'LuaStackSize',
  CHECK_TO_NATIVE = {
    -- default is to use the same type (number = 'number')
    integer      = 'number',
  },
  TYPE_TO_CHECK = {
    double       = 'number',
    float        = 'number',
    size_t       = 'integer',
    int          = 'integer',
    uint         = 'integer',
    unsigned     = 'integer',
    uint8        = 'integer',
    uint16       = 'integer',
    uint32       = 'integer',
    int8_t       = 'integer',
    int16_t      = 'integer',
    int32_t      = 'integer',
    uint8_t      = 'integer',
    uint16_t     = 'integer',
    uint32_t     = 'integer',
    char         = 'integer',
    short        = 'integer',
    LuaStackSize = 'integer',
    ['unsigned char']  = 'integer',
    ['signed int']     = 'integer',
    ['unsigned int']   = 'integer',
    ['signed short']   = 'integer',
    ['unsigned short'] = 'integer',

    bool       = 'boolean',

    ['char *'] = 'string',
    ['unsigned char *'] = 'string',
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
    number  = 'LUA_TNUMBER',
    boolean = 'LUA_TBOOLEAN',
    string  = 'LUA_TSTRING',
  },
  -- Relative path to copy dub headers and cpp files. Must be
  -- relative to the bindings output directory.
  COPY_DUB_PATH  = '',
  COMPILER       = 'g++',
  COMPILER_FLAGS = {
    macosx = '-O2 -fPIC -I/usr/local/include -g -Wall -Wl,-headerpad_max_install_names -flat_namespace -undefined suppress -dynamic -bundle -lstdc++',
    unix   = '-O2 -fPIC -I/usr/include/lua'..string.match(_VERSION, ' (.*)$')..' -g -Wall -Wl,-headerpad_max_install_names -shared -lstdc++',
  }
})
lib.COMPILER_FLAGS.linux = lib.COMPILER_FLAGS.unix
lib.COMPILER_FLAGS.win32 = lib.COMPILER_FLAGS.unix

local private = {}

--=============================================== dub.LuaBinder()
function lib.new(options)
  local self = {
    options         = options or {},
    extra_headers   = {},
    custom_bindings = {},
  }
  self.header_base = {'^'..private.escapePatternInPath(lfs.currentdir())..'/(.*)$'}
  return setmetatable(self, lib)
end

--=============================================== PUBLIC METHODS
-- Add xml headers to the database. All options in parenthesis are optional.
--
-- + output_directory: Path destination for generated C++ files.
-- + (single_lib):     Name of library when wrapping all classes into a single table.
--                     This creates a single library instead of one for each class.
--                     This name will be used as prefix for class metatables.
-- + (namespace):      Only parse elements in the given namespace. If this is set
--                     `single_lib` can be ommited and the namespace will be used as
--                     prefix.
-- + (no_prefix):      When this is set to `true`, do not add any prefix to
--                     class names.
-- + (header_base):    Part to remove in '#include' directives added to generated files.
--                     The default value is to remove the path to current directory.
-- + (extra_headers):  List of extra header includes to add in generated C++ files.
-- + (custom_bindings): Path to a directory containing yaml files with custom
--                     bindings. Can also be a table. See [Custom Bindings](dub.html#Custom-bindings).
function lib:bind(inspector, options)
  private.parseOptions(self, options)

  if not self.namespace and not options.no_prefix then
    -- This is the root of all classes.
    inspector.db.name = options.single_lib
  end

  self.output_directory = assert(options.output_directory, "Missing 'output_directory' setting.")

  self.ins = inspector
  local bound = {}
  if options.only then
    for _,name in ipairs(options.only) do
      local elem = inspector:find(name)
      if elem then
        lub.insertSorted(bound, elem, 'name')
        private.bindElem(self, elem, options)
      else
        print(format("Could not bind '%s' (not found).", name))
      end
    end
  else
    local ignore = {}
    if options.ignore then
      for _, name in ipairs(options.ignore) do
        ignore[name] = true
      end
    end
    
    private.bindAll(self, inspector, bound, ignore)
  end

  if options.single_lib then
    private.makeLibFile(self, options.single_lib, bound)
  end
  private.copyDubFiles(self)
end

-- Simple build system (mostly used for testing). The `opttions` table contains
-- the following entries:
-- + (work_dir):       Build working directory (default is current directory).
-- + (inputs):         List of C++ input files.
-- + (includes):       List of include paths.
-- + (flags):          List of extra compiler flags.
-- + (compiler):       List of compiler flags. Default is `self.COMPILER`.
-- + (compiler_flags): List of compiler flags. Default is
--                     `self.COMPILER_FLAGS[lub.plat()]`
-- + (verbose):        Print build commands if `true`.
function lib:build(options)
  local work_dir = options.work_dir or lfs.currentdir()
  local files = ''
  for _, e in ipairs(options.inputs) do
    files = files .. ' ' .. e
  end
  local flags = ' -I.'
  for _, e in ipairs(options.includes or {}) do
    flags = flags .. ' -I' .. lub.shellQuote(e)
  end
  if options.flags then
    flags = flags .. ' ' .. options.flags
  end
  local cmd = 'cd ' .. work_dir .. ' && '
  cmd = cmd .. (options.compiler or self.COMPILER) .. ' ' 
  cmd = cmd .. (options.compiler_flags or self.COMPILER_FLAGS[PLAT]) .. ' '
  cmd = cmd .. flags .. ' '
  cmd = cmd .. '-o ' .. options.output .. ' '
  cmd = cmd .. files
  if options.verbose then
    print(cmd)
  end
  local pipe = io.popen(cmd)
  local res = pipe:read('*a')
  if res ~= '' then
    print(res)
  end
end

--- Return a string containing the Lua bindings for a class.
-- The optional `options` table can contain:
-- + (header_base):    Part to remove in '#include' directives added to generated files.
--                     The default value is to remove the path to current directory.
-- + (extra_headers):  List of extra header includes to add in generated C++ files.
-- + (custom_bindings): Path to a directory containing yaml files with custom
--                     bindings. Can also be a table. See [Custom Bindings](dub.html#Custom-bindings).
function lib:bindClass(class, options)
  private.parseOptions(self, options)

  private.expandClass(self, class)
  if not self.class_template then
    -- path to current file
    self.class_template = lub.Template {path = lub.path('|assets/lua/class.cpp')}
  end
  return self.class_template:run {dub = dub, class = class, self = self}
end

function lib:addCustomTypes(list)
  for k, v in pairs(list) do
    if type(v) == 'table' and not v.type then
      v.type = k
    end
    self.TYPE_TO_CHECK[k] = v
  end
end

local strip = lub.strip
function lib:parseCustomBindings(custom)
  if type(custom) == 'string' then
    -- This is a directory. Build table.
    local dir = lub.Dir(custom)
    custom = {}
    for yaml_file in dir:glob('%.yml') do
      -- Class or global function name.
      local elem_name = string.match(yaml_file, '([^/]+)%.yml$')
      local lua = yaml.loadpath(yaml_file).lua
      for _, group in pairs(lua) do
        -- attributes, methods
        for name, value in pairs(group) do
          -- each attribute or method
          if type(value) == 'string' then
            -- strip last newline
            group[name] = {body = strip(value)}
          else
            for k, v in pairs(value) do
              value[k] = strip(v)
            end
          end
        end
      end
      custom[elem_name] = lua
    end
  end
  self.custom_bindings = custom or {}
end

--- Create the body of the bindings for a given method/function.
function lib:functionBody(parent, method)
  if not method then
    -- Just one parameter: global function. When creating method, we need the
    -- class because it could be a superclass method we are biding and thus the
    -- parent is not the correct one.
    method = parent
    parent = method.parent
  end

  -- Resolve C++ types to native lua types.
  self:resolveTypes(method)
  local custom = private.customMetBinding(self, parent, method)
  local res = ''

  if method.dtor then
    res = res .. format('DubUserdata *userdata = ((DubUserdata*)dub::checksdata_d(L, 1, "%s"));\n', self:libName(parent))
    if custom and custom.body then
      res = res .. custom.body
    else
      res = res .. 'if (userdata->gc) {\n'
      res = res .. format('  %sself = (%s)userdata->ptr;\n', parent.create_name, parent.create_name)
      if custom and custom.cleanup then
        res = res .. '  ' .. gsub(custom.cleanup, '\n', '\n  ')
      end
      local dtor = parent.dub.destructor or method.parent.dub.destructor
      if dtor then
        res = res .. format('  self->%s();\n', dtor)
      else
        res = res .. '  delete self;\n'
      end
      res = res .. '}\n'
      res = res .. 'userdata->gc = false;\n'
      res = res .. 'return 0;'
    end
  else
    local param_delta = 0
    if method.member then
      -- We need self
      res = res .. private.getSelf(self, parent, method, method.is_get_attr)
      param_delta = 1
    end
    if method.has_defaults then
      -- We need arg count
    end

    if method.is_set_attr then
      res = res .. private.switch(self, parent, method, param_delta, private.setAttrBody, parent.attributes)
    elseif method.is_get_attr then
      res = res .. private.switch(self, parent, method, param_delta, private.getAttrBody, parent.attributes)
    elseif method.is_cast then
      res = res .. private.switch(self, parent, method, param_delta, private.castBody, parent.superclasses)
    elseif method.overloaded then
      local tree, need_top = self:decisionTree(method.overloaded)
      if need_top then
        res = res .. 'int top__ = lua_gettop(L);\n'
      end
      res = res .. private.expandTree(self, tree, parent, param_delta, '')
    elseif method.has_defaults then
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
        res = res .. '  ' .. private.callWithParams(self, parent, method, param_delta, '  ', custom and custom['arg'..i], i) .. '\n'
      end
      res = res .. '}'
    else
      res = res .. private.callWithParams(self, parent, method, param_delta, '', custom and custom.body)
    end
  end
  return res
end

--=============================================== PRIVATE

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
      res = res .. 'self->' .. method.name .. '[' .. i_name .. '-1] = '
      res = res .. private.paramForCall(method.params_list[2]) .. ';\n'
      res = res .. 'return 0;'
    else
      local call = private.doCall(self, class, method, max_arg)
      res = res .. private.pushReturnValue(self, class, method, call)
    end
  end
  return gsub(res, '\n', '\n' .. indent)
end

function private:detectType(pos, type_name)
  local k = self.NATIVE_TO_TLUA[type_name]
  if k then
    return format('type__ == %s', k), false
  else
    return format('dub::issdata(L, %i, "%s", type__)', pos, type_name), true
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
      insert(keys, 1, k)
    else
      insert(keys, k)
    end
  end
  local last_key = #keys
  if last_key == 1 then
    -- single entry in decision, just go deeper
    return private.expandTreeByType(self, tree.map[keys[1]], class, param_delta, indent, max_arg)
  end

  res = res .. format('int type__ = lua_type(L, %i);\n', param_delta + pos)
  local ptr_for_pos = tree.ptr_for_pos
  if not ptr_for_pos then
    ptr_for_pos = {}
    tree.ptr_for_pos = ptr_for_pos
  end
  local clauses = {}

  -- Parse types once to make sure we declare the ptri__ pointers before
  -- we start using them in the type tests.
  for i, type_name in ipairs(keys) do
    if i == last_key then
      -- Never needed
      break
    end
    local clause, need_ptr = private.detectType(self, param_delta + pos, type_name)
    if need_ptr then
      local ptr_name = format('ptr%i__', param_delta + pos)
      if not ptr_for_pos[param_delta + pos] then
        ptr_for_pos[param_delta + pos] = ptr_name
        res = res .. format('void **%s;\n', ptr_name)
      end

      -- This ensures that we only use the ptr if there was a dub::issdata clause
      -- before (pointer is up-to-date).
      ptr_for_pos[format('%s-%i', type_name, param_delta + pos)] = ptr_name

      clauses[i] = format(' (%s = %s) ', ptr_name, clause)
    else
      clauses[i] = clause
    end
  end



  for i, type_name in ipairs(keys) do
    local elem = tree.map[type_name]
    if i > 1 then
      res = res .. '} else '
    end
    if i == last_key then
      res = res .. '{\n'
    else
      res = res .. format('if (%s) {\n', clauses[i])
    end
    if elem.type == 'dub.Function' then
      -- done
      elem.ptr_for_pos = ptr_for_pos
      res = res .. '  ' .. private.callWithParams(self, class, elem, param_delta, '  ', nil, max_arg) .. '\n'
    else
      -- continue expanding
      res = res .. '  ' .. private.expandTreeByType(self, elem, class, param_delta, '  ', max_arg) .. '\n'
    end
  end
  res = res .. '}'
  return gsub(res, '\n', '\n' .. indent)
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
        insert(keys, i, nb)
        done = true
        break
      end
    end
    if not done then
      -- insert at the end
      insert(keys, nb)
    end
  end

  local last_key = #keys
  if last_key == 1 then
    -- single entry in decision, just go deeper
    if not tree.map[format('%i',keys[1])] then
      print("MISSING KEY", keys[1])
      for k,v in pairs(tree.map) do
        print(k, v)
      end
    end
    return private.expandTreeByType(self, tree.map[format('%i',keys[1])], class, param_delta, indent)
  end

  for i, arg_count in ipairs(keys) do
    local elem = tree.map[format('%i',arg_count)]
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
  return gsub(res, '\n', '\n' .. indent)
end -- expandTree (by position)

function lib:bindName(method)
  local name = method.name
  local dname = method.dub.name
  if dname then
    -- This is to let users define custom binding name (overwrite '+'
    -- methods for example).
    return dname
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

-- Return an iterator over the header of the element plus any
-- extra header defined via 'extra_headers'.
function lib:headers(elem)
  local headers
  if elem then
    local fullname = elem:fullname()
    headers  = self.extra_headers[fullname] or {}
  else
    headers = self.extra_headers['::'] or {}
  end
  local seen = {}
  local co = coroutine.create(function()
    -- Extra headers
    for _, h in ipairs(headers) do
      if not seen[h] then
        coroutine.yield(h)
        seen[h] = true
      end
    end
    if elem then
      -- Class header
      if not seen[h] then
        coroutine.yield(elem.header)
        seen[h] = true
      end
    else
      -- No element, binding library
      for h in self.ins.db:headers() do
        -- Iterates over all bound_classes, global functions and
        -- constants.
        if not seen[h] then
          coroutine.yield(h)
          seen[h] = true
        end
      end
    end
  end)
  return function()
    local ok, elem = coroutine.resume(co)
    if ok then
      return elem
    end
  end
end
--=============================================== Methods that can be customized

-- Output the header for a class by removing the current path
-- or 'header_base',
function lib:header(header)
  local header = lub.absolutizePath(header)
  for _, base in ipairs(self.header_base) do
    local h = string.match(header, base)
    if h then
      return h
    end
  end
  return header
end

function lib:customTypeAccessor(method)
  if method:neverThrows() then
    return 'dub::checksdata_n'
  else
    return private.checkPrefix(self, method) .. self.TYPE_ACCESSOR
  end
end

-- Return the 'public' name to use for the element in the
-- bindings. This can be used to rename classes or namespaces. Instead
-- of rewriting this method, users can also use the 'name_filter' option.
function lib:name(elem)
  local func = self.options.name_filter
  if func then
    return func(elem)
  else
    return elem.name
  end
end

-- Return the 'lua_open' name to use for the element in the
-- bindings.
function lib:openName(elem)
  if not self.options.single_lib then
    return self:name(elem)
  else
    return gsub(self:libName(elem), '%.', '_')
  end
end

-- Return the 'public' name to use for a constant. Instead of rewriting this
-- method, users can also use the 'const_name_filter' option.
function lib:constName(name, enum)
  local func = self.options.const_name_filter
  if func then
    return func(name, enum)
  else
    return name
  end
end

-- Return the 'public' name to use for an attribute. Instead of rewriting this
-- method, users can also use the 'attr_name_filter' option.
function lib:attrName(elem)
  local func = self.options.attr_name_filter
  if func then
    return func(elem)
  else
    return elem.name
  end
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
      if elem.type == 'dub.Namespace' then
        -- no prefix before namespace
        break
      end
      elem = elem.parent
    end
    return res
  end
end

function lib:luaType(parent, ctype)
  local rtype = parent.db:resolveType(parent, ctype.name)

  if rtype and rtype.type == 'dub.Class' then
    -- userdata
    local mt_name = self:libName(rtype)
    return {
      type = 'userdata',
      -- Resolved type
      rtype   = rtype,
      mt_name = mt_name,
    }
  else
    -- If the database cannot resolve type, use provided ctype.
    rtype = rtype or ctype

    -- Is it a native lua type ?
    local check
    if ctype.ptr then
      check = self.TYPE_TO_CHECK[rtype.name..' *']
    else
      check = self.TYPE_TO_CHECK[rtype.name]
    end
    if check then
      if type(check) == 'table' then
        check.rtype = check
        return check
      else
        return {
          type  = self.CHECK_TO_NATIVE[check] or check,
          check = check,
          -- Resolved type
          rtype = rtype,
        }
      end
    else
      -- Not a native type and not known to the db: treat as 
      -- an unknown userdata type.
      local mt_name = self:libName(ctype)
      if mt_name ~= 'void' and mt_name ~= 'lua_State' then
        if rtype.ptr then
          dub.warn(5, "Using unknown type '%s *' (parent = %s).", mt_name, parent and parent.name or '??')
        else
          dub.warn(5, "Using unknown type '%s' (parent = %s).", mt_name, parent and parent.name or '??')
        end
      end
      -- Cache userdata type
      ctype.rtype = ctype.rtype or {
        type = 'userdata',
        -- Resolved type
        rtype   = private.makeType(ctype.name .. ' *'),
        mt_name = mt_name,
      }
      return ctype.rtype
    end
  end
end

local dummy_to_string_method = {
  neverThrows = function()
    return true
  end,
}
function lib:toStringBody(class)
  local res = ''
  -- We need self
  res = res .. private.getSelf(self, class, dummy_to_string_method, false)
  if class.dub.string_format then
    local args = class.dub.string_args
    if type(args) == 'table' then
      args = lub.join(args, ', ')
    end
    res = res .. format("lua_pushfstring(L, \"%s: %%p (%s)\", %s, %s);\n",
                        self:libName(class),
                        class.dub.string_format,
                        self.SELF,
                        args)
  else
    local fmt
    if class.dub.destroy == 'free' then
      fmt = "lua_pushfstring(L, \"%s: %%p (full)\", %s);\n"
    else
      fmt = "lua_pushfstring(L, \"%s: %%p\", %s);\n"
    end
    res = res .. format(fmt, self:libName(class), self.SELF)
  end
  return res
end

--=============================================== PRIVATE

-- if this method does never throw, we can use luaL_check...
function private:checkPrefix(method)
  if self.options.exceptions == false or
     method:neverThrows() then
    return 'luaL_'
  else
    return 'dub::'
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
  return format(fmt, class.create_name or class.name, self.SELF, class.create_name or class.name, self:customTypeAccessor(method), self:libName(class), nmt)
end

--- Prepare a variable with a function parameter.
function private:getParamVar(method, param, delta)
  if param.ctype.create_name == 'lua_State *' then
    if param.name == 'L' then
      return ''
    else
      return "lua_State * ".. param.name .. ' = L;\n'
    end
  end
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
    assert(method.params_list)
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
  local lua = param.lua
  local ctype = param.ctype
  -- Resolved ctype
  local rtype = lua.rtype
  if lua.mt_name and method.ptr_for_pos then
    local ptr = method.ptr_for_pos[format('%s-%i', lua.mt_name, delta + param.position)]
    if ptr then
      -- Only use ptr once (the first entry
      return format('*((%s*)%s)',
        rtype.create_name, ptr)
    end
  end
  
  if lua.type == 'userdata' then
    -- userdata
    type_method = self:customTypeAccessor(method)
    return format('*((%s*)%s(L, %i, "%s"))',
      rtype.create_name, type_method, param.position + delta, lua.mt_name)
  else
    -- native lua type
    local prefix = private.checkPrefix(self, method)
    if lua.pull then
      -- special accessor
      return lua.pull(param.name, param.position + delta, prefix)
    elseif rtype.cast then
      return format('(%s)%scheck%s(L, %i)', rtype.cast, prefix, lua.check, param.position + delta)
    else
      return format('%scheck%s(L, %i)', prefix, lua.check, param.position + delta)
    end
  end
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

function private:doCall(parent, method, max_arg)
  local max_arg = max_arg or #method.params_list
  local res
  if method.array_get then
    -- C array attribute get
    i_name = method.params_list[1].name
    res = method.name .. '[' .. i_name .. '-1]'
  else
    if method.ctor then
      res = string.sub(parent.create_name, 1, -3) .. '('
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
  elseif method.member then
    res = self.SELF .. '->' .. res
  elseif parent.is_scope then
    res = parent.name .. '::' .. res
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
      -- Call return value is not a pointer. This should never happen with
      -- a type that uses a custom push method.
      assert(not rtype.dub or not rtype.dub.push,
        format("Types with @dub 'push' setting should not be passed as values (%s).", method:fullname()))
      if method.is_get_attr then
        if ctype.const then
          if self.options.read_const_member == 'copy' then
            -- copy
            res = format('dub::pushudata(L, new %s(%s), "%s", true);', rtype.name, value, lua.mt_name)
          else
            -- cast
            res = format('dub::pushudata(L, const_cast<%s*>(&%s), "%s", false);', rtype.name, value, lua.mt_name)
          end
        else
          res = format('dub::pushudata(L, &%s, "%s", false);', value, lua.mt_name)
        end
      elseif return_value.ref then
        -- Return value is a reference.
        if ctype.const then
          if self.options.read_const_member == 'copy' then
            -- copy
            res = format('dub::pushudata(L, new %s(%s), "%s", true);', rtype.name, value, lua.mt_name)
          else
            -- cast
            res = format('dub::pushudata(L, const_cast<%s*>(&%s), "%s", false);', rtype.name, value, lua.mt_name)
          end
        else
          -- not const ref
          res = format('dub::pushudata(L, &%s, "%s", false);', value, lua.mt_name)
        end
      else
        -- Return by value.
        if method.parent.dub and method.parent.dub.destroy == 'free' then
          res = format('dub::pushfulldata<%s>(L, %s, "%s");', rtype.name, value, lua.mt_name)
        else
          -- Allocate on the heap.
          res = format('dub::pushudata(L, new %s(%s), "%s", true);', rtype.name, value, lua.mt_name)
        end
      end
    else
      -- Return value is a pointer.
      res = format('%s%sretval__ = %s;\n', 
        (ctype.const and 'const ') or '',
        rtype.create_name, value)
      if not method.ctor then
        res = res .. 'if (!retval__) return 0;\n'
      end
      local push_method = rtype.dub and rtype.dub.push
      local custom_push
      if push_method then
        custom_push = true
        push_method = 'retval__->'.. push_method
      else
        push_method = 'dub::pushudata'
      end
      if ctype.const then
        assert(not custom_push, format("Types with @dub 'push' setting should not be passed as const types (%s).", method:fullname()))
        if self.options.read_const_member == 'copy' then
          -- copy
          res = res .. format('%s(L, new %s(*retval__), "%s", true);',
                              push_method, rtype.name, lua.mt_name)
        else
          -- cast
          res = res .. format('%s(L, const_cast<%s*>(retval__), "%s", false);',
                              push_method, rtype.name, lua.mt_name)
        end
      else
        -- We should only GC in constructor.
        if method.ctor or (method.dub and method.dub.gc) then
          res = res .. format('%s(L, retval__, "%s", true);',
                              push_method, lua.mt_name)
        else
          res = res .. format('%s(L, retval__, "%s", false);',
                              push_method, lua.mt_name)
        end
      end
    end
  else
    -- native type
    res = format('lua_push%s(L, %s);', lua.type, value)
  end
  if string.match(res, '^return ') then
    return res
  else
    return res .. '\nreturn 1;'
  end
end

function private:copyDubFiles()
  local dub_path = self.COPY_DUB_PATH
  if dub_path then
    local base_path = self.output_directory .. dub_path
    os.execute(format("mkdir -p '%s'", base_path))
    -- path to current file
    local dub_dir = lub.path '|assets/lua/dub'
    for file in lfs.dir(dub_dir) do
      local res = lub.content(dub_dir .. '/' .. file)
      lub.writeall(base_path .. '/dub/' .. file, res, true)
    end
  end
end

-- function body to set a variable.
function private:setAttrBody(class, method, attr, delta)
  local custom = private.customAttrBinding(self, class, attr)
  if custom and custom.set then
    if custom.set:match(';') then
      -- Full custom binding definition
      return custom.set
    else
      -- Alias to a function call
      local met = class:method(custom.set) or attr.parent:method(custom.set)
      assert(met, format("Custom attribute binding for '%s' but '%s' method not found.", attr.name, custom.set))
      self:resolveTypes(met)
      return private.callWithParams(self, class, met, delta + 1, '')
    end
  end

  local name = attr.name
  local res = ''
  local param = {
    name     = name,
    ctype    = attr.ctype,
    position = 2,
  }
  local lua = self:luaType(class, param.ctype)
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
      res = res .. format('dub::protect(L, 1, %i, "%s");\n', param.position + delta, param.name)
    end
  else
    -- native type
  end
  if attr.static then
    res = res .. format('%s::%s = %s;\n', attr.parent.name, name, p)
  else
    res = res .. format('self->%s = %s;\n', name, p)
  end
  res = res .. 'return 0;'
  return res
end

-- function body to set a variable.
function private:castBody(class, method, super, delta)
  if not super.should_cast then
    return
  end
  local name = super.create_name
  local res = ''
  res = res .. format('*retval__ = static_cast<%s>(self);\n', name)
  res = res .. 'return 1;'
  return res
end

-- function body to get a variable.
function private:getAttrBody(class, method, attr, delta)
  if attr.ctype.const and self.options.read_const_member == 'no' then
    return nil
  end
  local custom = private.customAttrBinding(self, class, attr)
  if custom and custom.get then
    if custom.get:match(';') then
      -- Full custom binding definition
      return custom.get
    else
      -- Alias to a function call
      local met = class:method(custom.get) or attr.parent:method(custom.get)
      assert(met, format("Custom attribute binding for '%s' but '%s' method not found.", attr.name, custom.get))
      self:resolveTypes(met)
      return private.callWithParams(self, class, met, delta, '')
    end
  end

  local lua = self:luaType(class, attr.ctype)
  attr.ctype.lua = lua
  local accessor
  if attr.static then
    accessor = format('%s::%s', attr.parent.name, attr.name)
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
    ctype    = private.makeType('const char *'),
    position = 1,
  }
  param.lua = self:luaType(class, param.ctype)
  if method.index_op then
    -- operator[]
    res = res .. format('if (lua_type(L, %i) != LUA_TSTRING) {\n', delta + 1)
    method.index_op.name = 'operator[]'
    res = res .. '  ' .. private.callWithParams(self, class, method.index_op, delta, '  ') .. '\n'
    res = res .. '}\n'
    if not class:hasVariables() then
      res = res .. 'return 0;'
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

  local filter

  if method.is_cast then
    filter = function(elem)
      return self:libName(elem)
    end
  else
    filter = function(elem)
      return self:attrName(elem)
    end
  end

  local filtered_iterator = function()
    local function new_iterator()
      for elem in iterator(class) do
        local name = filter(elem)
        if name then
          coroutine.yield(name)
        end
      end
    end
    return coroutine.wrap(new_iterator)
  end

  -- get key hash
  local sz = dub.minHash(class, filtered_iterator)
  if not sz then
    -- get/set without any public variables but using
    -- suffix code
  else
    res = res .. format('int key_h = dub::hash(key, %i);\n', sz)
    -- switch
    res = res .. 'switch(key_h) {\n'
    for elem in iterator(class) do
      local lua_name = filter(elem)
      if lua_name then
        local body = bfunc(self, class, method, elem, delta)
        if body then
          res = res .. format('  case %i: {\n', dub.hash(lua_name, sz))
          -- get or set value
          res = res .. format('    if (DUB_ASSERT_KEY(key, "%s")) break;\n', lua_name)
          res = res .. '    ' .. gsub(body, '\n', '\n    ') .. '\n  }\n'
        end
      end
    end
    res = res .. '}\n'
  end

  local custom = self.custom_bindings[method.parent.name] or {}
  if method.is_set_attr then
    if custom.set_suffix then
      res = res .. custom.set_suffix
    else
      res = res .. 'if (lua_istable(L, 1)) {\n'
      -- <tbl> <'key'> <value>
      res = res .. '  lua_rawset(L, 1);\n'
      res = res .. '} else {\n'
      res = res .. '  luaL_error(L, KEY_EXCEPTION_MSG, key);\n'
      res = res .. '}\n'
      -- If <self> is a table, write there
    end
  elseif method.is_get_attr then
    if custom.get_suffix then
      res = res .. custom.get_suffix
    end
  end
  res = res .. 'return 0;'
  return res
end

function private:bindAll(parent, bound, ignore)
  for elem in parent:children() do
    if elem.type == 'dub.Class' then
      if not ignore[elem.name] and
         not (elem.dub.bind == false) then
        insert(bound, elem)
        private.bindElem(self, elem, options)
      end
    elseif elem.type == 'dub.Namespace' then
      if not ignore[elem.name] then
        private.bindAll(self, elem, bound, ignore)
      end
    end
  end
end

function private:bindElem(elem, options)
  if elem.type == 'dub.Class' then
    local path = self.output_directory .. lub.Dir.sep .. self:openName(elem) .. '.cpp'
    lub.writeall(path, self:bindClass(elem), true)
  end
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

function private:openOne(classes, i, res)
  local class = classes[i]
  local index = i + 1
  if not class then return end

  local nclas = classes[i + 1]
  insert(res, 'luaopen_'..self:openName(class)..'(L);')

  local name  = self:libName(class)
  local nname = nclas and self:libName(nclas)
  if nclas and sub(nname, 1, len(name)) == name then
    -- nclas is a sub-type of class
    -- <lib> <class>
    index = private.openOne(self, classes, index, res)
  end
  insert(res, '// <'..name..'>')
  insert(res, 'lua_setfield(L, -2, "'.. (class.dub.register or self:name(class)) ..'");')
  insert(res, '')
  return index
end

function lib:openClasses(classes, indent)
  indent = indent or '  '
  local res  = {}
  local i = 1
  while i do
    i = private.openOne(self, classes, i, res)
  end
  return lub.join(res, '\n'..indent)
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
    dub.warn(1, "No more arguments to decide (index=%i, parent=%s, function=%s)", max_index, func.parent.name, func.name)
    dub.warn(1, func.name .. func.argsstring)
    for _, func in ipairs(res.list) do
      dub.warn(1, func.name .. func.argsstring)
    end
    return
  elseif res.map.type == 'dub.Function' then
    res.list = {res.map, func}
  else
    insert(res.list, func)
  end

  -- Build a count of differences by available index [1,max_index]
  local diff = {}
  for _, func in ipairs(res.list) do
    for i=1,max_index do
      if skip_index and skip_index[i] then
        -- already used, cannot use again
      else
        local lua = func.params_list[i].lua
        local type_name = (lua.type == 'userdata' and lua.mt_name) or lua.type
        local d = diff[i..'']
        if not d then
          diff[i..''] = {position = i, count = 0, map = {}, weight = 0}
          d = diff[i..'']
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
            insert(list, func)
          end
        end
      end
    end
  end
  -- Select best match
  local match
  for _, d in pairs(diff) do
    if not match then
      match = d
    elseif d.weight > match.weight then
      match = d
    elseif d.weight == match.weight and d.count > match.count then
      match = d
    end
  end

  assert(match, func.name.. ' '.. func.header)
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
    self.lib_template = lub.Template {path = lub.path('|assets/lua/lib.cpp')}
  end
  self.bound_classes = list
  -- lib is a namespace
  local lib = self.namespace
  if not lib then
    -- lib is the global environment.
    lib = self.ins.db
    lib.has_constants = lib:hasConstants()
  end

  local res = self.lib_template:run {
    dub      = dub,
    lib      = lib,
    lib_name = lib_name,
    classes  = list,
    self     = self,
  }

  local openname = self.options.luaopen or lib_name
  local path = self.output_directory .. lub.Dir.sep .. openname .. '.cpp'
  lub.writeall(path, res, true)
end

function private:parseOptions(options)
  if not options then return end

  self.options = options
  if options.header_base then
    if type(options.header_base) == 'string' then
      options.header_base = {options.header_base}
    end
    self.header_base = {}
    for i, base in ipairs(options.header_base) do
      self.header_base[i] = '^'..private.escapePatternInPath(lub.absolutizePath(base))..'/(.*)$'
    end
  end
  self.extra_headers = {}
  private.parseExtraHeadersList(self, nil, options.extra_headers)

  if options.custom_bindings then
    self:parseCustomBindings(options.custom_bindings)
  end
end
  

function private:parseExtraHeadersList(base, list)
  if not list then
    return
  end
  for k, elem in pairs(list) do
    if type(k) == 'number' then
      local extra_list = self.extra_headers[base or '::']
      if not extra_list then
        extra_list = {}
        self.extra_headers[base or '::'] = extra_list
      end
      insert(extra_list, elem)
    elseif base then
      -- sub type
      private.parseExtraHeadersList(self, base..'::'..k, elem)
    else
      private.parseExtraHeadersList(self, k, elem)
    end
  end
end


local function getCustomBinding(custom_bindings, parent, key, elem)
  -- 1. current class
  local custom
  if parent.type == 'dub.MemoryStorage' then
    custom = custom_bindings._global
  else
    custom = custom_bindings[parent.name]
  end
  custom = custom and custom[key]
  custom = custom and custom[elem.name]
  if custom then
    return custom
  end
  -- 2. elem.parent
  custom = custom_bindings[elem.parent.name]
  custom = custom and custom[key]
  custom = custom and custom[elem.name]
  if custom then
    return custom
  end
end

-- Try to find a custom attribute binding. Search order:
-- 1. current class  (current class being bound: can be a sub-class)
-- 2. attr.parent    (class where the attribute/pseudo-attribute is defined)
function private:customAttrBinding(parent, attr)
  return getCustomBinding(self.custom_bindings, parent, 'attributes', attr)
end

-- Try to find custom binding definitions. Search order:
-- 1. current class   (current class being bound: can be a sub-class)
-- 2. method.parent   (class/namespace/db where the method is defined)
function private:customMetBinding(parent, method)
  return getCustomBinding(self.custom_bindings, parent, 'methods', method)
end

-- Add extra methods and attributes as needed by settings in 
-- custom_bindings.
function private:expandClass(class)
  -- Merge pseudo attributes in class variables.
  local custom = self.custom_bindings[class.name] or {}
  local attrs = custom.attributes
  if attrs then
    local list = class.variables_list
    local cache = class.cache
    for name, _ in pairs(attrs) do
      if not cache[name] then
        class.has_variables = true
        local attr = {
          type   = 'dub.PseudoAttribute',
          name   = name,
          parent = class,
          -- dummy type
          ctype = private.makeType('void'),
        }
        insert(list, attr)
        cache[name] = attr
      end
    end
  end
  dub.MemoryStorage.makeSpecialMethods(class, self.custom_bindings)
end

private.makeType = dub.MemoryStorage.makeType

-- When a path contains '-' or other special characters, escape them to form a
-- valid matching pattern.
function private.escapePatternInPath(path)
  local p = gsub(path, '[%(%)%.%%%+%-%*%?%[%^%$%]]', function(x)
    return '%'..x
  end)
  return p
end

return lib
