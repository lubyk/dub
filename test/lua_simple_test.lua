--[[------------------------------------------------------

  dub.LuaBinder
  -------------

  Test basic binding with the 'simple' class.

--]]------------------------------------------------------
require 'lubyk'
-- Run the test with the dub directory as current path.
local should = test.Suite('dub.LuaBinder - simple')
local binder = dub.LuaBinder()

local ins = dub.Inspector {
  INPUT   = 'test/fixtures/simple/include',
  doc_dir = lk.dir() .. '/tmp',
}

--=============================================== TESTS
function should.autoload()
  assertType('table', dub.LuaBinder)
end

function should.bindClass()
  local Simple = ins:find('Simple')
  local res = binder:bindClass(Simple)
  assertMatch('luaopen_Simple', res)
end

function should.bindDestructor()
  local Simple = ins:find('Simple')
  local dtor   = Simple:method('~Simple')
  local res = binder:bindClass(Simple)
  assertMatch('Simple__Simple', res)
  local res = binder:functionBody(Simple, dtor)
  assertMatch('if %(%*self%) delete %*self', res)
end

function should.bindStatic()
  local Simple = ins:find('Simple')
  local met = Simple:method('pi')
  local res = binder:bindClass(Simple)
  assertMatch('Simple_pi', res)
  local res = binder:functionBody(Simple, met)
  assertNotMatch('self', res)
  assertEqual('Simple_pi', binder:bindName(met))
end

function should.bindCompileAndLoad()
  local ins = dub.Inspector 'test/fixtures/simple/include'

  -- create tmp directory
  local tmp_path = lk.dir() .. '/tmp'
  lk.rmTree(tmp_path, true)
  os.execute("mkdir -p "..tmp_path)
  binder:bind(ins, {output_directory = tmp_path, only = {'Simple'}})
  local cpath_bak = package.cpath
  local s
  assertPass(function()
    binder:build {
      work_dir = lk.dir(),
      output   = 'tmp/Simple.so',
      inputs   = {
        'tmp/dub/dub.cpp',
        'tmp/Simple.cpp',
      },
      includes = {
        'tmp',
        'fixtures/simple/include',
      },
    }
    package.cpath = tmp_path .. '/?.so'
    require 'Simple'
    assertType('function', Simple)
  end, function()
    -- teardown
    package.loaded.Simple = nil
    package.cpath = cpath_bak
    if not Simple then
      test.abort = true
    end
  end)
  --lk.rmTree(tmp_path, true)
end

--=============================================== Simple tests

function should.bindNumber()
  local s = Simple(1.4)
  assertEqual(1.4, s:value())
end

function should.bindBoolean()
  assertFalse(Simple(1):isZero())
  assertTrue(Simple(0):isZero())
end

function should.bindMethodWithoutReturn()
  local s = Simple(3.4)
  s:setValue(5)
  assertEqual(5, s:value())
end

test.all()
