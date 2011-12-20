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
  assertEqual('class', makeClass().kind)
end

function should.detectConscructor()
  local class = makeClass()
  local constr = class:method('Simple')
  assertTrue(class:isConstructor(constr))
end

test.all()

