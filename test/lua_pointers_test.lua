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
  assertMatch('const char *name = dub_checkstring%(L, 1%);', res)
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
  local res = binder:functionBody(Box, set)
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
    binder:build(tmp_path .. '/Size.so', tmp_path, {'dub/dub.cpp', 'Box.cpp'}, '-I' .. lk.dir() .. '/fixtures/pointers')
    package.cpath = tmp_path .. '/?.so'
    require 'Box'
    require 'Size'
    -- Simple(4.5)

  end, function()
    -- teardown
    Box = nil
    Size = nil
    package.loaded.Box = nil
    package.loaded.Size = nil
    package.cpath = cpath_bak
  end)
  if s then
    assertEqual(4.5, s:value())
    assertEqual(123, s:add(110, 13))
  end
  --lk.rmTree(tmp_path, true)
end

test.all()

