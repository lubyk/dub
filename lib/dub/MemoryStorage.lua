--[[------------------------------------------------------

  dub.MemoryStorage
  -----------------

  This is used to store all definitions in memory.

--]]------------------------------------------------------

local lib     = {
  type = 'dub.MemoryStorage', 
}
local DOXYGEN_VERSION = "1.7.5"
local private = {}
local parse   = {}
lib.__index   = lib
dub.MemoryStorage = lib

--=============================================== dub.Inspector()
setmetatable(lib, {
  __call = function(lib)
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
})

--=============================================== PUBLIC METHODS
-- Prepare database

-- Parse xml directory and find header files. This will allow
-- us to find definitions as needed.
function lib:parse(xml_dir, not_lazy, ignore_list)
  self.ignore = {}
  private.parseIgnoreList(self, nil, ignore_list)
  local xml_headers = self.xml_headers
  local dir = lk.Dir(xml_dir)
  -- Parse header (.h) content first
  for file in dir:glob('_8h.xml') do
    table.insert(xml_headers, {path = file, dir = xml_dir})
  end
  -- Parse namespace content
  for file in dir:glob('namespace_.*.xml') do
    table.insert(xml_headers, {path = file, dir = xml_dir})
  end
  if not_lazy then
    private.parseAll(self)
  end
end

function lib:findByFullname(name)
  -- split name components
  local parts = lk.split(name, '::')
  local current = self
  if self.name == parts[1] then
    -- remove pseudo-scope
    table.remove(parts, 1)
  end
  for i, part in ipairs(parts) do
    local child = self:findChildFor(current, part)
    if not child then
      return nil
    else
      current = private.resolveTypedef(self, child)
    end
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
        if not seen[elem.name] then
          seen[elem.name] = true
          return elem
        end
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
    end
  end
end

