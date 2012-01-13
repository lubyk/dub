--[[------------------------------------------------------

  dub.Inspector test
  ------------------

  Test introspective operations with the 'thread' group
  of classes.

--]]------------------------------------------------------
require 'lubyk'
local should = test.Suite('dub.Inspector (thread)')

local ins = dub.Inspector 'test/fixtures/thread'

--=============================================== TESTS

-- TODO
-- function should.markClassAsThread()
--   local Callback = ins:find 'Callback'
--   assertTrue(Callback.thread)
-- end

test.all()


