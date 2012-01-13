--[[------------------------------------------------------

  dub.Inspector test
  ------------------

  Test introspective operations with the 'pointers' group
  of classes.

--]]------------------------------------------------------
require 'lubyk'
local should = test.Suite('dub.Inspector (pointers)')

local ins = dub.Inspector {
  INPUT = 'test/fixtures/pointers',
  doc_dir = lk.dir() .. '/tmp',
}

--=============================================== TESTS

function should.findSizeClass()
  local Size = ins:find('Size')
  assertEqual('dub.Class', Size.type)
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
  assertEqual('Size', p2.ctype.name)
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
  assertEqual('Size', p2.ctype.name)
  assertEqual('Size *', p2.ctype.create_name)
end

function should.listAttributes()
  local Size = ins:find('Size')
  local res = {}
  for attr in Size:attributes() do
    table.insert(res, attr.name)
  end
  assertValueEqual({'x', 'y'}, res)
end

function should.listMethods()
  local Size = ins:find('Size')
  local res = {}
  for meth in Size:methods() do
    table.insert(res, meth.name)
  end
  assertValueEqual({'_Size', 
    Size.GET_ATTR_NAME,
    Size.SET_ATTR_NAME,
    'Size',
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
  local Size = ins:find('Size')
  local set  = Size:method(Size.SET_ATTR_NAME)
  assertTrue(set.is_set_attr)
end

function should.parseAddOperator()
  local Size = ins:find('Size')
  local plus = Size:method('operator+')
  assertTrue(plus.member)
  assertEqual('operator+', plus.name)
  assertEqual('operator_add', plus.cname)
end

function should.parseSubOperator()
  local Size = ins:find('Size')
  local plus = Size:method('operator-')
  assertTrue(plus.member)
  assertEqual('operator-', plus.name)
  assertEqual('operator_sub', plus.cname)
end

--function should.parseUnmOperator()
--  local Size = ins:find('Size')
--  local plus = Size:method('operator+')
--  assertTrue(plus.member)
--  assertEqual('operator+', plus.name)
--  assertEqual('operator_plus', plus.cname)
--end

function should.parseMulOperator()
  local Size = ins:find('Size')
  local plus = Size:method('operator*')
  assertTrue(plus.member)
  assertEqual('operator*', plus.name)
  assertEqual('operator_mul', plus.cname)
end

function should.parseDivOperator()
  local Size = ins:find('Size')
  local plus = Size:method('operator/')
  assertTrue(plus.member)
  assertEqual('operator/', plus.name)
  assertEqual('operator_div', plus.cname)
end

function should.parseLtOperator()
  local Size = ins:find('Size')
  local plus = Size:method('operator<')
  assertTrue(plus.member)
  assertEqual('operator<', plus.name)
  assertEqual('operator_lt', plus.cname)
end

function should.parseLteOperator()
  local Size = ins:find('Size')
  local plus = Size:method('operator<=')
  assertTrue(plus.member)
  assertEqual('operator<=', plus.name)
  assertEqual('operator_le', plus.cname)
end

function should.parseEqOperator()
  local Size = ins:find('Size')
  local plus = Size:method('operator==')
  assertTrue(plus.member)
  assertEqual('operator==', plus.name)
  assertEqual('operator_eq', plus.cname)
end

test.all()

