--[[------------------------------------------------------

  dub.Inspector test
  ------------------

  Test introspective operations with the 'memory' group
  of classes.

--]]------------------------------------------------------
require 'lubyk'
local should = test.Suite('dub.Inspector - memory')

local base = lk.dir()
local ins  = dub.Inspector {
  INPUT    = base .. '/fixtures/memory',
  doc_dir  = lk.dir() .. '/tmp',
  keep_xml = true,
  PREDEFINED = {
    'SOME_FUNCTION_MACRO(x)=',
    'OTHER_FUNCTION_MACRO(x)=',
  },
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
    Nogc.SET_ATTR_NAME,
    Nogc.GET_ATTR_NAME,
    'Nogc:static',
    'surface',
    'operator+',
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
    'name',
    -- no SOME_FUNCTION_MACRO or OTHER_FUNCTION_MACRO
    -- no pushobject
  }, res)
end      

function should.notSeeMacroAsAttribute()
  local Pen = ins:find('Pen')
  assertFalse(Pen.has_variables)
end

--=============================================== UNION

local Union = ins:find('Union')

function should.parseUnionMembers()
  local uni_a = Union.variables_list[1]
  local res = {}
  for var in Union:attributes() do
    table.insert(res, var.name..':'..var.ctype.name)
  end
  assertValueEqual({
    'h:uint8_t',
    's:uint8_t',
    'v:uint8_t',
    'a:uint8_t',
    'c:uint32_t',
  }, res)
end

--=============================================== Custo dtor

local CustomDtor = ins:find('CustomDtor')

function should.parseDub()
  assertEqual('finalize', CustomDtor.dub.destructor)
end

function should.ignoreDtor()
  local res = {}
  for m in CustomDtor:methods() do
    table.insert(res, m.name)
  end

  assertValueEqual({
    'CustomDtor',
    '~CustomDtor',
    -- No 'finalize'
  }, res)
end

--=============================================== No dtor

local NoDtor = ins:find('NoDtor')

function should.parseNoDtorDub()
  assertEqual(false, NoDtor.dub.destructor)
end

function should.ignoreFalseDtor()
  local res = {}
  for m in NoDtor:methods() do
    table.insert(res, m.name)
  end

  assertValueEqual({
    'NoDtor',
    -- No '~NoDtor'
  }, res)
end

test.all()


