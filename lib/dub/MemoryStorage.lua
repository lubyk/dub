--[[------------------------------------------------------

  dub.MemoryStorage
  -----------------

  This is used to store all definitions in memory.

--]]------------------------------------------------------

local lib     = {}
local private = {make={}, parse={}}
lib.__index   = lib
dub.MemoryStorage = lib

--=============================================== dub.Inspector()
setmetatable(lib, {
  __call = function(lib)
    local self = {
      headers = {},
      cache   = {},
    }
    return setmetatable(self, lib)
  end
})

--=============================================== PUBLIC METHODS
-- Prepare database

-- Parse xml directory and find header files. This will allow
-- us to find definitions as needed.
function lib:parse(xml_dir)
  local headers = self.headers
  local dir = dub.Dir(xml_dir)
  for file in dir:glob('%_8h.xml') do
    table.insert(headers, {path = file, dir = xml_dir})
  end
end

function lib:findByFullname(name)
  -- done
  -- split name components
  local parts = dub.split(name, '::')
  local current = self
  for i, part in ipairs(parts) do
    current = current:findChild(part)
  end
  return current
end

function lib:findChild(name)
  -- Any element at the root of the name space
  return self.cache[name] or private.findInXml(self, name)
end

--=============================================== PRIVATE

function private:findInXml(name)
  local elem
  local cache = self.cache
  -- Look in all unparsed headers
  for i, header in ipairs(self.headers) do
    if not header.parsed then
      private.parse.header(self, header)
      elem = cache[name]
      if elem then
        return elem
      end
    end
  end
end

require 'lubyk'

--- Parse a header definition and return element 
-- identified by 'name' if found.
function private.parse.header(self, header)
  local cache = self.cache
  local data = xml.load(header.path):find('compounddef')
  header.parsed = true
  private.parse.children(self, data, header)
end

function private.parse.children(self, parent, header)
  local cache = self.cache
  for _, elem in ipairs(parent) do
    local func = private.parse[elem.xml]
    if func then
      local obj = func(self, elem, header)
      if obj then
        -- optimization for constructors
        cache[obj.name] = obj
      end
    else
      --print('skipping', elem.xml)
    end
  end
end

function private.parse.innernamespace(self, elem, header)
  return {
    kind = 'namespace',
    name = elem[1]
  }
end

function private.parse.innerclass(self, elem, header)
  return {
    kind = 'class',
    name = elem[1],
    path = header.dir .. dub.Dir.sep .. elem.refid .. '.xml',
  }
end

function private.parse.sectiondef(self, elem, header)
  if elem.kind == 'typedef' then
    private.parse.children(self, elem, header)
  end
end

function private.parse.memberdef(self, elem, header)
  local func = private.parse[elem.kind]
  if func then
    local obj = func(self, elem, header)
    if obj then
      self.cache[obj.name] = obj
    end
  else
    --print('skipping memberdef', elem.kind)
  end
end

function private.parse.typedef(self, elem, header)
  return {
    kind = 'typedef',
    name = elem:find('name')[1],
    type = elem:find('type')[1],
    desc = (elem:find('detaileddescription') or {})[1],
    xml  = elem,
  }
end
    

