--[[------------------------------------------------------

  dub.LuaBinder
  -------------

  Test binding with the 'thread' group of classes:

    * initialize object with custom method.
    * return <self> table instead of userdata.
    * callback from C++.
    * custom error function in self.

--]]------------------------------------------------------
local lub = require 'lub'
local lut = require 'lut'
local dub = require 'dub'

local should = lut.Test('dub.LuaBinder - thread', {coverage = false})
local binder = dub.LuaBinder()

local ins = dub.Inspector {
  INPUT    = 'test/fixtures/thread',
  doc_dir  = lub.path '|tmp',
}

local thread

--=============================================== Callback bindings

function should.bindClass()
  local Callback = ins:find('Callback')
  local met = Callback:method('Callback')
  local res = binder:functionBody(Callback, met)
  assertMatch('retval__%->dub_pushobject%(L, retval__, "Callback", true%);', res)
end

--=============================================== Build

function should.bindCompileAndLoad()
  local ins = dub.Inspector {
    INPUT    = 'test/fixtures/thread',
    doc_dir  = lub.path '|tmp',
  }

  -- create tmp directory
  local tmp_path = lub.path '|tmp'
  lub.rmTree(tmp_path, true)
  os.execute("mkdir -p "..tmp_path)

  -- How to avoid this step ?
  ins:find('Nogc')
  ins:find('Withgc')
  binder:bind(ins, {
    output_directory = tmp_path,
    single_lib = 'thread',
  })

  local cpath_bak = package.cpath
  assertPass(function()
    -- Build thread.so
    binder:build {
      output   = 'test/tmp/thread.so',
      inputs   = {
        'test/tmp/dub/dub.cpp',
        'test/tmp/thread.cpp',
        'test/tmp/thread_Callback.cpp',
        'test/tmp/thread_Caller.cpp',
        'test/tmp/thread_Foo.cpp',
        'test/fixtures/thread/lua_callback.cpp',
      },
      includes = {
        'test/tmp',
        -- This is for lua.h
        'test/tmp/dub',
        'test/fixtures/thread',
      },
    }
    package.cpath = tmp_path .. '/?.so'
    thread = require 'thread'
    assertType('table', thread.Callback)
    assertType('table', thread.Caller)
  end, function()
    -- teardown
    package.cpath = cpath_bak
    if not thread or not thread.Callback then
      lut.Test.abort = true
    end
  end)
  --lub.rmTree(tmp_path, true)
end

function should.returnATable()
  local c = thread.Callback('Alan Watts')
  assertType('table', c)
  assertType('userdata', c.super)
end

function should.executeMethodsOnSelf()
  local c = thread.Callback('Alan Watts')
  assertEqual(101, c:anyMethod(1))
end

function should.executeMethodsOnUserdata()
  local c = thread.Callback('Alan Watts')
  assertEqual(101, c.super:anyMethod(1))
end

function should.readCppAttributes()
  local c = thread.Callback('Alan Watts')
  assertEqual('Alan Watts', c.name)
end

function should.writeAttributes()
  local c = thread.Callback('Alan Watts')
  assertEqual('Alan Watts', c.name)
  -- C++ attribute
  c.name = 'C++ name'
  assertEqual('C++ name', c:getName())
  assertEqual('C++ name', c.super:getName())
end

function should.readAndWriteLuaValues()
  local c = thread.Callback('Alan Watts')
  c.foo = 'Hello'
  assertEqual('Hello', c.foo)
  assertNil(c.bar)
end

function should.notCastDubTemplate()
  -- __newindex for simple (native) types
  local Callback = ins:find('Callback')
  local met = Callback:method(Callback.CAST_NAME)
  local res = binder:functionBody(Callback, met)
  assertMatch('DUB_ASSERT_KEY%(key, "Foo"%)', res)
  assertNotMatch('Thread', res)
end
--=============================================== Callback from C++

local function makeCall(c, ...)
  local caller = thread.Caller(c)
  caller:call(...)
end

function should.callbackFromCpp()
  local c = thread.Callback('Alan Watts')
  local r
  function c:callback(value)
    r = value
  end
  makeCall(c, 'something')
  assertEqual('something', r)
end

--=============================================== Error handling

function should.useSelfErrorHandler()
  local c = thread.Callback('Alan Watts')
  local r
  function c:callback(value)
    error('Failure....')
  end
  function c:error(...)
    r = ...
  end
  makeCall(c, 'something')
  assertMatch('test/lua_thread_test.lua:%d+: Failure....', r)
end

function should.printErrorIfNoErrorHandler()
  local print_bak = print
  local print_out
  -- On object creation, the created default error handler calls print provided in
  -- the creation environment.
  function print(typ, msg)
    print_out = typ .. ': ' .. msg
  end
  local c = thread.Callback('Alan Watts')
  local r
  -- Print captured in c env, we can change it back.
  print = print_bak

  function c:callback(value)
    error('Printed error.')
  end
  assertPass(function()
    makeCall(c, 'something')
  end)
  assertMatch('error: .*lua_thread_test.lua.*Printed error', print_out)

  assertType('function', c._errfunc)
  c._errfunc('hello')
  assertMatch('error: hello', print_out)
end

--=============================================== Memory

function should.passSameObjectWhenStoredAsPointer()
  local c = thread.Callback('Alan Watts')
  local owner = thread.Caller(c)
  assertEqual(c, owner.clbk_) -- same table
end

function should.destroyFromCpp()
  local c = thread.Callback('Arty')
  local o = thread.Caller(c)
  o:destroyCallback()
  -- Destructor called in C++
  -- Object is dead in Lua
  assertError('using deleted thread.Callback', function()
    assertTrue(c:deleted())
    c.name = 'foo'
  end)
end

function should.notGcWhenStored()
  collectgarbage()
  local watch = thread.Callback('Foobar')
  watch.destroy_count = 0
  local c = thread.Callback('Alan Watts')
  local owner = thread.Caller()
  -- dub only protects assignment: thread.Caller(c) is not protected
  owner.clbk_ = c
  c = nil
  collectgarbage()
  collectgarbage()
  assertEqual(0, watch.destroy_count)
  owner = nil
  collectgarbage()
  collectgarbage()
  assertEqual(1, watch.destroy_count)
end

should:test()

