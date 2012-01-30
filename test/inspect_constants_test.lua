--[[------------------------------------------------------

  dub.Inspector test
  ------------------

  Test introspective operations with the 'constants' group
  of classes.

--]]------------------------------------------------------
require 'lubyk'
local should = test.Suite('dub.Inspector - constants')

local ins  = dub.Inspector {
  INPUT    = 'test/fixtures/constants',
  doc_dir  = lk.dir() .. '/tmp',
}

local Car = ins:find('Car')

--=============================================== TESTS

function should.resolveEnumType()
  local db = ins.db
  local Car = ins:find('Car')
  local b = db:resolveType(Car, 'Brand')
  assertValueEqual({
    name        = 'int',
    def         = 'int',
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

function should.findGlobalEnum()
  local enum = ins:find('GlobalConstant')
  assertEqual('dub.Enum', enum.type)
end

function should.haveGlobalConstants()
  assertTrue(ins.db.has_constants)
end

function should.listGlobalConstants()
  local res = {}
  for const in ins.db:constants() do
    table.insert(res, const)
  end
  assertValueEqual({
    'One',
    'Two',
    'Three',
  }, res)
end

function should.listConstHeaders()
  local res = {}
  for h in ins.db:headers({}) do
    table.insert(res, string.sub(h, -17, -1))
  end
  assertValueEqual({
    'constants/types.h',
  }, res)
end

function should.findEnumByFullname()
  local Brand = ins:find('Car::Brand')
  assertEqual('Brand', Brand.name)
  assertMatch('test/fixtures/constants/Car.h:17', Brand.location)
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

