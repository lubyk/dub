--[[------------------------------------------------------

  dub.Inspector test
  ------------------

  Test introspective operations with the 'constants' group
  of classes.

--]]------------------------------------------------------
require 'lubyk'
local should = test.Suite('dub.Inspector - constants')

local ins = dub.Inspector {
  INPUT   = 'test/fixtures/constants',
  doc_dir = lk.dir() .. '/tmp',
}

local Car = ins:find('Car')

--=============================================== TESTS

function should.resolveEnumType()
  local db = ins.db
  local Car = ins:find('Car')
  local b = db:resolveType(Car, 'Brand')
  assertValueEqual({
    name        = 'double',
    def         = 'double',
    create_name = 'Car::Brand ',
    cast        = 'Car::Brand',
    -- This is used to output default enum values.
    scope       = 'Car',
  }, b)
end

function should.findCarClass()
  assertEqual('dub.Class', Car.type)
end

function should.haveConstants()
  assertTrue(Car.has_constants)
end

function should.findEnumByFullname()
  local Brand = ins:find('Car::Brand')
  assertEqual('Brand', Brand.name)
  assertMatch('test/fixtures/constants/Car.h:16', Brand.location)
end

function should.listConstants()
  local res = {}
  for name in Car:constants() do
    table.insert(res, name)
  end
  assertValueEqual({
    'Smoky',
    'Polluty',
    'Noisy',
    'Dangerous',
  }, res)
end

test.all()

