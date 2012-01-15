--[[------------------------------------------------------

  dub.Function
  ------------

  ...

--]]------------------------------------------------------
require 'lubyk'
local should = test.Suite('dub.Function')

local ins = dub.Inspector {
  doc_dir = 'test/tmp',
  INPUT   = 'test/fixtures/simple/include',
}

-- Test helper to prepare the inspector.
local function makeFunction(func_name)
  local func_name = func_name or 'add'
  return ins:find('Simple'):method(func_name)
end

--=============================================== TESTS
function should.autoload()
  assertType('table', dub.Function)
end

function should.beAClass()
  assertEqual('dub.Function', makeFunction().type)
end

function should.haveParams()
  local func = makeFunction()
  local res = {}
  local i = 0
  for param in func:params() do
    i = i + 1
    table.insert(res, {i, param.name})
  end
  assertValueEqual({{1, 'v'}, {2, 'w'}}, res)
end

function should.haveReturnValue()
  local func = makeFunction()
  local ret = func.return_value
  assertEqual('MyFloat', ret.name)
end

function should.notHaveReturnValue()
  local func = makeFunction('setValue')
  assertNil(func.return_value)
end

function should.haveLocation()
  local func = makeFunction()
  assertMatch('test/fixtures/simple/include/simple.h:[0-9]+', func.location)
end

function should.haveDefinition()
  local func = makeFunction()
  assertMatch('MyFloat Simple::add', func.definition)
end

function should.haveArgsString()
  local func = makeFunction()
  assertMatch('%(MyFloat v, double w=10%)', func.argsstring)
end

function should.markConstructorAsStatic()
  local func = makeFunction('Simple')
  assertTrue(func.static)
end

function should.haveSignature()
  local func = makeFunction()
  assertEqual('MyFloat, double', func.sign)
end

test.all()


