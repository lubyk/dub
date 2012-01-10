--[[------------------------------------------------------

  dub.LuaBinder
  -------------

  Test basic binding with the 'simple' class.

--]]------------------------------------------------------
require 'lubyk'
-- Run the test with the dub directory as current path.
local should = test.Suite('dub.LuaBinder')
local binder = dub.LuaBinder()

-- Test helper to prepare the inspector.
local function makeInspector()
  local ins = dub.Inspector()
  ins:parse('test/fixtures/simple/doc/xml')
  return ins
end

--=============================================== TESTS
function should.autoload()
  assertType('table', dub.LuaBinder)
end

function should.bindClass()
  local ins = makeInspector()
  local Simple = ins:find('Simple')
  local res = binder:bindClass(Simple)
  --print(res)
end

function should.bindDestructor()
  local ins = makeInspector()
  local Simple = ins:find('Simple')
  local res = binder:bindClass(Simple)
  --print(res)
end

function should.bindCompileAndLoad()
  local class_name = 'Simple'
  local ins = makeInspector()
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
  lk.rmTree(tmp_path, true)
end
test.all()
