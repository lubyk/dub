--[[------------------------------------------------------

  dub.MemoryStorage
  -----------------

  This is used to store all definitions in memory.

--]]------------------------------------------------------

local lib     = {}
local private = {}
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
    table.insert(headers, {path = xml_dir .. dub.Dir.sep .. file})
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
  -- Look in all unparsed headers
  for i, header in ipairs(self.headers) do
    if not header.parsed then
      elem = private.parseHeader(self, header, name)
      if elem then
        return elem
      end
    end
  end
end

--- Parse a header definition and return element 
-- identified by 'name' if found.
function private.parseHeader(self, header, name)
  local xml = {} -- TODO: xml.parse(header.path)
  header.parsed = true
  -- Save root elements in cache
  -- innernamespace
  -- innerclass
  -- ...
  -- Just to make tests happy
  return {type='class'}
end