--- Return an iterator over all the headers of this library.
function lib:headers(classes)
  -- make sure we have parsed the headers
  private.parseHeaders(self)
  local co = coroutine.create(function()
    local seen = {}
    -- For each bound class
    for _, class in ipairs(classes) do
      local h = class.header
      if not seen[h] then
        coroutine.yield(h)
      end
    end
    -- For every global function
    for func in self:functions() do
      local h = func.header
      if not seen[h] then
        coroutine.yield(h)
      end
    end
    -- For every constant
    for i, h in ipairs(self.const_headers) do
      if not seen[h] then
        coroutine.yield(h)
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

--- Return an iterator over the variables of this class/namespace.
function lib:children()
  -- make sure we have parsed the headers
  private.parseHeaders(self)
  local co = coroutine.create(private.iterator)
  return function()
    local ok, elem = coroutine.resume(co, self.sorted_cache)
    if ok then
      return elem
    end
  end
end

--- Return an iterator over the superclasses of this class.
function lib:superclasses(parent)
  -- make sure we have parsed the headers
  private.parseHeaders(self)
  private.parseHeaders(parent)
  local co = co or coroutine.create(private.superIterator)
  return function()
    local ok, elem = coroutine.resume(co, self, parent)
    if ok then
      return elem
    end
  end
end

--- Return an iterator over the constants defined in this parent.
function lib:constants(parent)
  -- make sure we have parsed the headers
  private.parseHeaders(self)
  if parent then
    private.parseHeaders(parent)
  else
    parent = self
  end
  local co = co or coroutine.create(private.iterator)
  return function()
    local ok, elem = coroutine.resume(co, parent.constants_list)
    if ok then
      return elem
    end
  end
end

--- Return an iterator over the namespaces in root.
function lib:namespaces()
  -- make sure we have parsed the headers
  private.parseHeaders(self)
  local co = coroutine.create(private.iterator)
  return function()
    local ok, elem = coroutine.resume(co, self.namespaces_list)
    if ok then
      return elem
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
    elseif t.type == 'dub.Typedef' or
      t.type == 'dub.Enum' then
      -- alias type
      return t.ctype
    end
  end
end

function lib:resolveType(scope, name)
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
  return nil
end

function lib:fullname()
  return self.name
end

function lib:ignored(fullname)
  return self.ignore[fullname]
end
--=============================================== PRIVATE

function private.iterator(list)
  for _, child in ipairs(list) do
    coroutine.yield(child)
  end
end

function private.iteratorWithSuper(elem, key)
  private.iterator(elem[key])
  if elem.type == 'dub.Class' then
    for super in elem:superclasses() do
      for _, child in ipairs(super[key]) do
        if not child.no_inherit and
           not child.dtor and
           not child.static then
           coroutine.yield(child)
         end
      end
    end
  end
end

-- Iterate superclass hierarchy.
function private:superIterator(base)
  for _, name in ipairs(base.super_list) do
    local super = self:resolveType(base.parent or self, name)
    if not super then
      -- Yield an empty class that can be used for casting
      coroutine.yield(dub.Class {
        name = name,
        parent = base.parent,
        create_name = name .. ' *',
      })
    else
      if super then
        private.superIterator(self, super)
        coroutine.yield(super)
      end
    end
  end
  -- Find pseudo parents
  if base.dub.super then
    private.superIterator(self, {super_list = base.dub.super, dub = {}})
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

require 'lubyk'

--- Parse a header definition and return element 
-- identified by 'name' if found.
function parse:header(header, not_lazy)
  local data = xml.load(header.path)
  private.checkDoxygenVersion(data)
  data = data:find('compounddef')
  local h_path = data:find('location').file
  local base, h_file = lk.directory(h_path)
  header.file = h_path

  if data.kind == 'namespace' then
    local namespace = dub.Namespace {
      name   = data:find('compoundname')[1],
      parent = self,
      db     = self.db or self,
    }
    if self.cache[namespace.name] then
      -- do not add again
      self = self.cache[namespace.name]
    else
      self.cache[namespace.name] = namespace
      table.insert(self.namespaces_list, namespace)
      self = namespace
    end
  end
  self.header = h_path

  local opt = parse.opt(data)
  if opt then
    self:setOpt(opt)
  end
  parse.children(self, data, header, not_lazy)
  header.parsed = true
end

function parse:children(elem_list, header, not_lazy)
  local cache = self.cache
  local sorted_cache = self.sorted_cache
  -- First parse namespaces
  local collect = {}
  for _, elem in ipairs(elem_list) do
    if elem.xml == 'innernamespace' then
      table.insert(collect, 1, elem)
    else
      table.insert(collect, elem)
    end
  end
  -- Then parse the other elements.
  for _, elem in ipairs(collect) do
    local func = parse[elem.xml]
    if func then
      local child = func(self, elem, header, not_lazy)
      if child then
        cache[child.name] = child
        table.insert(sorted_cache, child)
      end
    else
      --print('skipping', elem.xml)
    end
  end
end

function parse:basecompoundref(elem, header)
  if elem.prot == 'public' then
    table.insert(self.super_list, elem[1])
  end
end

function parse:innernamespace(elem, header)
  local name = elem[1]
  if self.cache[name] then
    return nil
  end
  local namespace = dub.Namespace {
    name   = name,
    parent = self,
    db     = self.db or self,
  }
  table.insert(self.namespaces_list, namespace)
  return namespace
end

function parse:innerclass(elem, header, not_lazy)
  local name  = elem[1]
  local parent = self
  if string.match(name, '::') then
    -- inside a namespace or class
    parent = self.db or self
    local parts = lk.split(name, '::')
    local i = #parts
    name = parts[i]
    parts[i] = nil
    for i, part in ipairs(parts) do
      local child = parent.cache[part]
      if not child then
        assert(false, "Could not find parent '"..part.."' in '"..parent:fullname().."'.")
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
      {path = header.dir .. lk.Dir.sep .. elem.refid .. '.xml', dir = header.dir}
    },
  }
  if not parent.cache[class.name] then
    parent.cache[class.name] = class
    table.insert(parent.sorted_cache, class)
  end

  if not_lazy then
    private.parseAll(class)
  end
  
  -- Create --get--, --set-- and ~Destructor if needed.
  private.makeSpecialMethods(class)
end

