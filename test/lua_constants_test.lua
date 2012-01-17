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
  assertEqual('Car::Brand', lua.rtype.cast)
end

function should.resolveGlobalEnumTypeAsNumber()
  local Car = ins:find('Car')
  local lua = binder:luaType(Car, {name = 'GlobalConstant'})
  assertEqual('number', lua.type)
  assertEqual('GlobalConstant', lua.rtype.cast)
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
  local ins = dub.Inspector {
    INPUT    = 'test/fixtures/constants',
    doc_dir  = lk.dir() .. '/tmp',
  }

  -- create tmp directory
  local tmp_path = lk.dir() .. '/tmp'
  os.execute("mkdir -p "..tmp_path)

  binder:bind(ins, {
    output_directory = tmp_path,
    -- Execute all lua_open in a single go
    -- with lua_openb2 (creates traffic.cpp).
    single_lib = 'traffic',
  })
  local cpath_bak = package.cpath
  assertPass(function()
    
    -- Build traffic.so
    binder:build {
      output   = 'test/tmp/traffic.so',
      inputs   = {
        'test/tmp/dub/dub.cpp',
        'test/tmp/Car.cpp',
        'test/tmp/traffic.cpp',
      },
      includes = {
        'test/tmp',
        'test/fixtures/constants',
      },
    }
    
    package.cpath = tmp_path .. '/?.so'
    -- Must require Car first because Box depends on Car class and
    -- only Car.so has static members for Car.
    require 'traffic'
    assertType('table', traffic.Car)
  end, function()
    -- teardown
    package.loaded.traffic = nil
    package.cpath = cpath_bak
    if not traffic.Car then
      test.abort = true
    else
      Car = traffic.Car
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

function should.readGlobalConstant()
  assertEqual(1, traffic.One)
  assertEqual(2, traffic.Two)
  assertEqual(55, traffic.Three)
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

