--[[------------------------------------------------------

  dub.Inspector
  -------------

  Test template parsing and introspective operations with
  the 'template' group of classes.

--]]------------------------------------------------------
require 'lubyk'
local should = test.Suite('dub.Inspector - template')

local ins = dub.Inspector {
  INPUT    = 'test/fixtures/template',
  doc_dir  = lk.dir() .. '/tmp',
}

--=============================================== TESTS
function should.findCTemplate()
  local TVect = ins:find('TVect')
  assertEqual('dub.CTemplate', TVect.type)
end

function should.haveCTemplateParams()
  local TVect = ins:find('TVect')
  local res = {}
  assertValueEqual({'T'}, TVect.template_params)
end

function should.findCTemplateInNamespace()
  local obj = ins:find('Nem::TRect')
  assertEqual('dub.CTemplate', obj.type)
end

function should.haveAttributes()
  local obj = ins:find('TVect')
  local res = {}
  for attr in obj:attributes() do
    table.insert(res, attr.name .. ':' .. attr.ctype.name)
  end
  assertValueEqual({'x:T', 'y:T'}, res)
end

function should.haveAttributesInNamespace()
  local obj = ins:find('Nem::TRect')
  local res = {}
  for attr in obj:attributes() do
    table.insert(res, attr.name .. ':' .. attr.ctype.name)
  end
  assertValueEqual({
    'x1:T',
    'y1:T',
    'x2:T',
    'y2:T',
  }, res)
end

function should.resolveTypedef()
  local obj = ins:find('Vectf')
  assertEqual('dub.Class', obj.type)
  assertEqual('Vectf', obj.name)
end

function should.resolveAttributeTypes()
  local obj = ins:find('Vectf')
  local res = {}
  for attr in obj:attributes() do
    table.insert(res, attr.name .. ':' .. attr.ctype.name)
  end
  assertValueEqual({
    'x:float',
    'y:float',
  }, res)
end

function should.resolveTypedefInNamespace()
  local obj = ins:find('nmRect32')
  assertEqual('dub.Class', obj.type)
  assertEqual('nmRect32', obj.name)
end

function should.resolveAttributeTypesInNamespace()
  local obj = ins:find('nmRect32')
  local res = {}
  for attr in obj:attributes() do
    table.insert(res, attr.name .. ':' .. attr.ctype.name)
  end
  assertValueEqual({
    'x1:int32_t',
    'y1:int32_t',
    'x2:int32_t',
    'y2:int32_t',
  }, res)
end

function should.resolveParamTypes()
  local Vectf = ins:find('Vectf')
  local met = Vectf:method('addToX')
  local p = met.params_list[1]
  assertEqual('float', p.ctype.name)
end

function should.resolveReturnValue()
  local Vectf = ins:find('Vectf')
  local met = Vectf:method('surface')
  assertEqual('float', met.return_value.name)
  met = Vectf:method('addToX')
  assertEqual('float', met.return_value.name)
end

function should.resolveParamTypesInStatic()
  local Vectf = ins:find('Vectf')
  local met = Vectf:method('addTwo')
  local p = met.params_list[1]
  assertEqual('float', p.ctype.name)
  assertEqual('float', met.return_value.name)
end

function should.resolveConstParam()
  local Vectf = ins:find('Vectf')
  local met = Vectf:method('operator+')
  local p = met.params_list[1]
  assertEqual('Vectf', p.ctype.name)
  assertEqual('Vectf', met.return_value.name)
end

function should.listMethods()
  local Vectf = ins:find('Vectf')
  local res = {}
  for meth in Vectf:methods() do
    table.insert(res, meth.name)
  end
  assertValueEqual({
    'Vectf',
    'surface',
    'operator+',
    'addToX',
    'addTwo',
    '~Vectf',
    Vectf.GET_ATTR_NAME,
    Vectf.SET_ATTR_NAME,
  }, res)
end

function should.ignoreTemplatedMembers()
  local Foo = ins:find('Foo')
  local res = {}
  for meth in Foo:methods() do
    table.insert(res, meth.name)
  end
  assertValueEqual({
    '~Foo',
  }, res)
end

test.all()

