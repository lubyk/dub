--[[------------------------------------------------------
param_
  dub.LuaBinder
  -------------

  Test binding with the 'pointers' group of classes:

    * passing classes around as arguments.
    * casting script strings to std::string.
    * casting std::string to script strings.
    * accessing complex public members.
    * accessing public members
    * return value optimization
    * library prefix and single library file (require 'MyLib', MyLib.Vect)

--]]------------------------------------------------------
require 'lubyk'
-- Run the test with the dub directory as current path.
local should = test.Suite('dub.LuaBinder - pointers')
local binder = dub.LuaBinder()

local ins = dub.Inspector {
  INPUT    = 'test/fixtures/pointers',
  doc_dir  = lk.dir() .. '/tmp',
}
--=============================================== Special types
function should.resolveStdString()
  local Box = ins:find('Box')
  local met = Box:method('Box')
  local res = binder:functionBody(Box, met)
  assertMatch('size_t name_sz_;', res)
  assertMatch('const char %*name = dub_checklstring%(L, 1, %&name_sz_%);', res)
end

function should.notGcReturnedPointer()
  local Box = ins:find('Box')
  local met = Box:method('size')
  local res = binder:functionBody(Box, met)
  -- no gc
  assertMatch('pushudata[^\n]+, false%);', res)
end

function should.gcReturnedPointerMarkedAsGc()
  local Box = ins:find('Box')
  local met = Box:method('copySize')
  local res = binder:functionBody(Box, met)
  -- no gc
  assertMatch('pushudata[^\n]+, true%);', res)
end

function should.notBindCtorInAbstractType()
  local Abstract = ins:find('Abstract')
  local res = binder:bindClass(Abstract)
  -- no ctor
  assertNotMatch('"new"XXXX', res)
  assertNotMatch('Abstract_Abstract', res)
end

function should.useTopInMethodWithDefaults()
  local Box = ins:find('Box')
  local met = Box:method('Box')
  local res = binder:functionBody(Box, met)
  -- no gc
  assertMatch('new Box%(std::string%(name, name_sz_%), %*size%);', res)
  assertMatch('new Box%(std::string%(name, name_sz_%)%);', res)
end

--=============================================== Set/Get vars.
function should.bindSimpleSetMethod()
  -- __newindex for simple (native) types
  local Vect = ins:find('Vect')
  local set = Vect:method(Vect.SET_ATTR_NAME)
  local res = binder:bindClass(Vect)
  assertMatch('__newindex.*Vect__set_', res)
  local res = binder:functionBody(Vect, set)
  assertMatch('self%->x = luaL_checknumber%(L, 3%);', res)
  -- static member
  assertMatch('Vect::create_count = luaL_checkint%(L, 3%);', res)
end

function should.bindCharAsNumber()
  local Vect = ins:find('Vect')
  local met = Vect:method('someChar')
  local res = binder:functionBody(Vect, met)
  assertMatch('char c = dub_checkint%(L, 2%);', res)
  assertMatch('lua_pushnumber%(L, self%->someChar%(c%)%);', res)
end

function should.bindConstCharPtrAsString()
  local Vect = ins:find('Vect')
  local met = Vect:method('someStr')
  local res = binder:functionBody(Vect, met)
  assertMatch('const char %*s = dub_checkstring%(L, 2%);', res)
  assertMatch('lua_pushstring%(L, self%->someStr%(s%)%);', res)
end

function should.bindComplexSetMethod()
  -- __newindex for non-native types
  local Box = ins:find('Box')
  local res = binder:bindClass(Box)
  assertMatch('__newindex.*Box__set_', res)
  local set = Box:method(Box.SET_ATTR_NAME)
  local res = binder:functionBody(Box, set)
  assertMatch('self%->size_ = %*%*%(%(Vect %*%*%)', res)
end

function should.ignoreArrayAttrInSet()
  -- __newindex for non-native types
  local Vect = ins:find('Vect')
  local res = binder:bindClass(Vect)
  assertMatch('"d".*Vect_d', res)
  local set = Vect:method(Vect.SET_ATTR_NAME)
  local res = binder:functionBody(Vect, set)
  assertNotMatch('self%->d ', res)
