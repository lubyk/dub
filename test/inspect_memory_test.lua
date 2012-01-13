--[[------------------------------------------------------

  dub.Inspector test
  ------------------

  Test introspective operations with the 'memory' group
  of classes.

--]]------------------------------------------------------
require 'lubyk'
local should = test.Suite('dub.Inspector - memory')

-- Test helper to prepare the inspector.
local function makeInspector()
  return dub.Inspector 'test/fixtures/memory'
end

--=============================================== TESTS


test.all()


