--[[------------------------------------------------------

  dub.Inspector
  -------------

  Test basic parsing and introspective operations with
  the 'simple' class.

--]]------------------------------------------------------
-- Run the test with the dub directory as current path.
package.path = 'lib/?.lua;test/helper/?.lua;'..package.path
require 'test'
require 'dub'
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
  assertEqual('class', simple.type)
end

test.all()
