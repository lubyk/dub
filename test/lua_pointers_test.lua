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
local should = test.Suite('dub.LuaBinder - pointers')
local binder = dub.LuaBinder()

local ins = dub.Inspector {
  INPUT    = 'test/fixtures/pointers',
  doc_dir  = lk.dir() .. '/tmp',
}

--=============================================== Special types
function should.resolveStdString()
  local Box  = ins:find('Box')
  local ctor = Box:method('Box')
  local res  = binder:functionBody(Box, ctor)
  assertMatch('size_t name_sz_;', res)
  assertMatch('const char %*name = dub_checklstring%(L, 1, %&name_sz_%);', res)
end

--=============================================== Set/Get vars.
function should.bindSimpleSetMethod()
  -- __newindex for simple (native) types
  local Vect = ins:find('Vect')
  local set = Vect:method(Vect.SET_ATTR_NAME)
  local res = binder:bindClass(Vect)
  assertMatch('__newindex.*Vect__set_', res)
  local res = binder:functionBody(Vect, set)
  assertMatch('self%->x = luaL_checknumber%(L, 3%);', res)
  -- static member
  assertMatch('Vect::create_count = luaL_checknumber%(L, 3%);', res)
end

function should.bindComplexSetMethod()
  -- __newindex for non-native types
  local Box = ins:find('Box')
  local set = Box:method(Box.SET_ATTR_NAME)
  local res = binder:bindClass(Box)
  assertMatch('__newindex.*Box__set_', res)
  local res = binder:functionBody(Box, set)
  assertMatch('self%->size_ = %*%*%(%(Vect%*%*%)', res)
end

function should.bindSimpleGetMethod()
  -- __newindex for simple (native) types
  local Vect = ins:find('Vect')
  local get = Vect:method(Vect.GET_ATTR_NAME)
  local res = binder:bindClass(Vect)
  assertMatch('__index.*Vect__get_', res)
  local res = binder:functionBody(Vect, get)
  assertMatch('lua_pushnumber%(L, self%->x%);', res)
  -- static member
  assertMatch('lua_pushnumber%(L, Vect::create_count%);', res)
end


function should.bindComplexGetMethod()
  -- __newindex for non-native types
  local Box = ins:find('Box')
  local set = Box:method(Box.SET_ATTR_NAME)
  local res = binder:bindClass(Box)
  assertMatch('__index.*Box__get_', res)
  local res = binder:functionBody(Box, set)
  assertMatch('self%->size_ = %*%*%(%(Vect%*%*%)', res)
end

function should.notGetSelfInStaticMethod()
  local Box = ins:find('Box')
  local met = Box:method('MakeBox')
  local res = binder:functionBody(Box, met)
  assertNotMatch('self', res)
end

function should.bindCompileAndLoad()
  -- create tmp directory
  local tmp_path = lk.dir() .. '/tmp'
  os.execute("mkdir -p "..tmp_path)

  binder:bind(ins, {output_directory = tmp_path})
  local cpath_bak = package.cpath
  assertPass(function()
    
    -- Build Vect.so
    binder:build {
      work_dir = lk.dir(),
      output   = 'tmp/Vect.so',
      inputs   = {
        'tmp/dub/dub.cpp',
        'tmp/Vect.cpp',
        'fixtures/pointers/vect.cpp',
      },
      includes = {
        'tmp',
        'fixtures/pointers',
      },
    }
    
    -- Build Box.so
    binder:build {
      work_dir = lk.dir(),
      output   = 'tmp/Box.so',
      inputs   = {
        'tmp/dub/dub.cpp',
        'tmp/Box.cpp',
      },
      includes = {
        'tmp',
        'fixtures/pointers',
      },
    }
    package.cpath = tmp_path .. '/?.so'
    -- Must require Vect first because Box depends on Vect class and
    -- only Vect.so has static members for Vect.
    require 'Vect'
    require 'Box'
    assertType('table', Vect)
  end, function()
    -- teardown
    package.loaded.Box = nil
    package.loaded.Vect = nil
    package.cpath = cpath_bak
    if not Vect then
      test.abort = true
    end
  end)
  --lk.rmTree(tmp_path, true)
end

--=============================================== Vect

function should.createVectObject()
  local v = Vect(1,2)
  assertType('userdata', v)
end

function should.readVectAttributes()
  local v = Vect(1.2, 3.4)
  assertEqual(1.2, v.x)
  assertEqual(3.4, v.y)
end

function should.writeVectAttributes()
  local v = Vect(1.2, 3.4)
  v.x = 15
  assertEqual(15, v.x)
  assertEqual(3.4, v.y)
  assertEqual(51, v:surface())
end


function should.accessStaticAttributes()
  local t, v = Vect(1,1), Vect(1,1)
  -- Access static members through members.
  t.create_count = 0
  assertEqual(0, v.create_count)
  t.create_count = 100
  assertEqual(100, v.create_count)
end

