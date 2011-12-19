--[[------------------------------------------------------

  dub.Inspector
  -------------

  Test basic parsing and introspective operations with
  the 'simple' class.

--]]------------------------------------------------------
require 'lubyk'
-- Run the test with the dub directory as current path.
local should = test.Suite('dub.Inspector')

-- Test helper to prepare the inspector.
local function makeInspector()
  local ins = dub.Inspector()
  ins:parse('test/fixtures/simple/doc/xml')
  return ins
end

--=============================================== TESTS
function should.loadDub()
  assertType('table', dub)
end

function should.createInspector()
  local foo = dub.Inspector()
  assertType('table', foo)
end

function should.parseXml()
  local simple = dub.Inspector()
  assertPass(function()
    simple:parse('test/fixtures/simple/doc/xml')
  end)
end

function should.findSimpleClass()
  local ins = makeInspector()
  local simple = ins:find('Simple')
  assertEqual('class', simple.kind)
end

function should.findTypedef()
  local ins = makeInspector()
  local obj = ins:find('MyFloat')
  assertEqual('typedef', obj.kind)
end

function should.findMemberMethod()
  local ins = makeInspector()
  local Simple = ins:find('Simple')
  local obj = Simple:method('value')
  assertEqual('function', obj.kind)
end

function should.listMemberMethods()
  local ins = makeInspector()
  local Simple = ins:find('Simple')
  local res = {}
  for meth in Simple:methods() do
    table.insert(res, meth.name)
  end
  assertValueEqual({'Simple', 'value', 'add', 'setValue'}, res)
end

test.all()
