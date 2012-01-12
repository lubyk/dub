--[[------------------------------------------------------

  dub.Inspector test
  ------------------

  Test introspective operations with the 'pointers' group
  of classes.

--]]------------------------------------------------------
require 'lubyk'
local should = test.Suite('dub.Inspector')

-- Test helper to prepare the inspector.
local function makeInspector()
  return dub.Inspector {
    INPUT = 'test/fixtures/pointers',
    doc_dir = lk.dir() .. '/tmp',
  }

  --return dub.Inspector 'test/fixtures/pointers'
end

--=============================================== TESTS

function should.findSizeClass()
  local ins = makeInspector()
  local Size = ins:find('Size')
  assertEqual('dub.Class', Size.type)
end

function should.parseParamTypes()
  local ins = makeInspector()
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
  local ins = makeInspector()
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
  local ins = makeInspector()
  local Size = ins:find('Size')
  local res = {}
  for attr in Size:attributes() do
    table.insert(res, attr.name)
  end
  assertValueEqual({'x', 'y'}, res)
end

function should.listMethods()
  local ins = makeInspector()
  local Size = ins:find('Size')
  local res = {}
  for meth in Size:methods() do
    table.insert(res, meth.name)
  end
  assertValueEqual({'_Size', Size.GET_ATTR_NAME, Size.SET_ATTR_NAME, 'Size', 'surface'}, res)
end

function should.listStaticMethods()
  local ins = makeInspector()
  local Box = ins:find('Box')
  local res = {}
  for meth in Box:methods() do
    table.insert(res, meth.name)
  end
  assertValueEqual({'_Box', Box.GET_ATTR_NAME, Box.SET_ATTR_NAME, 'Box', 'name', 'MakeBox'}, res)
end

function should.staticMethodShouldBeStatic()
  local ins = makeInspector()
  local Box = ins:find('Box')
  local met = Box:method('MakeBox')
  assertTrue(met.static)
end

function should.haveSetMethod()
  local ins = makeInspector()
  local Size = ins:find('Size')
  local set  = Size:method(Size.SET_ATTR_NAME)
  assertTrue(set.is_set_attr)
end

test.all()

