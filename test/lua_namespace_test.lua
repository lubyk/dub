--[[------------------------------------------------------

  dub.LuaBinder
  -------------

  Test binding with the 'namespace' group of classes:

    * nested classes
    * proper namespace in bindings

--]]------------------------------------------------------
local lub = require 'lub'
local lut = require 'lut'
local dub = require 'dub'

local should = lut.Test('dub.LuaBinder - namespace', {coverage = false})
local binder = dub.LuaBinder()

binder:parseCustomBindings(lub.path '|fixtures/namespace')

local ins, moo

function should.setup()
  dub.warn = dub.silentWarn
  if not ins then
    ins = dub.Inspector {
      INPUT    = lub.path '|fixtures/namespace',
      doc_dir  = lub.path '|tmp',
    }
  end
end

function should.teardown()
  dub.warn = dub.printWarn
end

--=============================================== bindings

function should.bindClass()
  local A = ins:find('Nem::A')
  local res = binder:bindClass(A)
  assertMatch('luaopen_A', res)
end

function should.useFullnameInMetaName()
  local A = ins:find('Nem::A')
  local res = binder:bindClass(A)
  assertMatch('dub::pushudata%(L, retval__, "Nem.A", true%);', res)
end

function should.bindGlobalFunction()
  local met = ins:find('Nem::addTwo')
  local res = binder:functionBody(met)
  assertMatch('B %*a = %*%(%(B %*%*%)dub::checksdata%(L, 1, "Nem.B"%)%);', res)
  assertMatch('B %*b = %*%(%(B %*%*%)dub::checksdata%(L, 2, "Nem.B"%)%);', res)
  assertMatch('lua_pushnumber%(L, Nem::addTwo%(%*a, %*b%)%);', res)
end

function should.useCustomBindingsForGlobal()
  local met = ins:find('Nem::customGlobal')
  local res = binder:functionBody(met)
  assertMatch('float a = dub::checknumber%(L, 1%);', res)
  assertMatch('float b = dub::checknumber%(L, 2%);', res)
  assertMatch('lua_pushnumber%(L, a %+ b%);', res)
  assertMatch('lua_pushstring%(L, "custom global"%);', res)
  assertMatch('return 2;', res)
end

function should.bindGlobalFunctionNotInNamespace()
  local met = ins:find('addTwoOut')
  local res = binder:functionBody(met)
  assertMatch('B %*a = %*%(%(B %*%*%)dub::checksdata%(L, 1, "Nem.B"%)%);', res)
  assertMatch('B %*b = %*%(%(B %*%*%)dub::checksdata%(L, 2, "Nem.B"%)%);', res)
  assertMatch('lua_pushnumber%(L, addTwoOut%(%*a, %*b%)%);', res)
end

function should.bindAll()
  local tmp_path = lub.path '|tmp'
  lub.rmTree(tmp_path, true)

  binder:bind(ins, {
    output_directory = tmp_path,
    single_lib = 'moo',
    no_prefix  = true,
  })
  local files = {}
  for file in lub.Dir(tmp_path):list() do
    local base, filename = lub.dir(file)
    lub.insertSorted(files, filename)
  end
  assertValueEqual({
    'Nem_A.cpp',
    'Nem_B.cpp',
    'dub',
    'moo.cpp',
  }, files)
end

--=============================================== nested class

function should.useFullnameInCtor()
  local C   = ins:find('Nem::B::C')
  local met = C:method('C')
  local res = binder:functionBody(met)
  assertMatch('B::C %*retval__', res)
  assertMatch('new B::C%(', res)
  assertMatch('dub::pushudata%(L, retval__, "Nem.B.C", true%);', res)
end

function should.properlyResolveReturnTypeInMethod()
  local C   = ins:find('Nem::B')
  local met = C:method('getC')
  local res = binder:functionBody(met)
  assertMatch('B::C %*retval__ = self%->getC%(%);', res)
  assertMatch('dub::pushudata%(L, retval__, "Nem.B.C", false%);', res)
end

