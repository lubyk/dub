--[[------------------------------------------------------
param_
  dub.LuaBinder
  -------------

  Test binding with the 'pointers' group of classes:

    * passing classes around as arguments.
    * casting script strings to std::string.
    * casting std::string to script strings.
    * accessing complex public members.
    * accessing public members
    * return value optimization

--]]------------------------------------------------------
require 'lubyk'
-- Run the test with the dub directory as current path.
local should = test.Suite('dub.LuaBinder')
local binder = dub.LuaBinder()

-- Test helper to prepare the inspector.
local function makeInspector()
  return dub.Inspector 'test/fixtures/pointers'
end

--=============================================== Special types
function should.resolveStdString()
  local ins  = makeInspector()
  local Box  = ins:find('Box')
  local ctor = Box:method('Box')
  local res  = binder:functionBody(Box, ctor)
  assertMatch('size_t name_sz_;', res)
  assertMatch('const char %*name = dub_checklstring%(L, 1, %&name_sz_%);', res)
end

--=============================================== Set/Get vars.
function should.bindSimpleSetMethod()
  -- __newindex for simple (native) types
  local ins = makeInspector()
  local Size = ins:find('Size')
  local set = Size:method(Size.SET_ATTR_NAME)
  local res = binder:bindClass(Size)
  assertMatch('__newindex.*Size__set_', res)
  local res = binder:functionBody(Size, set)
  assertMatch('self%->x = luaL_checknumber%(L, 3%);', res)
end

function should.bindComplexSetMethod()
  -- __newindex for non-native types
  local ins = makeInspector()
  local Box = ins:find('Box')
  local set = Box:method(Box.SET_ATTR_NAME)
  local res = binder:bindClass(Box)
  assertMatch('__newindex.*Box__set_', res)
  local res = binder:functionBody(Box, set)
  assertMatch('self%->size_ = %*%*%(%(Size%*%*%)', res)
end

function should.bindSimpleGetMethod()
  -- __newindex for simple (native) types
  local ins = makeInspector()
  local Size = ins:find('Size')
  local set = Size:method(Size.SET_ATTR_NAME)
  local res = binder:bindClass(Size)
  assertMatch('__index.*Size__get_', res)
  local res = binder:functionBody(Size, set)
  assertMatch('self%->x = luaL_checknumber%(L, 3%);', res)
end


function should.bindComplexGetMethod()
  -- __newindex for non-native types
  local ins = makeInspector()
  local Box = ins:find('Box')
  local set = Box:method(Box.SET_ATTR_NAME)
  local res = binder:bindClass(Box)
  assertMatch('__index.*Box__get_', res)
  local res = binder:functionBody(Box, set)
  assertMatch('self%->size_ = %*%*%(%(Size%*%*%)', res)
end

function should.notGetSelfInStaticMethod()
  local ins = makeInspector()
  local Box = ins:find('Box')
  local met = Box:method('MakeBox')
  local res = binder:functionBody(Box, met)
  assertNotMatch('self', res)
end

function should.bindCompileAndLoad()
  local ins = dub.Inspector {INPUT='test/fixtures/pointers', doc_dir = lk.dir() .. '/tmpa'}

  -- create tmp directory
  local tmp_path = lk.dir() .. '/tmp'
  lk.rmTree(tmp_path, true)
  os.execute("mkdir -p "..tmp_path)

  binder:bind(ins, {output_directory = tmp_path})
  local cpath_bak = package.cpath
  local dub_cpp = tmp_path .. '/dub/dub.cpp'
  local s
  assertPass(function()
    -- Build Box.so
    binder:build(tmp_path .. '/Box.so', tmp_path, {'dub/dub.cpp', 'Box.cpp'}, '-I' .. lk.dir() .. '/fixtures/pointers')
    -- Build Size.so
    binder:build(tmp_path .. '/Size.so', tmp_path, {'dub/dub.cpp', 'Size.cpp'}, '-I' .. lk.dir() .. '/fixtures/pointers')
    package.cpath = tmp_path .. '/?.so'
    require 'Box'
    require 'Size'
  end, function()
    -- teardown
    package.loaded.Box = nil
    package.loaded.Size = nil
    package.cpath = cpath_bak
  end)
  --lk.rmTree(tmp_path, true)
end

--=============================================== Size

function should.createSizeObject()
  local s = Size(1,2)
  assertType('userdata', s)
end

function should.readSizeAttributes()
  local s = Size(1.2, 3.4)
  assertEqual(1.2, s.x)
  assertEqual(3.4, s.y)
end

function should.writeSizeAttributes()
  local s = Size(1.2, 3.4)
  s.x = 15
  assertEqual(15, s.x)
  assertEqual(3.4, s.y)
  assertEqual(51, s:surface())
end

function should.handleBadWriteSizeAttr()
  local s = Size(1.2, 3.4)
  assertError("invalid key 'asdf'", function()
    s.asdf = 15
  end)
  assertEqual(1.2, s.x)
  assertEqual(3.4, s.y)
  assertEqual(nil, s.asdf)
end

function should.executeSizeMethods()
  local s = Size(1.2, 3.4)
  assertEqual(4.08, s:surface())
end

--=============================================== Box

function should.createBoxObject()
  local s = Box('Cat', Size(2,3))
  assertType('userdata', s)
end

function should.readBoxAttributes()
  local s = Box('Cat', Size(2,3))
  assertEqual('Cat', s.name_)
  local sz = s.size_
  assertEqual(2, sz.x)
  assertEqual(3, sz.y)
end

function should.writeBoxAttributes()
  local s = Box('Cat', Size(2,3))
  s.name_ = 'Dog'
  assertEqual('Dog', s.name_)
  assertEqual('Dog', s:name())

  s.size_ = Size(8, 1.5)
  assertEqual(8, s.size_.x)
  assertEqual(1.5, s.size_.y)
  assertEqual(12, s:surface())
end

function should.executeBoxMethods()
  local s = Box('Cat', Size(2,3))
  assertEqual(6, s:surface())
end

test.all()