end

function should.ignoreArrayAttrInGet()
  -- __newindex for simple (native) types
  local Vect = ins:find('Vect')
  local get = Vect:method(Vect.GET_ATTR_NAME)
  local res = binder:functionBody(Vect, get)
  assertNotMatch('self%->d', res)
end

function should.bindSimpleGetMethod()
  -- __newindex for simple (native) types
  local Vect = ins:find('Vect')
  local res = binder:bindClass(Vect)
  assertMatch('__index.*Vect__get_', res)
  local get = Vect:method(Vect.GET_ATTR_NAME)
  local res = binder:functionBody(Vect, get)
  assertMatch('lua_pushnumber%(L, self%->x%);', res)
  -- static member
  assertMatch('lua_pushnumber%(L, Vect::create_count%);', res)
end


function should.bindComplexGetMethod()
  -- __newindex for non-native types
  local Box = ins:find('Box')
  local set = Box:method(Box.SET_ATTR_NAME)
  local res = binder:bindClass(Box)
  assertMatch('__index.*Box__get_', res)
  local res = binder:functionBody(Box, set)
  assertMatch('self%->size_ = %*%*%(%(Vect %*%*%)', res)
end

function should.notGetSelfInStaticMethod()
  local Box = ins:find('Box')
  local met = Box:method('MakeBox')
  local res = binder:functionBody(Box, met)
  assertNotMatch('self', res)
end

function should.createLibFileWithCustomNames()
  local tmp_path = 'test/tmp'
  lk.rmTree(tmp_path, true)

  os.execute('mkdir -p '..tmp_path)
  -- Our binder resolves types differently due to MyLib so we
  -- need our own inspector.
  local ins = dub.Inspector {
    INPUT    = 'test/fixtures/pointers',
    doc_dir  = lk.dir() .. '/tmp',
  }
  local binder = dub.LuaBinder()
  function binder:name(elem)
    local name = elem.name
    if name == 'Vect' then
      return 'V'
    elseif name == 'Box' then
      return 'B'
    else
      return name
    end
  end
  binder:bind(ins, {
    output_directory = tmp_path,
    -- Execute all lua_open in a single go
    -- with lua_MyLib.
    -- This creates a MyLib_open.cpp file
    -- that has to be included in build.
    -- Also forces classes to live in foo.ClassName
    single_lib = 'foo',
  })
  local res = lk.readall(tmp_path .. '/foo_V.cpp')
  assertMatch('"foo.V"', res)
  assertMatch('luaopen_foo_V%(', res)

  assertPass(function()
    -- Build foo.so
    binder:build {
      output   = 'test/tmp/foo.so',
      inputs   = {
        'test/tmp/dub/dub.cpp',
        'test/tmp/foo_V.cpp',
        'test/tmp/foo_B.cpp',
        'test/tmp/foo_Abstract.cpp',
        'test/tmp/foo_AbstractSub.cpp',
        'test/tmp/foo_AbstractHolder.cpp',
        'test/tmp/foo.cpp',
        'test/fixtures/pointers/vect.cpp',
      },
      includes = {
        'test/tmp',
      },
    }
    package.cpath = tmp_path .. '/?.so'
    -- Must require Vect first because Box depends on Vect class and
    -- only Vect.so has static members for Vect.
    require 'foo'
    assertType('table', foo.V)
    assertType('table', foo.B)
    assertType('table', foo.Abstract)
    assertType('table', foo.AbstractSub)
    assertType('table', foo.AbstractHolder)
  end, function()
    -- teardown
    package.cpath = cpath_bak
    if not foo then
      test.abort = true
    end
  end)
end

function should.useVectInMyLib()
  local v = foo.V(2,2.5)
  assertEqual('foo.V', v.type)
  assertEqual(5, v:surface())
end

