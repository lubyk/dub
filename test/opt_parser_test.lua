--[[------------------------------------------------------

  dub.OptParser test
  ------------------

  ...

--]]------------------------------------------------------
require 'lubyk'
-- Run the test with the dub directory as current path.
local should = test.Suite('dub.OptParser')

local parseOpt = dub.OptParser.parse

function should.parseOneValue()
  assertValueEqual({
    foo = 'hell',
  }, parseOpt('foo: hell'))
end

function should.parseString()
  assertValueEqual({
    foo = 'hell on the rocks: yes',
  }, parseOpt('foo: "hell on the rocks: yes"'))
end

function should.parseTrueFalse()
  assertValueEqual({
    foo = false,
    bar = true,
  }, parseOpt('foo: false\nbar: true'))
end

-- Parses lists both as dict and array.
function should.parseListAsHash()
  assertValueEqual({
    list = {'Parent', 'GrandParent', 'three',
      Parent = true,
      GrandParent = true,
      three = true,
    },
  }, parseOpt('list: Parent, GrandParent, three'))
end

test.all()

