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

function should.parseList()
  assertValueEqual({
    list = {'Parent', 'GrandParent', 'three'},
  }, parseOpt('list: Parent, GrandParent, three'))
end

test.all()

