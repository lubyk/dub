--[[------------------------------------------------------

  dub.Inspector test
  ------------------

  Test introspective operations with the 'namespace' group
  of classes.

--]]------------------------------------------------------
local lub = require 'lub'
local lut = require 'lut'
local dub = require 'dub'

local should = lut.Test('dub.Inspector - namespace', {coverage = false})

local ins

function should.setup()
  dub.warn = dub.silentWarn
  if not ins then
    ins = dub.Inspector {
      INPUT    = {
        lub.path '|fixtures/namespace',
      },
      doc_dir  = lub.path '|tmp',
    }
  end
end

function should.teardown()
  dub.warn = dub.printWarn
end
--=============================================== TESTS
              
function should.findNamespace()
  local Nem = ins:find('Nem')
  assertEqual('dub.Namespace', Nem.type)
end
              
function should.listNamespaces()
  local res = {}
  for nm in ins.db:namespaces() do
    table.insert(res, nm.name)
  end
  assertValueEqual({
    'Nem',
  }, res)
end

function should.listHeaders()
  local res = {}
  -- It does not matter which namespace we use in 'headers'. We will 
  for h in ins.db:headers(ins:find('Nem::A')) do
    local name = string.match(h, '/([^/]+/[^/]+)$')
    table.insert(res, name)
  end
  assertValueEqual({
    'namespace/A.h',
    'namespace/B.h',
    'namespace/Out.h',
    'namespace/TRect.h',
    'namespace/constants.h',
    'namespace/nem.h',
  }, res)
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

function should.resolveElementsOutOfNamespace()
  local e = ins:find('nmRectf')
  assertEqual('dub.Class', e.type)
  assertEqual('nmRectf', e:fullname())
end

function should.resolveElementsOutOfNamespace()
  local e = ins:find('Nem::Rectf')
  assertEqual('dub.Class', e.type)
  assertEqual('Nem::Rectf', e:fullname())
end

function should.notUseSingleLibNameInNamespace()
  ins.db.name = 'foo'
  local e = ins:find('Nem')
  assertEqual('dub.Namespace', e.type)
  assertEqual('Nem', e:fullname())
  ins.db.name = nil
end

function should.findMethodsInParent()
  local B = ins:find('Nem::B')
  local res = {}
  for met in B:methods() do
    table.insert(res, met.name)
  end
  assertValueEqual({
    '~B',
    B.SET_ATTR_NAME,
    B.GET_ATTR_NAME,
    'B',
    '__tostring',
    'getC',
  }, res)
end

--=============================================== namespace functions

function should.listNamespaceFunctions()
  local res = {}
  for func in ins.db:functions() do
    lub.insertSorted(res, func:fullcname())
  end
  assertValueEqual({
    'Nem::addTwo',
    'Nem::customGlobal',
    'addTwoOut',
    'customGlobalOut',
  }, res)
end

function should.setFlagsOnNamespaceFunction()
  local addTwo = ins:find('Nem::addTwo')
  assertEqual('dub.Function', addTwo.type)
  assertEqual(false, addTwo.member)
end

--=============================================== namespace constants

function should.findNamespaceConstants()
  local n = ins:find('Nem')
  local enum = ins:find('Nem::NamespaceConstant')
  assertEqual('dub.Enum', enum.type)
  assertTrue(n.has_constants)
end

function should.listNamespaceConstants()
  local n = ins:find('Nem')
  local res = {}
  for const in n:constants() do
    lub.insertSorted(res, const)
  end
  assertValueEqual({
    'One',
    'Three',
    'Two',
  }, res)
end

function should.listAllConstants()
  local res = {}
  for const in ins.db:constants() do
    lub.insertSorted(res, const)
  end
  assertValueEqual({
    'One',
    'Three',
    'Two',
  }, res)
end

should:test()

