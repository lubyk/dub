--[[------------------------------------------------------

  dub.Class
  ---------

  ...

--]]------------------------------------------------------
require 'lubyk'
local should = test.Suite('dub.Class')

-- Test helper to prepare the inspector.
local function makeClass()
  local ins = dub.Inspector()
  ins:parse('test/fixtures/simple/doc/xml')
  return ins:find('Simple')
end

--=============================================== TESTS
function should.autoload()
  assertType('table', dub.Class)
end

function should.beAClass()
  assertEqual('dub.Class', makeClass().type)
end

function should.detectConscructor()
  local class  = makeClass()
  local method = class:method('Simple')
  assertTrue(class:isConstructor(method))
end

function should.listMethods()
  local class = makeClass()
  local m
  for method in class:methods() do
    if method.name == 'setValue' then
      m = method
      break
    end
  end
  assertEqual(m, class:method('setValue'))
end

function should.listHeaders()
  local class = makeClass()
  local h
  for header in class:headers() do
    h = header.path
  end
  assertEqual(h, 'simple.h')
end

function should.detectDestructor()
  local class  = makeClass()
  local method = class:method('~Simple')
  assertTrue(class:isDestructor(method))
end

test.all()

