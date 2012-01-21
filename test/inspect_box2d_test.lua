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
  print('skip Box2D')
  return
end

local should = test.Suite('dub.Inspector - Box2D')

local ins = dub.Inspector {
  INPUT   = {
    box2d_path .. '/Box2D/Common',
    box2d_path .. '/Box2D/Collision',
    box2d_path .. '/Box2D/Dynamics',
  },
  doc_dir = lk.dir() .. '/tmp',
}

--=============================================== TESTS
function should.parseClasses()
  local b2Vec2 = ins:find('b2Vec2')
  assertType('table', b2Vec2)
  local res = {}
  for met in b2Vec2:methods() do
    table.insert(res, met.name)
  end
  assertValueEqual({
    'b2Vec2',
    'SetZero',
    'Set',
    'operator- ',
    'operator()',
    'operator+=',
    'operator-=',
    'operator*=',
    'Length',
    'LengthSquared',
    'Normalize',
    'IsValid',
    'Skew',
    '~b2Vec2',
    '_get_',
    '_set_',
  }, res)
end

test.all()


