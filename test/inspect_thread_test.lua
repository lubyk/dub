--[[------------------------------------------------------

  dub.Inspector test
  ------------------

  Test introspective operations with the 'thread' group
  of classes.

--]]------------------------------------------------------
require 'lubyk'
local should = test.Suite('dub.Inspector')

-- Test helper to prepare the inspector.
local function makeInspector()
  return dub.Inspector 'test/fixtures/thread'
end

--=============================================== TESTS


test.all()


