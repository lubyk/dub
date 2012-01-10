--[[------------------------------------------------------

  dub.Function
  ------------

  ...

--]]------------------------------------------------------
require 'lubyk'
local should = test.Suite('dub.Function')

-- Test helper to prepare the inspector.
local function makeFunction(func_name)
  local func_name = func_name or 'add'
  local ins = dub.Inspector()
  ins:parse('test/fixtures/simple/doc/xml')
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
  assertValueEqual({{1, 'v'}}, res)
end

function should.haveReturnValue()
  local func = makeFunction()
  local ret = func.return_value
  assertEqual('MyFloat', ret.ctype)
end

function should.notHaveReturnValue()
  local func = makeFunction('setValue')
  assertNil(func.return_value)
end

function should.haveLocation()
  local func = makeFunction()
  assertEqual('test/fixtures/simple/include/simple.h:18', func.location)
end

function should.markConstructorAsStatic()
  local func = makeFunction('Simple')
  assertTrue(func.static)
end

test.all()


