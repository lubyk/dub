--[[------------------------------------------------------

  dub.LuaBinder
  -------------

  Test binding with the 'memory' group of classes:

    * no gc optimization

--]]------------------------------------------------------
require 'lubyk'
-- Run the test with the dub directory as current path.
local should = test.Suite('dub.LuaBinder - memory')
local binder = dub.LuaBinder()

local base = lk.dir()
local ins_opts = {
  INPUT    = base .. '/fixtures/memory',
  doc_dir  = base .. '/tmp',
  PREDEFINED = {
    'SOME_FUNCTION_MACRO(x)=',
    'OTHER_FUNCTION_MACRO(x)=',
  }
}
local ins = dub.Inspector(ins_opts)


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
  assertMatch('dub_pushfulldata<Nogc>%(L, self%->operator%+%(%*v%), "Nogc"%);', res)
end

function should.useCustomPush()
  local Pen = ins:find('Pen')
  local met = Pen:method('Pen')
  local res = binder:functionBody(Pen, met)
  assertMatch('retval__%->pushobject%(L, retval__, "Pen", true%);', res)
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
      output   = base .. '/tmp/mem.so',
      inputs   = {
        base .. '/tmp/dub/dub.cpp',
        base .. '/tmp/mem_Nogc.cpp',
        base .. '/tmp/mem_Withgc.cpp',
        base .. '/tmp/mem_Union.cpp',
        base .. '/tmp/mem_Pen.cpp',
        base .. '/tmp/mem_Owner.cpp',
        base .. '/tmp/mem_PrivateDtor.cpp',
        base .. '/tmp/mem_CustomDtor.cpp',
        base .. '/tmp/mem_NoDtor.cpp',
        base .. '/tmp/mem_NoDtorCleaner.cpp',
        base .. '/fixtures/memory/owner.cpp',
        base .. '/tmp/mem.cpp',
      },
      includes = {
        base .. '/tmp',
        base .. '/fixtures/memory',
      },
    }
    package.cpath = tmp_path .. '/?.so'
    --require 'Box'
    require 'mem'
    assertType('table', mem)
  end, function()
    -- teardown
    package.cpath = cpath_bak
    if not mem then
      test.abort = true
    end
  end)
  --lk.rmTree(tmp_path, true)
end

--=============================================== Nogc

local function createAndDestroyMany(ctor)
  local t = {}
  local start = now()
  for i = 1,100000 do
    table.insert(t, ctor(1,3))
  end
  t = nil
  collectgarbage()
  collectgarbage()
  return now() - start
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

test.all()


