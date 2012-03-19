--[[------------------------------------------------------
param_
  dub.LuaBinder
  -------------

  Test binding with the 'inherit' group of classes:

    * binding attributes accessor with super attributes.
    * binding methods from super classes.
    * custom bindings.
    * cast to super type when needed.

--]]------------------------------------------------------
require 'lubyk'
-- Run the test with the dub directory as current path.
local should = test.Suite('dub.LuaBinder - inherit')
local binder = dub.LuaBinder()

local base = lk.dir()

local ins = dub.Inspector {
  INPUT    = base .. '/fixtures/inherit',
  doc_dir  = base .. '/tmp',
}

--=============================================== Set/Get vars.
function should.bindSetMethodWithSuperAttrs()
  -- __newindex for simple (native) types
  local Child = ins:find('Child')
  local set = Child:method(Child.SET_ATTR_NAME)
  local res = binder:bindClass(Child)
  assertMatch('__newindex.*Child__set_', res)
  local res = binder:functionBody(Child, set)
  assertMatch('self%->birth_year = luaL_checknumber%(L, 3%);', res)
end

function should.bindGetMethodWithSuperAttrs()
  -- __newindex for simple (native) types
  local Child = ins:find('Child')
  local get = Child:method(Child.GET_ATTR_NAME)
  local res = binder:bindClass(Child)
  assertMatch('__index.*Child__get_', res)
  local res = binder:functionBody(Child, get)
  assertMatch('lua_pushnumber%(L, self%->birth_year%);', res)
end

function should.bindCastWithTemplateParent()
  -- __newindex for simple (native) types
  local Orphan = ins:find('Orphan')
  local met = Orphan:method(Orphan.CAST_NAME)
  local res = binder:functionBody(Orphan, met)
  assertMatch('%*retval__ = static_cast<Foo< int > %*>%(self%);', res)
end

function should.notBindSuperStaticMethods()
  local Child = ins:find('Child')
  local res = binder:bindClass(Child)
  assertNotMatch('getName', res)
end

function should.bindCompileAndLoad()
  local tmp_path = base .. '/tmp'
  -- create tmp directory
  lk.rmTree(tmp_path, true)
  os.execute('mkdir -p '..tmp_path)

  binder:bind(ins, {
    output_directory = base .. '/tmp',
    custom_bindings  = base .. '/fixtures/inherit',
    extra_headers = {
      Child = {
        "../inherit_hidden/Mother.h",
      }
    }
  })
  local cpath_bak = package.cpath
  local dub_cpp = tmp_path .. '/dub/dub.cpp'
  local s
  assertPass(function()
    -- Build Child.so
    --
    binder:build {
      output   = base .. '/tmp/Child.so',
      inputs   = {
        base .. '/tmp/dub/dub.cpp',
        base .. '/tmp/Child.cpp',
        base .. '/fixtures/inherit/child.cpp',
      },
      includes = {
        base .. '/tmp',
        base .. '/fixtures/inherit',
      },
    }

    -- Build Parent.so
    binder:build {
      output   = base .. '/tmp/Parent.so',
      inputs   = {
        base .. '/tmp/dub/dub.cpp',
        base .. '/tmp/Parent.cpp',
      },
      includes = {
        base .. '/tmp',
        base .. '/fixtures/inherit',
      },
    }

    -- Build Orphan.so
    binder:build {
      output   = base .. '/tmp/Orphan.so',
      inputs   = {
        base .. '/tmp/dub/dub.cpp',
        base .. '/tmp/Orphan.cpp',
      },
      includes = {
        base .. '/tmp',
        base .. '/fixtures/inherit',
      },
    }

    package.cpath = tmp_path .. '/?.so'
    require 'Child'
    require 'Parent'
    require 'Orphan'
    assertType('table', Child)
  end, function()
    -- teardown
    package.loaded.Child  = nil
    package.loaded.Parent = nil
    package.cpath = cpath_bak
    if not Child then
      test.abort = true
    end
  end)
  --lk.rmTree(tmp_path, true)
end

--=============================================== Inheritance

function should.createChildObject()
  local c = Child('Romulus', Parent.Depends, -771, 1.23, 2.34)
  assertType('userdata', c)
end

function should.readChildAttributes()
  local c = Child('Romulus', Parent.Single, -771, 1.23, 2.34)
  assertEqual(-771, c.birth_year)
  assertTrue(c.happy)
  assertEqual(Child.Single)
  assertNil(c.asdfasd)
end

function should.writeChildAttributes()
  local c = Child('Romulus', Parent.Poly, -771, 1.23, 2.34)
  assertError("invalid key 'asdfasd'", function()
    c.asdfasd = 15
  end)
  c.birth_year = 2000
  assertEqual(2000, c.birth_year)
  c.status = Parent.Single
  assertEqual(Parent.Single, c.status)
end

function should.executeSuperMethods()
  local c = Child('Romulus', Parent.Poly, -771, 1.23, 2.34)
  assertEqual(2783, c:computeAge(2012))
end

--=============================================== Cast

function should.castInCalls()
  local c = Child('Romulus', Parent.Married, -771, 1.23, 2.34)
  local p = Parent('Rhea', Parent.Single, -800)
  assertEqual('Romulus', Parent.getName(c))
  assertEqual('Rhea', Parent.getName(p))
end

--=============================================== Custom bindings

function should.useCustomBindings()
  local c = Child('Romulus', Parent.Depends, -771, 1.23, 2.34)
  local x, y = c:position()
  assertEqual(1.23, x)
  assertEqual(2.34, y)
end

function should.useCustomBindingsWithDefaultValue()
  local c = Child('Romulus', Parent.Depends, -771, 1.23, 2.34)
  assertEqual(5.23, c:addToX())
  assertEqual(2.23, c:addToX(1))
end

test.all()

