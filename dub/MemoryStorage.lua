--[[------------------------------------------------------

  # MemoryStorage

  (internal) This is used to store all definitions in memory.

--]]------------------------------------------------------
local lub     = require 'lub'
local dub     = require 'dub'
local xml     = require 'xml'
local pairs, ipairs, format,        gsub,        match,        insert  = 
      pairs, ipairs, string.format, string.gsub, string.match, table.insert
local lib     = lub.class 'dub.MemoryStorage'
local private = {}
local parse   = {}

local find = xml.find

-- Pattern to check for Doxygen version
local DOXYGEN_VERSIONS = {"1%.7%.", "1%.8%."}

-- Create a new storage engine for parsed content.
function lib.new()
  local self = {
    -- xml definitions list
    xml_headers     = {},
    -- .h header files
    headers_list    = {},
    cache           = {},
    sorted_cache    = {},
    functions_list  = {},
    constants_list  = {},
    const_headers   = {},
    resolved_cache  = {},
    namespaces_list = {},
  }
  -- Just so that we can pass the db as any scope.
  self.db = self
  return setmetatable(self, lib)
end

--=============================================== PUBLIC METHODS
-- Prepare database

-- Parse xml directory and find header files. This will allow
-- us to find definitions as needed.
function lib:parse(xml_dir, not_lazy, ignore_list)
  self.ignore = {}
  private.parseIgnoreList(self, nil, ignore_list)
  local xml_headers = self.xml_headers
  local dir = lub.Dir(xml_dir)
  -- Parse header (.h) content first
  for file in dir:glob('_8h.xml') do
    insert(xml_headers, {path = file, dir = xml_dir})
  end
  -- Parse namespace content
  for file in dir:glob('namespace.*.xml') do
    insert(xml_headers, {path = file, dir = xml_dir})
  end
  if not_lazy then
    private.parseAll(self)
  end
end

function lib:findByFullname(name)
  -- split name components
  local parts = type(name) == 'table' and name or lub.split(name, '::')
  local current = self
  for i, part in ipairs(parts) do
    local child = self:findChildFor(current, part)
    if not child then
      current = nil
      break
    else
      current = private.resolveTypedef(self, child)
    end
  end
  if not current and self.name == parts[1] then
    -- remove pseudo-scope
    table.remove(parts, 1)
    return self:findByFullname(parts)
  end
  return current
end

function lib:findChild(name)
  -- Any element at the root of the name space
  return self:findChildFor(self, name)
end

function lib:findChildFor(parent, name)
  -- Any element at the root of the name space
  if parent.is_scope or parent == self then
    return parent.cache[name] or private.parseHeaders(parent, name)
  end
end

--- Return an iterator over the functions of this class/namespace.
function lib:functions(parent)
  if not parent then
    return private.allGlobalFunctions(self)
  end
  -- make sure we have parsed the headers
  private.parseHeaders(parent)
  local co = coroutine.create(private.iteratorWithSuper)
  local seen = {}
  return function()
    local ok, elem
    -- For this first version, just ignore super methods with same name:
    -- no handling of overloaded functions through inheritance chain.
    while true do
      local ok, elem = coroutine.resume(co, parent, 'functions_list')
      if ok and elem then
        if parent.dub.destroy=="free" and elem.dtor then
          -- do nothing: no destructor should be generated in this case
        elseif not seen[elem.name] then
          seen[elem.name] = true
          return elem
        end
      elseif not ok then
        print(elem, debug.traceback(co))
      else
        return nil
      end
    end
  end
end

--- Return an iterator over the variables of this class/namespace.
function lib:variables(parent)
  -- make sure we have parsed the headers
  private.parseHeaders(parent)
  local co = coroutine.create(private.iteratorWithSuper)
  return function()
    local ok, elem = coroutine.resume(co, parent, 'variables_list')
    if ok then
      return elem
    else
      print(elem, debug.traceback(co))
    end
  end
end

--- Return an iterator over all the headers ever seen. Used when binding lib
-- file.
function lib:headers()
  -- make sure we have parsed the headers
  private.parseHeaders(self)
  local co = coroutine.create(function()
    -- For each bound class
    for _, h in ipairs(self.headers_list) do
      coroutine.yield(h)
    end
  end)
  return function()
    local ok, elem = coroutine.resume(co)
    if ok then
      return elem
    else
      print(elem, debug.traceback(co))
    end
  end
