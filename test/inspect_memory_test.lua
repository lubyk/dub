--[[------------------------------------------------------

  dub.Inspector test
  ------------------

  Test introspective operations with the 'memory' group
  of classes.

--]]------------------------------------------------------
require 'lubyk'
local should = test.Suite('dub.Inspector - memory')

local ins  = dub.Inspector {
  INPUT    = 'test/fixtures/memory',
  doc_dir  = lk.dir() .. '/tmp',
  keep_xml = true,
}

--=============================================== TESTS
              
function should.notHaveADestructor()
  local Nogc = ins:find('Nogc')
  local res = {}
  for meth in Nogc:methods() do
    local name = meth.name
    if meth.static then
      name = name .. ':static'
    end
    table.insert(res, name)
  end
  assertValueEqual({
    'Nogc:static',
    'surface',
    'operator+',
    -- No ~Nogc destructor
    Nogc.GET_ATTR_NAME,
    Nogc.SET_ATTR_NAME,
  }, res)
end       
              
function should.notHavePrivateDestructor()
  local PrivateDtor = ins:find('PrivateDtor')
  local res = {}
  for meth in PrivateDtor:methods() do
    local name = meth.name
    if meth.static then
      name = name .. ':static'
    end
    table.insert(res, name)
  end
  assertValueEqual({
    -- No ~Nogc destructor
    'PrivateDtor:static',
  }, res)
end       

test.all()


