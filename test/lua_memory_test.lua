--[[------------------------------------------------------

  dub.LuaBinder
  -------------

  Test binding with the 'memory' group of classes:

    * no gc optimization

--]]------------------------------------------------------
local lub = require 'lub'
local lut = require 'lut'
local dub = require 'dub'

local should = lut.Test('dub.LuaBinder - memory', {coverage = false})

local binder = dub.LuaBinder()
local elapsed = function() return 0 end

local ins_opts = {
  INPUT    = lub.path '|fixtures/memory',
  doc_dir  = lub.path '|tmp',
  PREDEFINED = {
    'SOME_FUNCTION_MACRO(x)=',
    'OTHER_FUNCTION_MACRO(x)=',
  }
}
local ins = dub.Inspector(ins_opts)

local mem

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

function should.pushFullUserdataInRetval()
  local Nogc = ins:find('Nogc')
  local met = Nogc:method('operator+')
  local res = binder:functionBody(Nogc, met)
  assertMatch('dub::pushfulldata<Nogc>%(L, self%->operator%+%(%*v%), "Nogc"%);', res)
end

function should.useCustomPush()
  local Pen = ins:find('Pen')
  local met = Pen:method('Pen')
  local res = binder:functionBody(Pen, met)
  assertMatch('retval__%->dub_pushobject%(L, retval__, "Pen", true%);', res)
end

function should.bindDestructor()
  local Withgc = ins:find('Withgc')
  local res = binder:bindClass(Withgc)
  assertMatch('__gc', res)
end

--=============================================== Build

function should.bindCompileAndLoad()
  -- create tmp directory
  local tmp_path = lub.path '|tmp'
  lub.rmTree(tmp_path, true)
  os.execute("mkdir -p "..tmp_path)

  local ins = dub.Inspector(ins_opts)
  binder:bind(ins, {
    output_directory = tmp_path,
    single_lib = 'mem',
    attr_name_filter = function(elem)
      return elem.name:match('(.*)_$') or elem.name
    end,
  })
  local cpath_bak = package.cpath
  assertPass(function()
    -- Build mem.so
    binder:build {
      output   = lub.path '|tmp/mem.so',
      inputs   = {
        lub.path '|tmp/dub/dub.cpp',
        lub.path '|tmp/mem_Nogc.cpp',
        lub.path '|tmp/mem_Withgc.cpp',
        lub.path '|tmp/mem_Union.cpp',
        lub.path '|tmp/mem_Pen.cpp',
        lub.path '|tmp/mem_Owner.cpp',
        lub.path '|tmp/mem_PrivateDtor.cpp',
        lub.path '|tmp/mem_CustomDtor.cpp',
        lub.path '|tmp/mem_NoDtor.cpp',
        lub.path '|tmp/mem_NoDtorCleaner.cpp',
        lub.path '|fixtures/memory/owner.cpp',
        lub.path '|tmp/mem.cpp',
      },
      includes = {
        lub.path '|tmp',
        -- This is for lua.h
        lub.path '|tmp/dub',
        lub.path '|fixtures/memory',
      },
    }
    package.cpath = tmp_path .. '/?.so'
    --require 'Box'
    mem = require 'mem'
    assertType('table', mem)
  end, function()
    -- teardown
    package.cpath = cpath_bak
    if not mem then
      lut.Test.abort = true
    end
  end)
  --lub.rmTree(tmp_path, true)
end

--=============================================== Nogc

local function createAndDestroyMany(ctor)
  local t = {}
  local start = elapsed()
  for i = 1,100000 do
    table.insert(t, ctor(1,3))
  end
  t = nil
  collectgarbage()
  collectgarbage()
  return elapsed() - start
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
  if test_speed then
    local lens = require 'lens'
    elapsed = lens.elapsed
    runGcTest(mem.Nogc.new,   "__gc optimization:      create and destroy 100'000 elements: %.2f ms.")
    runGcTest(mem.Withgc.new, "Normal __gc:            create and destroy 100'000 elements: %.2f ms.")
    runGcTest(mem.Withgc,     "Normal __gc and __call: create and destroy 100'000 elements: %.2f ms.")
  else
    runGcTest(mem.Nogc.new)
    runGcTest(mem.Withgc.new)
  end
end

--=============================================== UNION

function should.destroyFromLua()
  local p = mem.Pen('Arty')
  local o = mem.Owner()
  p:setOwner(o)
  p = nil
  collectgarbage()
  collectgarbage()
  -- Destructor called in C++
  assertEqual("Pen 'Arty' is dying...", o.message)
end

function should.destroyFromCpp()
  local p = mem.Pen('Arty')
  local o = mem.Owner(p)
  o:destroyPen()
  -- Destructor called in C++
  assertEqual("Pen 'Arty' is dying...", o.message)
  -- Object is dead in Lua
  assertError('lua_memory_test.lua:[0-9]+: name: using deleted mem.Pen', function()
    p:name()
  end)
  assertTrue(p:deleted())
end

function should.considerAnonUnionAsMembers()
  local u = mem.Union(10, 15, 4, 100)
  assertEqual(10,  u.h)
  assertEqual(15,  u.s)
  assertEqual(4,   u.v)
  assertEqual(100, u.a)
  local c = 10 + (15 * 2^8) + (4 * 2^16) + (100 * 2^24)
  assertEqual(c,  u.c)

  u.a = 11
  local c = 10 + (15 * 2^8) + (4 * 2^16) + (11 * 2^24)
  assertEqual(c,  u.c)
end

--=============================================== Custom dtor

function should.useCustomDtor()
  local d = mem.CustomDtor()
  local t
  function d:callback()
    t = true
  end
  assertNil(t)
  d = nil
  collectgarbage('collect')
  collectgarbage('collect')
  assertTrue(t)
end

--=============================================== No dtor

function should.notUseDtor()
  local d = mem.NoDtor('Hulk')
  local cleaner = mem.NoDtorCleaner(d)
  local t
  -- When d is deleted, it calls cleaner->deleted which
  -- calls this callback.
  function cleaner:callback(s)
    t = s
  end
  assertNil(t)
  d = nil
  collectgarbage('collect')
  collectgarbage('collect')
  -- Callback not called: d is not deleted
  assertNil(t)
  -- Explicitely delete attached NoDtor.
  cleaner:cleanup()
  -- Callback called: d is deleted
  assertEqual('Hulk', t)
end

should:test()

