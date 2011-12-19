--[[------------------------------------------------------

  dub.LuaBinder
  -------------

  Test basic binding with the 'simple' class.

--]]------------------------------------------------------
require 'lubyk'
-- Run the test with the dub directory as current path.
local should = test.Suite('dub.LuaBinder')
local binder = dub.LuaBinder()

-- Test helper to prepare the inspector.
local function makeInspector()
  local ins = dub.Inspector()
  ins:parse('test/fixtures/simple/doc/xml')
  return ins
end

--=============================================== TESTS
function should.autoload()
  assertType('table', dub.LuaBinder)
end

function should.bindClass()
  local ins = makeInspector()
  local Simple = ins:find('Simple')
  local res = binder:bindClass(Simple)
  print(res)
end

test.all()
