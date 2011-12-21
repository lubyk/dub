--[[------------------------------------------------------

  dub.Function
  ------------

  ...

--]]------------------------------------------------------
require 'lubyk'
local should = test.Suite('dub.Function')

-- Test helper to prepare the inspector.
local function makeFunction()
  local ins = dub.Inspector()
  ins:parse('test/fixtures/simple/doc/xml')
  return ins:find('Simple'):method('add')
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

test.all()