end

--- Return an iterator over the variables of this class/namespace.
function lib:children(parent)
  parent = parent or self
  -- make sure we have parsed the headers
  private.parseHeaders(parent)
  local co = coroutine.create(private.iterator)
  return function()
    local ok, elem = coroutine.resume(co, parent, 'sorted_cache')
    if ok then
      return elem
    else
      print(elem, debug.traceback(co))
    end
  end
end

--- Return an iterator over the superclasses of this class.
function lib:superclasses(parent)
  -- make sure we have parsed the headers
  private.parseHeaders(self)
  private.parseHeaders(parent)
  local co = coroutine.create(private.superIterator)
  return function()
    local ok, elem = coroutine.resume(co, self, parent)
    if ok then
      return elem
    else
      print(elem, debug.traceback(co))
    end
  end
end

--- Return an iterator over the constants defined in this parent.
function lib:constants(parent)
  local list
  -- make sure we have parsed the headers
  private.parseHeaders(self)
  if parent then
    private.parseHeaders(parent)
    list = {parent}
  else
    list = {self}
    for namespace in self:namespaces() do
      insert(list, namespace)
    end
  end
  local co = coroutine.create(function()
    local seen = {}
    -- For each namespace, get global constants
    for _, namespace in ipairs(list) do
      for _, enum in ipairs(namespace.constants_list) do
        local scope
        if enum.parent == self then
          scope = ''
        else
          scope = enum.parent.name
        end

        for _, name in ipairs(enum.list) do
          if not seen[name] then
            seen[name] = true
            coroutine.yield(name, scope)
          end
        end
      end
    end                                   
  end)
  return function()
    local ok, name, scope = coroutine.resume(co)
    if ok then
      return name, scope
    else
      print(name, debug.traceback(co))
    end
  end
end

function lib:hasConstants()
  if not self.checked_constants then
    self.checked_constants = true
    self.has_constants = self:constants()() and true
  end
  return self.has_constants
end

--- Return an iterator over the namespaces in root.
function lib:namespaces()
  -- make sure we have parsed the headers
  private.parseHeaders(self)
  local co = coroutine.create(private.iterator)
  return function()
    local ok, elem = coroutine.resume(co, self, 'namespaces_list')
    if ok then
      return elem
    else
      print(elem, debug.traceback(co))
    end
  end
end

local function resolveOne(self, scope, name)
  local base = scope:fullname()
  if base then
    base = base .. '::'
  else
    base = ''
  end
  local fullname = base .. name
  local t = self:findByFullname(fullname)
  if t then
    if t.type == 'dub.Class' or t.type == 'dub.CTemplate' then
      -- real type
      return t
    elseif t.type == 'dub.Typedef' then
      -- alias type
      return resolveOne(self, scope, t.ctype.name) or t.ctype
    elseif t.type == 'dub.Enum' then
      return t.ctype
    end
  end
end

function lib:resolveType(scope, name)
  name = name:gsub('%.', '::')
  local fullname = scope:fullname()
  if fullname then
    fullname = fullname .. '::' .. name
  else
    fullname = name
  end
  local t = self.resolved_cache[fullname]
  if t ~= nil then
    return t
  end
  -- Do we have a typedef or enum ?
  -- Look in nested scopes
  while scope do
    t = resolveOne(self, scope, name)
    if t then
      self.resolved_cache[fullname] = t
      return t
    end
    if scope.type == 'dub.Class' then
      -- Look in superclasses
      for super in scope:superclasses() do
        t = resolveOne(self, super, name)
        if t then
          self.resolved_cache[fullname] = t
          return t
        end
      end
    end
    scope = scope.parent
  end
  -- not found (could be a native type)
  self.resolved_cache[fullname] = false
  return false
end

function lib:fullname()
  return self.name
end

function lib:ignored(fullname)
  return self.ignore[fullname]
end
--=============================================== PRIVATE

function private.iterator(elem, key)
  local ignore = elem.ignore or {}
  for _, child in ipairs(elem[key]) do
    if not ignore[child.name] then
      coroutine.yield(child)
    end
  end
end

