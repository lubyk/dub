--[[------------------------------------------------------

  dub.LuaBinder
  -------------

  Test binding with the 'thread' group of classes:

    * initialize object with custom method.
    * return <self> table instead of userdata.
    * callback from C++.
    * custom error function in self.

--]]------------------------------------------------------
require 'lubyk'
-- Run the test with the dub directory as current path.
local should = test.Suite('dub.LuaBinder - thread')
local binder = dub.LuaBinder()

local ins = dub.Inspector {
  INPUT    = 'test/fixtures/thread',
  doc_dir  = lk.dir() .. '/tmp',
}

--=============================================== Callback bindings

function should.bindClass()
  local Callback = ins:find('Callback')
  local met = Callback:method('Callback')
  local res = binder:functionBody(Callback, met)
  assertMatch('retval__%->pushobject%(L, retval__, "Callback", true%);', res)
end

--=============================================== Build

function should.bindCompileAndLoad()
  local ins = dub.Inspector {
    INPUT    = 'test/fixtures/thread',
    doc_dir  = lk.dir() .. '/tmp',
  }
  -- create tmp directory
  local tmp_path = lk.dir() .. '/tmp'
  lk.rmTree(tmp_path, true)
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
        'test/fixtures/thread/lua_callback.cpp',
      },
      includes = {
        'test/tmp',
        'test/fixtures/thread',
      },
    }
    package.cpath = tmp_path .. '/?.so'
    --require 'Box'
    require 'thread'
    assertType('table', thread.Callback)
    assertType('table', thread.Caller)
  end, function()
    -- teardown
    package.cpath = cpath_bak
    if not thread.Callback then
      test.abort = true
    end
  end)
  --lk.rmTree(tmp_path, true)
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
  assertEqual('test/lua_thread_test.lua:145: Failure....', r)
end

function should.printErrorIfNoErrorHandler()
  local c = thread.Callback('Alan Watts')
  local r
  function c:callback(value)
    error('Normal output during testing.')
  end
  assertPass(function()
    makeCall(c, 'something')
  end)
end

--=============================================== Memory

function should.passSameObjectWhenStoredAsPointer()
  local c = thread.Callback('Alan Watts')
  local owner = thread.Caller(c)
  assertEqual(c, owner.clbk_) -- same table
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

test.all()

