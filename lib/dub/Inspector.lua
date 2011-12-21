--[[------------------------------------------------------

  dub.Inspector
  -------------

  The Inspector 'knows' about the functions and classes
  and can answer queries. It first the main entry point to
  parse and create bindings.

--]]------------------------------------------------------
local lib     = {type = 'dub.Inspector'}
local private = {}
lib.__index   = lib
dub.Inspector = lib

--=============================================== dub.Inspector()
setmetatable(lib, {
  __call = function(lib)
    local self = {db = dub.MemoryStorage()}
    return setmetatable(self, lib)
  end
})

--=============================================== PUBLIC METHODS
-- Add xml headers to the database
function lib:parse(xml_dir)
  self.db:parse(xml_dir)
end

-- A class in a namespace is queried with 'std::string'.
function lib:find(name)
  -- A 'child' of the Inspector can be anything so we
  -- have to walk through the files to find what we
  -- are asked for.
  -- Object lives at the root of the name space.
  return self.db:findByFullname(name)
end

--- Try to follow typedefs to resolve a type
function lib:resolveType(name)
  return self.db:resolveType(name)
end
--=============================================== PRIVATE