function should.properlyResolveTypeInGetAttr()
  local C   = ins:find('Nem::B::C')
  local met = C:method('C')
  local res = binder:functionBody(met)
  assertMatch('B::C %*retval__', res)
  assertMatch('new B::C%(', res)
  assertMatch('dub::pushudata%(L, retval__, "Nem.B.C", true%);', res)
end

--=============================================== Build

function should.changeNamespaceNameOnBind()
  -- Cannot reuse inspector with different binder settings (Nem.B.C
  -- found instead of moo.B.C)
  local ins = dub.Inspector {
    INPUT    = {
      lub.path '|fixtures/namespace',
      -- This is just to have the Vect class for gc testing.
      lub.path '|fixtures/pointers',
    },
    doc_dir  = lub.path '|tmp',
  }

  local tmp_path = lub.path '|tmp'
  lub.rmTree(tmp_path, true)

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
    -- This is used to bind the namespace constants and
    -- functions.
    namespace  = 'Nem',
    -- We need this to avoid nesting prefix
    no_prefix = true,
    only = {
      'Nem::A',
      'Nem::B',
      'Nem::B::C',
      'Nem::Rect',
      'Vect',
    },
    custom_bindings = lub.path '|fixtures/namespace',
  })
  binder.name = nil
  local res = lub.content(tmp_path .. '/moo_A.cpp')
  assertNotMatch('moo%.Nem', res)
  assertMatch('"moo%.A"', res)
  assertMatch('luaopen_moo_A', res)

  local res = lub.content(tmp_path .. '/moo_B_C.cpp')
  assertNotMatch('moo%.Nem', res)
  assertMatch('"moo%.B%.C"', res)
  assertMatch('luaopen_moo_B_C', res)

  -- Build 'moo.so'

  assertPass(function()
    binder:build {
      output   = lub.path '|tmp/moo.so',
      inputs   = {
        lub.path '|tmp/dub/dub.cpp',
        lub.path '|tmp/moo_A.cpp',
        lub.path '|tmp/moo_B.cpp',
        lub.path '|tmp/moo_B_C.cpp',
        lub.path '|tmp/moo.cpp',
        lub.path '|tmp/Vect.cpp',
        lub.path '|tmp/moo_Rect.cpp',
        lub.path '|fixtures/pointers/vect.cpp',
      },
      includes = {
        lub.path '|tmp',
        -- This is for lua.h
        lub.path '|tmp/dub',
        lub.path '|fixtures/namespace',
      },
    }

    local cpath_bak = package.cpath
    package.cpath = tmp_path .. '/?.so'

    moo = require 'moo'
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
      lut.Test.abort = true
    end
  end)
end

function should.bindGlobalFunctions()
  --local res = lub.content(tmp_path .. '/moo.cpp')
  --assertMatch('XXXXX', res)
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
  local watch = moo.Vect(0,0)
  assertNil(a.userdata)
  collectgarbage()
  watch.create_count  = 0
  watch.destroy_count = 0
  local v = moo.Vect(3, 4)
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
  local watch = moo.Vect(0,0)
  collectgarbage()
  watch.create_count  = 0
  watch.destroy_count = 0
  local v = moo.Vect(3, 7)
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

function should.callNamespaceFunction()
  local a = moo.B(1)
  local b = moo.B(2)
  assertEqual(3, moo.addTwo(a,b))
end

function should.haveFunctionOutOfNamespace()
  assertEqual('function', type(moo.addTwoOut))
end

function should.callCustomGlobal()
  assertValueEqual({
    9,
    "custom global",
  }, {moo.customGlobal(4, 5)})
end

function should.readNamespaceConstant()
  assertEqual(1, moo.One)
  assertEqual(2, moo.Two)
  assertEqual(55, moo.Three)
end

function should.decideOver()
  local a = moo.A(1)
  local b = moo.B(2)
  assertPass(function()
    assertEqual('A', a:over(a))
  end)
  assertPass(function()
    assertEqual('B', a:over(b))
  end)
end

should:test()

