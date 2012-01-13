--[[------------------------------------------------------

  dub.Inspector test
  ------------------

  Test introspective operations with the 'pointers' group
  of classes.

--]]------------------------------------------------------
require 'lubyk'
local should = test.Suite('dub.Inspector - pointers')

local ins = dub.Inspector {
  INPUT = 'test/fixtures/pointers',
  doc_dir = lk.dir() .. '/tmp',
}

--=============================================== TESTS

function should.findVectClass()
  local Vect = ins:find('Vect')
  assertEqual('dub.Class', Vect.type)
end

function should.parseParamTypes()
  local Box = ins:find('Box')
  local ctor = Box:method('Box')
  local p1   = ctor.sorted_params[1]
  local p2   = ctor.sorted_params[2]
  assertEqual('name', p1.name)
  assertEqual('std::string', p1.ctype.name)
  assertTrue(p1.ctype.const)
  assertTrue(p1.ctype.ref)
  assertEqual('const std::string ', p1.ctype.create_name)
  assertEqual('size', p2.name)
  assertEqual('Vect', p2.ctype.name)
end

function should.parsePointerParamTypes()
  local Box = ins:find('Box')
  local met = Box:method('MakeBox')
  local p1   = met.sorted_params[1]
  local p2   = met.sorted_params[2]
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

function should.listAttributes()
  local Vect = ins:find('Vect')
  local res = {}
  for attr in Vect:attributes() do
    table.insert(res, attr.name)
  end
  assertValueEqual({'x', 'y'}, res)
end

function should.listMethods()
  local Vect = ins:find('Vect')
  local res = {}
  for meth in Vect:methods() do
    table.insert(res, meth.name)
  end
  assertValueEqual({'_Vect', 
    Vect.GET_ATTR_NAME,
    Vect.SET_ATTR_NAME,
    'Vect',
    'surface',
    'operator+',
    'operator-',
    'operator*',
    'operator/',
    'operator<',
    'operator<=',
    'operator==',
  }, res)
end

function should.listStaticMethods()
  local Box = ins:find('Box')
  local res = {}
  for meth in Box:methods() do
    table.insert(res, meth.name)
  end
  assertValueEqual({'_Box', Box.GET_ATTR_NAME, Box.SET_ATTR_NAME, 'Box', 'name', 'surface', 'MakeBox'}, res)
end

function should.staticMethodShouldBeStatic()
  local Box = ins:find('Box')
  local met = Box:method('MakeBox')
  assertTrue(met.static)
end

function should.haveSetMethod()
  local Vect = ins:find('Vect')
  local set  = Vect:method(Vect.SET_ATTR_NAME)
  assertTrue(set.is_set_attr)
end

function should.parseAddOperator()
  local Vect = ins:find('Vect')
  local plus = Vect:method('operator+')
  assertTrue(plus.member)
  assertEqual('operator+', plus.name)
  assertEqual('operator_add', plus.cname)
end

function should.parseSubOperator()
  local Vect = ins:find('Vect')
  local plus = Vect:method('operator-')
  assertTrue(plus.member)
  assertEqual('operator-', plus.name)
  assertEqual('operator_sub', plus.cname)
end

--function should.parseUnmOperator()
--  local Vect = ins:find('Vect')
--  local plus = Vect:method('operator+')
--  assertTrue(plus.member)
--  assertEqual('operator+', plus.name)
--  assertEqual('operator_plus', plus.cname)
--end

function should.parseMulOperator()
  local Vect = ins:find('Vect')
  local plus = Vect:method('operator*')
  assertTrue(plus.member)
  assertEqual('operator*', plus.name)
  assertEqual('operator_mul', plus.cname)
end

function should.parseDivOperator()
  local Vect = ins:find('Vect')
  local plus = Vect:method('operator/')
  assertTrue(plus.member)
  assertEqual('operator/', plus.name)
  assertEqual('operator_div', plus.cname)
end

function should.parseLtOperator()
  local Vect = ins:find('Vect')
  local plus = Vect:method('operator<')
  assertTrue(plus.member)
  assertEqual('operator<', plus.name)
  assertEqual('operator_lt', plus.cname)
end

function should.parseLteOperator()
  local Vect = ins:find('Vect')
  local plus = Vect:method('operator<=')
  assertTrue(plus.member)
  assertEqual('operator<=', plus.name)
  assertEqual('operator_le', plus.cname)
end

function should.parseEqOperator()
  local Vect = ins:find('Vect')
  local plus = Vect:method('operator==')
  assertTrue(plus.member)
  assertEqual('operator==', plus.name)
  assertEqual('operator_eq', plus.cname)
end

test.all()

