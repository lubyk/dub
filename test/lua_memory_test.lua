--[[------------------------------------------------------

  dub.LuaBinder
  -------------

  Test binding with the 'memory' group of classes:

    * no gc optimization

--]]------------------------------------------------------
require 'lubyk'
-- Run the test with the dub directory as current path.
local should = test.Suite('dub.LuaBinder - template')
local binder = dub.LuaBinder()

local ins = dub.Inspector {
  INPUT    = 'test/fixtures/memory',
  doc_dir  = lk.dir() .. '/tmp',
  PREDEFINED = {
    'SOME_FUNCTION_MACRO(x)=',
    'OTHER_FUNCTION_MACRO(x)=',
  }
}

--=============================================== Nogc bindings

function should.bindClass()
  local Nogc = ins:find('Nogc')
  local res = binder:bindClass(Nogc)
  assertMatch('luaopen_Nogc', res)
end

function should.notBindDestructor()
  local Nogc = ins:find('Nogc')
  local res = binder:bindClass(Nogc)
  assertNotMatch('__gc', res)
end

function should.bindDestructor()
  local Withgc = ins:find('Withgc')
  local res = binder:bindClass(Withgc)
  assertMatch('__gc', res)
end

--=============================================== Build

function should.bindCompileAndLoad()
  -- create tmp directory
  local tmp_path = lk.dir() .. '/tmp'
  lk.rmTree(tmp_path, true)
  os.execute("mkdir -p "..tmp_path)

  -- How to avoid this step ?
  ins:find('Nogc')
  ins:find('Withgc')
  binder:bind(ins, {output_directory = tmp_path})
  local cpath_bak = package.cpath
  assertPass(function()
    -- Build Nogc.so
    binder:build {
      output   = 'test/tmp/Nogc.so',
      inputs   = {
        'test/tmp/dub/dub.cpp',
        'test/tmp/Nogc.cpp',
      },
      includes = {
        'test/tmp',
        'test/fixtures/memory',
      },
    }
    -- Build Withgc.so
    binder:build {
      output   = 'test/tmp/Withgc.so',
      inputs   = {
        'test/tmp/dub/dub.cpp',
        'test/tmp/Withgc.cpp',
      },
      includes = {
        'test/tmp',
        'test/fixtures/memory',
      },
    }
    package.cpath = tmp_path .. '/?.so'
    --require 'Box'
    require 'Nogc'
    require 'Withgc'
    assertType('table', Nogc)
    assertType('table', Withgc)
  end, function()
    -- teardown
    package.loaded.Box = nil
    package.loaded.Nogc = nil
    package.cpath = cpath_bak
    if not Nogc then
      test.abort = true
    end
  end)
  --lk.rmTree(tmp_path, true)
end

--=============================================== Nogc

local function createAndDestroyMany(ctor)
  local t = {}
  local start = worker:now()
  for i = 1,100000 do
    table.insert(t, ctor(1,3))
  end
  t = nil
  collectgarbage()
  collectgarbage()
  return worker:now() - start
end

local function runGcTest(ctor, fmt)
  -- warmup
  createAndDestroyMany(ctor)
  local vm_size = collectgarbage('count')
  if fmt then
    local t = createAndDestroyMany(ctor)
    printf(fmt, t)
  else
    createAndDestroyMany(ctor)
  end
  assertEqual(vm_size, collectgarbage('count'), 1.5)
end

function should.createAndDestroy()
  if test.speed then
    runGcTest(Nogc.new,   "__gc optimization:      create and destroy 100'000 elements: %.2f ms.")
    runGcTest(Withgc.new, "Normal __gc:            create and destroy 100'000 elements: %.2f ms.")
    runGcTest(Withgc,     "Normal __gc and __call: create and destroy 100'000 elements: %.2f ms.")
  else
    runGcTest(Nogc.new)
    runGcTest(Withgc.new)
  end
end

test.all()


