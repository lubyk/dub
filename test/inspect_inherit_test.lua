--[[------------------------------------------------------

  dub.Inspector test
  ------------------

  Test introspective operations with the 'inherit' group
  of classes.

--]]------------------------------------------------------
local lub = require 'lub'
local lut = require 'lut'
local dub = require 'dub'

local should = lut.Test('dub.Inspector - inherit', {coverage = false})

local ins  = dub.Inspector {
  INPUT    = 'test/fixtures/inherit',
  doc_dir  = lub.path '|tmp',
}

--=============================================== TESTS

function should.listSuperClasses()
  local Child = ins:find 'Child'
  local res = {}
  for elem in Child:superclasses() do
    table.insert(res, elem.name)
  end
  assertValueEqual({
    'Parent',
    'GrandParent',
    'ChildHelper',
    'Mother',
  }, res)
end

function should.teardown()
  dub.warn = dub.printWarn
end

function should.listUnknownParentsDeclaredInDubComment()
  dub.warn = dub.silentWarn
    local Orphan = ins:find 'Orphan'
    local res = {}
    for elem in Orphan:superclasses() do
      table.insert(res, elem.name)
    end
    assertValueEqual({
      'Bar',
      'Foo< int >',
    }, res)
  dub.warn = dub.printWarn
end

function should.haveCastForUnknownParent()
  local Orphan = ins:find 'Orphan'
  local res = {}
  for elem in Orphan:methods() do
    table.insert(res, elem.name)
  end
  assertValueEqual({
    '~Orphan',
    '_cast_',
    'Orphan',
  }, res)
end

function should.listSuperMethods()
  local Child = ins:find 'Child'
  local res = {}
  for elem in Child:methods() do
    table.insert(res, elem.name)
  end
  assertValueEqual({
    '~Child',
    '_set_',
    '_get_',
    '_cast_',
    'Child',
    'x',
    'y',
    'returnUnk1',
    'returnUnk2',
    'methodWithUnknown',
    'name',
    'computeAge',
    'position',
    'addToX',
  }, res)
end

function should.listSuperAttributes()
  local Child = ins:find 'Child'
  local res = {}
  for elem in Child:attributes() do
    table.insert(res, elem.name)
  end
  assertValueEqual({
    'teeth',
    'status',
    'happy',
    'birth_year',
  }, res)
end

function should.haveVariables()
  local GrandChild = ins:find 'GrandChild'
  assertTrue(GrandChild:hasVariables())
  local res = {}
  for elem in GrandChild:attributes() do
    table.insert(res, elem.name)
  end
  assertValueEqual({
    'teeth',
    'status',
    'happy',
    'birth_year',
  }, res)
end

function should.getDubInfoInHelper()
  local ChildHelper = ins:find 'ChildHelper'
  assertEqual(false, ChildHelper.dub.bind)
  assertEqual(false, ChildHelper.dub.cast)
end

function should.resolveEnumWithParent()
  local Child  = ins:find 'Child'
  local Parent = ins:find 'Parent'
  local b = ins.db:resolveType(Child, 'MaritalStatus')
  assertValueEqual({
    name        = 'int',
    def         = 'int',
    create_name = 'Parent::MaritalStatus ',
    cast        = 'Parent::MaritalStatus',
    -- This is used to output default enum values.
    scope       = 'Parent',
  }, b)
  local c = ins.db:resolveType(Parent, 'MaritalStatus')
  assertValueEqual(b, c)
end

should:test()

