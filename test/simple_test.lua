--[[------------------------------------------------------

  dub.Inspector
  -------------

  Test basic parsing and introspective operations with
  the 'simple' class.

--]]------------------------------------------------------
require 'lubyk'
local should = test.Suite('dub.Inspector')

-- Test helper to prepare the inspector.
local function makeInspector()
  local ins = dub.Inspector()
  ins:parse('test/fixtures/simple/doc/xml')
  return ins
end

--=============================================== TESTS
function should.loadDub()
  assertType('table', dub)
end

function should.createInspector()
  local foo = dub.Inspector()
  assertType('table', foo)
end

function should.parseXml()
  local simple = dub.Inspector()
  assertPass(function()
    simple:parse('test/fixtures/simple/doc/xml')
  end)
end

function should.findSimpleClass()
  local ins = makeInspector()
  local simple = ins:find('Simple')
  assertEqual('dub.Class', simple.type)
end

function should.findTypedef()
  local ins = makeInspector()
  local obj = ins:find('MyFloat')
  assertEqual('dub.Typedef', obj.type)
end

function should.findMemberMethod()
  local ins = makeInspector()
  local Simple = ins:find('Simple')
  local obj = Simple:method('value')
  assertEqual('dub.Function', obj.type)
end

function should.listMemberMethods()
  local ins = makeInspector()
  local Simple = ins:find('Simple')
  local res = {}
  for meth in Simple:methods() do
    table.insert(res, meth.name)
  end
  assertValueEqual({'Simple', 'value', 'add', 'setValue'}, res)
end

function should.listParamsOnMethod()
  local ins = makeInspector()
  local Simple = ins:find('Simple')
  local add = Simple:method('add')
  local names = {}
  local types = {}
  for param in add:params() do
    table.insert(names, param.name) 
    table.insert(types, param.ctype) 
  end
  assertValueEqual({'v', 'w'}, names)
  assertValueEqual({'MyFloat', 'float'}, types)
end

function should.resolveNativeTypes()
  local ins = makeInspector()
  assertEqual('float', ins:resolveType('MyFloat'))
end
test.all()