function should.createLibFile()
  local tmp_path = 'test/tmp'
  -- Our binder resolves types differently due to MyLib so we
  -- need our own inspector.
  local ins = dub.Inspector {
    INPUT    = 'test/fixtures/pointers',
    doc_dir  = lk.dir() .. '/tmp',
  }

  os.execute('mkdir -p ' .. tmp_path)
  binder:bind(ins, {
    output_directory = tmp_path,
    -- Execute all lua_open in a single go
    -- with lua_MyLib.
    -- This creates a MyLib_open.cpp file
    -- that has to be included in build.
    single_lib = 'MyLib',
    -- Forces classes to live in MyLib.Foobar
    lib_prefix = 'MyLib',
  })

  assertTrue(lk.exist(tmp_path .. '/MyLib.cpp'))
  local res = lk.readall(tmp_path .. '/MyLib.cpp')
  assertMatch('int luaopen_MyLib_Box%(lua_State %*L%);', res)
  assertMatch('int luaopen_MyLib_Vect%(lua_State %*L%);', res)
  assertMatch('luaopen_MyLib%(lua_State %*L%) %{', res)
  assertMatch('luaopen_MyLib_Box%(L%);', res)
  assertMatch('luaopen_MyLib_Vect%(L%);', res)
  local res = lk.readall(tmp_path .. '/MyLib_Vect.cpp')
  assertMatch('"MyLib.Vect"', res)

  assertPass(function()
    -- Build MyLib.so
    binder:build {
      output   = 'test/tmp/MyLib.so',
      inputs   = {
        'test/tmp/dub/dub.cpp',
        'test/tmp/MyLib_Vect.cpp',
        'test/tmp/MyLib_Box.cpp',
        'test/tmp/MyLib_Abstract.cpp',
        'test/tmp/MyLib_AbstractSub.cpp',
        'test/tmp/MyLib_AbstractHolder.cpp',
        'test/tmp/MyLib.cpp',
        'test/fixtures/pointers/vect.cpp',
      },
      includes = {
        'test/tmp',
      },
    }
    package.cpath = tmp_path .. '/?.so;'
    -- Must require Vect first because Box depends on Vect class and
    -- only Vect.so has static members for Vect.
    require 'MyLib'
    assertType('table', MyLib.Vect)
    assertType('table', MyLib.Box)
  end, function()
    -- teardown
    package.loaded.MyLib = nil
    package.cpath = cpath_bak
    if not MyLib then
      test.abort = true
    end
  end)
end

function should.useVectInMyLib()
  local v = MyLib.Vect(2,2.5)
  assertEqual('MyLib.Vect', v.type)
  assertEqual(5, v:surface())
end

function should.bindCompileAndLoad()
  -- create tmp directory
  local tmp_path = lk.dir() .. '/tmp'
  os.execute("mkdir -p "..tmp_path)

  binder:bind(ins, {output_directory = tmp_path})

  local cpath_bak = package.cpath
  assertPass(function()
    
    -- Build Vect.so
    binder:build {
      output   = 'test/tmp/Vect.so',
      inputs   = {
        'test/tmp/dub/dub.cpp',
        'test/tmp/Vect.cpp',
        'test/fixtures/pointers/vect.cpp',
      },
      includes = {
        'test/tmp',
      },
    }
    
    -- Build Box.so
    binder:build {
      output   = 'test/tmp/Box.so',
      inputs   = {
        'test/tmp/dub/dub.cpp',
        'test/tmp/Box.cpp',
      },
      includes = {
        'test/tmp',
      },
    }
    package.cpath = tmp_path .. '/?.so'
    -- Must require Vect first because Box depends on Vect class and
    -- only Vect.so has static members for Vect.
    require 'Vect'
    require 'Box'
    assertType('table', Vect)
  end, function()
    -- teardown
    package.loaded.Box = nil
    package.loaded.Vect = nil
    package.cpath = cpath_bak
    if not Vect then
      test.abort = true
    end
  end)
  --lk.rmTree(tmp_path, true)
end

--=============================================== Vect

function should.createVectObject()
  local v = Vect(1,2)
  assertType('userdata', v)
