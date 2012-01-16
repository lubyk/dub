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

local ins = dub.Inspector {
  INPUT    = 'test/fixtures/inherit',
  doc_dir  = lk.dir() .. '/tmp',
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

function should.notBindSuperStaticMethods()
  local Child = ins:find('Child')
  local res = binder:bindClass(Child)
  assertNotMatch('getName', res)
end

function should.bindCompileAndLoad()
  -- create tmp directory
  local tmp_path = lk.dir() .. '/tmp'
  lk.rmTree(tmp_path, true)
  os.execute('mkdir -p '..tmp_path)

  binder:bind(ins, {
    output_directory = tmp_path,
    custom_bindings = 'test/fixtures/inherit',
  })
  local cpath_bak = package.cpath
  local dub_cpp = tmp_path .. '/dub/dub.cpp'
  local s
  assertPass(function()
    -- Build Child.so
    --
    binder:build {
      work_dir = lk.dir(),
      output   = 'tmp/Child.so',
      inputs   = {
        'tmp/dub/dub.cpp',
        'tmp/Child.cpp',
      },
      includes = {
        'tmp',
        'fixtures/inherit',
      },
    }

    -- Build Parent.so
    binder:build {
      work_dir = lk.dir(),
      output   = 'tmp/Parent.so',
      inputs   = {
        'tmp/dub/dub.cpp',
        'tmp/Parent.cpp',
      },
      includes = {
        'tmp',
        'fixtures/inherit',
      },
    }

    package.cpath = tmp_path .. '/?.so'
    require 'Child'
    require 'Parent'
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
  local c = Child('Romulus', false, -771, 1.23, 2.34)
  assertType('userdata', c)
end

function should.readChildAttributes()
  local c = Child('Romulus', false, -771, 1.23, 2.34)
  assertEqual(-771, c.birth_year)
  assertFalse(c.married)
  assertNil(c.asdfasd)
end

function should.writeChildAttributes()
  local c = Child('Romulus', false, -771, 1.23, 2.34)
  assertError("invalid key 'asdfasd'", function()
    c.asdfasd = 15
  end)
  c.birth_year = 2000
  assertEqual(2000, c.birth_year)
  c.married = true
  assertTrue(c.married)
end

function should.executeSuperMethods()
  local c = Child('Romulus', nil, -771, 1.23, 2.34)
  assertEqual(2783, c:computeAge(2012))
end

--=============================================== Cast

function should.castInCalls()
  local c = Child('Romulus', true, -771, 1.23, 2.34)
  local p = Parent('Rhea', nil, -800)
  assertEqual('Romulus', Parent.getName(c))
  assertEqual('Rhea', Parent.getName(p))
end

--=============================================== Custom bindings

function should.useCustomBindings()
  local c = Child('Romulus', true, -771, 1.23, 2.34)
  local x, y = c:position()
  assertEqual(1.23, x)
  assertEqual(2.34, y)
end

test.all()

