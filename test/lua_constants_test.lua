--[[------------------------------------------------------
param_
  dub.LuaBinder
  -------------

  Test binding with the 'constants' group of classes:

    * passing classes around as arguments.
    * casting script strings to std::string.
    * casting std::string to script strings.
    * accessing complex public members.
    * accessing public members
    * return value optimization

--]]------------------------------------------------------
require 'lubyk'
-- Run the test with the dub directory as current path.
local should = test.Suite('dub.LuaBinder - constants')
local binder = dub.LuaBinder()

local ins = dub.Inspector {
  INPUT    = 'test/fixtures/constants',
  doc_dir  = lk.dir() .. '/tmp',
}

--=============================================== Constants in mt table
function should.haveConstantsInMetatable()
  local Car = ins:find('Car')
  local res = binder:bindClass(Car)
  assertMatch('"Smoky".*Car::Smoky', res)
end

function should.resolveEnumTypeAsNumber()
  local Car = ins:find('Car')
  local res = binder:bindClass(Car)
  local met = Car:method(Car.SET_ATTR_NAME)
  local lua = binder:luaType(Car, {name = 'Brand'})
  assertEqual('number', lua.type)
end

--=============================================== Set/Get enum type.
function should.castValueForEnumTypes()
  local Car = ins:find('Car')
  -- __newindex for simple (native) types
  local Car = ins:find('Car')
  local set = Car:method(Car.SET_ATTR_NAME)
  local res = binder:functionBody(Car, set)
  assertMatch('self%->brand = %(Car::Brand%)luaL_checknumber%(L, 3%);', res)
end

--=============================================== Build
function should.bindCompileAndLoad()
  -- create tmp directory
  local tmp_path = lk.dir() .. '/tmp'
  os.execute("mkdir -p "..tmp_path)

  binder:bind(ins, {output_directory = tmp_path})
  local cpath_bak = package.cpath
  assertPass(function()
    
    -- Build Car.so
    binder:build {
      work_dir = lk.dir(),
      output   = 'tmp/Car.so',
      inputs   = {
        'tmp/dub/dub.cpp',
        'tmp/Car.cpp',
      },
      includes = {
        'tmp',
        'fixtures/constants',
      },
    }
    
    package.cpath = tmp_path .. '/?.so'
    -- Must require Car first because Box depends on Car class and
    -- only Car.so has static members for Car.
    require 'Car'
    assertType('table', Car)
  end, function()
    -- teardown
    package.loaded.Car = nil
    package.cpath = cpath_bak
    if not Car then
      test.abort = true
    end
  end)
  --lk.rmTree(tmp_path, true)
end

--=============================================== Constants access

function should.createCarObject()
  local c = Car('any')
  assertType('userdata', c)
  assertEqual('any', c.name)
end

function should.castInputParams()
  local c = Car('any', Car.Smoky)
  assertEqual(Car.Smoky, c.brand)
  c:setBrand(Car.Dangerous)
  assertEqual('Dangerous', c:brandName())
end

function should.readEnumAttribute()
  local c = Car('any', Car.Smoky)
  assertEqual(Car.Smoky, c.brand)
  assertEqual('Smoky', c:brandName())
end

function should.writeEnumAttribute()
  local c = Car('any', Car.Smoky)
  c.brand = Car.Dangerous
  assertEqual(Car.Dangerous, c.brand)
  assertEqual('Dangerous', c:brandName())
end

function should.writeBadEnumValue()
  local c = Car('any', Car.Smoky)
  c.brand = 938
  assertEqual(938, c.brand)
  assertEqual('???', c:brandName())
end

--=============================================== Car alternate binding style

function should.respondToNew()
  local Car = Car
  local c = Car.new('any', Car.Dangerous)
  assertEqual('Dangerous', c:brandName())
  c.brand = Car.Noisy
  assertEqual('Noisy', c:brandName())
end

--=============================================== Compare speed with extra metatable

local function createMany(ctor)
  local Noisy = Car.Noisy
  local t = {}
  collectgarbage('stop')
  local start = worker:now()
  for i = 1,100000 do
    table.insert(t, ctor('simple string', Noisy))
  end
  local elapsed = worker:now() - start
  t = nil
  collectgarbage('collect')
  return elapsed
end

local function runGcTest(ctor, fmt)
  -- warmup
  createMany(ctor)
  local vm_size = collectgarbage('count')
  if fmt then
    local t = createMany(ctor)
    printf(fmt, t)
  else
    createMany(ctor)
  end
  assertEqual(vm_size, collectgarbage('count'), 1.5)
end


function should.createAndDestroy()
  if test.speed then
    runGcTest(Car.new,   "Car.new:                            create 100'000 elements: %.2f ms.")
    runGcTest(Car,       "Car:                                create 100'000 elements: %.2f ms.")
  else
    runGcTest(Car)
  end
end

test.all()