function private.iteratorWithSuper(elem, key)
  private.iterator(elem, key)
  local b_ignore = elem.ignore or {}
  if elem.type == 'dub.Class' then
    for super in elem:superclasses() do
      local ignore = super.ignore or {}
      for _, child in ipairs(super[key]) do
        if not ignore[child.name]   and
           not b_ignore[child.name] and
           not child.no_inherit     and
           not child.dtor           and
           not child.static         then
           coroutine.yield(child)
         end
      end
    end
  end
end

-- Iterate superclass hierarchy.
function private:superIterator(base, seen, allow_cast_class)
  -- Only iterate over a parent once
  local seen = seen or {}
  for _, name in ipairs(base.super_list) do
    local class
    local super = self:resolveType(base.parent or self, name)
    if not super and not allow_cast_class then
      -- Ignore empty class if not explicitely declared in
      -- @dub super statement.
    else
      if not super then
        -- Yield an empty class that can be used for casting
        dub.warn(5, "Class definition not found for '%s' (using empty class).", name)
        class = dub.Class {
          name = name,
          parent = base.parent,
          create_name = name .. ' *',
          db = self,
          should_cast = true,
        }
      else
        class = super
      end
      local fullname = class:fullname()
      if not seen[fullname] then
        coroutine.yield(class)
        seen[fullname] = true
        private.superIterator(self, class, seen)
      end
    end
  end

  -- Find pseudo parents
  if base.dub.super then
    private.superIterator(self, {super_list = base.dub.super, dub = {}}, seen, true)
  end
end

function private:parseAll()
  if self.parsed_headers then
    return
  end
  for i, header in ipairs(self.xml_headers) do
    if not header.parsed then
      parse.header(self, header, true)
    end
  end
  self.parsed_headers = true
end

-- Here 'self' can be the db (root) or a class.
function private:parseHeaders(name)
  local cache = self.cache
  if self.parsed_headers then
    return cache[name] 
  end
  local elem
  -- Look in all unparsed headers
  for i, header in ipairs(self.xml_headers) do
    if not header.parsed then
      parse.header(self, header)
      if name and cache[name] then
        return cache[name]
      end
    end
  end
  self.parsed_headers = true
end

local parser = xml.Parser(xml.Parser.TrimWhitespace)

--- Parse a header definition and return element 
-- identified by 'name' if found. 'self' can be the db or a dub.Class.
function parse:header(header, not_lazy)
  header.parsed = true
  local data = parser:loadpath(header.path)
  private.checkDoxygenVersion(data)
  data = find(data, 'compounddef')
  local h_path = find(data, 'location').file
  local base, h_file = lub.dir(h_path)
  header.file = h_path

  if data.kind == 'namespace' then
    local namespace = dub.Namespace {
      name   = find(data, 'compoundname')[1],
      parent = self,
      db     = self.db or self,
    }
    if match(namespace.name, '::') then
      -- Ignore: nested namespaces not supported now.
      dub.warn(5, "Ignoring nested namespace '%s'.", namespace.name)
      return
    end
    if self.cache[namespace.name] then
      -- do not add again
      self = self.cache[namespace.name]
    else
      self.cache[namespace.name] = namespace
      insert(self.namespaces_list, namespace)
      self = namespace
    end
  end
  self.header = h_path

  local opt = parse.opt(data)
  if opt then
    self:setOpt(opt)
  end
  parse.children(self, data, header, not_lazy)
end

function parse:children(elem_list, header, not_lazy)
  local cache = self.cache
  local sorted_cache = self.sorted_cache
  -- First parse namespaces
  local collect = {}
  for _, elem in ipairs(elem_list) do
    if elem.xml == 'innernamespace' then
      insert(collect, 1, elem)
    else
      insert(collect, elem)
    end
  end
  -- Then parse the other elements.
  for _, elem in ipairs(collect) do
    local func = parse[elem.xml]
    if func then
      local child = func(self, elem, header, not_lazy)
      if child then
        cache[child.name] = child
        insert(sorted_cache, child)
      end
    else
      --print('skipping', elem.xml)
    end
  end
end

-- This is parsed before inheritancegraph.
function parse:basecompoundref(elem, header)
  if elem.prot == 'public' then
    insert(self.super_list, elem[1])
  end
end

function parse:innernamespace(elem, header)
  local name = elem[1]

  if self.cache[name] then
    return nil
  end

  if self.type ~= 'dub.MemoryStorage' or
     match(name, '::') then
    -- Ignore nested namespaces for now.
    dub.warn(5, "Ignoring nested namespace '%s'.", name)
    return nil
  end

  local namespace = dub.Namespace {
    name   = name,
    parent = self,
    db     = self.db or self,
  }
  insert(namespace.const_headers, header.file)
  insert(self.namespaces_list, namespace)
  return namespace