function parse:templateparamlist(elem, header)
  -- change self from dub.Class to dub.CTemplate
  if self.type == 'dub.Class' then
    setmetatable(self, dub.CTemplate)
  end
  self.template_params = {}
  for _, param in ipairs(elem) do
    local name = private.flatten(param:find('type')[1])
    name = string.gsub(name, 'class ', '')
    name = string.gsub(name, 'typename ', '')
    table.insert(self.template_params, name)
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
      -- global enum
      table.insert(self.const_headers, header.file)
    end
  elseif kind == 'private-func' then
    -- private methods (to detect private dtor)
    for _, elem in ipairs(elem) do
      if elem.xml == 'memberdef' and
         elem.kind == 'function' then

        local name = elem:find('name')[1]
        if name == '~' .. self.name then
          -- Private dtor
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
      table.insert(sorted_cache, child)
    end
  else
    --print('skipping memberdef ', kind)
  end
end

function parse:variable(elem, header)
  local name = elem:find('name')[1]
  local definition = elem:find('definition')[1]
  if string.match(definition, '@') then
    -- ignore
    return nil
  end

  local child  = {
    name       = name,
    type       = 'dub.Attribute',
    ctype      = parse.type(elem),
    static     = elem.static == 'yes',
    argsstring = elem:find('argsstring')[1],
    definition = definition,
  }
  local dim = child.argsstring and string.match(child.argsstring, '^%[(.*)%]$')
  if dim then
    child.array_dim = dim
    -- Transform into two dub.Function name(int) and set_name(int)
    private.makeAttrArrayMethods(self, child)
  else
    self.has_variables = true
    table.insert(self.variables_list, child)
  end
  return child
end

function parse:enum(elem, header)
  local constants = self.constants_list
  local list = {}
  for _, v in ipairs(elem) do
    if v.xml == 'enumvalue' then
      local const = v:find('name')[1]
      table.insert(list, const)
      table.insert(constants, const)
    end
  end
  local name = elem:find('name')[1]
  local enum = {
    type     = 'dub.Enum',
    name     = name,
    location = private.makeLocation(elem, header),
    list     = list,
    ctype    = lib.makeType('int'),
  }
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
    name        = elem:find('name')[1],
    ctype       = parse.type(elem),
    desc        = (elem:find('detaileddescription') or {})[1],
    xml         = elem,
    definition  = elem:find('definition')[1],
    location    = private.makeLocation(elem, header),
    header_path = header.file,
  }
  typ.ctype.create_name = typ.name .. ' '
  return typ
end
    
parse['function'] = function(self, elem, header)
  local name = elem:find('name')[1]
  if self.is_class then
    if name == '~' .. self.name and self.dub.destroy == 'free' then
      return nil
    end
  end

  local argsstring = elem:find('argsstring')[1]
  if string.match(argsstring, '%.%.%.') or string.match(argsstring, '%[') then
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
    definition    = elem:find('definition')[1],
    argsstring    = argsstring,
    location      = private.makeLocation(elem, header),
    desc          = (elem:find('detaileddescription') or {})[1],
    static        = elem.static == 'yes' or (self.name == name),
    xml           = elem,
    member        = self.is_class,
    dtor          = self.is_class and name == '~' .. self.name,
    ctor          = self.is_class and name == self.name,
    dub           = parse.opt(elem) or {},
    pure_virtual  = elem.virt == 'pure-virtual',
  }

  if not child then
    -- invalid child
    return nil
  end

  if child.pure_virtual then
    self.abstract = true
    -- remove ctor
    for i, met in ipairs(self.functions_list) do
      if met.name == self.name then
        table.remove(self.functions_list, i)
        break
      end
    end
    self.cache[self.name] = nil
  elseif child.ctor and self.abstract then
    return nil
  end

  local template_params = elem:find('templateparamlist')
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
  if exist then
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
    table.insert(list, child)
    exist.overloaded = list
    -- not not add it again in cache
    return nil
  else
    local list = self.functions_list
    if list then
      table.insert(list, child)
    end
    return child
  end
end

