--[[------------------------------------------------------

  dub.LuaBinder
  -------------

  Test binding with the 'namespace' group of classes:

    * nested classes
    * proper namespace in bindings

--]]------------------------------------------------------
require 'lubyk'
-- Run the test with the dub directory as current path.
local should = test.Suite('dub.LuaBinder - namespace')
local binder = dub.LuaBinder()

local ins = dub.Inspector {
  INPUT    = {
    'test/fixtures/namespace',
  },
  doc_dir  = lk.dir() .. '/tmp',
}

--=============================================== bindings

function should.bindClass()
  local A = ins:find('Nem::A')
  local res = binder:bindClass(A)
  assertMatch('luaopen_A', res)
end

function should.useFullnameInMetaName()
  local A = ins:find('Nem::A')
  local res = binder:bindClass(A)
  assertMatch('dub_pushudata%(L, retval__, "Nem.A", true%);', res)
end

--=============================================== nested class

function should.useFullnameInCtor()
  local C   = ins:find('Nem::B::C')
  local met = C:method('C')
  local res = binder:functionBody(C, met)
  assertMatch('B::C %*retval__', res)
  assertMatch('new B::C%(', res)
  assertMatch('dub_pushudata%(L, retval__, "Nem.B.C", true%);', res)
end

function should.properlyResolveReturnTypeInMethod()
  local C   = ins:find('Nem::B')
  local met = C:method('getC')
  local res = binder:functionBody(C, met)
  assertMatch('B::C %*retval__ = self%->getC%(%);', res)
  assertMatch('dub_pushudata%(L, retval__, "Nem.B.C", false%);', res)
end

function should.properlyResolveTypeInGetAttr()
  local C   = ins:find('Nem::B::C')
  local met = C:method('C')
  local res = binder:functionBody(C, met)
  assertMatch('B::C %*retval__', res)
  assertMatch('new B::C%(', res)
  assertMatch('dub_pushudata%(L, retval__, "Nem.B.C", true%);', res)
end

--=============================================== Build

function should.changeNamespaceNameOnBind()
  -- Cannot reuse inspector with different binder settings (Nem.B.C
  -- found instead of moo.B.C)
  local ins = dub.Inspector {
    INPUT    = {
      'test/fixtures/namespace',
      -- This is just to have the Vect class for gc testing.
      'test/fixtures/pointers',
    },
    doc_dir  = lk.dir() .. '/tmp',
  }

  local tmp_path = 'test/tmp'
  lk.rmTree(tmp_path, true)

  os.execute('mkdir -p '..tmp_path)
  -- This is how we can change namespace scoping
  function binder:name(elem)
    if elem.name == 'Nem' then
      return 'moo'
    else
      return elem.name
    end
  end
  binder:bind(ins, {
    output_directory = tmp_path,
    -- Execute all lua_open in a single go
    -- with lua_MyLib.
    -- This creates a MyLib_open.cpp file
    -- that has to be included in build.
    single_lib = 'moo',
    lib_prefix = false,
    only = {
      'Nem::A',
      'Nem::B',
      'Nem::B::C',
      'Nem::Rect',
      'Vect',
    },
    custom_bindings = 'test/fixtures/namespace',
  })
  binder.name = nil
  local res = lk.readall(tmp_path .. '/moo_A.cpp')
  assertNotMatch('moo%.Nem', res)
  assertMatch('"moo%.A"', res)
  assertMatch('luaopen_moo_A', res)

  local res = lk.readall(tmp_path .. '/moo_B_C.cpp')
  assertNotMatch('moo%.Nem', res)
  assertMatch('"moo%.B%.C"', res)
  assertMatch('luaopen_moo_B_C', res)

  -- Build 'moo.so'

  assertPass(function()
    binder:build {
      output   = 'test/tmp/moo.so',
      inputs   = {
        'test/tmp/dub/dub.cpp',
        'test/tmp/moo_A.cpp',
        'test/tmp/moo_B.cpp',
        'test/tmp/moo_B_C.cpp',
        'test/tmp/moo.cpp',
        'test/tmp/Vect.cpp',
        'test/tmp/moo_Rect.cpp',
        'test/fixtures/pointers/vect.cpp',
      },
      includes = {
        'test/tmp',
        'test/fixtures/namespace',
      },
    }

    local cpath_bak = package.cpath
    package.cpath = tmp_path .. '/?.so'

    require 'moo'
    assertType('table', moo)
    assertType('table', moo.A)
    assertType('table', moo.B)
    assertType('table', moo.B.C)
  end, function()
    -- teardown
    package.cpath = cpath_bak
    -- teardown
    package.cpath = cpath_bak
    if not moo then
      test.abort = true
    end
  end)
end

function should.findA()
  local a = moo.A()
  assertEqual('moo.A', a.type)
end

function should.findB()
  local b = moo.B(5)
  assertEqual('moo.B', b.type)
end

function should.findC()
  local c = moo.B.C(99)
  assertEqual('moo.B.C', c.type)
end

function should.findNestedClass()
  local c = moo.B.C(456)
  assertEqual(456, c:nb())
  local b = moo.B(c)
  assertEqual(456, b.c:nb())
  assertEqual(456, b.nb_)
end

function should.useCustomAccessor()
  local a = moo.A()
  local watch = Vect(0,0)
  assertNil(a.userdata)
  collectgarbage()
  watch.create_count  = 0
  watch.destroy_count = 0
  local v = Vect(3, 4)
  assertEqual(1, watch.create_count)
  a.userdata = v
  assertEqual(4, a.userdata.y)
  assertEqual(1, watch.create_count)
  v = nil
  collectgarbage() -- should not release v
  assertEqual(0, watch.destroy_count)
  a = nil
  collectgarbage() -- should release v
  collectgarbage() -- should release v
  assertEqual(1, watch.destroy_count)
end

function should.useCustomAccessor()
  local a = moo.A()
  local watch = Vect(0,0)
  collectgarbage()
  watch.create_count  = 0
  watch.destroy_count = 0
  local v = Vect(3, 7)
  assertEqual(1, watch.create_count)
  a.userdata = v
  assertEqual(1, a.userdata.x)
  assertEqual(1, watch.create_count)
  v = nil
  collectgarbage() -- should not release v
  assertEqual(3, a.userdata.x)
  assertEqual(0, watch.destroy_count)
  a.userdata = nil
  collectgarbage() -- should release v
  assertEqual(1, watch.destroy_count)
end

function should.setAnyLuaValue()
  local a = moo.A()
  local e = {}
  a.userdata = e
  assertEqual(e, a.userdata)
  a.userdata = 4.53
  assertEqual(4.53, a.userdata)
end

function should.buildTemplate()
  local r = moo.Rect(4,3)
  assertEqual(4, r.w)
  assertEqual(3, r.h)
end
test.all()


