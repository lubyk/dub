--[[------------------------------------------------------

  dub.Inspector
  -------------

  Test basic parsing and introspective operations with
  the 'simple' class.

--]]------------------------------------------------------
require 'lubyk'
local should = test.Suite('dub.Inspector - simple')

local tmp_path = lk.dir() .. '/tmp'
lk.rmTree(tmp_path, true)
os.execute('mkdir -p '..tmp_path)

local ins = dub.Inspector {
  INPUT   = 'test/fixtures/simple/include',
  doc_dir = lk.dir() .. '/tmp',
  ignore  = {
    Simple = {
      'shouldBeIgnored',
    },
    'badFuncToIgnore',
  },
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

function should.resolveTypes()
  local Simple = ins:find('Simple')
  local db = ins.db
  assertEqual(Simple, db:resolveType(db, 'Simple'))
  assertEqual(Simple, db:resolveType(Simple, 'Simple'))
  assertValueEqual({
    name        = 'double',
    def         = 'double',
    create_name = 'MyFloat ',
  }, db:resolveType(Simple, 'MyFloat'))

  assertValueEqual({
    name        = 'double',
    def         = 'double',
    create_name = 'MyFloat ',
  }, db:resolveType(db, 'MyFloat'))
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
  assertValueEqual({
    'Simple',
    'Foo',
    'Bar',
    'MyFloat',
  }, res)
end

function should.listMemberMethods()
  local Simple = ins:find('Simple')
  local res = {}
  for meth in Simple:methods() do
    table.insert(res, meth.name)
  end
  assertValueEqual({
    'Simple',
    '~Simple',
    'value',
    'add',
    'mul',
    'testA',
    'testB',
    'addAll',
    'setValue',
    'isZero',
    'showBuf',
    'showSimple',
    'pi',
  }, res)
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

function should.getDefaultParamsInMethod()
  local Simple = ins:find('Simple')
  local met = Simple:method('add')
  local p1 = met.params_list[1]
  local p2 = met.params_list[2]
  assertEqual('v', p1.name)
  assertNil(p1.default)
  assertEqual('w', p2.name)
  assertEqual('10', p2.default)
end

function should.markFunctionWithDefaults()
  local Simple = ins:find('Simple')
  local met = Simple:method('add')
  assertTrue(met.has_defaults)
  met = Simple:method('Simple')
  assertFalse(met.has_defaults)
end

function should.setFirstDefaultPositionInFunction()
  local Simple = ins:find('Simple')
  local met = Simple:method('add')
  assertTrue(met.has_defaults)
  assertEqual(2, met.first_default)
  met = Simple:method('Simple')
  assertFalse(met.has_defaults)
end

function should.detectOverloadFunctions()
  local Simple = ins:find('Simple')
  local met = Simple:method('add')
  assertTrue(met.overloaded)
  local met = Simple:method('mul')
  assertEqual(4, #met.overloaded)
end

--=============================================== Overloaded

function should.haveOverloadedList()
  local Simple = ins:find('Simple')
  local met = Simple:method('add')
  local res = {}
  for _, m in ipairs(met.overloaded) do
    table.insert(res, m.sign)
  end
  assertValueEqual({
    'MyFloat, double',
    'Simple',
  }, res)
  
  met = Simple:method('mul')
  res = {}
  for _, m in ipairs(met.overloaded) do
    table.insert(res, m.sign)
  end
  assertValueEqual({
    'Simple',
    'double, char',
    'double, double',
    '',
  }, res)
  
  met = Simple:method('addAll')
  res = {}
  for _, m in ipairs(met.overloaded) do
    table.insert(res, m.sign)
  end
  assertValueEqual({
    'double, double, double',
    'double, double, double, char',
  }, res)
end

function should.resolveNativeTypes()
  assertEqual('double', ins:resolveType('MyFloat').name)
end

--=============================================== struct by value
function should.parseStructParam()
  local Simple = ins:find('Simple')
  local met = Simple:method('showBuf')
  local p = met.params_list[1]
  assertEqual('MyBuf', p.ctype.name)
  assertFalse(p.ctype.ptr)
  assertEqual('MyBuf ', p.ctype.create_name)
end

function should.parseClassByValueParam()
  local Simple = ins:find('Simple')
  local met = Simple:method('showSimple')
  local p = met.params_list[1]
  assertEqual('Simple', p.ctype.name)
  assertFalse(p.ctype.ptr)
  assertEqual('Simple ', p.ctype.create_name)
end

test.all()
