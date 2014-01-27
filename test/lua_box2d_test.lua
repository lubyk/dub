--[[------------------------------------------------------

  box2d dub.Inspector test
  ------------------------

  Test introspective operations with 'box2d' headers. To
  enable these tests, download Box2D into 
  test/fixtures/Box2D.

--]]------------------------------------------------------
local lub = require 'lub'
local lut = require 'lut'
local dub = require 'dub'

local should = lut.Test('dub.LuaBinder - Box2D', {coverage = false})

--=============================================== Only if Box2D present
local box2d_path = lub.path '|fixtures/Box2D'
if not lub.exist(box2d_path) then
  return
end

local should = test.Suite('dub.Inspector - Box2D')

local ins = dub.Inspector {
  INPUT   = {
    box2d_path .. '/Box2D/Common',
    box2d_path .. '/Box2D/Collision',
    box2d_path .. '/Box2D/Collision/Shapes',
    box2d_path .. '/Box2D/Dynamics',
  },
  doc_dir = lub.path '|tmp',
}
local binder = dub.LuaBinder()


function should.resolveUint8()
  local b2ContactFeature = ins:find('b2ContactFeature')
  local indexA = b2ContactFeature.variables_list[1]
  assertEqual('indexA', indexA.name)
  assertEqual('uint8', indexA.ctype.name)
  local rtype = binder:luaType(b2ContactFeature, indexA.ctype)
  assertEqual('number', rtype.type)
end

function should.resolveUnsignedInt()
  local b2ContactID = ins:find('b2ContactID')
  local key = b2ContactID.variables_list[2]
  assertEqual('key', key.name)
  assertEqual('uint32', key.ctype.name)
  local rtype = binder:luaType(b2ContactID, key.ctype)
  assertEqual('number', rtype.type)
end

--=============================================== Build

function should.bindCompileAndLoad()
  -- create tmp directory
  local tmp_path = lub.path '|tmp'
  lub.rmTree(tmp_path, true)
  os.execute('mkdir -p ' .. tmp_path)

  -- How to avoid this step ?
  local c = ins:find('b2Vec2')

  binder:bind(ins, {
    output_directory = tmp_path,
    only = {
      'b2Vec2',
      'b2World',
      'b2BodyDef',
      'b2Body',
      'b2Shape',
      'b2PolygonShape',
      'b2CircleShape',
      'b2FixtureDef',
    },
    -- Remove this part in headers
    header_base = box2d_path,
    -- Execute all lua_open in a single go
    -- with lua_openb2 (creates b2.cpp).
    single_lib = 'b2',

    -- Class and function name alterations
    name_filter = function(elem)
      local name = elem.name
      if name then
        name = string.match(name, '^b2(.+)') or name
      end
      return name
    end,

    const_name_filter = function(name)
      name = string.match(name, '^b2_(.+)') or name
      return name
    end,

  })

  local cpath_bak = package.cpath
  assertPass(function()
    -- Build static lib

    -- Build b2Vec2.so
    binder:build {
      output   = 'test/tmp/b2.so',
      inputs   = {
        -- Build this one with cmake
        'test/fixtures/Box2D/libBox2D.a',
        'test/tmp/dub/dub.cpp',
        'test/tmp/*.cpp',
      },
      includes = {
        'test/tmp',
        -- This is for lua.h
        'test/tmp/dub',
        box2d_path,
        'test/fixtures/Box2D',
      },
    }
    package.cpath = tmp_path .. '/?.so'
    --require 'Box'
    require 'b2'
    assertType('table', b2.Vec2)
  end, function()
    -- teardown
    package.loaded.b2 = nil
    package.cpath = cpath_bak
    if not b2.Vec2 then
      lut.Test.abort = true
    end
  end)
end

--=============================================== Box2D Hello World

function should.loadLib()
  local v = b2.Vec2(0, -10)
  assertEqual(0, v(0))
end

function should.runHelloWorld()
  -- Define the gravity vector.
  local gravity = b2.Vec2(0.0, -10.0)

  -- Construct a world object, which will hold and simulate the rigid bodies.
  local world = b2.World(gravity)

  -- Define the ground body.
  local groundBodyDef = b2.BodyDef()
  groundBodyDef.position:Set(0.0, -10.0)
  -- Call the body factory which allocates memory for the ground body
  -- from a pool and creates the ground box shape (also from a pool).
  -- The body is also added to the world.
  local groundBody = world:CreateBody(groundBodyDef)

  -- Define the ground box shape.
  local groundBox = b2.PolygonShape()
  -- The extents are the half-widths of the box.
  groundBox:SetAsBox(50.0, 10.0)

  -- Add the ground fixture to the ground body.
  groundBody:CreateFixture(groundBox, 0.0)
  
  -- Define the dynamic body. We set its position and call the body factory.
  local bodyDef = b2.BodyDef()
  bodyDef.type = b2.dynamicBody
  bodyDef.position:Set(0.0, 4.0)
  local body = world:CreateBody(bodyDef)
  -- Define another box shape for our dynamic body.
  local dynamicBox = b2.PolygonShape()
  dynamicBox:SetAsBox(1.0, 1.0)

  -- Define the dynamic body fixture.
  local fixtureDef = b2.FixtureDef()

  fixtureDef.shape = dynamicBox

  -- Set the box density to be non-zero, so it will be dynamic.
  fixtureDef.density = 1.0

  -- Override the default friction.
  fixtureDef.friction = 0.3

  -- Add the shape to the body.
  body:CreateFixture(fixtureDef)
  -- Prepare for simulation. Typically we use a time step of 1/60 of a
  -- second (60Hz) and 10 iterations. This provides a high quality simulation
  -- in most game scenarios.
  local timeStep = 1.0 / 60.0
  local velocityIterations = 6
  local positionIterations = 2

  -- This is our little game loop.
  for i=1,60 do
    -- Instruct the world to perform a single step of simulation.
    -- It is generally best to keep the time step and iterations fixed.
    world:Step(timeStep, velocityIterations, positionIterations)

    -- Now print the position and angle of the body.
    local position = body:GetPosition()
    local angle = body:GetAngle()

    --printf("%4.2f %4.2f %4.2f\n", position.x, position.y, angle)
  end

  -- When the world destructor is called, all bodies and joints are freed. This can
  -- create orphaned pointers, so be careful about your world management.
end

should:test()

