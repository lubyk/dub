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
      work_dir = lk.dir(),
      output   = 'tmp/Nogc.so',
      inputs   = {
        'tmp/dub/dub.cpp',
        'tmp/Nogc.cpp',
      },
      includes = {
        'tmp',
        'fixtures/memory',
      },
    }
    -- Build Withgc.so
    binder:build {
      work_dir = lk.dir(),
      output   = 'tmp/Withgc.so',
      inputs   = {
        'tmp/dub/dub.cpp',
        'tmp/Withgc.cpp',
      },
      includes = {
        'tmp',
        'fixtures/memory',
      },
    }
    package.cpath = tmp_path .. '/?.so'
    --require 'Box'
    require 'Nogc'
    require 'Withgc'
    assertType('function', Nogc)
    assertType('function', Withgc)
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
  local now = worker:now()
  for i = 1,100000 do
    table.insert(t, ctor(1,3))
  end
  t = nil
  collectgarbage()
  collectgarbage()
  return worker:now() - now
end

local function runGcTest(ctor)
  -- warmup
  createAndDestroyMany(ctor)
  local vm_size = collectgarbage('count')
  local t = 0
  for i=1,10 do
    t = t + createAndDestroyMany(ctor) / 10
  end
  print('Average execution on 10 runs:', t)
  assertEqual(vm_size, collectgarbage('count'), 1.5)
end

function should.createAndDestroy()
  print('Nogc')
  runGcTest(Nogc)
  print('Withgc')
  runGcTest(Withgc)
end

test.all()


