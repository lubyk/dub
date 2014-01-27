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

--=============================================== Only if Box2D present
local box2d_path = lub.path '|fixtures/Box2D'
if not lub.exist(box2d_path) then
  return
end

local should = lut.Test('dub.Inspector - Box2D', {coverage = false})

local ins = dub.Inspector {
  INPUT   = {
    box2d_path .. '/Box2D/Common',
    box2d_path .. '/Box2D/Collision',
    box2d_path .. '/Box2D/Dynamics',
  },
  doc_dir = lub.path '|tmp',
}

function should.ignoreFunctionsWithComplexParams()
  local res = {}
  for func in ins.db:functions() do
    res[func.name] = func
  end
  assertNil(res.b2GetPointStates)
  assertEqual('dub.Function', res.b2PairLessThan.type)
end

--=============================================== TESTS
function should.parseClasses()
  local b2Vec2 = ins:find('b2Vec2')
  assertType('table', b2Vec2)
  local res = {}
  for met in b2Vec2:methods() do
    table.insert(res, met.name)
  end
  assertValueEqual({
    '~b2Vec2',
    b2Vec2.SET_ATTR_NAME,
    b2Vec2.GET_ATTR_NAME,
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
  }, res)
end

should:test()


