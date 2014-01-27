--[[------------------------------------------------------

  dub.Namespace
  -------------

  ...

--]]------------------------------------------------------
local lub = require 'lub'
local lut = require 'lut'
local dub = require 'dub'

local should = lut.Test('dub.Namespace', {coverage = false})

local ins = dub.Inspector {
  INPUT    = {
    lub.path '|fixtures/namespace',
  },
  doc_dir  = lub.path '|tmp',
}

--=============================================== TESTS
function should.autoload()
  assertType('table', dub.Namespace)
end

function should.createClass()
  local c = ins:find('Nem')
  assertEqual('dub.Namespace', c.type)
end

function should.returnFalseOnIsClass()
  local c = ins:find('Nem')
  assertEqual(false, c.is_class)
end

should:test()


