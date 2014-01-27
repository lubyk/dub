--[[------------------------------------------------------

  dub test
  --------

  Run all tests, test some helpers.

--]]------------------------------------------------------
local lub = require 'lub'
local lut = require 'lut'
local dub = require 'dub'

local should = lut.Test 'dub'

-- These functions are private: no coverage testing.
should.ignore.warn       = true
should.ignore.printWarn  = true
should.ignore.silentWarn = true

function should.findMinHash()
  assertEqual(6, dub.minHash {'a', 'b', 'ab', 'ca'})
  assertEqual(14, dub.minHash {'a', 'b', 'ab', 'ac', 'ca'})
  assertEqual(14, dub.minHash {'a', 'b', 'ab', 'ac', 'ca', 'bobli'})
  assertEqual(14, dub.minHash {'a', 'b', 'ab', 'ac', 'ca', 'bobli', 'malc'})
  assertEqual(3, dub.minHash {'name_', 'size_'})
end

function should.findMinHashWithDuplicates()
  assertEqual(6, dub.minHash {'a', 'a', 'b', 'ab', 'ca'})
end

function should.returnNilMinHashOnEmptyList()
  assertNil(dub.minHash {})
end

function should.hash()
  local sz = 14
  assertEqual(13, dub.hash('a',14))
  assertEqual(0, dub.hash('b',14))
  assertEqual(5, dub.hash('ab',14))
  assertEqual(6, dub.hash('ac',14))
  assertEqual(8, dub.hash('ca',14))
  assertEqual(0, dub.hash('name_',5))
  assertEqual(1, dub.hash('birth_year',2))
end

should:test()