function parse.params(elem, header)
  local res = {str = elem:find('argsstring')[1]}
  local i = 0
  local first_default
  for _, p in ipairs(elem) do
    if p.xml == 'param' then
      local param = parse.param(p, i+1)
      if param then
        i = i + 1
        table.insert(res, param)
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
  local declname = elem:find('declname')

  if not declname then
    -- unnamed parameter
    declname = string.format("p%d",position);
  else
    declname = declname[1]
  end
  
  local default = elem:find('defval')
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
  local ctype = elem:find('type')
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
  typename = string.gsub(typename, ' &', '')
  local create_name = typename
  typename = string.gsub(typename, ' %*', '')
  if typename == create_name then
    create_name = create_name .. ' '
  end
  typename = string.gsub(typename, 'const ', '')
  typename = string.gsub(typename, 'struct ', '')
  return {
    def   = str,
    name  = typename,
    create_name = create_name,
    ptr   = string.match(str, '%*'),
    const = string.match(str, 'const'),
    ref   = string.match(str, '&'),
  }
end

function private.makeLocation(elem, header)
  local loc  = elem:find('location')
  local file = lk.absToRel(loc.file, lfs.currentdir())
  return file .. ':' .. loc.line
end

-- self == class
function private:makeDestructor()
  if self.cache['~' .. self.name] or self.dub.destroy == 'free' then
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
  table.insert(self.functions_list, child)
  self.cache['~' .. name] = child
end

function private:makeSpecialMethods()
  -- Force destructor creation when needed.
  private.makeDestructor(self)
  private.makeGetAttribute(self)
  private.makeSetAttribute(self)
  if #self.super_list > 0 or self.dub.super then
    private.makeCast(self)
  end
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
  table.insert(self.functions_list, child)
  table.insert(self.sorted_cache, child)
  self.cache[child.name] = child
end

-- self == class
function private:makeGetAttribute()
  if not self.has_variables or
     self.cache[self.GET_ATTR_NAME] then
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
  table.insert(self.functions_list, child)
  table.insert(self.sorted_cache, child)
  self.cache[child.name] = child
end

function private:makeSetAttribute()
  if not self.has_variables or
     self.cache[self.SET_ATTR_NAME] then
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
  table.insert(self.functions_list, child)
  table.insert(self.sorted_cache, child)
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
  table.insert(self.functions_list, child)
  table.insert(self.sorted_cache, child)
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
  local opt = parse.opt(elem)
  if opt then
    self:setOpt(opt)
  end
end

local parseOpt = dub.OptParser.parse

function parse.opt(elem)
  -- This would not work if simplesect is not the first one
  local sect = elem:find('simplesect', 'kind', 'par')
  if sect then
    if (sect:find('title') or {})[1] == 'Bindings info:' then
      local txt = private.flatten(sect:find('para'))
      -- HACK TO RECREATE NEWLINES...
      txt = string.gsub(txt, ' ([a-z]+):', '\n%1:')
      return parseOpt(txt)
    end
  end
  return nil
end

-- function lib:find(scope, name)
--   return self:findByFullname(name) or 
--   self:findByFullname(elem.parent:fullname() .. '::' .. name)
-- end

function private:resolveTypedef(elem)
  if elem.type == 'dub.Typedef' then
    -- try to resolve and make a full class
    local name, types = string.match(elem.ctype.name, '^(.*) < (.+) >$')
    if name then
      types = lk.split(types, ', ')
      -- Try to find the template.
      local template = self:resolveType(elem.parent, name)
      if template and template.type == 'dub.CTemplate' then
        local class = template:resolveTemplateParams(elem.parent, elem.name, types)
        self.cache[class.name] = class
        table.insert(self.sorted_cache, class)
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
  local str = (data:find('doxygen') or {version='???'}).version
  if not checked_versions[str] then
    checked_versions[str] = true
    local pattern = '^'..string.gsub(DOXYGEN_VERSION, '%.', '%.')
    if not string.match(str, pattern) then
      print(string.format("WARNING: XML generated by Doxygen '%s'. This version of Dub was tested with version '%s'.", str, DOXYGEN_VERSION))
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
    table.insert(scopes, namespace)
  end
  return function()
    local ok, elem = coroutine.resume(co, scopes, 'functions_list')
    if ok then
      return elem
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