end

function parse:innerclass(elem, header, not_lazy)
  local fullname = elem[1]
  local name = fullname
  local parent = self
  if match(fullname, '::') then
    -- inside a namespace or class
    parent = self.db or self
    local parts = lub.split(fullname, '::')
    local i = #parts
    name = parts[i]
    parts[i] = nil
    for i, part in ipairs(parts) do
      local child = parent.cache[part]
      if not child then
        dub.warn(5, "Ignoring class '%s'.", fullname)
        -- Ignore: this can be due to nested namespaces.
        return nil
        --assert(false, "Could not find parent '"..part.."' in '"..parent:fullname().."'.")
      end
      parent = child
    end
  end

  local class = dub.Class {
    -- self can be a class or db (root)
    db      = self.db or self,
    parent  = parent,
    name    = name,
    xml     = elem,
    xml_headers  = {
      {path = header.dir .. lub.Dir.sep .. elem.refid .. '.xml', dir = header.dir}
    },
  }
  if not parent.cache[class.name] then
    parent.cache[class.name] = class
    insert(parent.sorted_cache, class)
  end

  if not_lazy then
    private.parseAll(class)
  end
end

function parse:templateparamlist(elem, header)
  -- change self from dub.Class to dub.CTemplate
  if self.type == 'dub.Class' then
    setmetatable(self, dub.CTemplate)
  end
  self.template_params = {}
  for _, param in ipairs(elem) do
    local name = private.flatten(find(param, 'type')[1])
    name = gsub(name, 'class ', '')
    name = gsub(name, 'typename ', '')
    insert(self.template_params, name)
  end
end

function parse:sectiondef(elem, header)
  local kind = elem.kind
  if kind == 'public-func' or 
     -- methods
     kind == 'enum' or
     -- global enum
     kind == 'func' or
     -- global func
     kind == 'typedef' or
     -- typedef
     kind == 'public-attrib' or
     -- attributes
     kind == 'public-static-attrib' or
     -- static attributes
     kind == 'public-static-func' or
     -- static methods
     kind == 'public-type'
     -- enum, sub-types
     then
    parse.children(self, elem, header)
    if kind == 'enum' then
      -- global or namespace enum
      insert(self.const_headers, header.file)
    end
  elseif kind == 'private-func' or kind == 'protected-func' then
    -- private methods (to detect private ctor/dtor)
    for _, elem in ipairs(elem) do
      if elem.xml == 'memberdef' and
         elem.kind == 'function' then

        local name = find(elem, 'name')[1]
        if name == '~' .. self.name or
           name ==        self.name then
          -- Private dtor or ctor
          self.cache[name] = 'private'
        end
      end
    end
  end
end

function parse:memberdef(elem, header)
  local cache = self.cache
  local sorted_cache = self.sorted_cache
  local kind = elem.kind
  local func = parse[kind]
  if func then
    local child = func(self, elem, header)
    if child then
      cache[child.name] = child
      insert(sorted_cache, child)
    end
  else
    --print('skipping memberdef ', kind)
  end
end

function parse:variable(elem, header)
  local name = find(elem, 'name')[1]
  local definition = find(elem, 'definition')[1]
  if match(definition, '@') or
     -- ignore defined in class
     self.ignore[name] or
     -- ignore defined in inspector
     self.db.ignore[self.name .. '::' .. name] then
    -- ignore
    return nil
  end

  local child  = {
    name       = name,
    parent     = self,
    type       = 'dub.Attribute',
    ctype      = parse.type(elem),
    static     = elem.static == 'yes',
    argsstring = find(elem, 'argsstring')[1],
    definition = definition,
  }
  local dim = child.argsstring and match(child.argsstring, '^%[(.*)%]$')
  if dim then
    child.array_dim = dim
    -- Transform into two dub.Function name(int) and set_name(int)
    private.makeAttrArrayMethods(self, child)
  else
    self.has_variables = true
    insert(self.variables_list, child)
  end
  return child
end

