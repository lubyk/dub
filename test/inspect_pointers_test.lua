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

function should.haveSetMethod()
  local ins = makeInspector()
  local Size = ins:find('Size')
  local set  = Size:method(Size.SET_ATTR_NAME)
  assertTrue(set.is_set_attr)
end

test.all()