end

function should.readVectAttributes()
  local v = Vect(1.2, 3.4)
  assertEqual(1.2, v.x)
  assertEqual(3.4, v.y)
end

function should.writeVectAttributes()
  local v = Vect(1.2, 3.4)
  v.x = 15
  assertEqual(15, v.x)
  assertEqual(3.4, v.y)
  assertEqual(51, v:surface())
end

function should.readArrayAttributes()
  local v = Vect(1,2)
  assertEqual(4, v:d(1))
  assertEqual(5, v:d(2))
  assertEqual(6, v:d(3))
  assertNil(v:d(0))
  assertNil(v:d(4))
end

function should.writeBadAttribute()
  local v = Vect(1,2)
  -- this operation is just ignored
  assertError("invalid key 'xcvx'", function()
    v.xcvx = 'foo'
  end)
  assertNil(v.xcvx)
end

function should.writeArrayAttributes()
  local v = Vect(1,2)
  --v.set_d(1, 10)
  -- Could enable : v.d[1] = 1.5
  -- by doing some work on a DubObject:
  -- v.d          ==> return {self = self, key = 'd'}
  -- v.d[1] = 1.5 ==> function __newindex({self=self, key='d'}, k, v)
  --                     self._d_set(k, v)
  --                  end
  --assertEqual(13, v.d(1))
end

function should.accessStaticAttributes()
  local t, v = Vect(1,1), Vect(1,1)
  -- Access static members through members.
  t.create_count = 0
  assertEqual(0, v.create_count)
  t.create_count = 100
  assertEqual(100, v.create_count)
end

function should.handleBadWriteVectAttr()
  local v = Vect(1.2, 3.4)
  assertError("invalid key 'asdf'", function()
    v.asdf = 15
  end)
  assertEqual(1.2, v.x)
  assertEqual(3.4, v.y)
  assertEqual(nil, v.asdf)
end

function should.executeVectMethods()
  local v = Vect(1.2, 3.4)
  assertEqual(4.08, v:surface())
end

function should.overloadAdd()
  local v1, v2 = Vect(1.2, -1), Vect(4, 2)
  local v = v1 + v2
  assertEqual(5.2, v.x)
  assertEqual(1, v.y)
  assertEqual(1.2, v1.x)
  assertEqual(-1, v1.y)
  assertEqual(4, v2.x)
  assertEqual(2, v2.y)
end

function should.overloadMinus()
  local v1 = Vect(7, 2)
  local v = -v1
  assertEqual(-7, v.x)
  assertEqual(-2, v.y)
end

function should.overloadSub()
  local v1, s2 = Vect(7, 2), Vect(4, 2)
  local v = v1 - s2
  assertEqual(3, v.x)
  assertEqual(0, v.y)
end

function should.overloadMul()
  local v1 = Vect(7, 2)
  local v = v1 * 4
  assertEqual(28, v.x)
  assertEqual(8, v.y)
  -- overloaded operator* for const Vect.
  assertEqual(12, v1 * Vect(1, 2))
end

function should.overloadDiv()
  local v1 = Vect(7, 2)
  local v = v1 / 2
  assertEqual(3.5, v.x)
  assertEqual(1, v.y)
end

function should.overloadLess()
  -- compares surfaces
  local v1, s2 = Vect(1, 2), Vect(4, 2)
  local v = v1 - s2
  assertTrue(v1  < s2)
  assertFalse(s2 < v1)

  assertTrue(s2  > v1)
  assertFalse(v1 > s2)
end

function should.overloadLessEqual()
  -- compares surfaces
  local v1, s2 = Vect(7, 2), Vect(4, 2)
  local v = v1 - s2
  assertTrue(s2  <= v1)
  assertFalse(v1 <= s2)
  assertTrue(s2  <= s2)

  assertTrue(v1  >= s2)
  assertFalse(s2 >= v1)
  assertTrue(v1  >= v1)
end

function should.overloadEqual()
  local v1, s2 = Vect(7, 2), Vect(4, 2)
  assertFalse(v1 == s2)
  assertTrue(v1 == Vect(7,2))
