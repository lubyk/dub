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

function should.haveAttributes()
  local TVect = ins:find('TVect')
  local res = {}
  for attr in TVect:attributes() do
    table.insert(res, attr.name .. ':' .. attr.ctype.name)
  end
  assertValueEqual({'x:T', 'y:T'}, res)
end

function should.resolveTypedef()
  local Vectf = ins:find('Vectf')
  assertEqual('dub.Class', Vectf.type)
  assertEqual('Vectf', Vectf.name)
end

function should.resolveAttributeTypes()
  local Vectf = ins:find('Vectf')
  local res = {}
  for attr in Vectf:attributes() do
    table.insert(res, attr.name .. ':' .. attr.ctype.name)
  end
  assertValueEqual({'x:float', 'y:float'}, res)
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
  assertValueEqual({'~Vectf', 
    Vectf.GET_ATTR_NAME,
    Vectf.SET_ATTR_NAME,
    'Vectf',
    'surface',
    'operator+',
    'addToX',
    'addTwo',
  }, res)
end

test.all()

