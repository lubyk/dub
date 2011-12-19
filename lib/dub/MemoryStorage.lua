--[[------------------------------------------------------

  dub.MemoryStorage
  -----------------

  This is used to store all definitions in memory.

--]]------------------------------------------------------

local lib     = {}
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
function lib:parse(xml_dir)
  local xml_headers = self.xml_headers
  local dir = lk.Dir(xml_dir)
  for file in dir:glob('%_8h.xml') do
    table.insert(xml_headers, {path = file, dir = xml_dir})
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
  -- Any element at the root of the name space
  return parent.cache[name] or private.parseHeaders(parent, name)
end

--- Return an iterator over the functions of this class/namespace.
function lib:functions(parent)
  -- make sure we have parsed the headers
  private.parseHeaders(parent)
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
    return td.type
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
    if child.kind == 'function' then
      coroutine.yield(child)
    end
  end
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
function parse.header(self, header)
  local data = xml.load(header.path):find('compounddef')
  local h_path = data:find('location').file
  local base, h_file = lk.directory(h_path)
  table.insert(self.headers_list, {path = h_file})

  parse.children(self, data, header)
  header.parsed = true
end

function parse.children(self, parent, header)
  local cache = self.cache
  local sorted_cache = self.sorted_cache
  for _, elem in ipairs(parent) do
    local func = parse[elem.xml]
    if func then
      local obj = func(self, elem, header)
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
    kind = 'namespace',
    name = elem[1]
  }
end

function parse.innerclass(self, elem, header)
  return dub.Class {
    db      = self,
    cache   = {},
    sorted_cache = {},
    name    = elem[1],
    xml     = elem,
    headers_list = {},
    xml_headers  = {
      {path = header.dir .. lk.Dir.sep .. elem.refid .. '.xml', dir = header.dir}
    },
  }
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
    kind = 'typedef',
    name = elem:find('name')[1],
    type = elem:find('type')[1],
    desc = (elem:find('detaileddescription') or {})[1],
    xml  = elem,
  }
end
    
parse['function'] = function(self, elem, header)
  return dub.Function {
    name          = elem:find('name')[1],
    sorted_params = parse.params(self, elem, header),
    desc          = (elem:find('detaileddescription') or {})[1],
    xml           = elem,
  }
end

function parse.params(self, elem, header)
  local res = {str = elem:find('argsstring')[1]}
  for _,param in ipairs(elem) do
    if param.xml == 'param' then
      table.insert(res, parse.param(self, param, header))
    end
  end
  return res
end

function parse.param(self, elem, header)
  return {
    type = elem:find('type')[1],
    name = elem:find('declname')[1],
  }
end