function parse:enum(elem, header)
  local constants = self.constants_list
  local list = {}
  for _, v in ipairs(elem) do
    if v.xml == 'enumvalue' then
      local const = find(v, 'name')[1]
      insert(list, const)
    end
  end
  local name = find(elem, 'name')[1]
  local l, f = private.makeLocation(self.db, elem, header)
  local enum = {
    type     = 'dub.Enum',
    name     = name,
    parent   = self,
    location = l,
    list     = list,
    ctype    = lib.makeType('int'),
  }
  insert(constants, enum)
  if self.type == 'dub.Namespace' then
    insert(self.const_headers, f)
  end
  if self.name then
    enum.ctype.cast = self:fullname() .. '::' .. name
    enum.ctype.create_name = self:fullname() .. '::' .. name .. ' '
    enum.ctype.scope = self:fullname()
  else
    enum.ctype.cast = name
    enum.ctype.create_name = name .. ' '
  end

  self.has_constants = true
  return enum
end

function parse:typedef(elem, header)
  local typ = {
    type        = 'dub.Typedef',
    parent      = self, 
    db          = self.db or self,
    name        = find(elem, 'name')[1],
    ctype       = parse.type(elem),
    desc        = (find(elem, 'detaileddescription') or {})[1],
    xml         = elem,
    definition  = find(elem, 'definition')[1],
    location    = private.makeLocation(self.db, elem, header),
    header_path = find(elem, 'location').file,
  }
  if not typ.ctype then
    local loc = find(elem, 'location') or {}
    dub.warn(3, "ERROR: Could not find type for '%s' in (%s:%i).", typ.name, find(elem, 'location').file, loc.file, loc.line)
  else
    typ.ctype.create_name = typ.name .. ' '
  end
  return typ
end
    
parse['function'] = function(self, elem, header)
  local name = find(elem, 'name')[1]
  if self.is_class then
    if name == '~' .. self.name and self.dub.destroy == 'free' then
      return nil
    end
  end

  local argsstring = find(elem, 'argsstring')[1]
  if match(argsstring, '%.%.%.') or match(argsstring, '%[') then
    -- cannot deal with vararg or array types
    return nil
  end

  local child = dub.Function {
    -- self can be a class or db (root)
    db            = self.db or self,
    parent        = self,
    header        = header.file,
    name          = name,
    params_list   = parse.params(elem, header),
    return_value  = parse.retval(elem),
    definition    = find(elem, 'definition')[1],
    argsstring    = argsstring,
    location      = private.makeLocation(self.db, elem, header),
    desc          = (find(elem, 'detaileddescription') or {})[1],
    static        = elem.static == 'yes' or (self.name == name),
    xml           = elem,
    member        = self.is_class,
    dtor          = self.is_class and name == '~' .. self.name,
    ctor          = self.is_class and name == self.name,
    throw         = parse.throw(elem),
    dub           = parse.opt(elem) or {},
    pure_virtual  = elem.virt == 'pure-virtual',
  }

  local pure_virtual = elem.virt == 'pure-virtual'

  if pure_virtual then
    self.abstract = true
    -- remove ctor
    for i, met in ipairs(self.functions_list) do
      if met.name == self.name then
        table.remove(self.functions_list, i)
        break
      end
    end
    self.cache[self.name] = nil
  elseif child and child.ctor and self.abstract then
    return nil
  end

  if not child then
    -- invalid or ignored child
    return nil
  end


  local template_params = find(elem, 'templateparamlist')
  if template_params then
    parse.templateparamlist(child, template_params, header)
  end

  if child.template_params then
    -- we ignore templated functions for now
    return nil
  end

  if self.is_class and self.name == name then
    -- Constructor
    child.return_value = lib.makeType(self.create_name)
  elseif name == 'operator[]' then
    -- Special case for index method
    child.is_get_attr  = true
    child.index_op     = child
    child.name         = self.GET_ATTR_NAME
    child.cname        = self.GET_ATTR_NAME
    local exist = self.cache[self.GET_ATTR_NAME]
    if exist then
      exist.index_op = child
      return nil
    else
      child.index_op = child
    end
  end

  if name == 'operator-' and #child.params_list == 0 then
    -- unary minus trick
    name = 'operator- '
    child:setName(name)
  end

  local exist = self.cache[name]
  if exist and exist ~= 'private' then
    local list = exist.overloaded
    if not list then
      list = {exist}
    end
    for _,met in ipairs(list) do
      if met.sign == child.sign then
        -- do not add this new version
        return nil
      end
    end
    insert(list, child)
    exist.overloaded = list
    -- not not add it again in cache
    return nil
  else
    -- We do not have a previous function or we had a private ctor/dtor.
    local list = self.functions_list
    if list then
      insert(list, child)
    end
    return child
  end
