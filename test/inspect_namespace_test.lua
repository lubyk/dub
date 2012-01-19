--[[------------------------------------------------------

  dub.Inspector test
  ------------------

  Test introspective operations with the 'namespace' group
  of classes.

--]]------------------------------------------------------
require 'lubyk'
local should = test.Suite('dub.Inspector - namespace')

local ins  = dub.Inspector {
  INPUT    = 'test/fixtures/namespace',
  doc_dir  = lk.dir() .. '/tmp',
  keep_xml = true,
}

--=============================================== TESTS
              
function should.findNamespace()
  local Nem = ins:find('Nem')
  assertEqual('dub.Namespace', Nem.type)
end

function should.findByFullname()
  local A = ins:find('Nem::A')
  assertEqual('dub.Class', A.type)
end

function should.findNamespace()
  local A = ins:find('Nem::A')
  assertEqual('Nem', A:namespace().name)
end

function should.findTemplate()
  local TRect = ins:find('Nem::TRect')
  assertEqual('TRect', TRect.name)
  assertEqual('dub.CTemplate', TRect.type)
end

function should.findTypdefByFullname()
  local Rect = ins:find('Nem::Rect')
  assertEqual('Rect', Rect.name)
  assertEqual('Nem', Rect:namespace().name)
  assertEqual('dub.Class', Rect.type)
end

function should.findNestedClassByFullname()
  local C = ins:find('Nem::B::C')
  assertEqual('dub.Class', C.type)
  assertEqual('C', C.name)
end

function should.findNamespaceFromNestedClass()
  local C = ins:find('Nem::B::C')
  assertEqual('Nem', C:namespace().name)
end

function should.haveFullypeReturnValueInCtor()
  local C = ins:find('Nem::B::C')
  local met = C:method('C')
  assertEqual('B::C *', met.return_value.create_name)
end

function should.prefixInnerClassInTypes()
  local C = ins:find('Nem::B::C')
  assertEqual('B::C *', C.create_name)
end

function should.properlyResolveType()
  local C = ins:find('Nem::B::C')
  local t = ins.db:resolveType(C, 'Nem::B::C')
  assertEqual(C, t)
  t = ins.db:resolveType(C, 'B::C')
  assertEqual(C, t)
  t = ins.db:resolveType(C, 'C')
  assertEqual(C, t)
end

function should.findAttributesInParent()
  local B = ins:find('Nem::B')
  local res = {}
  for var in B:attributes() do
    table.insert(res, var.name)
  end
  assertValueEqual({
    'nb_',
    'a',
    'c',
  }, res)
end

function should.findMethodsInParent()
  local B = ins:find('Nem::B')
  local res = {}
  for met in B:methods() do
    table.insert(res, met.name)
  end
  assertValueEqual({
    'B',
    '__tostring',
    'getC',
    '~B',
    B.GET_ATTR_NAME,
    B.SET_ATTR_NAME,
  }, res)
end

test.all()


