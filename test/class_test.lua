--[[------------------------------------------------------

  dub.Class
  ---------

  ...

--]]------------------------------------------------------
require 'lubyk'
local should = test.Suite('dub.Class')

local ins = dub.Inspector {
  doc_dir = 'test/tmp',
  INPUT   = 'test/fixtures/simple/include',
}

local class = ins:find('Simple')

--=============================================== TESTS
function should.autoload()
  assertType('table', dub.Class)
end

function should.beAClass()
  assertEqual('dub.Class', class.type)
end

function should.detectConscructor()
  local method = class:method('Simple')
  assertTrue(method.ctor)
end

function should.detectDestructor()
  local method = class:method('~Simple')
  assertTrue(method.dtor)
end

function should.listMethods()
  local m
  for method in class:methods() do
    if method.name == 'setValue' then
      m = method
      break
    end
  end
  assertEqual(m, class:method('setValue'))
end

function should.haveHeader()
  local path = lk.absolutizePath(lk.dir() .. '/fixtures/simple/include/simple.h')
  assertEqual(path, class.header)
end

function should.detectDestructor()
  local method = class:method('~Simple')
  assertTrue(class:isDestructor(method))
end

test.all()