end

function parse.params(elem, header)
  local res = {str = find(elem, 'argsstring')[1]}
  local i = 0
  local first_default
  for _, p in ipairs(elem) do
    if p.xml == 'param' then
      local param = parse.param(p, i+1)
      if param then
        i = i + 1
        insert(res, param)
        if param.default and not first_default then
          first_default = param.position
        end
      end
    end
  end
  res.first_default = first_default
  return res
end

function parse.param(elem, position)
  local declname = find(elem, 'declname')

  if not declname then
    -- unnamed parameter
    declname = format("p%d",position);
  else
    declname = declname[1]
  end

  local default = find(elem, 'defval')
  if default then
    default = private.flatten(default)
  end

  local ctype = parse.type(elem)
  if not ctype then
    -- type was 'void'
    return nil
  end

  return {
    type     = 'dub.Param',
    name     = declname,
    position = position,
    ctype    = ctype,
    default  = default,
  }
end

function parse.retval(elem)
  local ctype = parse.type(elem)
  if ctype and ctype.name ~= 'void' then
    return ctype
  end
end

-- Return a string like 'float' or 'MyFloat'.
function parse.type(elem)
  local ctype = find(elem, 'type')
  if type(ctype) == 'table' then
    ctype = private.flatten(ctype)
  end
  if ctype and ctype ~= 'void' then
    return lib.makeType(ctype)
  end
end

-- This can be used by binders to create types on the fly.
function lib.makeType(str)
  local typename = str
  typename = gsub(typename, ' &', '')
  local create_name = typename
  typename = gsub(typename, ' %*', '')
  if typename == create_name then
    create_name = create_name .. ' '
  end
  typename = gsub(typename, 'const ', '')
  typename = gsub(typename, 'struct ', '')
  return {
    def   = str,
    name  = typename,
    create_name = create_name,
    ptr   = match(str, '%*'),
    const = match(str, 'const'),
    ref   = match(str, '&'),
  }
end

function private:makeLocation(elem, header)
  local loc  = find(elem, 'location')
  local file = lub.absToRel(loc.file, lfs.currentdir())
  if not self.headers_list[file] then
    self.headers_list[file] = true
    lub.insertSorted(self.headers_list, file)
  end
  return file .. ':' .. loc.line, file
end

-- self == class
function private:makeConstructor()
  if self.cache[self.name] or self.abstract then
    -- Constructor not needed.
    return
  end
  local name = self.name
  local child = dub.Function {
    db            = self.db,
    parent        = self,
    name          = name,
    params_list   = {},
    return_value  = lib.makeType(self.create_name),
    definition    = name,
    argsstring    = '()',
    location      = '',
    desc          = name .. ' default constructor.',
    static        = true,
    xml           = nil,
    ctor          = true,
    member        = true,
  }
  -- constructor goes on top
  insert(self.functions_list, 1, child)
  insert(self.sorted_cache, 1, child)
  self.cache['~' .. name] = child
end

-- self == class
function private:makeDestructor()
  if self.cache['~' .. self.name]  or
     self.ignore['~' .. self.name] or
     self.dub.destroy == 'free' then
    -- Destructor not needed.
    return
  end
  local name = self.name
  local child = dub.Function {
    db            = self.db,
    parent        = self,
    name          = '~' .. name,
    params_list   = {},
    return_value  = nil,
    definition    = '~' .. name,
    argsstring    = '()',
    location      = '',
    desc          = name .. ' destructor.',
    static        = false,
    xml           = nil,
    dtor          = true,
    member        = true,
  }
  -- destructor goes on top list
  insert(self.functions_list, 1, child)
  insert(self.sorted_cache, 1, child)
  self.cache['~' .. name] = child
end

