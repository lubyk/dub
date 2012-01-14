--[[------------------------------------------------------

  dub.Inspector test
  ------------------

  Test introspective operations with the 'memory' group
  of classes.

--]]------------------------------------------------------
require 'lubyk'
local should = test.Suite('dub.Inspector - memory')

local ins = dub.Inspector {
  INPUT   = 'test/fixtures/memory',
  doc_dir = lk.dir() .. '/tmp',
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
    -- No ~Nogc destructor
    Nogc.GET_ATTR_NAME,
    Nogc.SET_ATTR_NAME,
    'Nogc:static',
    'surface',
    'operator+',
  }, res)
end       

test.all()


