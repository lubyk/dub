--[[------------------------------------------------------

  box2d dub.Inspector test
  ------------------------

  Test introspective operations with 'box2d' headers. To
  enable these tests, download Box2D into 
  test/fixtures/Box2D.

--]]------------------------------------------------------
require 'lubyk'

--=============================================== Only if Box2D present
local box2d_path = lk.dir() .. '/fixtures/Box2D'
if not lk.exist(box2d_path) then
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
  doc_dir = lk.dir() .. '/tmp',
}
local binder = dub.LuaBinder()

--=============================================== Build

function should.bindCompileAndLoad()
  -- create tmp directory
  local tmp_path = lk.dir() .. '/tmp'
  lk.rmTree(tmp_path, true)
  os.execute('mkdir -p ' .. tmp_path)

  -- How to avoid this step ?
  local c = ins:find('b2Vec2')

  function binder:name(elem)
    local name = elem.name
    if name then
      name = string.match(name, '^b2(.+)') or name
    end
    return name
  end

  function binder:constName(name)
    name = string.match(name, '^b2_(.+)') or name
    return name
  end

  binder:bind(ins, {
    output_directory = tmp_path,
    only = {
      'b2Vec2',
      'b2World',
      'b2BodyDef',
      'b2Body',
      'b2Shape',
      'b2PolygonShape',
      'b2FixtureDef',
    },
    -- Remove this part in headers
    header_base = box2d_path,
    -- Execute all lua_open in a single go
    -- with lua_openb2 (creates b2.cpp).
    single_lib = 'b2',
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
      test.abort = true
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

    printf("%4.2f %4.2f %4.2f\n", position.x, position.y, angle)
  end

  -- When the world destructor is called, all bodies and joints are freed. This can
  -- create orphaned pointers, so be careful about your world management.
end

test.all()