-- We pass custom_bindings so that we create get/set methods
-- even if we do not have public attributes but we have custom
-- code for these methods. This should be called just before
-- binding (once everything is parsed).
function lib.makeSpecialMethods(class, custom_bindings)
  if custom_bindings then
    -- Only run this when called from the bindings generator (once
    -- everything is parsed).
    private.makeConstructor(class)
  else
    custom_bindings = {}
  end
    
  if private.needsCast(class.db, class) then
    private.makeCast(class)
  end

  private.makeGetAttribute(class, custom_bindings[class.name] or {})
  private.makeSetAttribute(class, custom_bindings[class.name] or {})
  private.makeDestructor(class)
end

function private:needsCast(class)
  for _, name in ipairs(class.super_list) do
    local super = self:resolveType(class.parent or self, name)
    if super and super.should_cast then
      return true
    end
  end
  for _, name in ipairs(class.dub.super or {}) do
    local super = self:resolveType(class.parent or self, name)
    if super and super.should_cast then
      return true
    end
  end
  return false
end

-- self == class
function private:makeAttrArrayMethods(attr)
  local name = attr.name
  local child = dub.Function {
    db            = self.db,
    parent        = self,
    name          = attr.name,
    params_list   = {{
      type     = 'dub.Param',
      name     = 'i',
      position = 1,
      ctype    = lib.makeType('size_t'),
    }},
    return_value  = attr.ctype,
    definition    = 'Read ' .. name,
    argsstring    = '(size_t i)',
    location      = '',
    desc          = 'Read attribute '..name..' for ' .. self.name .. '.',
    static        = false,
    xml           = nil,
    -- Should not be inherited by sub-classes
    no_inherit    = true,
    member        = true,
    array_get     = true,
    array_dim     = attr.array_dim,
  }
  insert(self.functions_list, child)
  insert(self.sorted_cache, child)
  self.cache[child.name] = child

  child.overloaded = {child}
  local overloaded = child.overloaded
  child = dub.Function {
    db            = self.db,
    parent        = self,
    name          = attr.name,
    params_list   = {
      {
        type     = 'dub.Param',
        name     = 'i',
        position = 1,
        ctype    = lib.makeType('size_t'),
      }, 
      {
        type     = 'dub.Param',
        name     = 'v',
        position = 2,
        ctype    = attr.ctype,
      }, 
    },
    return_value  = nil,
    definition    = 'Write ' .. name,
    argsstring    = format('(size_t i, %s %s)', attr.ctype.name, name),
    location      = '',
    desc          = 'Write attribute '..name..' for ' .. self.name .. '.',
    static        = false,
    xml           = nil,
    -- Should not be inherited by sub-classes
    no_inherit    = true,
    member        = true,
    array_set     = true,
    array_dim     = attr.array_dim,
  }

  insert(overloaded, child)
end

-- self == class
function private:makeGetAttribute(custom_bindings)
  if self.cache[self.GET_ATTR_NAME] or
     (not self:hasVariables() and
      not custom_bindings.get_suffix
     ) then
    return
  end
  local name = self.GET_ATTR_NAME
  local child = dub.Function {
    db            = self.db,
    parent        = self,
    name          = name,
    params_list   = {},
    return_value  = nil,
    definition    = 'Get attributes ',
    argsstring    = '(key)',
    location      = '',
    desc          = 'Read attributes values for ' .. self.name .. '.',
    static        = false,
    xml           = nil,
    -- Should not be inherited by sub-classes
    no_inherit    = true,
    is_get_attr   = true,
    member        = true,
  }
  insert(self.functions_list, 1, child)
  insert(self.sorted_cache, 1, child)
  self.cache[child.name] = child
end

function private:makeSetAttribute(custom_bindings)
  if self.cache[self.SET_ATTR_NAME] or
     (not self:hasVariables() and
      not custom_bindings.set_suffix
     ) then
    return
  end
  local name = self.SET_ATTR_NAME
  local child = dub.Function {
    db            = self.db,
    parent        = self,
    name          = name,
    params_list   = {},
    return_value  = nil,
    definition    = 'Set attributes ',
    argsstring    = '(key, value)',
    location      = '',
    desc          = 'Set attributes values for ' .. self.name .. '.',
    static        = false,
    xml           = nil,
    -- Should not be inherited by sub-classes
    no_inherit    = true,
    is_set_attr   = true,
    member        = true,
  }
  insert(self.functions_list, 1, child)
  insert(self.sorted_cache, 1, child)
  self.cache[child.name] = child
end

