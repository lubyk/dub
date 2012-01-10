--[[------------------------------------------------------

  dub.Inspector test
  ------------------

  Test introspective operations with the 'pointers' group
  of classes.

--]]------------------------------------------------------
require 'lubyk'
local should = test.Suite('dub.Inspector')

-- Test helper to prepare the inspector.
local function makeInspector()
  return dub.Inspector 'test/fixtures/pointers'
end

--=============================================== TESTS


test.all()

