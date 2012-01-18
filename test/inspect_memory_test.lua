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
  PREDEFINED = {
    'SOME_FUNCTION_MACRO(x)=',
    'OTHER_FUNCTION_MACRO(x)=',
  }
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

function should.notHaveMacroFunctions()
  local Pen = ins:find('Pen')
  local res = {}
  for met in Pen:methods() do
    local name = met.name
    if met.static then
      name = name .. ':static'
    end
    table.insert(res, name)
  end
  assertValueEqual({
    'Pen:static',
    'setOwner',
    '~Pen',
    -- no SOME_FUNCTION_MACRO or OTHER_FUNCTION_MACRO
  }, res)
end      

function should.notSeeMacroAsAttribute()
  local Pen = ins:find('Pen')
  assertFalse(Pen.has_variables)
end

test.all()


