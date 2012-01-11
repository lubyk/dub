--[[------------------------------------------------------

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

--=============================================== TESTS
function should.bindSetAttributes()
  local ins = makeInspector()
  local Size = ins:find('Size')
  local set = Size:method(Size.SET_ATTR_NAME)
  local res = binder:bindClass(Size)
  assertMatch('__newindex.*Size__set_', res)
  local res = binder:functionBody(Size, set)
  assertMatch('xxxx', res)
end

--[[
function should.bindCompileAndLoad()
  local class_name = 'Simple'
  local ins = dub.Inspector 'test/fixtures/simple/include'

  -- create tmp directory
  local tmp_path = lk.dir() .. '/tmp'
  lk.rmTree(tmp_path, true)
  os.execute("mkdir -p "..tmp_path)
  binder:bind(ins, {output_directory = tmp_path, only = {class_name}})
  local cpath_bak = package.cpath
  local s
  assertPass(function()
    binder:build(tmp_path .. '/' .. class_name .. '.so', tmp_path, '%.cpp', '-I' .. lk.dir() .. '/fixtures/simple/include')
    package.cpath = tmp_path .. '/?.so'
    require(class_name)
    -- Simple(4.5)
    s = _G[class_name](4.5)
  end, function()
    -- teardown
    _G[class_name] = nil
    package.loaded[class_name] = nil
    package.cpath = cpath_bak
  end)
  if s then
    assertEqual(4.5, s:value())
    assertEqual(123, s:add(110, 13))
  end
  --lk.rmTree(tmp_path, true)
end
--]]

test.all()

