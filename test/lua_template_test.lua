--[[------------------------------------------------------

  dub.LuaBinder
  -------------

  Test binding with the 'template' group of classes:

    * parameter resolution
    * attribute resolution
    * chained typedef

--]]------------------------------------------------------
require 'lubyk'
-- Run the test with the dub directory as current path.
local should = test.Suite('dub.LuaBinder - template')
local binder = dub.LuaBinder()

local ins = dub.Inspector {
  INPUT    = 'test/fixtures/template',
  doc_dir  = lk.dir() .. '/tmp',
}

--=============================================== Vectf bindings

function should.bindClass()
  local Vectf = ins:find('Vectf')
  local res = binder:bindClass(Vectf)
  assertMatch('luaopen_Vect', res)
end

function should.bindMethod()
  local Vectf = ins:find('Vectf')
  local met = Vectf:method('surface')
  local res = binder:functionBody(Vectf, met)
  assertMatch('lua_pushnumber%(L, self%->surface%(%)%);', res)
end

--=============================================== Build

function should.bindCompileAndLoad()
  -- create tmp directory
  local tmp_path = lk.dir() .. '/tmp'
  lk.rmTree(tmp_path, true)
  os.execute("mkdir -p "..tmp_path)

  -- Force resolution of typedef. How to not require this step ?
  ins:find('Vectf')
  binder:bind(ins, {output_directory = tmp_path})
  local cpath_bak = package.cpath
  assertPass(function()
    -- Build Vectf.so
    binder:build {
      output   = 'test/tmp/Vectf.so',
      inputs   = {
        'test/tmp/dub/dub.cpp',
        'test/tmp/Vectf.cpp',
      },
      includes = {
        'test/tmp',
        'test/fixtures/template',
      },
    }
    package.cpath = tmp_path .. '/?.so'
    --require 'Box'
    require 'Vectf'
    assertType('table', Vectf)
  end, function()
    -- teardown
    package.loaded.Box = nil
    package.loaded.Vectf = nil
    package.cpath = cpath_bak
    if not Vectf then
      test.abort = true
    end
  end)
  --lk.rmTree(tmp_path, true)
end

--=============================================== Vectf

-- Our Lua has double precision and our typedef is on float.
-- We have to use values that do not need rounding.

function should.createVectObject()
  local v = Vectf(1.5, 44)
  assertType('userdata', v)
end

function should.readVectAttributes()
  local v = Vectf(1.5, 35)
  assertEqual(1.5, v.x)
  assertEqual(35, v.y)
end

function should.writeVectAttributes()
  local v = Vectf(1.5, 35)
  v.x = 15
  assertEqual(15, v.x)
  assertEqual(35, v.y)
  assertEqual(525, v:surface())
end

function should.handleBadWriteVectAttr()
  local v = Vectf(1.5, 35)
  assertError("invalid key 'asdf'", function()
    v.asdf = 15
  end)
  assertEqual(1.5, v.x)
  assertEqual(35, v.y)
  assertEqual(nil, v.asdf)
end

function should.executeVectMethods()
  local v = Vectf(1.5, 35)
  assertEqual(52.5, v:surface())
end

function should.overloadAdd()
  local v1, v2 = Vectf(1.5, -1), Vectf(4, 2)
  local v = v1 + v2
  assertEqual(5.5, v.x)
  assertEqual(1, v.y)
  assertEqual(5.5, v:surface())
end

function should.executeStaticMethods()
  local v1, v2 = Vectf(1.5, -1), Vectf(4, 2)
  assertEqual(123.5, Vectf.addTwo(120, 3.5))
end

test.all()