end

function should.overloadCall()
  local v1 = Vect(7, 2)
  assertEqual(7, v1(1))
  assertEqual(2, v1(2))
end

function should.overloadIndex()
  local v1 = Vect(7, 2)
  assertEqual(7, v1[1])
  assertEqual(2, v1[2])
end

-- operator+=
function should.overloadAdde()
  local v = Vect(7, 2)
  v:add(Vect(3,2))
  assertEqual(10, v.x)
  assertEqual(4, v.y)
end

-- operator-=
function should.overloadSube()
  local a = Vect(7, 3)
  local b = Vect(1, 2)
  a:sub(b)
  assertEqual(6, a.x)
  assertEqual(1, a.y)
  assertEqual(1, b.x)
  assertEqual(2, b.y)
end
--=============================================== Box

function should.createBoxObject()
  local v = Box('Cat')
  assertType('userdata', v)
end

function should.readBoxAttributes()
  local v = Box('Cat', Vect(2,3))
  assertEqual('Cat', v.name_)
  local sz = v.size_
  assertEqual(2, sz.x)
  assertEqual(3, sz.y)
end

-- Changes should propagate back to Vect in Box.
function should.notCopyPointer()
  local b = Box('Cat', Vect(2,3))
  local sz = b:size()
  sz.x = 5
  assertEqual(5, b.size_.x)
end

-- Changes should propagate back to Vect in Box.
function should.notCopyAttribute()
  local b = Box('Cat', Vect(2,3))
  local sz = b.size_
  sz.x = 5
  assertEqual(5, b.size_.x)
end

function should.notCopyRef()
  local b = Box('Cat', Vect(2,3))
  local sz = b:sizeRef()
  sz.x = 5
  assertEqual(5, b.size_.x)
end

-- Default behavior is 'cast' (which might not be a good idea).
function should.castConstRef()
  local b = Box('Cat', Vect(2,3))
  local sz = b:constRef()
  b.size_.x = 14
  assertEqual(14, sz.x)
end

function should.notGcOwnerBeforePointer()
  local b = Box('Cat', Vect(2,3))
  local sz = b.size_
  b = nil
  collectgarbage()
  sz.x = 4
end

-- Should not gc
function should.notGCPointerToMember()
  local b = Box('Cat', Vect(2,3))
  local sz = b.size_
  local watch = Vect(0,0)
  collectgarbage()
  watch.destroy_count = 0
  watch.create_count = 0
  watch.copy_count = 0
  sz:__gc() -- does nothing
  sz = nil
  collectgarbage()
  assertEqual(0, watch.destroy_count)
end

function should.writeBoxAttributes()
  local v = Box('Cat', Vect(2,3))
  v.name_ = 'Dog'
  assertEqual('Dog', v.name_)
  assertEqual('Dog', v:name())

  v.size_ = Vect(8, 1.5)
  assertEqual(8, v.size_.x)
  assertEqual(1.5, v.size_.y)
  assertEqual(12, v:surface())
end

function should.returnNilOnNullPointer()
  local b = Box('any')
  assertNil(b.position)
  assertNil(b.const_vect)
end

function should.getPointerMember()
  local b = Box('any', Vect(1,2))
  local v = Vect(4,4)
  b.position = v
  local w = b.position
  w.x = 123.45
  assertEqual(123.45, v.x)
  assertEqual(v, w) -- not the same udata but operator==
end

function should.getCastOfConstPointerMember()
  local b = Box('any', Vect(1,2))
  local v = Vect(4,4)
  b.const_vect = v
  -- const cast (remove constness)
  local w = b.const_vect
  w.x = 123.45
  assertEqual(123.45, v.x)
end

function should.setPointerMember()
  local b = Box('any')
  local v = Vect(4,4)
  b.position = v
  b.position.x = 5
  assertEqual(5, v.x)
end

