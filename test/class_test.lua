--[[------------------------------------------------------

  dub.Class
  ---------

  ...

--]]------------------------------------------------------
local lub = require 'lub'
local lut = require 'lut'
local dub = require 'dub'

local should = lut.Test 'dub.Class'

local ins = dub.Inspector {
  doc_dir = 'test/tmp',
  INPUT   = {
    'test/fixtures/simple/include',
    'test/fixtures/constants',
    'test/fixtures/namespace',
    'test/fixtures/inherit',
  },
}

local Simple = ins:find('Simple')
local Car    = ins:find('Car')
local A      = ins:find('Nem::A')
local Child  = ins:find('Child')

--=============================================== TESTS
function should.autoload()
  assertType('table', dub.Class)
end

function should.createClass()
  local c = dub.Class()
  assertEqual('dub.Class', c.type)
end

function should.inheritNewInSubClass()
  local Sub = setmetatable({}, dub.Class)
  local c = Sub()
  assertEqual('dub.Class', c.type)
end

function should.beAClass()
  assertEqual('dub.Class', Simple.type)
end

function should.detectConscructor()
  local method = Simple:method('Simple')
  assertTrue(method.ctor)
end

function should.detectDestructor()
  local method = Simple:method('~Simple')
  assertTrue(method.dtor)
end

function should.listMethods()
  local m
  for method in Simple:methods() do
    if method.name == 'setValue' then
      m = method
      break
    end
  end
  assertEqual(m, Simple:method('setValue'))
end

function should.notListIgnoredMethods()
  local m
  for method in Child:methods() do
    if method.name == 'virtFunc' then
      fail("Method 'virtFunc' ignored but listed by 'methods()' iterator")
    end
  end
  assertTrue(true)
end

function should.haveHeader()
  local path = lub.absolutizePath(lub.path '|fixtures/simple/include/simple.h')
  assertEqual(path, Simple.header)
end

function should.detectDestructor()
  local method = Simple:method('~Simple')
  assertTrue(Simple:isDestructor(method))
end

function should.respondToAttributes()
  local r = {}
  for att in Car:attributes() do
    lub.insertSorted(r, att.name)
  end
  assertValueEqual({
    'brand',
    'name_',
  }, r)
end

function should.respondToAttributes()
  local r = {}
  for att in car:attributes() do
    lub.insertSorted(r, att.name)
  end
  assertValueEqual({
    'brand',
    'name_',
  }, r)
end

function should.respondToConstants()
  local r = {}
  for c in Car:constants() do
    lub.insertSorted(r, c)
  end
  assertValueEqual({
    'Dangerous',
    'Noisy',
    'Polluty',
    'Smoky',
  }, r)
end

function should.respondToFindChild()
  local f = Car:findChild 'setBrand'
  assertEqual('dub.Function', f.type)
end

function should.respondToNamespace()
  local n = A:namespace()
  assertEqual('dub.Namespace', n.type)
end

function should.respondToNeedCast()
  assertFalse(A:needCast())
  assertTrue(Child:needCast())
end

should:test()

