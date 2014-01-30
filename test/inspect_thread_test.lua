--[[------------------------------------------------------

  dub.Inspector test
  ------------------

  Test introspective operations with the 'thread' group
  of classes.

--]]------------------------------------------------------
local lub = require 'lub'
local lut = require 'lut'
local dub = require 'dub'

local should = lut.Test('dub.Inspector - thread', {coverage = false})

local ins = dub.Inspector {
  INPUT    = 'test/fixtures/thread',
  doc_dir  = lub.path '|tmp',
}

local Callback = ins:find('Callback')
--=============================================== TESTS

function should.useCustomPush()
  assertEqual('dub_pushobject', Callback.dub.push)
end

should:test()

