--[[------------------------------------------------------

  dub.MemoryStorage
  -----------------

  This is used to store all definitions in memory.

--]]------------------------------------------------------

local lib     = {type = 'dub.MemoryStorage'}
local private = {}
local parse   = {}
lib.__index   = lib
dub.MemoryStorage = lib

--=============================================== dub.Inspector()
setmetatable(lib, {
  __call = function(lib)
    local self = {
      -- xml definitions list
      xml_headers  = {},
      -- .h header files
      headers_list = {},
      cache   = {},
      sorted_cache = {},
    }
    return setmetatable(self, lib)
  end
})

--=============================================== PUBLIC METHODS
-- Prepare database

-- Parse xml directory and find header files. This will allow
-- us to find definitions as needed.
function lib:parse(xml_dir, not_lazy)
  local xml_headers = self.xml_headers
  local dir = lk.Dir(xml_dir)
  for file in dir:glob('%_8h.xml') do
    table.insert(xml_headers, {path = file, dir = xml_dir})
  end
  if not_lazy then
    private.parseAll(self)
  end
end

function lib:findByFullname(name)
  -- done
  -- split name components
  local parts = lk.split(name, '::')
  local current = self
  for i, part in ipairs(parts) do
    current = current:findChild(self, part)
  end
  return current
end

function lib:findChild(parent, name)
  local class_dest = string.match(name, '^~(.+)$')
  if class_dest then
    name = '_' .. class_dest
  end
  -- Any element at the root of the name space
  local child = parent.cache[name] or private.parseHeaders(parent, name)
  if not child and class_dest then
    -- Destructor not always declared in header file. Build as needed.
    child = dub.Function {
      db            = parent.db,
      name          = name,
      sorted_params = {},
      return_value  = nil,
      definition    = '~' .. class_dest .. '()',
      argsstring    = '',
      location      = '',
      desc          = class_dest .. ' destructor.',
      static        = false,
      xml           = nil,
    }
    table.insert(parent.sorted_cache, child)
    parent.cache[name] = child
  end
  return child
end

--- Return an iterator over the functions of this class/namespace.
function lib:functions(parent)
  -- make sure we have parsed the headers
  private.parseHeaders(parent)
  if parent.type == 'dub.Class' then
    -- Force destructor creation.
    self:findChild(parent, '~' .. parent.name)
  end
  local co = coroutine.create(private.functionsIterator)
  return function()
    local ok, value = coroutine.resume(co, parent)
    if ok then
      return value
    end
  end
end

--- Return an iterator over the functions of this class/namespace.
function lib:headers(parent)
  -- make sure we have parsed the headers
  private.parseHeaders(parent)
  local co = coroutine.create(private.headersIterator)
  return function()
    local ok, value = coroutine.resume(co, parent)
    if ok then
      return value
    end
  end
end

function lib:resolveType(name)
  -- Do we have a typedef ?
  local td = self:findByFullname(name)
  if td then
    return td.ctype
  end
end
--=============================================== PRIVATE

function private.headersIterator(parent)
  for _, child in ipairs(parent.headers_list) do
    coroutine.yield(child)
  end
end

function private.functionsIterator(parent)
  for _, child in pairs(parent.sorted_cache) do
    if child.type == 'dub.Function' then
      coroutine.yield(child)
    end
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
function parse.header(self, header, not_lazy)
  local data = xml.load(header.path):find('compounddef')
  local h_path = data:find('location').file
  local base, h_file = lk.directory(h_path)
  table.insert(self.headers_list, {path = h_file})

  parse.children(self, data, header, not_lazy)
  header.parsed = true
end

function parse.children(self, parent, header, not_lazy)
  local cache = self.cache
  local sorted_cache = self.sorted_cache
  for _, elem in ipairs(parent) do
    local func = parse[elem.xml]
    if func then
      local obj = func(self, elem, header, not_lazy)
      if obj then
        cache[obj.name] = obj
        table.insert(sorted_cache, obj)
      end
    else
      --print('skipping', elem.xml)
    end
  end
end

function parse.innernamespace(self, elem, header)
  return {
    type = 'dub.Namespace',
    name = elem[1]
  }
end

function parse.innerclass(parent, elem, header, not_lazy)
  local class = dub.Class {
    -- parent can be a class or db (root)
    db      = parent.db or parent,
    cache   = {},
    sorted_cache = {},
    name    = elem[1],
    xml     = elem,
    headers_list = {},
    xml_headers  = {
      {path = header.dir .. lk.Dir.sep .. elem.refid .. '.xml', dir = header.dir}
    },
  }
  if not_lazy then
    private.parseAll(class)
  end
  return class
end

function parse.sectiondef(self, elem, header)
  if elem.kind == 'public-func' or elem.kind == 'typedef' then
    parse.children(self, elem, header)
  end
end

function parse.memberdef(self, elem, header)
  local func = parse[elem.kind]
  if func then
    local obj = func(self, elem, header)
    if obj then
      self.cache[obj.name] = obj
      table.insert(self.sorted_cache, obj)
    end
  else
    --print('skipping memberdef', elem.kind)
  end
end

function parse.typedef(self, elem, header)
  return {
    type    = 'dub.Typedef',
    name    = elem:find('name')[1],
    ctype   = parse.type(elem),
    desc    = (elem:find('detaileddescription') or {})[1],
    xml     = elem,
  }
end
    
parse['function'] = function(parent, elem, header)
  local name = elem:find('name')[1]
  return dub.Function {
    -- parent can be a class or db (root)
    db            = parent.db or parent,
    name          = name,
    sorted_params = parse.params(elem, header),
    return_value  = parse.retval(elem),
    definition    = elem:find('definition')[1],
    argsstring    = elem:find('argsstring')[1],
    location      = private.makeLocation(elem, header),
    desc          = (elem:find('detaileddescription') or {})[1],
    static        = elem.static == 'yes' or (parent and parent.name == name),
    xml           = elem,
  }
end

function parse.params(elem, header)
  local res = {str = elem:find('argsstring')[1]}
  local i = 0
  for _, param in ipairs(elem) do
    if param.xml == 'param' then
      i = i + 1
      table.insert(res, parse.param(param, i))
    end
  end
  return res
end

function parse.param(elem, position)
  return {
    position = position,
    type     = 'dub.Param',
    ctype    = parse.type(elem),
    name     = elem:find('declname')[1],
  }
end

function parse.retval(elem)
  local ctype = parse.type(elem)
  if ctype and ctype ~= 'void' then
    return {
      type     = 'dub.Retval',
      ctype    = ctype,
    }
  end
end

-- Return a string like 'float' or 'MyFloat'.
function parse.type(elem)
  local ctype = elem:find('type')[1]
  if type(ctype) == 'table' then
    -- <ref refid='...' kindref='member'>
    ctype = ctype[1]
  end
  return ctype
end

function private.makeLocation(elem, header)
  local loc  = elem:find('location')
  local file = lk.absToRel(loc.file, lfs.currentdir())
  return file .. ':' .. loc.line
end