function should.protectGcOfSetMember()
  local b = Box('any')
  local v = Vect(4,4)
  local watch = Vect(0,0)
  collectgarbage()
  watch.destroy_count = 0

  b.position = v
  v = nil
  collectgarbage() -- should not collect v
  assertEqual(0, watch.destroy_count)

  b = nil
  collectgarbage() -- should collect b and v
  assertEqual(2, watch.destroy_count) -- b internal size + v
end

function should.protectGcOfOwner()
  local b = Box('any')
  local v = Vect(4,4)
  local watch = Vect(0,0)
  collectgarbage()
  watch.destroy_count = 0

  b.position = v
  local w = b.position
  b = nil
  v = nil
  collectgarbage() -- should not collect v
  assertEqual(0, watch.destroy_count)

  w = nil
  collectgarbage() -- should collect w, b and v
  assertEqual(2, watch.destroy_count) -- b internal size + (v == w)
end

function should.executeBoxMethods()
  local v = Box('Cat', Vect(2,3))
  assertEqual(6, v:surface())
end

function should.passDoubleForChar()
  local v = Vect(0,0)
  assertEqual(45, v:someChar(45))
end

function should.passStringForConstCharPtr()
  local v = Vect(0,0)
  assertEqual('hello World', v:someStr('hello World'))
end

function should.callMethodWithUnamedParams()
  local v = Vect(0,0)
  assertEqual(9.5, v:unamed(3.5, 3))
end

function should.callVoidMethod()
  local v = Vect(0,0)
  assertEqual(1, v:noparam())
end

--=============================================== std::string with \0

function should.handleBinaryData()
  local data = 'Hello\0 World'
  local b = Box(data, Vect(1,2))
  assertEqual(data, b:name())
  data = 'One\0Two\0Three'
  b.name_ = data
  assertEqual(data, b.name_)
  assertNotEqual('One', b.name_)
end

--=============================================== Return value opt.
function should.optimizeReturnValue()
  collectgarbage()
  local t = Vect(1,1)
  -- Access static members through members.
  t.create_count = 0
  t.copy_count = 0
  t.destroy_count = 0

  local v1, v2 = Vect(1,2), Vect(50,80)
  assertEqual(2, t.create_count)
  assertEqual(0, t.copy_count)
  assertEqual(0, t.destroy_count)
  local v3 = v1 + v2
  assertEqual(3, t.create_count)
  assertEqual(0, t.copy_count)
  assertEqual(0, t.destroy_count)
  local v4 = v1 * 2
  assertEqual(4, t.create_count)
  assertEqual(0, t.copy_count)
  assertEqual(0, t.destroy_count)
  v4 = v1 * 3
  collectgarbage()
  assertEqual(5, t.create_count)
  assertEqual(0, t.copy_count)
  assertEqual(1, t.destroy_count)
  v1, v2, v3, v4 = nil, nil, nil, nil
  collectgarbage()
  assertEqual(5, t.create_count)
  assertEqual(0, t.copy_count)
  assertEqual(5, t.destroy_count)
end

--=============================================== Garbage collection
local function createAndDestroyMany()
  local Vect = Vect
  local t = {}
  for i = 1,100000 do
    table.insert(t, Vect(1,3))
  end
  t = nil
  collectgarbage()
  collectgarbage()
end

function should.createAndDestroy()
  -- warmup
  createAndDestroyMany()
  local vm_size = collectgarbage('count')
  createAndDestroyMany()
  assertEqual(vm_size, collectgarbage('count'))
end

--=============================================== Wrap usdata in table

function should.findObjectInTable()
  local v = Vect(2,-4)
  local o = setmetatable({super = v}, Vect)
  assertEqual(2, o.x)
  o.hep = 'Mea Lua'
  assertEqual('Mea Lua', o.hep)
end

--=============================================== Call methods on abstract type

function should.callMethodsOnAbstractType()
  local a = foo.AbstractSub(100)
  local b = foo.AbstractHolder(a)
  local c = b:getPtr()
  assertEqual(123, c:pureVirtual(23))
  assertMatch('foo.Abstract', c.type)
end

test.all()

