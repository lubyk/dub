--[[------------------------------------------------------

  dub.OptParser test
  ------------------

  ...

--]]------------------------------------------------------
local lub = require 'lub'
local lut = require 'lut'
local dub = require 'dub'

local should = lut.Test('dub.OptParser')

local opt = dub.OptParser

function should.parseOneValue()
  assertValueEqual({
    foo = 'hell',
  }, opt.parse('foo: hell'))
end

function should.parseString()
  assertValueEqual({
    foo = 'hell on the rocks: yes',
  }, opt.parse('foo: "hell on the rocks: yes"'))
end

function should.parseUnderscoreKey()
  assertValueEqual({
    string_format = '%s:%i',
    string_args = {
      'self->hostname()',
      'self->port()',
      ['self->hostname()'] = true,
      ['self->port()'] = true,
    },
  }, opt.parse('string_format: %s:%i\nstring_args: self->hostname(), self->port()'))
end

function should.parseTrueFalse()
  assertValueEqual({
    foo = false,
    bar = true,
  }, opt.parse('foo: false\nbar: true'))
end

-- Parses lists both as dict and array.
function should.parseListAsHash()
  assertValueEqual({
    list = {'Parent', 'GrandParent', 'three',
      Parent = true,
      GrandParent = true,
      three = true,
    },
  }, opt.new('list: Parent, GrandParent, three'))
end

should:test()

