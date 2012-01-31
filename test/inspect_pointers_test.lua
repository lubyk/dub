--[[------------------------------------------------------

  dub.Inspector test
  ------------------

  Test introspective operations with the 'pointers' group
  of classes.

--]]------------------------------------------------------
require 'lubyk'
local should = test.Suite('dub.Inspector - pointers')

local ins  = dub.Inspector {
  INPUT    = 'test/fixtures/pointers',
  doc_dir  = lk.dir() .. '/tmp',
}

local Vect = ins:find('Vect')
local Box  = ins:find('Box')

--=============================================== TESTS

function should.notHaveCtorForAbstractTypes()
  local Abstract = ins:find('Abstract')
  assertTrue(Abstract.abstract)
  local res = {}
  for met in Abstract:methods() do
    table.insert(res, met.name)
  end
  assertValueEqual({
    '~Abstract',
    'pureVirtual',
  }, res)
end

function should.detectPureVirtualFunctions()
  local Abstract = ins:find('Abstract')
  local pureVirtual = Abstract:method('pureVirtual')
  assertTrue(pureVirtual.pure_virtual)
end

function should.findVectClass()
  assertEqual('dub.Class', Vect.type)
end

function should.parseParamTypes()
  local ctor = Box:method('Box')
  local p1   = ctor.params_list[1]
  local p2   = ctor.params_list[2]
  assertEqual('name', p1.name)
  assertEqual('std::string', p1.ctype.name)
  assertTrue(p1.ctype.const)
  assertTrue(p1.ctype.ref)
  assertEqual('const std::string ', p1.ctype.create_name)
  assertEqual('size', p2.name)
  assertEqual('Vect', p2.ctype.name)
end

function should.assignDefaultNamesToParams()
  local met = Vect:method('unamed')
  local p1  = met.params_list[1]
  local p2  = met.params_list[2]
  assertEqual('p1', p1.name)
  assertEqual('double', p1.ctype.name)
  assertEqual('p2', p2.name)
  assertEqual('int', p2.ctype.name)
end

function should.notConfuseVoidAsType()
  local met = Vect:method('noparam')
  assertEqual(0, #met.params_list)
end

function should.parsePointerParamTypes()
  local met = Box:method('MakeBox')
  local p1   = met.params_list[1]
  local p2   = met.params_list[2]
  assertEqual('name', p1.name)
  assertEqual('char', p1.ctype.name)
  assertTrue(p1.ctype.const)
  assertTrue(p1.ctype.ptr)
  assertFalse(p1.ctype.ref)
  assertEqual('const char *', p1.ctype.create_name)
  assertEqual('size', p2.name)
  assertEqual('Vect', p2.ctype.name)
  assertEqual('Vect *', p2.ctype.create_name)
end

function should.listBoxAttributes()
  local res = {}
  for attr in Box:attributes() do
    local name = attr.name
    if attr.static then
      name = name .. ':static'
    end
    table.insert(res, name)
  end
  assertValueEqual({
    'name_',
    'size_',
    'position',
    'const_vect',
  }, res)
end

function should.markConstMembers()
  local attr = Box:findChild('const_vect')
  assertTrue(attr.ctype.const)
end

function should.markPointerMembers()
  local attr = Box:findChild('position')
  assertTrue(attr.ctype.ptr)
end

function should.listVectAttributes()
  local res = {}
  for attr in Vect:attributes() do
    local name = attr.name
    if attr.static then
      name = name .. ':static'
    end
    table.insert(res, name)
  end
  assertValueEqual({
    'x',
    'y',
    'create_count:static',
    'copy_count:static',
    'destroy_count:static',
  }, res)
end

function should.detectArrayAttributes()
  local d = Vect:findChild('d')
  assertEqual('d', d.name)
  assertEqual('MAX_DIM', d.array_dim)
end

function should.listMethods()
  local res = {}
  for meth in Vect:methods() do
    local name = meth.name
    if meth.static then
      name = name .. ':static'
    end
    table.insert(res, name)
  end
  assertValueEqual({
    Vect.SET_ATTR_NAME,
    'd',
    'Vect:static',
    '~Vect',
--  'd_set',
    'surface',
    'operator+',
    'operator+=',
    'operator-',
    -- unary minus
    'operator- ',
    'operator-=',
    'operator*',
    'operator/',
    'operator<',
    'operator<=',
    'operator==',
    'operator()',
    Vect.GET_ATTR_NAME,
    'someChar',
    'someStr',
    'unamed',
    'noparam',
  }, res)
end

function should.listStaticMethods()
  local Box = ins:find('Box')
  local res = {}
  for meth in Box:methods() do
    local name = meth.name
    if meth.static then
      name = name .. ':static'
    end
    table.insert(res, name)
  end
  assertValueEqual({
    '~Box',
    Box.SET_ATTR_NAME,
    Box.GET_ATTR_NAME,
    'Box:static',
    'name',
    'surface',
    'size',
    'sizeRef',
    'constRef',
    'copySize',
    'MakeBox:static',
  }, res)
end

function should.staticMethodShouldBeStatic()
  local Box = ins:find('Box')
  local met = Box:method('MakeBox')
  assertTrue(met.static)
end

function should.haveSetMethod()
  local set  = Vect:method(Vect.SET_ATTR_NAME)
  assertTrue(set.is_set_attr)
end

function should.haveGetMethod()
  local set  = Vect:method(Vect.GET_ATTR_NAME)
  assertTrue(set.is_get_attr)
end

function should.parseCompoundNameInDefault()
  local Box = ins:find('Box')
  local met = Box:method('Box')
  local p = met.params_list[2]
  assertEqual('Vect(0, 0)', p.default)
end

function should.parseAddOperator()
  local met = Vect:method('operator+')
  assertTrue(met.member)
  assertEqual('operator+', met.name)
  assertEqual('operator_add', met.cname)
end

function should.parseSubOperator()
  local met = Vect:method('operator-')
  assertTrue(met.member)
  assertEqual('operator-', met.name)
  assertEqual('operator_sub', met.cname)
end

--function should.parseUnmOperator()
--  local met = Vect:method('operator+')
--  assertTrue(met.member)
--  assertEqual('operator+', met.name)
--  assertEqual('operator_plus', met.cname)
--end

function should.parseMulOperator()
  local met = Vect:method('operator*')
  assertTrue(met.member)
  assertEqual('operator*', met.name)
  assertEqual('operator_mul', met.cname)
end

function should.parseDivOperator()
  local met = Vect:method('operator/')
  assertTrue(met.member)
  assertEqual('operator/', met.name)
  assertEqual('operator_div', met.cname)
end

function should.parseLtOperator()
  local met = Vect:method('operator<')
  assertTrue(met.member)
  assertEqual('operator<', met.name)
  assertEqual('operator_lt', met.cname)
end

function should.parseLteOperator()
  local met = Vect:method('operator<=')
  assertTrue(met.member)
  assertEqual('operator<=', met.name)
  assertEqual('operator_le', met.cname)
end

function should.parseEqOperator()
  local met = Vect:method('operator==')
  assertTrue(met.member)
  assertEqual('operator==', met.name)
  assertEqual('operator_eq', met.cname)
end

function should.ignoreOverloadedWithSameType()
  -- Vect(double x, double y)
  -- Vect(const Vect &v)
  -- Vect(const Vect *v)
  local met = Vect:method('Vect')
  assertTrue(met.overloaded)
  assertEqual(2, #met.overloaded)
end

test.all()