function private:makeCast()
  if self.cache[self.CAST_NAME] then
    return
  end
  local name = self.CAST_NAME
  local child = dub.Function {
    db            = self.db,
    parent        = self,
    name          = name,
    params_list   = {},
    return_value  = nil,
    definition    = 'Cast ',
    argsstring    = '(class_name)',
    location      = '',
    desc          = 'Cast to superclass for ' .. self.name .. '.',
    static        = false,
    xml           = nil,
    -- Should not be inherited by sub-classes
    no_inherit    = true,
    is_cast       = true,
    member        = true,
  }
  insert(self.functions_list, 1, child)
  insert(self.sorted_cache, 1, child)
  self.cache[child.name] = child
end

function private.flatten(xml)
  if type(xml) == 'string' then
    return xml
  else
    local res = ''
    for i, e in ipairs(xml) do
      local f = private.flatten(e)
      if i > 1 and string.sub(f, 1, 1) ~= '(' then
        res = res .. ' ' .. f
      else
        res = res .. f
      end
    end
    return res
  end
end

function parse.detaileddescription(self, elem, header)
  local opt= parse.opt(elem)
  if opt then
    self:setOpt(opt)
  elseif opt == nil then
    print(format("Could not parse @dub settings: %s", xml.dump(elem)))
  end
end

local parseOpt = dub.OptParser.parse

function parse.opt(elem)
  -- This would not work if simplesect is not the first one
  local sect = find(elem, 'simplesect', 'kind', 'par')
  if sect then
    if (find(sect, 'title') or {})[1] == 'Bindings info:' then
      local txt = private.flatten(find(sect, 'para'))
      -- HACK TO RECREATE NEWLINES...
      txt = gsub(txt, ' ([A-Z_a-z]+):', '\n%1:')
      return parseOpt(txt)
    end
  end
  return false
end

-- function lib:find(scope, name)
--   return self:findByFullname(name) or 
--   self:findByFullname(elem.parent:fullname() .. '::' .. name)
-- end

function private:resolveTypedef(elem)
  if elem.type == 'dub.Typedef' then
    -- try to resolve and make a full class
    local name, types = match(elem.ctype.name, '^(.*) < (.+) >$')
    if name then
      types = lub.split(types, ', ')
      -- Try to find the template.
      local template = self:resolveType(elem.parent, name)
      if template and template.type == 'dub.CTemplate' then
        local class = template:resolveTemplateParams(elem.parent, elem.name, types)
        self.cache[class.name] = class
        insert(self.sorted_cache, class)
        class.typedef = elem.definition .. ';'
        class.header  = elem.header_path
        return class
      end
    end
  end
  return elem
end

local checked_versions = {}
function private.checkDoxygenVersion(data)
  local str = (find(data, 'doxygen') or {version='???'}).version
  if not checked_versions[str] then
    checked_versions[str] = true
    local ok = false
    local versions = {}
    for pat in ipairs(DOXYGEN_VERSIONS) do
      insert(versions, gsub(pat,'%%','')..'x')
      if match(str, '^'..pat) then
        ok = true
        break
      end
    end
    if not ok then
      dub.warn(4, "WARNING: XML generated by Doxygen '%s'. This version of Dub was tested with versions %s.", str, lub.join(versions, ', '))
    end
  end
end

function private.iteratorWithScopes(scopes, key)
  for _, scope in ipairs(scopes) do
    local list = scope[key]
    for _, elem in ipairs(list) do
      coroutine.yield(elem)
    end
  end
end

function private:allGlobalFunctions()
  -- make sure we have parsed the headers
  private.parseHeaders(self)
  local co = coroutine.create(private.iteratorWithScopes)
  local scopes = {self}
  for _, namespace in ipairs(self.namespaces_list) do
    insert(scopes, namespace)
  end
  return function()
    local ok, elem = coroutine.resume(co, scopes, 'functions_list')
    if ok then
      return elem
    else
      print(elem, debug.traceback(co))
    end
  end
end

function private:parseIgnoreList(base, list)
  if not list then
    return
  end
  if base then
    base = base .. '::'
  else
    base = ''
  end
  for k, name in pairs(list) do
    if type(name) == 'string' then
      self.ignore[base .. name] = true
    else
      private.parseIgnoreList(self, base .. k, name)
    end
  end
end

function parse.throw(elem)
  local ex = find(elem, 'exceptions')
  if ex then
    return lub.strip(ex[1])
  end
end

return lib
