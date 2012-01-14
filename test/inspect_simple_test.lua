--[[------------------------------------------------------

  dub.Inspector
  -------------

  Test basic parsing and introspective operations with
  the 'simple' class.

--]]------------------------------------------------------
require 'lubyk'
local should = test.Suite('dub.Inspector - simple')

local ins = dub.Inspector {
  INPUT   = 'test/fixtures/simple/include',
  doc_dir = lk.dir() .. '/tmp',
}

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
    simple:parseXml('test/fixtures/simple/doc/xml')
  end)
end

function should.findSimpleClass()
  local simple = ins:find('Simple')
  assertEqual('dub.Class', simple.type)
end

function should.findReturnValueOfCtor()
  local Simple = ins:find('Simple')
  local ctor = Simple:method('Simple')
  assertEqual('Simple *', ctor.return_value.create_name)
end

function should.findReturnValue()
  local Simple = ins:find('Simple')
  local ctor = Simple:method('add')
  assertEqual('MyFloat ', ctor.return_value.create_name)
end

function should.findTypedef()
  local obj = ins:find('MyFloat')
  assertEqual('dub.Typedef', obj.type)
end

function should.findMemberMethod()
  local Simple = ins:find('Simple')
  local met = Simple:method('value')
  assertEqual('dub.Function', met.type)
  assertEqual(Simple, met.parent)
  assertTrue(met.member)
  assertFalse(met.ctor)
  assertFalse(met.dtor)
end

function should.findStaticMemberMethod()
  local Simple = ins:find('Simple')
  local met = Simple:method('pi')
  assertTrue(met.static)
  assertEqual('dub.Function', met.type)
end

function should.markCtorAsStatic()
  local Simple = ins:find('Simple')
  local met = Simple:method('Simple')
  assertTrue(met.static)
  assertTrue(met.ctor)
  assertEqual('dub.Function', met.type)
end

function should.listMembers()
  local res = {}
  for child in ins:children() do
    table.insert(res, child.name)
  end
  assertValueEqual({'Simple', 'MyFloat'}, res)
end

function should.listMemberMethods()
  local Simple = ins:find('Simple')
  local res = {}
  for meth in Simple:methods() do
    table.insert(res, meth.name)
  end
  assertValueEqual({'Simple', '~Simple', 'value', 'add', 'setValue', 'isZero', 'pi'}, res)
end

function should.listParamsOnMethod()
  local Simple = ins:find('Simple')
  local add = Simple:method('add')
  local names = {}
  local types = {}
  for param in add:params() do
    table.insert(names, param.name) 
    table.insert(types, param.ctype.name) 
  end
  assertValueEqual({'v', 'w'}, names)
  assertValueEqual({'MyFloat', 'double'}, types)
end

function should.resolveNativeTypes()
  assertEqual('double', ins:resolveType('MyFloat').name)
end

test.all()
