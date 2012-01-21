--[[------------------------------------------------------

  dub test
  --------

  Run all tests, test some helpers.

--]]------------------------------------------------------
require 'lubyk'
-- Run the test with the dub directory as current path.
local should = test.Suite('dub')

function should.findMinHash()
  assertEqual(6, dub.minHash {'a', 'b', 'ab', 'ca'})
  assertEqual(14, dub.minHash {'a', 'b', 'ab', 'ac', 'ca'})
  assertEqual(14, dub.minHash {'a', 'b', 'ab', 'ac', 'ca', 'bobli'})
  assertEqual(14, dub.minHash {'a', 'b', 'ab', 'ac', 'ca', 'bobli', 'malc'})
  assertEqual(3, dub.minHash {'name_', 'size_'})
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

test.all()