function should.handleBadWriteVectAttr()
  local v = Vect(1.2, 3.4)
  assertError("invalid key 'asdf'", function()
    v.asdf = 15
  end)
  assertEqual(1.2, v.x)
  assertEqual(3.4, v.y)
  assertEqual(nil, v.asdf)
end

function should.executeVectMethods()
  local v = Vect(1.2, 3.4)
  assertEqual(4.08, v:surface())
end

function should.overloadAdd()
  local v1, s2 = Vect(1.2, -1), Vect(4, 2)
  local v = v1 + s2
  assertEqual(5.2, v.x)
  assertEqual(1, v.y)
  assertEqual(5.2, v:surface())
end

function should.overloadSub()
  local v1, s2 = Vect(7, 2), Vect(4, 2)
  local v = v1 - s2
  assertEqual(3, v.x)
  assertEqual(0, v.y)
end

function should.overloadMul()
  local v1 = Vect(7, 2)
  local v = v1 * 4
  assertEqual(28, v.x)
  assertEqual(8, v.y)
  -- overloaded operator* for const Vect.
  assertEqual(12, v1 * Vect(1, 2))
end

function should.overloadDiv()
  local v1 = Vect(7, 2)
  local v = v1 / 2
  assertEqual(3.5, v.x)
  assertEqual(1, v.y)
end

function should.overloadLess()
  -- compares surfaces
  local v1, s2 = Vect(1, 2), Vect(4, 2)
  local v = v1 - s2
  assertTrue(v1  < s2)
  assertFalse(s2 < v1)

  assertTrue(s2  > v1)
  assertFalse(v1 > s2)
end

function should.overloadLessEqual()
  -- compares surfaces
  local v1, s2 = Vect(7, 2), Vect(4, 2)
  local v = v1 - s2
  assertTrue(s2  <= v1)
  assertFalse(v1 <= s2)
  assertTrue(s2  <= s2)

  assertTrue(v1  >= s2)
  assertFalse(s2 >= v1)
  assertTrue(v1  >= v1)
end

function should.overloadEqual()
  local v1, s2 = Vect(7, 2), Vect(4, 2)
  assertFalse(v1 == s2)
  assertTrue(v1 == Vect(7,2))
end
--=============================================== Box

function should.createBoxObject()
  local v = Box('Cat', Vect(2,3))
  assertType('userdata', v)
end

function should.readBoxAttributes()
  local v = Box('Cat', Vect(2,3))
  assertEqual('Cat', v.name_)
  local sz = v.size_
  assertEqual(2, sz.x)
  assertEqual(3, sz.y)
end

function should.writeBoxAttributes()
  local v = Box('Cat', Vect(2,3))
  v.name_ = 'Dog'
  assertEqual('Dog', v.name_)
  assertEqual('Dog', v:name())

  v.size_ = Vect(8, 1.5)
  assertEqual(8, v.size_.x)
  assertEqual(1.5, v.size_.y)
  assertEqual(12, v:surface())
end

function should.executeBoxMethods()
  local v = Box('Cat', Vect(2,3))
  assertEqual(6, v:surface())
end

--=============================================== std::string with \0

function should.handleBinaryData()
  local data = 'Hello\0 World'
  local b = Box(data, Vect(1,2))
  assertEqual(data, b:name())
  data = 'One\0Two\0Three'
  b.name_ = data
  assertEqual(data, b.name_)
  assertNotEqual('One', b.name_)
end

--=============================================== Return value opt.
function should.optimizeReturnValue()
  collectgarbage()
  local t = Vect(1,1)
  -- Access static members through members.
  t.create_count = 0
  t.copy_count = 0
  t.destroy_count = 0

  local v1, v2 = Vect(1,2), Vect(50,80)
  assertEqual(2, t.create_count)
  assertEqual(0, t.copy_count)
  assertEqual(0, t.destroy_count)
  local v3 = v1 + v2
  assertEqual(3, t.create_count)
  assertEqual(0, t.copy_count)
  assertEqual(0, t.destroy_count)
  local v4 = v1 * 2
  assertEqual(4, t.create_count)
  assertEqual(0, t.copy_count)
  assertEqual(0, t.destroy_count)
  v4 = v1 * 3
  collectgarbage()
  assertEqual(5, t.create_count)
  assertEqual(0, t.copy_count)
  assertEqual(1, t.destroy_count)
  v1, v2, v3, v4 = nil, nil, nil, nil
  collectgarbage()
  assertEqual(5, t.create_count)
  assertEqual(0, t.copy_count)
  assertEqual(5, t.destroy_count)
end

--=============================================== Garbage collection
local function createAndDestroyMany()
  local Vect = Vect
  local t = {}
  for i = 1,100000 do
    table.insert(t, Vect(1,3))
  end
  t = nil
  collectgarbage()
  collectgarbage()
end

function should.createAndDestroy()
  -- warmup
  createAndDestroyMany()
  local vm_size = collectgarbage('count')
  createAndDestroyMany()
  assertEqual(vm_size, collectgarbage('count'))
end

test.all()

